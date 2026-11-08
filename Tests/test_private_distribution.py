"""Contain the legacy publisher until a private delivery profile is qualified."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('contained_release', ROOT / 'Scripts/release.py')
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class PrivateDistributionContainmentTests(unittest.TestCase):
    def test_all_release_entrypoints_refuse_before_external_effects(self):
        for name in ('distribution_preflight', 'prepare', 'package', 'publish'):
            with self.subTest(command=name), \
                 patch.object(release, 'run') as run, \
                 patch.object(release, 'api') as api, \
                 patch.object(release, 'download') as download, \
                 patch.object(release.subprocess, 'run') as process, \
                 patch.dict(release.os.environ, {key: 'fixture' for key in release.REQUIRED_SECRETS}, clear=True):
                with self.assertRaisesRegex(ValueError, 'Private distribution migration'):
                    getattr(release, name)('sterling-v1.2.3')
                for effect in (run, api, download, process):
                    effect.assert_not_called()

    def test_cli_refuses_signing_and_publication_without_credentials_or_tools(self):
        # An empty executable search path prevents a regression from invoking gh
        # or signing tools. Only the absolute Python interpreter can execute.
        for command in ('distribution-preflight', 'prepare', 'package', 'publish'):
            with self.subTest(command=command):
                result = subprocess.run(
                    [sys.executable, str(ROOT / 'Scripts/release.py'), command],
                    env={'PATH': '', 'RELEASE_TAG': 'sterling-v1.2.3'},
                    capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(result.stdout, '')
                self.assertIn('Private distribution migration', result.stderr)

    def test_environment_flags_cannot_restore_public_publication(self):
        with patch.dict(os.environ, {'STERLING_DISTRIBUTION_BUILD': '1',
                                     'STERLING_ALLOW_PUBLIC_RELEASE': '1',
                                     'STERLING_DISTRIBUTION_MODE': 'public'}):
            with self.assertRaisesRegex(ValueError, 'Private distribution migration'):
                release.distribution_preflight('sterling-v1.2.3')

    def test_invalid_tag_is_rejected_without_external_effects(self):
        with patch.object(release, 'api') as api, patch.object(release, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'Expected sterling-vX.Y.Z'):
                release.distribution_preflight('sterling-v1.2.3;publish')
            api.assert_not_called()
            run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
