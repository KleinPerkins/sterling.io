# sterling.io agent entrypoint

This repository is born under doc-warden v2 governance.

<!-- doc-warden:begin -->
## Documentation governance

| Artifact type | Location |
|---|---|
| Project, roadmap, and state | `.planning/` |
| Phase plans | `.planning/phases/` |
| ADRs | `docs/adr/` |
| Runbooks | `docs/runbooks/` |

**Policy:** `~/dev/_ops/doc-warden/POLICY.md`
**Engine:** `~/dev/_ops/bin/doc-warden.sh doctor repo --repo .`
<!-- doc-warden:end -->

## Product and implementation

- Start with `README.md`, `docs/README.md`, and the preserved approved specification at `docs/reference/approved-product-specification-v1.md`. Do not silently edit approved bytes; new product decisions require reviewed successors.
- Current state is an S0 feasibility prototype. The dated S0 evidence is historical. It is not S0 exit, production, accessibility, likeness or release approval.
- Keep the simulation in `SterlingCore`, with one runtime owner. The native host sends commands and renders snapshots. Rendering must never award gameplay effects. No frame-by-frame language model is required.
- Passive visuals always ignore input. Only the explicit care window owns local gestures. Preserve cancellation, absence forgiveness and manual Hide/Pause precedence.
- No global key/event monitor, event injection, document/screen-content access, real-file mutation, or AX write is part of this prototype. The simulation stays local. Signed distribution builds may use Sparkle for owner-initiated or explicitly enabled update checks; local builds and probes never start the updater. Optional desktop integration and release acceptance remain separately gated.
- Temporary geometric artwork is not a likeness. AppKit care controls are a feasibility harness; the approved SwiftUI production direction remains intact.

## Execution and verification

- Personal source belongs in `~/dev/personal/src/KleinPerkins/sterling.io`. Follow the native Codex worktree entry rule, use a unique `DEV_SESSION_ID`, and verify writer ownership before source changes. Native attachment is not AWA registration or protection.
- Use LOCAL `KleinPerkins <49759187+KleinPerkins@users.noreply.github.com>` identity; do not change global identity or bypass commit guards.
- `make verify` runs source checks, Swift domain/input tests, and the release app build. It requires macOS; a Linux-only static check cannot stand in for that evidence. `make probe` requires a logged-in desktop and is a separate explicit runtime check.
- Keep generated app bundles, raw logs, caches and archives ignored. Commit small dated evidence when it changes an acceptance decision, with provenance and limits.
- Make each implementation body reviewable in a PR; keep incomplete work draft and mark verified work ready. Run applicable checks and the required review process. Verify the actual target revision and effective merge gates before delivery claims.
- The source repository uses native GitHub Actions with meaningful quality/native coverage. The authoring agent automatically obtains fresh independent review from the PR-creation Codex account, preferring an enrolled same-account cloud route and otherwise the enrolled local adapter. Work and personal accounts remain distinct despite their shared GitHub user. Use `Scripts/local_review.py`, then `Scripts/create_review_pr.py`, then publish the unedited review receipt prefixed with `<!-- g1-review-receipt:v1 -->`. Repeat review after head, current base or trusted policy changes. Unknown origin or unavailable review blocks that PR; the operator is not the technical reviewer.
- The trusted-main Reviewer App checks the separate creation-origin witness, independent review and exact CI run before App-owned native squash. Initial automation admission remains owner-controlled; agents never manually merge, arm auto-merge or bypass checks. Existing Dependabot maintenance remains separately governed and cannot authorize a product release. An ambiguous creation response requires preserving its journal and read-only diagnosis, never a blind retry or an invented origin witness. Follow `docs/runbooks/releasing.md` for signed-release authority.
- The owner selected private product downloads and updates while keeping source public. Follow `docs/runbooks/releasing.md#private-distribution-migration`. The obsolete public publisher is blocked before signing/packaging/publication, including retries. Do not bypass that block or treat a local declaration as publication authority. Shared provider qualification, recipient access and installed-update proof remain open; the dev-owned provider-neutral standard governs the eventual product adapter.
- Source control, merge, UAT, signing/notarization, installation and release are distinct outcomes. Report only the ones actually verified.

## Documentation authority

Use the global doc-warden skill and repository v2 profile for semantic/structural mutations. Its exact preview/consent contract applies. Preserve prior accepted input and evidence during adoption; do not infer new PRD/design/phase acceptance from repository creation. The projected roadmap retains the S0–S4 sequence and expansion scope. Canonical PRD v1 is the accepted planning baseline and is frozen; semantic changes require reviewed successors. Original requirement identifiers remain preserved alongside tooling aliases. Acceptance does not settle proposed defaults or unresolved founder decisions, and does not approve design, S0 exit or release.
