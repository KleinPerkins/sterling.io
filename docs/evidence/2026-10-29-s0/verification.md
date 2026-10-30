# Sterling S0 engineering receipt

**Result:** a working local native feasibility preview and tested simulation scaffold. **S0 remains in progress.** No production or external-beta acceptance is claimed.

Recorded 29 October 2026. App version 0.0.1 (1), Apple silicon release build. The approved specification is byte-identical to the prior deliverable; all implementation notes are separate.

## Built and checked

| Area | Evidence | Limit |
| --- | --- | --- |
| Domain and input contracts | 17 Swift Testing tests across two suites passed; seeded replay and serialization, contact rise/saturation/re-entry, still-contact expiry, play fatigue, meal repetition, bounds, attention budget, absence recovery, gesture ownership and display transforms | Pure-model evidence; no durable persistence or full behavior catalog |
| Live native probe | 21 Boolean checks passed, plus nonzero inactive rendering and two connected-display placements | Keyboard handlers and wake handlers are invoked locally; physical OS input and actual sleep transitions remain untested |
| Rendering and control | 25 inactive frames during the initial two-second sample; unchanged foreground PID; overlay ignores events/cannot key; Hide/Pause stop draw work; resume restarts; one visible cat; care controls fit | Window properties are not end-to-end click-through proof |
| Display placement | Both connected 2560×1440 logical displays tested; 2× and 1× backing scales matched, overlay remained in usable bounds | Disconnect, mirroring, Spaces, Stage Manager, full-screen and older OS behavior remain open |
| Packaging | Release app built, local ad-hoc hardened-runtime signature verified; source/executable hashes attached to receipts | No Developer ID identity, notarization or app-sandbox proof; no installation or release |

`outputs/care-window.png` is an own-view AppKit render with the app's own scene bitmap inserted because view caching does not capture a Metal drawable. It is **not** a desktop screenshot. Visual inspection confirmed readable controls, clear Pet/Play modes, keyboard guidance and no clipping in this 560×500 light-appearance view. Final art, dark appearance, larger text and VoiceOver still need acceptance.

GPU command duration p95 in this brief, simple-shape run: **0.054 ms**. This does not measure end-to-end latency, CPU, memory, energy, atlas costs or sustained frame pacing and does not pass the production resource budget.

## Gate status

| Gate | Current status | Required evidence next |
| --- | --- | --- |
| FZ-01 Input and overlay | Partial — passive host, care ownership domain, key-handler and cancellation checks pass | Physical click-through, typing, foreign drag and cancellation matrix in `ManualChecks.md`; optional silhouette input remains disabled |
| FZ-02 Desktop transitions | Partial — connected-display positioning/scaling passes | Real Spaces/Stage Manager/full-screen, reconnect, mirroring, lock and sleep/wake matrix |
| FZ-03 Permissions/geometry | Base prototype requests no desktop permissions; optional integrations absent | Intended sandbox and permission-denied/revoked behavior; separately qualify AX geometry only if pursued |
| FZ-04 Rendering/art | Partial — SKRenderer works while inactive; shape study only | Reference photo, likeness/rig/scale approval, valid animation asset manifest, actual clips and sustained resource measurements |
| FZ-05 Distribution / FZ-06 optional illusions | FZ-05 local signature only; FZ-06 deferred | Canonical repository enrollment, signing identity, notarization, supported-platform proof; external illusions need separate evidence |

## Implementation choices and limits

- Seven prototype activities exercise the state reducer; they are not substitutes for the 72-entry catalog. Basic food is a reducer exercise; no full food inventory/preferences UI exists. Attention limits are unit-tested but no attention bids are emitted.
- Native AppKit controls keep the feasibility host small. The approved SwiftUI care/settings direction is retained for production.
- The actor owns the simulation. Serialized UI commands and gesture generations prevent old work from cancelling newer input. Rendering reads snapshots and cannot award effects.
- The passive overlay is always click-through. Only an explicitly opened, opaque-backed care window accepts input. No global event monitor or event injection is installed. No screen contents, Finder files, accessibility tree, microphone or external network service are read by the prototype.
- The runtime is in memory. Quitting resets this prototype. Codable replay tests do not prove durable save migration, corruption recovery or relaunch continuity.
- Hide and Pause freeze normal stepping. System and screen sleep notifications cancel input and suspend; return reconciliation keeps manual Hide/Pause. Actual lock/session switching remains part of the manual gate.
- Reduced Motion retains small breathing/blink cues while suppressing large wandering and autonomous lure movement. Low Power Mode adjusts render targets; long-run power measurements remain pending.
- No reference photo was supplied, so the gray geometric cat is explicitly temporary. It is not a likeness proposal or final animation.
- This selected local folder has no Git repository or remote. These files and the exported kit preserve the work. No commit, push, PR or merge is claimed; production repository enrollment remains open under the personal-workspace policy.

## Reproduce and inspect

Run `Scripts/test.sh`, `Scripts/build-app.sh`, `Scripts/probe.sh`, then `Scripts/package.sh`. The probe opens and automatically closes its own app; it has a 30-second timeout. Physical testing uses the supplied manual checklist. All scripts use local tooling and no third-party package dependencies.

This machine: macOS 26.7.2 (25G332), Apple silicon, Swift 6.4, SDK 27.0, deployment target macOS 15. Only this runtime/architecture is validated. Full Xcode and Developer ID identities were absent. The command-line linker emitted missing optional developer-framework search-path warnings; builds and tests completed successfully.

The wrapper builds in a project-specific temporary directory because File Provider Finder metadata in synced Documents caused generated test-bundle signing to fail. It explicitly locates the installed Swift Testing compiler plugin. No system configuration was changed to resolve these build issues.

## Identity

- Executable SHA-256: `0fc2cd1090dc12b47bc148189975d1f20c4bfe1712ee303ae55aefd5761f1e28`
- Source SHA-256 (ordered Package.swift + Sources files): `b0158089326c5f69644375e943a74bfaba8d9e2c9e4882663d71d85d181788a1`
- Approved specification SHA-256: `16b6b4bf4c471e456d98d4f04d9b2f26ba100f049d39d0616b6ec5f600f1c15d`
- Native check completed: `2026-10-29T11:10:30.472780+00:00`

The package script rejects stale source, mismatched build/probe executables, changed domain/test files and failing receipts before writing the preview kit. Runtime logs and detailed JSON receipts accompany the kit.
