#!/usr/bin/env python3
"""Validate configured signing credentials without submitting or publishing a release."""
import base64
from contextlib import contextmanager
import json
import os
from pathlib import Path
import re
import secrets
import shlex
import subprocess
import sys
import tempfile

import release

ROOT = Path(__file__).resolve().parents[1]


class ReadinessError(RuntimeError):
    pass


def command(stage, *args, input=None, allowed=(0,)):
    result = subprocess.run([str(arg) for arg in args], input=input, capture_output=True, text=True, cwd=ROOT)
    if result.returncode not in allowed:
        # Never log arguments, output, or exception context: these can contain secrets.
        raise ReadinessError(f'{stage} failed; check the corresponding release environment setting')
    return result


def configuration(env):
    missing = [name for name in release.REQUIRED_SECRETS if not env.get(name)]
    if missing:
        raise ReadinessError('Missing release configuration: ' + ', '.join(missing))
    team, identity = env['APPLE_TEAM_ID'], env['APPLE_SIGNING_IDENTITY']
    if not re.fullmatch(r'[A-Z0-9]{10}', team) or not re.fullmatch(r'Developer ID Application: .+ \(' + re.escape(team) + r'\)', identity):
        raise ReadinessError('APPLE_SIGNING_IDENTITY must be a Developer ID Application identity for APPLE_TEAM_ID')
    try:
        if len(base64.b64decode(env['SPARKLE_PUBLIC_ED_KEY'], validate=True)) != 32:
            raise ValueError()
        certificate = base64.b64decode(env['APPLE_CERTIFICATE'], validate=True)
        if not certificate:
            raise ValueError()
    except (ValueError, TypeError):
        raise ReadinessError('Invalid certificate or public update key encoding') from None
    return certificate


@contextmanager
def signing_keychain(temp, certificate, env):
    old = shlex.split(command('Read keychain configuration', 'security', 'list-keychains', '-d', 'user').stdout)
    keychain = temp / 'readiness.keychain-db'
    p12 = temp / 'certificate.p12'
    password = secrets.token_urlsafe(32)
    p12.write_bytes(certificate)
    p12.chmod(0o600)
    try:
        command('Create temporary keychain', 'security', 'create-keychain', '-p', password, keychain)
        command('Configure temporary keychain', 'security', 'set-keychain-settings', '-lut', '600', keychain)
        command('Unlock temporary keychain', 'security', 'unlock-keychain', '-p', password, keychain)
        command('Import certificate/password', 'security', 'import', p12, '-k', keychain,
                '-P', env['APPLE_CERTIFICATE_PASSWORD'], '-T', '/usr/bin/codesign', '-T', '/usr/bin/security')
        command('Configure signing access', 'security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', password, keychain)
        command('Select temporary keychain', 'security', 'list-keychains', '-d', 'user', '-s', keychain, *old)
        yield keychain
    finally:
        try:
            command('Restore keychain configuration', 'security', 'list-keychains', '-d', 'user', '-s', *old)
        finally:
            try:
                if keychain.exists():
                    command('Delete temporary keychain', 'security', 'delete-keychain', keychain)
            finally:
                p12.unlink(missing_ok=True)


def verify_credentials(env):
    certificate = configuration(env)
    identity, team = env['APPLE_SIGNING_IDENTITY'], env['APPLE_TEAM_ID']
    with tempfile.TemporaryDirectory(prefix='sterling-readiness-') as name:
        temp = Path(name)
        with signing_keychain(temp, certificate, env) as keychain:
            identities = command('Validate certificate trust', 'security', 'find-identity', '-v', '-p', 'codesigning', keychain).stdout
            if identity not in re.findall(r'"([^"]+)"', identities):
                raise ReadinessError('The imported certificate is not a valid signing identity matching APPLE_SIGNING_IDENTITY')
            source, binary = temp / 'probe.c', temp / 'probe'
            source.write_text('int main(void) { return 0; }\n')
            command('Compile disposable probe', 'xcrun', 'clang', source, '-o', binary)
            command('Developer ID signing', 'codesign', '--force', '--sign', identity, '--keychain', keychain,
                    '--options', 'runtime', '--timestamp', binary)
            command('Verify Developer ID signature', 'codesign', '--verify', '--strict', binary)
            details = command('Inspect Developer ID signature', 'codesign', '-d', '--verbose=4', binary).stderr
            if f'TeamIdentifier={team}' not in details.splitlines() or 'runtime' not in details:
                raise ReadinessError('Signed probe has the wrong team or lacks hardened runtime')
            command('Validate Apple notarization credentials', 'xcrun', 'notarytool', 'store-credentials',
                    'sterling-readiness', '--keychain', keychain, '--apple-id', env['APPLE_ID'],
                    '--password', env['APPLE_PASSWORD'], '--team-id', team)
            # Read-only authentication proof; no notarytool submit, product build, tag, or GitHub release.
            command('Read notarization history', 'xcrun', 'notarytool', 'history', '--keychain-profile',
                    'sterling-readiness', '--keychain', keychain, '--output-format', 'json')
        tools = release.tools_directory(temp)
        payload = temp / 'update-probe.txt'
        payload.write_text('Sterling credential-readiness probe\n')
        signature = command('Sign Sparkle probe', tools / 'bin/sign_update', '--ed-key-file', '-', '-p', payload,
                            input=env['SPARKLE_PRIVATE_ED_KEY'] + '\n').stdout.strip()
        verifier = temp / 'verify-update'
        command('Compile update verifier', 'xcrun', 'swiftc', ROOT / 'Scripts/verify-update.swift',
                '-module-cache-path', temp / 'module-cache', '-o', verifier)
        command('Verify configured Sparkle key pair', verifier, env['SPARKLE_PUBLIC_ED_KEY'], signature, payload)
        payload.write_text('Modified probe: signature must fail\n')
        tampered = command('Reject tampered update', verifier, env['SPARKLE_PUBLIC_ED_KEY'], signature, payload, allowed=(0, 1))
        if tampered.returncode != 1:
            raise ReadinessError('Update verifier accepted a tampered payload')
    return {'schema': 'sterling-credential-readiness/v1',
            'commit': command('Read commit', 'git', 'rev-parse', 'HEAD').stdout.strip(),
            'developer_id_signing': True, 'notarization_authentication': True,
            'sparkle_key_pair': True, 'tampered_update_rejected': True,
            'temporary_credentials_removed': True,
            'product_notarized': False, 'release_published': False, 'update_installation_tested': False}


def main():
    if os.environ.get('GITHUB_REPOSITORY') != release.REPO or os.environ.get('GITHUB_REF') != 'refs/heads/main':
        raise ReadinessError('Credential readiness runs only from the protected main workflow')
    receipt = verify_credentials(os.environ)
    output = ROOT / 'outputs/credential-readiness.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(receipt, indent=2) + '\n')
    print('Developer ID signing, Apple authentication, Sparkle keys and cleanup verified. No release published.')


if __name__ == '__main__':
    try:
        main()
    except ReadinessError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except Exception:
        # Download/parse/system exceptions may include output or values. Keep logs generic.
        print('Credential readiness failed; no release was submitted or published.', file=sys.stderr)
        sys.exit(1)
