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

- Personal source belongs in `~/dev/personal/sterling.io`. Follow the native Codex worktree entry rule, use a unique `DEV_SESSION_ID`, and verify writer ownership before source changes. Native attachment is not AWA registration or protection.
- Use LOCAL `KleinPerkins <49759187+KleinPerkins@users.noreply.github.com>` identity; do not change global identity or bypass commit guards.
- `make verify` runs source checks, Swift domain/input tests, and the release app build. It requires macOS; a Linux-only static check cannot stand in for that evidence. `make probe` requires a logged-in desktop and is a separate explicit runtime check.
- Keep generated app bundles, raw logs, caches and archives ignored. Commit small dated evidence when it changes an acceptance decision, with provenance and limits.
- Make each implementation body reviewable in a PR; keep incomplete work draft and mark verified work ready. Run applicable checks and the required review process. Verify the actual target revision and effective merge gates before delivery claims.
- Owner direction for this intended public repository is native GitHub Actions and hosted macOS runners, with an installed App approving verified ordinary PR heads and arming GitHub squash auto-merge. Private repositories retain their controller policy. The App excludes release PRs and protected automation paths; these remain owner-controlled. Agents do not manually pre-arm auto-merge or bypass failed checks. Follow `docs/runbooks/releasing.md` for activation and signed releases.
- Source control, merge, UAT, signing/notarization, installation and release are distinct outcomes. Report only the ones actually verified.

## Documentation authority

Use the global doc-warden skill and repository v2 profile for semantic/structural mutations. Its exact preview/consent contract applies. Preserve prior accepted input and evidence during adoption; do not infer new PRD/design/phase acceptance from repository creation. The projected roadmap retains the S0–S4 sequence and expansion scope. Canonical PRD v1 is the accepted planning baseline and is frozen; semantic changes require reviewed successors. Original requirement identifiers remain preserved alongside tooling aliases. Acceptance does not settle proposed defaults or unresolved founder decisions, and does not approve design, S0 exit or release.
