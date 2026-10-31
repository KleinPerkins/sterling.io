"""Exercise the App workflow boundary without GitHub writes or credential access."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('app_workflow', ROOT / 'Scripts/auto-merge.py')
app = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(app)


class AppWorkflowTests(unittest.TestCase):
    def exercise(self, *, rename=False, moved_head=False, passing_gate=True):
        head = 'a' * 40
        pr = {'number': 7, 'state': 'open', 'draft': False, 'base': {'ref': 'main'},
              'head': {'sha': head, 'ref': 'ordinary-tests', 'repo': {'full_name': app.REPO}},
              'author_association': 'OWNER', 'changed_files': 1}
        run = {'id': 10, 'event': 'pull_request', 'conclusion': 'success',
               'head_sha': head, 'head_repository': {'full_name': app.REPO}}
        entry = {'filename': 'Tests/test_example.py'}
        if rename:
            entry['previous_filename'] = 'Scripts/release.py'
        reviews = []
        reads = 0

        def fake_api(path, *, payload=None, token=None, paginate=False):
            nonlocal reads
            if '/commits/' in path:
                return [{'number': 7}]
            if '/files?' in path:
                self.assertTrue(paginate)
                return [[entry]]
            if '/jobs?' in path:
                self.assertEqual(token, 'fixture-read-token')
                return {'jobs': [{'name': 'ci-required', 'conclusion': 'success' if passing_gate else 'failure'}]}
            if path.endswith('/reviews'):
                reviews.append(payload)
                return {}
            self.assertEqual(path, f'repos/{app.REPO}/pulls/7')
            reads += 1
            result = copy.deepcopy(pr)
            if moved_head and reads > 1:
                result['head']['sha'] = 'b' * 40
            return result

        with tempfile.TemporaryDirectory() as directory:
            event = Path(directory) / 'event.json'
            event.write_text(json.dumps({'repository': {'full_name': app.REPO}, 'workflow_run': run}))
            with patch.dict(app.os.environ, {'GITHUB_EVENT_PATH': str(event), 'CI_READ_TOKEN': 'fixture-read-token'}), \
                 patch.object(app, 'api', side_effect=fake_api), \
                 patch.object(app.subprocess, 'run') as command:
                if passing_gate:
                    app.main()
                else:
                    with self.assertRaisesRegex(SystemExit, 'ci-required'):
                        app.main()
                return reviews, command.call_args_list

    def test_renaming_a_protected_file_cannot_gain_app_approval(self):
        reviews, commands = self.exercise(rename=True)
        self.assertEqual(reviews, [])
        self.assertEqual(commands, [])

    def test_push_between_eligibility_and_review_prevents_approval(self):
        reviews, commands = self.exercise(moved_head=True)
        self.assertEqual(reviews, [])
        self.assertEqual(commands, [])

    def test_successful_run_without_required_gate_cannot_merge(self):
        reviews, commands = self.exercise(passing_gate=False)
        self.assertEqual(reviews, [])
        self.assertEqual(commands, [])

    def test_ordinary_review_and_merge_are_bound_to_the_verified_commit(self):
        reviews, commands = self.exercise()
        self.assertEqual(reviews, [{'event': 'APPROVE', 'commit_id': 'a' * 40}])
        self.assertEqual(len(commands), 1)
        self.assertEqual(commands[0].args[0], ['gh', 'pr', 'merge', '7', '--repo', app.REPO,
                                             '--auto', '--squash', '--match-head-commit', 'a' * 40])


if __name__ == '__main__':
    unittest.main()
