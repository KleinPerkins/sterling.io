# sterling.io

A local native macOS companion inspired by Sterling. This private repository holds the approved product specification, the first feasibility prototype, and the evidence for work completed so far.

**Current stage: S0 feasibility, in progress.** The prototype is a local engineering preview with temporary geometric artwork and in-memory state. It is not a production release or a likeness approval.

## Start here

- [Approved product specification v1](docs/reference/approved-product-specification-v1.md): preserved byte-for-byte; requirements R-001–R-048, architecture, S0–S4 delivery sequence and expansion scope.
- [Documentation map](docs/README.md): authority, historical evidence, and future authoring paths.
- [S0 verification record](docs/evidence/2026-10-29-s0/verification.md): 17 domain/input tests, 21 automated native checks, two display scales, and explicit unverified gates.
- [Physical-input and desktop checks](docs/runbooks/feasibility-manual-checks.md): work still required before S0 can close.
- [Agent entrypoint](AGENTS.md): execution boundaries and the existing home operating model.

The native app uses AppKit for the feasibility host and care controls, SpriteKit through SKRenderer/MetalKit for drawing, and a pure Swift simulation library owned by one actor. Rendering cannot award simulation effects. SwiftUI remains the approved production direction for care/settings; the AppKit controls are a temporary test harness. Full architecture and alternatives are in section 8 of the approved specification.

## Build and verify

Requires a Mac with Apple command-line tools. The checked build is Apple silicon on macOS 26.7.2 with Swift 6.4. macOS 15 is the deployment target, not an already-validated compatibility claim.

```sh
make verify        # source integrity, domain/input tests, release app build
make probe         # brief native desktop probe; automatically exits
make package       # preview kit; requires current passing build/test/probe receipts
```

Open `outputs/Sterling Feasibility.app`. Use the paw menu to open Care. Space starts/stops Pet or Play, arrow keys move the toy in Play, and Escape closes care. Hide, Pause, Focus, Reduce motion and Quit are in the menu. Basic food exercises the meal reducer. State resets when the app quits.

Generated builds, caches, app bundles, current-run logs and preview archives stay ignored. Small historical receipts and the temporary-art images are retained under `docs/evidence/`. `make probe` opens this app and invokes local handlers; it does not synthesize global input or capture another app. Physical click-through, actual sleep/Space/full-screen transitions, accessibility and final art remain separate checks.

## Source layout

| Path | Responsibility |
| --- | --- |
| `Sources/SterlingCore/` | Pure state, reducer, seeded replay, attention budget, geometry and gesture ownership |
| `Sources/SterlingPrototype/` | Native lifecycle, passive panel, care mat, presentation and explicit probe mode |
| `Tests/SterlingCoreTests/` | Domain and interaction regression tests |
| `Scripts/` | Local build, test, probe and packaging entrypoints |
| `.planning/` | Doc-warden v2 identity, canonical semantic records and generated project/roadmap/state views |
| `docs/adr/` | Numbered decisions created through doc-warden |
| `docs/runbooks/` | Operational and manual verification procedures |
| `docs/reference/` | Preserved prior approved input; never silently rewritten |
| `docs/evidence/` | Dated observations; evidence does not imply acceptance |

## Repository policy

This is `KleinPerkins/sterling.io`, distinct from the existing `KleinPerkins/sterling` project. The canonical personal checkout is `~/dev/personal/sterling.io`; active source work follows the native worktree rule. Use local `KleinPerkins <49759187+KleinPerkins@users.noreply.github.com>` identity and the installed session, identity and data guards.

The repository inherits the standard private baseline and doc-warden v2 profile. No GitHub Actions workflow or hosted/self-hosted runner is used. Runnerless PR automation is **not activated**: qualification and enrollment remain an explicit gate owned by the existing controller. Do not fabricate verification checks, enable PR auto-merge, or bypass protections to close that gap.

Use small reviewable branches and draft PRs, verify their exact source, and follow the currently effective owner merge policy. A pushed branch is source-controlled work, not proof of merge, release or UAT acceptance. Preserve approved documents; changes use reviewed successor versions.
