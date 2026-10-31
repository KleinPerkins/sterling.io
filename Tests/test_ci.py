import copy
import hashlib
import json
from pathlib import Path
import sys
import re
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'Scripts'))
import ci

IDS = [f'CoreTests.Example/test{i}()' for i in range(40)]
COMMIT = 'a' * 40


def receipts(count=2):
    ids = ci.inventory(IDS)
    groups = ci.partition(ids, count)
    return [dict(schema='sterling-test-shard/v1', platform=platform, index=index, count=count,
                 commit=COMMIT, source_digest='b' * 64, inventory=ids,
                 inventory_sha256=ci.digest_ids(ids), selected=selected, executed=selected,
                 discovery_build_seconds=1.0, test_seconds=0.1)
            for platform in ci.PLATFORMS for index, selected in enumerate(groups)]


def report(path, ids):
    suite = ET.Element('testsuite', tests=str(len(ids)), failures='0', errors='0')
    for test in ids:
        classname, name = test.split('/')
        ET.SubElement(suite, 'testcase', classname=classname, name=name)
    ET.ElementTree(suite).write(path)


class TestShards(unittest.TestCase):
    def test_partition_is_stable_disjoint_complete_and_accepts_future_targets(self):
        ids = IDS + ['NewTests.Future/newBehavior()']
        groups = ci.partition(ids, 3)
        self.assertEqual(groups, ci.partition(reversed(ids), 3))
        self.assertEqual(sorted(sum(groups, [])), sorted(ids))
        self.assertEqual(len(set(sum(groups, []))), len(ids))
        self.assertTrue(all(groups))

    def test_filter_allows_runtime_source_suffix_without_matching_other_tests(self):
        pattern = ci.filter_pattern([IDS[0]])
        self.assertRegex(IDS[0], pattern)
        self.assertRegex(IDS[0] + '/CoreTests/Test.swift:12:3', pattern)
        self.assertIsNone(re.search(pattern, IDS[0] + 'Extra'))
        self.assertIsNone(re.search(pattern, 'Another' + IDS[0]))

    def test_inventory_rejects_empty_duplicate_and_unknown_discovery(self):
        for ids in ([], ['no tests found'], [IDS[0], IDS[0]], ['warning: unsupported']):
            with self.subTest(ids=ids), self.assertRaises(ValueError):
                ci.inventory(ids)
        self.assertEqual(ci.inventory(['', IDS[0], '\n']), [IDS[0]])

    def test_partition_rejects_empty_shards_and_invalid_counts(self):
        for count in (0, 9, True, '2', 1.5):
            with self.subTest(count=count), self.assertRaises(ValueError):
                ci.partition(IDS, count)
        with self.assertRaises(ValueError):
            ci.partition([IDS[0]], 2)

    def test_configuration_rejects_unknown_schema_fields_and_types(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            (root / '.github').mkdir()
            path = root / '.github/test-shards.json'
            path.write_text(json.dumps({'schema': 'sterling-test-shards/v1', 'native_shards': 2}))
            self.assertEqual(ci.configuration(root), 2)
            for config in ({}, {'schema': 'v2', 'native_shards': 2},
                           {'schema': 'sterling-test-shards/v1', 'native_shards': True},
                           {'schema': 'sterling-test-shards/v1', 'native_shards': 2, 'skip': True}):
                path.write_text(json.dumps(config))
                with self.subTest(config=config), self.assertRaises(ValueError):
                    ci.configuration(root)

    def test_receipts_require_every_exact_current_shard(self):
        valid = receipts()
        ci.validate_receipts(valid, 2, COMMIT)
        cases = [valid[:-1], valid + [valid[0]]]
        for key, value in [('commit', 'stale'), ('count', 1), ('index', 7), ('platform', 'linux'),
                           ('schema', 'unknown'), ('index', True), ('test_seconds', -1), ('test_seconds', float('nan')), ('inventory_sha256', 'c' * 64),
                           ('source_digest', 'c' * 64), ('selected', []), ('executed', []),
                           ('executed', valid[0]['executed'] + [valid[0]['executed'][0]])]:
            changed = copy.deepcopy(valid)
            changed[0][key] = value
            cases.append(changed)
        for changed in cases:
            with self.subTest(changed=changed[0]), self.assertRaises(ValueError):
                ci.validate_receipts(changed, 2, COMMIT)

    def test_mutually_consistent_receipts_from_another_source_snapshot_fail(self):
        with self.assertRaisesRegex(ValueError, 'aggregate checkout'):
            ci.validate_receipts(receipts(), 2, COMMIT, expected_source='c' * 64)

    def test_discovery_drift_is_rejected_even_if_receipt_is_self_consistent(self):
        changed = receipts()
        ids = ci.inventory(IDS + ['ExtraTests.Future/added()'])
        changed[0].update(inventory=ids, inventory_sha256=ci.digest_ids(ids),
                          selected=ci.partition(ids, 2)[0], executed=ci.partition(ids, 2)[0])
        with self.assertRaisesRegex(ValueError, 'inventories differ'):
            ci.validate_receipts(changed, 2, COMMIT)

    def test_xunit_rejects_skips_failures_duplicates_and_xml_entities(self):
        with tempfile.TemporaryDirectory() as name:
            path = Path(name) / 'report.xml'
            report(path, [IDS[0]])
            self.assertEqual(ci.observed_tests(path), [IDS[0]])
            for tag in ('failure', 'error', 'skipped'):
                report(path, [IDS[0]])
                tree = ET.parse(path)
                ET.SubElement(tree.getroot()[0], tag)
                tree.write(path)
                with self.subTest(tag=tag), self.assertRaises(ValueError):
                    ci.observed_tests(path)
            for body in ('<testsuite tests="0"/>', '<other/>', '<!DOCTYPE x><testsuite/>',
                         '<testsuite errors="1"/>'):
                path.write_text(body)
                with self.assertRaises(ValueError):
                    ci.observed_tests(path)
            report(path, [IDS[0], IDS[0]])
            with self.assertRaises(ValueError):
                ci.observed_tests(path)

    def test_aggregate_binds_artifacts_to_reports_and_requires_all_jobs(self):
        needs = {'quality': {'result': 'success'}, 'native': {'result': 'success'}}
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            for item in receipts():
                directory = root / f"{item['platform']}-{item['index']}"
                directory.mkdir()
                xml = directory / 'tests.xml'
                report(xml, item['executed'])
                item['report_sha256'] = hashlib.sha256(xml.read_bytes()).hexdigest()
                (directory / 'receipt.json').write_text(json.dumps(item))
            with patch.object(ci, 'source_digest', return_value='b' * 64):
                ci.aggregate(root, 2, COMMIT, needs)
            for result in ('failure', 'skipped', 'cancelled', None, 'unknown'):
                changed = copy.deepcopy(needs)
                changed['native']['result'] = result
                with self.subTest(result=result), self.assertRaises(ValueError):
                    ci.aggregate(root, 2, COMMIT, changed)
            with self.assertRaises(ValueError):
                ci.aggregate(root, 2, COMMIT, {'quality': {'result': 'success'}})
            xml.write_text('<testsuite/>')
            with self.assertRaisesRegex(ValueError, 'digest mismatch'):
                ci.aggregate(root, 2, COMMIT, needs)


if __name__ == '__main__':
    unittest.main()
