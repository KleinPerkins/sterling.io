"""Release trust boundaries and bot policy; no network, credentials or signing required."""
import base64
import copy
import importlib.util
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Scripts"))
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'Scripts' / filename)
    value = importlib.util.module_from_spec(spec); spec.loader.exec_module(value); return value
release = module('release', 'release.py')
merge = module('auto_merge', 'auto-merge.py')

class ReleaseTests(unittest.TestCase):
    def feed(self):
        return f'''<rss xmlns:sparkle="{release.NS[1:-1]}"><channel><item>
        <sparkle:version>1.2.3</sparkle:version><sparkle:minimumSystemVersion>15.0.0</sparkle:minimumSystemVersion>
        <enclosure url="https://github.com/KleinPerkins/sterling.io/releases/download/sterling-v1.2.3/Sterling-1.2.3-universal.zip"
        sparkle:edSignature="{base64.b64encode(bytes(64)).decode()}" length="20"/>
        </item></channel></rss>'''.encode()
    def test_tag_rejects_commands_traversal_and_nonstable_versions(self):
        for tag in ('sterling-v1.2.3;true', '../main', '-x', 'v1.2.3', 'sterling-v01.2.3', 'sterling-v1.2.3-beta'):
            with self.subTest(tag=tag), self.assertRaises(ValueError): release.version_for(tag)
        self.assertEqual(release.version_for('sterling-v1.2.3'), '1.2.3')
    def test_feed_binds_version_archive_signature_and_size(self):
        self.assertEqual(release.validate_feed(self.feed(), 'sterling-v1.2.3')[2], 20)
        for before, after in ((b'<sparkle:version>1.2.3', b'<sparkle:version>1.2.4'),
                              (b'https://github.com/', b'https://evil.example/'),
                              (b'length="20"', b'length="0"'),
                              (base64.b64encode(bytes(64)), b'bad')):
            with self.subTest(before=before), self.assertRaises(ValueError):
                release.validate_feed(self.feed().replace(before, after), 'sterling-v1.2.3')
    def test_feed_rejects_entities_and_multiple_items(self):
        for data in (b'<!DOCTYPE rss>'+self.feed(), self.feed().replace(b'</channel>',b'<item/></channel>')):
            with self.assertRaises(ValueError): release.validate_feed(data,'sterling-v1.2.3')
    def test_missing_secrets_fail_before_build_or_import(self):
        with patch.dict(release.os.environ, {}, clear=True), patch.object(release, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'Missing release configuration'): release.package('sterling-v1.2.3')
            run.assert_not_called()
    def test_published_release_assets_are_never_replaced(self):
        with patch.object(release,'api',return_value={'draft':False}), patch.object(release,'run') as run:
            with self.assertRaisesRegex(ValueError,'published'): release.publish('sterling-v1.2.3')
            run.assert_not_called()
    def test_tag_ci_failure_prevents_checkout(self):
        def api(path):
            if path == '': return {'private':False}
            if path.startswith('releases/'): return {'draft':True,'prerelease':False}
            return {'check_runs':[{'app':{'slug':'github-actions'},'status':'completed','conclusion':'failure'}]}
        def run(*args,**kwargs): return '1.2.3' if args[:2] == ('git','show') else 'a'*40
        with patch.object(release,'api',side_effect=api), patch.object(release,'run',side_effect=run) as command:
            with self.assertRaisesRegex(ValueError,'CI failed'): release.prepare('sterling-v1.2.3')
            self.assertFalse(any('checkout' in c.args for c in command.call_args_list))
    def test_live_feed_failure_restores_previous_latest(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);dist=root/'outputs/release';dist.mkdir(parents=True)
            (dist/'release-receipt.json').write_text(json.dumps({'commit':'abc','sha256':{}}))
            calls=[]
            def api(path,payload=None):
                calls.append((path,payload))
                return {'id':2,'draft':True}
            def smoke(*args,**kwargs):
                if kwargs.get('latest'): raise ValueError('bad live feed')
            previous=type('Result',(),{'returncode':0,'stdout':json.dumps({'id':1,'tag_name':'sterling-v1.2.2'}),'stderr':''})()
            with patch.object(release,'ROOT',root),patch.object(release,'api',side_effect=api),patch.object(release,'run',return_value='abc'),patch.object(release.subprocess,'run',return_value=previous),patch.object(release,'public_smoke',side_effect=smoke),patch.object(release.time,'sleep'),patch.dict(release.os.environ,{'SPARKLE_PUBLIC_ED_KEY':'public'}):
                with self.assertRaisesRegex(ValueError,'bad live feed'): release.publish('sterling-v1.2.3')
            self.assertEqual(calls[-1],('releases/1',{'make_latest':'true'}))
            self.assertIn(('releases/2',{'draft':False,'make_latest':'false'}),calls)

class AutoMergeTests(unittest.TestCase):
    def setUp(self):
        self.run={'event':'pull_request','conclusion':'success','head_repository':{'full_name':merge.REPO},'head_sha':'a'*40}
        self.pr={'state':'open','draft':False,'number':7,'base':{'ref':'main','repo':{'full_name':merge.REPO}},'head':{'repo':{'full_name':merge.REPO},'sha':'a'*40,'ref':'feature'},'author_association':'OWNER'}
    def test_ordinary_verified_head_eligible(self):
        self.assertTrue(merge.eligible(self.pr,self.run,['Sources/SterlingCore/Simulation.swift']))
    def test_release_and_draft_prs_require_human(self):
        for field,value in [('draft',True),('state','closed')]:
            pr=copy.deepcopy(self.pr);pr[field]=value;self.assertFalse(merge.eligible(pr,self.run,['README.md']))
        self.pr['head']['ref']='release-please--branches--main'
        self.assertFalse(merge.eligible(self.pr,self.run,['CHANGELOG.md']))
    def test_forks_and_head_races_are_rejected(self):
        self.pr['head']['sha']='b'*40;self.assertFalse(merge.eligible(self.pr,self.run,['README.md']))
        self.pr['head']['sha']='a'*40;self.pr['head']['repo']['full_name']='someone/fork'
        self.assertFalse(merge.eligible(self.pr,self.run,['README.md']))
    def test_privileged_paths_are_manual(self):
        for path in ('.github/workflows/release.yml','Scripts/release.py','Configuration/signing.entitlements','Sources/SterlingPrototype/AppUpdater.swift','AGENTS.md','Makefile','.gitleaks.toml','Package.resolved','VERSION'):
            with self.subTest(path=path):self.assertFalse(merge.eligible(self.pr,self.run,[path]))
    def test_dependabot_and_untrusted_authors_cannot_use_ordinary_policy(self):
        self.pr['author_association']='NONE';self.pr['user']={'login':'unknown'}
        self.assertFalse(merge.eligible(self.pr,self.run,['README.md']))
        self.pr['user']['login']='dependabot[bot]'
        self.assertFalse(merge.eligible(self.pr,self.run,['README.md']))
    def test_failed_ci_and_empty_file_lists_never_approve(self):
        self.assertFalse(merge.eligible(self.pr,self.run,[]))
        self.run['conclusion']='failure';self.assertFalse(merge.eligible(self.pr,self.run,['README.md']))

class TestReportingTests(unittest.TestCase):
    def test_older_toolchain_without_final_suite_count(self):
        reporting=module('test_reporting','test_reporting.py')
        log="Suite UpdateConfigurationTests passed after 0.1 seconds.\nSuite InteractionTests passed after 0.1 seconds.\nSuite SimulationTests passed after 0.2 seconds.\nTest run with 21 tests passed after 0.2 seconds."
        self.assertEqual(reporting.parse_summary(log),(21,3))
    def test_newer_toolchain_separate_target_summaries(self):
        reporting=module('test_reporting','test_reporting.py')
        log="Test run with 4 tests in 1 suite passed after 0.1 seconds.\nTest run with 17 tests in 2 suites passed after 0.2 seconds."
        self.assertEqual(reporting.parse_summary(log),(21,3))
    def test_empty_failed_or_zero_test_runs_are_rejected(self):
        reporting=module('test_reporting','test_reporting.py')
        for log in ('','Test run with 21 tests failed.','Test run with 0 tests in 0 suites passed.'):
            with self.subTest(log=log),self.assertRaises(ValueError):reporting.parse_summary(log)

if __name__=='__main__':unittest.main()
