import base64
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'Scripts'))
import readiness


def settings():
    return dict(APPLE_CERTIFICATE=base64.b64encode(b'certificate fixture').decode(),
                APPLE_CERTIFICATE_PASSWORD='test-only-password',
                APPLE_SIGNING_IDENTITY='Developer ID Application: Example (ABCDEFGHIJ)',
                APPLE_TEAM_ID='ABCDEFGHIJ', APPLE_ID='example@example.invalid',
                APPLE_PASSWORD='test-only-apple-password', SPARKLE_PRIVATE_ED_KEY='test-only-update-key',
                SPARKLE_PUBLIC_ED_KEY=base64.b64encode(b'p' * 32).decode())


class ReadinessTests(unittest.TestCase):
    def test_missing_and_mismatched_credentials_fail_before_import(self):
        self.assertEqual(readiness.configuration(settings()), b'certificate fixture')
        for key, value in [('APPLE_ID', ''), ('APPLE_TEAM_ID', 'WRONGTEAM0'),
                           ('APPLE_SIGNING_IDENTITY', 'Apple Development: Example (ABCDEFGHIJ)'),
                           ('APPLE_CERTIFICATE', 'not base64'), ('SPARKLE_PUBLIC_ED_KEY', 'short')]:
            with self.subTest(key=key):
                env = settings()
                env[key] = value
                with self.assertRaises(readiness.ReadinessError):
                    readiness.configuration(env)

    def test_failed_commands_do_not_expose_arguments_or_output(self):
        secret = 'sensitive-fixture-value'
        with patch.object(readiness.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, secret, secret)):
            with self.assertRaises(readiness.ReadinessError) as error:
                readiness.command('Certificate import', 'security', secret)
        self.assertNotIn(secret, str(error.exception))
        self.assertIn('Certificate import', str(error.exception))

    def test_keychain_and_certificate_removed_after_import_or_body_failure(self):
        for import_failure in (False, True):
            calls = []
            with self.subTest(import_failure=import_failure), tempfile.TemporaryDirectory() as name:
                temp = Path(name)
                def command(stage, *args, **kwargs):
                    calls.append(args)
                    if args[:2] == ('security', 'create-keychain'):
                        Path(args[-1]).touch()
                    if import_failure and args[:2] == ('security', 'import'):
                        raise readiness.ReadinessError('import failed')
                    if args[:2] == ('security', 'delete-keychain'):
                        Path(args[-1]).unlink()
                    return subprocess.CompletedProcess(args, 0, '"/tmp/original.keychain-db"\n', '')
                with patch.object(readiness, 'command', side_effect=command), self.assertRaises(readiness.ReadinessError):
                    with readiness.signing_keychain(temp, b'fixture', settings()):
                        raise readiness.ReadinessError('later stage failed')
                self.assertFalse((temp / 'certificate.p12').exists())
                self.assertFalse((temp / 'readiness.keychain-db').exists())
                self.assertEqual(calls[-2], ('security', 'list-keychains', '-d', 'user', '-s', '/tmp/original.keychain-db'))
                self.assertEqual(calls[-1][:2], ('security', 'delete-keychain'))

    def test_readiness_never_submits_or_publishes_and_rejects_accepted_tampering(self):
        for tampered_code in (0, 1):
            calls = []
            def command(stage, *args, **kwargs):
                calls.append(args)
                stdout, stderr, code = '', '', 0
                if stage == 'Validate certificate trust':
                    stdout = '1) 000 "' + settings()['APPLE_SIGNING_IDENTITY'] + '"'
                if stage == 'Inspect Developer ID signature':
                    stderr = 'TeamIdentifier=ABCDEFGHIJ\nflags=0x10000(runtime)\n'
                if stage == 'Reject tampered update':
                    code = tampered_code
                if stage == 'Read commit':
                    stdout = 'a' * 40
                return subprocess.CompletedProcess(args, code, stdout, stderr)
            with self.subTest(tampered_code=tampered_code), patch.object(readiness, 'command', side_effect=command), patch.object(readiness.release, 'tools_directory', side_effect=lambda temp: temp):
                if tampered_code == 0:
                    with self.assertRaisesRegex(readiness.ReadinessError, 'tampered'):
                        readiness.verify_credentials(settings())
                else:
                    receipt = readiness.verify_credentials(settings())
                    self.assertTrue(receipt['developer_id_signing'])
                    self.assertFalse(receipt['product_notarized'])
                    self.assertFalse(receipt['release_published'])
            self.assertFalse(any('submit' in call or 'gh' in call for call in calls))

    def test_workflow_entry_rejects_non_main_before_reading_credentials(self):
        with patch.dict(readiness.os.environ, {'GITHUB_REPOSITORY': 'KleinPerkins/sterling.io',
                                              'GITHUB_REF': 'refs/heads/feature'}, clear=True), patch.object(readiness, 'verify_credentials') as verify:
            with self.assertRaises(readiness.ReadinessError):
                readiness.main()
            verify.assert_not_called()


if __name__ == '__main__':
    unittest.main()
