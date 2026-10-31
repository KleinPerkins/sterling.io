"""Exercise ordinary App policy without GitHub writes or credential access."""
import copy
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'Scripts'))
SPEC = importlib.util.spec_from_file_location('app_workflow', ROOT / 'Scripts/auto-merge.py')
app = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(app)


class AppWorkflowTests(unittest.TestCase):
    def exercise(self, *, rename=False, moved_head=False, passing_gate=True,
                 dependabot=False, approval_error=False, merge_error=False, already=False):
        head = 'a' * 40
        reviewer = {'login': 'sterling-test-app[bot]', 'id': 12345, 'type': 'Bot'}
        pr = {'number': 7, 'state': 'open', 'draft': False,
              'base': {'ref': 'main', 'repo': {'full_name': app.REPO}},
              'head': {'sha': head, 'ref': 'ordinary-tests', 'repo': {'full_name': app.REPO}},
              'author_association': 'OWNER', 'changed_files': 1,
              'auto_merge': {'merge_method': 'squash'} if already else None}
        if dependabot:
            pr['user'] = {'login': 'dependabot[bot]', 'id': 49699333, 'type': 'Bot'}
        run = {'id': 10, 'event': 'pull_request', 'conclusion': 'success',
               'head_sha': head, 'head_repository': {'full_name': app.REPO},
               'actor': {'login': 'some-app[bot]'}}
        entry = {'filename': 'Tests/test_example.py'}
        if rename:
            entry['previous_filename'] = 'Scripts/release.py'
        reviews, reads = [], 0

        def fake_api(path, *, payload=None, token=None, paginate=False, **kwargs):
            nonlocal reads
            if path.startswith('users/'):
                return reviewer
            if '/check-runs?' in path:
                self.assertEqual(token, 'fixture-read-token')
                return [{'check_runs': [{'name': 'ci-required', 'head_sha': head, 'status': 'completed',
                                         'conclusion': 'success' if passing_gate else 'failure', 'app': {'id': 15368}}]}]
            if '/commits/' in path:
                return [[{'number': 7}]]
            if '/files?' in path:
                self.assertTrue(paginate)
                return [[entry]]
            if '/reviews?' in path:
                return [[{'id': 1, 'user': reviewer, 'state': 'APPROVED', 'commit_id': head}]] if already else [[]]
            if path.endswith('/reviews'):
                if approval_error:
                    raise app.AutomationError('Approval failed (HTTP 403)')
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
            with patch.dict(app.os.environ, {'GITHUB_EVENT_PATH': str(event), 'CI_READ_TOKEN': 'fixture-read-token',
                                             'REVIEWER_LOGIN': reviewer['login']}), \
                 patch.object(app, 'api', side_effect=fake_api), \
                 patch.object(app, 'enable_merge', side_effect=app.AutomationError('Merge failed') if merge_error else None) as merge:
                result = app.main()
                return result, reviews, merge.call_args_list

    def test_renaming_a_protected_file_cannot_gain_app_approval(self):
        result, reviews, commands = self.exercise(rename=True)
        self.assertEqual((result, reviews, commands), (0, [], []))

    def test_push_between_eligibility_and_review_prevents_approval(self):
        result, reviews, commands = self.exercise(moved_head=True)
        self.assertEqual((result, reviews, commands), (0, [], []))

    def test_successful_run_without_current_required_gate_cannot_merge(self):
        result, reviews, commands = self.exercise(passing_gate=False)
        self.assertEqual((result, reviews, commands), (0, [], []))

    def test_ordinary_review_and_merge_are_bound_to_the_verified_commit(self):
        result, reviews, commands = self.exercise()
        self.assertEqual(result, 0)
        self.assertEqual(reviews[0]['event'], 'APPROVE')
        self.assertEqual(reviews[0]['commit_id'], 'a' * 40)
        self.assertEqual(commands[0].args, (7, 'a' * 40))

    def test_app_triggered_dependabot_events_never_use_ordinary_policy(self):
        self.assertEqual(self.exercise(dependabot=True), (0, [], []))

    def test_approval_and_merge_errors_are_not_swallowed(self):
        self.assertEqual(self.exercise(approval_error=True)[0], 1)
        self.assertEqual(self.exercise(merge_error=True)[0], 1)

    def test_repeated_run_does_not_duplicate_approval_or_auto_merge(self):
        self.assertEqual(self.exercise(already=True), (0, [], []))


if __name__ == '__main__':
    unittest.main()
