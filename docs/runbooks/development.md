# Sterling development ecosystem

Status: draft operating guide; observations at main `8c59c4ed4d59781a1e1868f3ed87e6cab69740f0`. This guide reconciles setup evidence without changing product acceptance or release authority.

## Fresh Mac setup

1. Use macOS 15 or later with the Apple developer tools selected by `xcode-select -p`; verify `xcrun --find swift`, `xcrun swift --version`, `xcrun --sdk macosx --show-sdk-version`, `python3 --version`, and `git --version`. Swift tools language baseline is 6.0; use the selected Apple toolchain, not a separately installed Linux/community Swift. Full Xcode is useful for Instruments and accessibility testing; command-line tools suffice for the verified local prototype build. A missing SDK or toolchain is a setup failure, not a reason to lower deployment targets.
2. Clone `git@github.com:KleinPerkins/sterling.io.git` into the personal source workspace. Verify the remote before any mutation; `KleinPerkins/sterling` is a different repository. Set only local Git identity to `KleinPerkins <49759187+KleinPerkins@users.noreply.github.com>`.
3. For governed agents, use the repository's native Codex create/attach procedure, explicit returned working directory, unique `DEV_SESSION_ID`, and writer guard. A developer outside the KleinPerkins home setup can build and test with the commands below; canonical documentation writes require the enabled doc-warden v2 engine and matching profile. Native attachment does not confer AWA protection.
4. Run `make verify`. SwiftPM resolves the committed exact Sparkle pin and binary artifact; the first build needs network access to GitHub. Generated build caches live in a path-specific temporary directory selected by `Scripts/swift.sh`; logs/receipts live in ignored `work/` and `outputs/`. Do not rely on another worktree's build. Do not delete other worktrees' caches to repair this one.
5. Open `outputs/Sterling Feasibility.app` only in a logged-in desktop when ready for local interaction. `make probe` separately launches and automatically exits its own app. `make package` requires matching current build/test/probe receipts. A build does not start Sparkle, prove physical input safety, or publish a release.

No credential is needed to build the local ad-hoc signed prototype. Never ask a new contributor to download production signing keys. The development wrapper uses SwiftPM's `--disable-sandbox` build option to accommodate the existing toolchain; this is distinct from the macOS App Sandbox entitlement and proves nothing about production sandbox behavior.

## Daily commands and failure recovery

| Command | Evidence | Common failure and next action |
|---|---|---|
| `make verify` | Source integrity, all Swift tests, Python contract tests, update verifier self-test, release-mode local build | Read `work/test.log` or build output; repair the affected code/toolchain. A process timeout or missing artifact is not a pass. |
| `make test` | Complete local Swift Testing suites and source-bound receipt | New tests join discovery automatically. Use small typed fixtures and fixed seeds. |
| `make test-delivery` | All Python delivery/CI tests and CryptoKit verifier | Required after delivery changes; ordinary product work still runs this through `make verify`. |
| `make probe` | Own-app native handler/window/render evidence | Requires a desktop. It is not physical clicking, VoiceOver UAT, sleep/lock or a sustained energy test. |
| `make package` | Reproducible engineering preview with matching inputs | Regenerate stale receipts rather than editing their hashes. Preview kit is not distributable release approval. |
| `bash ~/dev/_ops/bin/doc-warden.sh doctor repo --repo .` | Enabled v2 profile and read-only governance status | Follow validated previews for authoring; don't hand-edit generated projections or accepted artifacts. |

For a failed first SwiftPM fetch, inspect the named URL/network error and retry the same pinned resolution after the connection is restored. Do not substitute an unverified binary or loosen the dependency pin. For signing errors in synced folders, use the established path-specific temporary build root. For live input failures, hide/quit Sterling, retain a small sanitized reproduction and keep FZ-01 open.

## Growth rules

| Addition | Owner and registration | Required evidence |
|---|---|---|
| Domain behavior | `Sources/SterlingCore/`; one simulation owner, pure state/commands, deterministic RNG/time | Requirement + catalog IDs, preconditions, effects, interruption/safe exit, cooldown, fallback; same-version replay and targeted invariants. Renderer never awards effects. |
| New Swift module | Add a target only when a dependency or concurrency boundary is demonstrated; no one-file micro-packages | Acyclic dependency map, Swift Testing target, compiler-discovered coverage on both CI OSes; Package.swift is owner-controlled in PR automation. |
| Care or settings UI | Native SwiftUI direction inside the existing AppKit lifecycle host | Approved UX/design versions, all state/keyboard/VoiceOver/reduced-motion coverage, visual UAT. AppKit harness is temporary. |
| Content or art | Bundled typed definitions; production source separated from runtime exports | Stable IDs, schema/content/tuning versions, source revision/rights, hashes, scale/anchors/contact/safe exits; initial manifest + founder likeness review before S1 art. Synthetic validator fixtures are not approved assets. |
| Native integration | macOS adapter; permission-free base preserved | Official API evidence + physical matrix, denied/revoked/stale fallback and bounded cost; no AX writes, global input, file mutation or capture. |
| Diagnostics | Local, explicit opt-in, bounded semantic records | Version identities, synthetic/local data, redaction and size limits; no external app titles/content or ambient pointer trails. |
| Tests | Swift Testing for native/domain; Python for repository/delivery | Compiler/xUnit identity must match; no hand-maintained count, skipped failures or changed-path exclusions. Fixtures isolated from shared writable state. |

Keep simulation and presentation boundaries within the current targets until a measured need justifies extraction. The roadmap names logical owners; it does not mandate immediate target creation. Add packages only with a concrete use, license and reviewed dependency policy. Dependabot maintains current pins, including major versions, under the existing App policy.

## CI and repository delivery

Native GitHub Actions and hosted macOS runners are the approved public-repository route. Current effective rules require linear history, an approving review with stale dismissal, resolved review threads, and strict current-commit `ci-required` from GitHub Actions. Main and release tags have deletion/force-update protections. Public visibility, secret scanning, push protection, squash and auto-merge availability were read back from GitHub.

The installed App owns eligible ordinary PR approval and squash auto-merge. Its approval is policy-based, not substantive code review. Engineers/agents still review technical findings. Protected paths (workflow, scripts, package/build, signing/updater and policy paths) need the owner-controlled process. Do not broaden the allowlist to deliver an ordinary product change. Ready PRs remain owned through checks and verified merge; never pre-arm auto-merge or use an administrative bypass. Release PR #5 remains manual.

The default is one Swift shard on each of macOS 15 and 26. Every discovered test executes exactly once per OS; the aggregate verifies inventory, head/source identity, reports and disjoint coverage. Use the existing [testing runbook](../../docs/runbooks/testing.md) before changing concurrency. Measure test execution against duplicated compilation and queue cost. No increase is justified by the current small domain suite.

## Verified setup versus open product gates

| Area | Observed evidence | Remaining limit |
|---|---|---|
| CI and maintenance | PRs #7/#8 merged; current main preserves exact sharding and all-size Dependabot policy | Maintenance run [41169009251](https://github.com/KleinPerkins/sterling.io/actions/runs/41169009251) passed with no eligible dependency PRs; real branch refresh/merge remains unobserved. Do not fabricate an upgrade. |
| Credentials | [41164898459](https://github.com/KleinPerkins/sterling.io/actions/runs/41164898459) succeeded: Developer ID test signature, notarization authentication, matching Sparkle signature | Not a Sterling notarization, installation, installed update or publication. No key recreation is needed. |
| Release authority | Protected `release` environment requires KleinPerkins; release PR is excluded from App merging | Owner must approve product release and the protected environment. Clean-machine install/update and platform acceptance remain open. |
| Product | S0 prototype, in-memory state, temporary art | FZ evidence, founder decisions, production UI/art, persistence and full catalog remain open. |

Operational release commands and failure recovery remain authoritative in [releasing.md](../../docs/runbooks/releasing.md). This guide links that procedure rather than duplicating credential details or adding a second release workflow.
