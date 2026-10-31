#!/usr/bin/env python3
"""Deterministic Swift shards and an exact-coverage, fail-closed CI gate."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PLATFORMS = ('macos-15', 'macos-26')
MAX_SHARDS = 8


def shard_count(value):
    if isinstance(value, bool) or not isinstance(value, int) or not 1 <= value <= MAX_SHARDS:
        raise ValueError('native_shards must be an integer from 1 to 8')
    return value


def configuration(root=ROOT):
    config = json.loads((root / '.github/test-shards.json').read_text())
    if set(config) != {'schema', 'native_shards'} or config['schema'] != 'sterling-test-shards/v1':
        raise ValueError('Unknown test-sharding configuration')
    return shard_count(config['native_shards'])


def inventory(lines):
    ids = [line.strip() for line in lines if line.strip()]
    if not ids or len(ids) != len(set(ids)):
        raise ValueError('Test inventory must be nonempty and unique')
    if any(not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*\.[^\s/]+/[^\s]+', test) for test in ids):
        raise ValueError('Unsupported discovery output; refusing to omit tests')
    return sorted(ids)


def partition(ids, count):
    shard_count(count)
    ids = inventory(ids)
    groups = [[] for _ in range(count)]
    for test in ids:
        bucket = int.from_bytes(hashlib.sha256(test.encode()).digest()[:8], 'big') % count
        groups[bucket].append(test)
    if any(not group for group in groups):
        raise ValueError('Empty shard: reduce the configured shard count')
    return groups


def filter_pattern(ids):
    # Swift Testing appends /source-file:line:column to its runtime ID, while
    # SwiftPM discovery omits it. Keep a component boundary instead of an end anchor.
    return '^(?:' + '|'.join(re.escape(test) for test in inventory(ids)) + ')(?:/|$)'


def observed_tests(path):
    raw = path.read_bytes()
    if b'<!DOCTYPE' in raw.upper() or b'<!ENTITY' in raw.upper():
        raise ValueError('Unexpected XML declarations')
    root = ET.fromstring(raw)
    if root.tag not in ('testsuite', 'testsuites'):
        raise ValueError('Unexpected xUnit root')
    if any(list(root.iter(tag)) for tag in ('failure', 'error', 'skipped')):
        raise ValueError('Failed, errored, or skipped tests are not complete coverage')
    suites = list(root.iter('testsuite'))
    if any(int(s.get(name, '0')) != 0 for s in suites for name in ('failures', 'errors', 'skipped')):
        raise ValueError('Non-passing xUnit suite')
    ids = [case.attrib['classname'] + '/' + case.attrib['name'] for case in root.iter('testcase')]
    return inventory(ids)


def digest_ids(ids):
    return hashlib.sha256(json.dumps(ids, separators=(',', ':')).encode()).hexdigest()


def source_digest():
    paths = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT).decode().split('\0')
    digest = hashlib.sha256()
    for path in sorted(set(paths) - {''}):
        file = ROOT / path
        if file.is_file():
            digest.update(path.encode() + b'\0' + file.read_bytes())
    return digest.hexdigest()


def command(args, log):
    started = time.monotonic()
    result = subprocess.run([str(arg) for arg in args], cwd=ROOT, capture_output=True, text=True)
    log.write_text(result.stdout + result.stderr)
    if result.returncode:
        print('\n'.join((result.stdout + result.stderr).splitlines()[-60:]))
        raise RuntimeError('Test command failed; see ' + str(log.relative_to(ROOT)))
    return result.stdout, round(time.monotonic() - started, 3)


def run_shard(platform, index, count):
    shard_count(count)
    if platform not in PLATFORMS or not 0 <= index < count:
        raise ValueError('Invalid platform or shard index')
    directory = ROOT / 'outputs/ci' / f'{platform}-{index}'
    directory.mkdir(parents=True, exist_ok=True)
    receipt = directory / 'receipt.json'
    report = directory / 'tests.xml'
    receipt.unlink(missing_ok=True)
    report.unlink(missing_ok=True)
    # Discovery is compiler-owned and includes every current/future test target.
    # Each runner builds once; the selected tests reuse that exact build.
    listing, discovery_seconds = command([ROOT / 'Scripts/swift.sh', 'test', 'list'], directory / 'discovery.log')
    ids = inventory(listing.splitlines())
    selected = partition(ids, count)[index]
    pattern = filter_pattern(selected)
    _, test_seconds = command([ROOT / 'Scripts/swift.sh', 'test', '--skip-build', '--filter', pattern,
                               '--xunit-output', report], directory / 'tests.log')
    executed = observed_tests(report)
    if executed != selected:
        raise ValueError('Executed test IDs differ from the selected shard')
    data = {'schema': 'sterling-test-shard/v1', 'platform': platform, 'index': index, 'count': count,
            'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
            'source_digest': source_digest(), 'inventory': ids, 'inventory_sha256': digest_ids(ids),
            'selected': selected, 'executed': executed,
            'report_sha256': hashlib.sha256(report.read_bytes()).hexdigest(),
            'discovery_build_seconds': discovery_seconds, 'test_seconds': test_seconds}
    receipt.write_text(json.dumps(data, indent=2) + '\n')
    print(f'{platform} shard {index + 1}/{count}: {len(executed)}/{len(ids)} tests verified; '
          f'discovery/build {discovery_seconds}s; execution {test_seconds}s')


def validate_receipts(receipts, count, commit, platforms=PLATFORMS, expected_source=None):
    shard_count(count)
    expected = {(platform, index) for platform in platforms for index in range(count)}
    seen = set()
    inventory_digest = None
    source = None
    for receipt in receipts:
        if receipt.get('schema') != 'sterling-test-shard/v1':
            raise ValueError('Unknown receipt schema')
        if type(receipt['index']) is not int or type(receipt['count']) is not int:
            raise ValueError('Shard index and count must be integers')
        for field in ('discovery_build_seconds', 'test_seconds'):
            value = receipt[field]
            if type(value) not in (int, float) or not math.isfinite(value) or value < 0:
                raise ValueError('Invalid timing evidence')
        key = (receipt['platform'], receipt['index'])
        if key not in expected or key in seen or receipt['count'] != count or receipt['commit'] != commit:
            raise ValueError('Unexpected, duplicate, stale, or misconfigured shard receipt')
        ids = inventory(receipt['inventory'])
        calculated = digest_ids(ids)
        if calculated != receipt['inventory_sha256'] or (inventory_digest and calculated != inventory_digest):
            raise ValueError('Test inventories differ across shards/platforms')
        if not re.fullmatch(r'[a-f0-9]{64}', receipt['source_digest']) or (source and source != receipt['source_digest']):
            raise ValueError('Shard source snapshots differ')
        if expected_source is not None and receipt['source_digest'] != expected_source:
            raise ValueError('Shard source does not match the aggregate checkout')
        inventory_digest, source = calculated, receipt['source_digest']
        selected = partition(ids, count)[receipt['index']]
        if receipt['selected'] != selected or receipt['executed'] != selected:
            raise ValueError('Missing, extra, duplicate, or incorrectly assigned executed tests')
        seen.add(key)
    if seen != expected:
        raise ValueError('Missing required shard receipts')


def aggregate(directory, count, commit, needs):
    if set(needs) != {'quality', 'native'} or any(job.get('result') != 'success' for job in needs.values()):
        raise ValueError('Every CI job must succeed; skipped/cancelled/unknown results fail')
    receipts = []
    for path in sorted(directory.rglob('receipt.json')):
        receipt = json.loads(path.read_text())
        report = path.parent / 'tests.xml'
        if hashlib.sha256(report.read_bytes()).hexdigest() != receipt['report_sha256']:
            raise ValueError('Test report digest mismatch')
        if observed_tests(report) != receipt['executed']:
            raise ValueError('Receipt does not match the executed test report')
        receipts.append(receipt)
    validate_receipts(receipts, count, commit, expected_source=source_digest())
    lines = ['| Platform | Shard | Tests | Discovery/build seconds | Test seconds |',
             '|---|---:|---:|---:|---:|']
    for item in receipts:
        lines.append(f"| {item['platform']} | {item['index'] + 1}/{count} | {len(item['executed'])} | "
                     f"{item['discovery_build_seconds']} | {item['test_seconds']} |")
    print('\n'.join(lines))
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as output:
            output.write('\n'.join(lines) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    plan = sub.add_parser('plan')
    plan.add_argument('--shards', type=int)
    run = sub.add_parser('run')
    run.add_argument('--platform', choices=PLATFORMS, required=True)
    run.add_argument('--index', type=int, required=True)
    run.add_argument('--shards', type=int)
    gate = sub.add_parser('aggregate')
    gate.add_argument('--directory', type=Path, required=True)
    gate.add_argument('--shards', type=int, required=True)
    args = parser.parse_args()
    configured = configuration()
    count = configured if args.shards is None else shard_count(args.shards)
    if args.command == 'plan':
        matrix = {'include': [{'os': os_name, 'shard': index, 'count': count}
                              for os_name in PLATFORMS for index in range(count)]}
        output = 'shards=' + str(count) + '\nmatrix=' + json.dumps(matrix, separators=(',', ':')) + '\n'
        if os.environ.get('GITHUB_OUTPUT'):
            with open(os.environ['GITHUB_OUTPUT'], 'a') as file:
                file.write(output)
        print(output, end='')
    elif args.command == 'run':
        run_shard(args.platform, args.index, count)
    else:
        commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        aggregate(args.directory, count, commit, json.loads(os.environ['CI_NEEDS_JSON']))


if __name__ == '__main__':
    main()
