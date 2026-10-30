# Native delivery preparation — 2026-10-30

Prepared against main `9f46eb8f60553702e221d93ba2e34cdbcbc57726` in a non-Git review copy because this chat still pointed to the old non-Git workspace. Canonical source, GitHub visibility and settings were unchanged during preparation. This is local verification, not a claim that hosted CI or release automation is operational.

- `make verify`: 21 Swift tests in three suites, 13 Python delivery-policy tests, signature tamper verification and local bundle build passed.
- All four workflows passed actionlint; external actions and Sparkle are pinned.
- Universal compilation produced arm64 and x86_64 slices. Execution on Intel and macOS 15 remains unverified.
- `make probe`: 21 Boolean checks and one connected display placement passed. Physical input, real sleep/Spaces transitions and production accessibility remain open.
- Preview packaging preserved Sparkle framework symlinks and passed deep strict signature verification after extraction. This is ad-hoc signing, not Developer ID or notarization.
- The available Git history scan found only the non-secret documentation repository UUID. The scanner excludes that exact value; the reviewed scan is clean.

In-place review found and fixed a draft-tag creation issue, multi-suite test undercounting, framework symlink loss during ZIP export, protected-file rename evasion, and permissive silent-install defaults. No independent review was available. The approved specification and frozen canonical PRD remain unchanged. See `verification.json` for limits and the release runbook for the remaining live gates.
