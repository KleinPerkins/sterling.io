# S0 input observations and mixed-scale clipping repair — 2026-11-01 UTC

Status: defect delivery verified; physical input coverage remains partial. This record does not accept FZ-01, FZ-02, accessibility, production UI/art, platform support, S0 exit or release.

## Delivered defect and validation

[PR #11](https://github.com/KleinPerkins/sterling.io/pull/11) merged to main at `c3fac149f1dbf09719fba3e216178fb3aa6d8335`. The inspected PR head was `ce61d0d41058d0505deef5c08c22d68c27f144d2`. Required current-head `ci-required`, hosted macOS 15/26 checks and the installed App's exact-head approval succeeded before squash merge. [PR CI](https://github.com/KleinPerkins/sterling.io/actions/runs/41285701870) and [merged-main CI](https://github.com/KleinPerkins/sterling.io/actions/runs/41285870556) record the source gates. App approval is policy-based; separate technical review found no remaining material issue after the probe synchronization correction.

The founder reported a clipped passive cat while attempting the click-through trial. The original window-placement checks passed, but a new content check failed: on the connected 1× display, a 520×210-point view had a 260×105-point scene. The character extended beyond that scene. The same check passed at 2×. A private desktop screenshot was inspected in chat and was not copied into the repository.

`CatScene` now uses `aspectFit` while the host retains ownership of logical point dimensions. The native probe waits for the requested backing scale and drawable dimensions, then two completed frames, with a two-second timeout. It checks scene/view equality and character/ground bounds on each connected display and in Care. Failure exits the native probe unsuccessfully. This catches clipped content that an in-bounds window alone cannot detect.

Apple documents [scene size in points](https://developer.apple.com/documentation/spritekit/skscene/size), [Metal drawable size in pixels](https://developer.apple.com/documentation/metalkit/mtkview/drawablesize), and [scene scaling modes](https://developer.apple.com/documentation/spritekit/scaling-a-scene-s-content-to-fit-the-view). The local reproduction and subsequent native/physical observations establish this defect; the documentation alone does not prove desktop behavior.

| Verification | Observed result | Limit |
| --- | --- | --- |
| Regression before correction | New content check failed at 1×; window placement passed on both displays. | Local connected-display reproduction, not a universal display matrix. |
| Final `make verify` | 33 Swift tests in four suites, 58 Python tests, signature-verifier self-test and local release-mode app build passed. | Ad-hoc feasibility build; no product signing/notarization acceptance. |
| Final `make probe` | Existing 21 checks and new frame-synchronized content checks passed on 1×/2× displays and Care. | Handler/own-scene evidence; no physical input is synthesized. |
| Physical visibility recheck | Founder confirmed the complete cat was visible on the first corrected build. | The later source change only strengthened the probe; final click-through results retain their own binary identity below. |
| Manual fixture self-check | 16 characters, one click per target, reset to zero; Target A spans the bottom 210 px of a 1280×800 browser viewport. | Automated fixture-only check, with Sterling closed; not input-safety proof. |

Final local environment: macOS 26.7.2 (25G332), arm64, Apple Swift 6.4, SDK 27.0. Both connected displays reported 2560×1440 logical dimensions with backing scales 2 and 1. On each, the passive scene remained 520×210 points; drawable sizes were 1040×420 and 520×210 pixels respectively. Care was 512×248 points at its observed scale. Actual Space changes, full-screen transitions, disconnects and sustained resource behavior remain untested here.

- Final executable SHA-256: `4a3806c425fb40a1c3ae33059bdd1d4caee170f9118cc0aff2f213cf60b7eda9`.
- Final source digest: `794445e886e0102034259dc133401458ed5e6e4af38d6b00b23ae6959efa9dc1`.
- Final Swift test-log digest: `3398b5602bb502b3f99468d1d439fd334923543f6f2e0906a14e42d11a1e6786`.
- Full local verification-log digest: `4896f7a70588b6f848998c5b572805c330fc7ba8af7cb8820345aa782043bc76`.
- Local preview kit SHA-256: `3aded850d38c3be85d6fba19af65cbcd0a2fde0a8e0aecc9bca3eea99eb3ba28` (1,801,434 bytes); build/probe/source identities and extracted local signature matched. It is an ignored developer output, not a public release.
- Manual fixture SHA-256: `cdf5c56684440f7d1566e61a5019f41c9e0f7c4a0a047ccd2573b50fd88ed550`. No network, persistent storage, file writes or synthetic input are added by the page.

The probe's historical “no signing identity” label is not a new credential check. The existing credential-readiness diagnostic remains valid separately; this local build was ad-hoc and not notarized. Brief GPU timing is not sustained resource evidence. No keys were recreated and release PR #5 remains manual.

## Physical input observations

All rows below are the founder's physical observations reported in this chat. No automated input was sent to Sterling or the user's document. The main display was used, but the exact display identity and keyboard/pointer models were not recorded; do not generalize these results across configurations. No typed text, private window title, desktop image or raw input trail is retained.

| Trial | Result | Binary prefix | Report |
| --- | --- | --- | --- |
| INP-01 | pass | `7299e8ef1db2` | Pass — typing stayed uninterrupted |
| INP-02 | inconclusive | `7299e8ef1db2` | Inconclusive — I could not position the target; cat clipped at screen edge |
| INP-02-retry | inconclusive | `eba247d61e85` | Cannot position Target A beneath the cat at the bottom of the screen; manual fixture needs a bottom-edge target |
| Visibility recheck | pass — user reported | `eba247d61e85` | Founder confirmed the complete head, ears, tail and feet visible with space around the cat. |

Binary identities:

- Original launch: `7299e8ef1db221f0e7371845cf7295f8467ad99f0d2bef70ac5f4856f2a5e914`, from main `e83d1ecebf568ffc57602d36fd8b24c38985560f`.
- First rendering correction: `eba247d61e85c83f6996cefef02033c28d53e3448f5f1f2ec2fbb3e7614921ba`.
- Final reviewed renderer/probe: `4a3806c425fb40a1c3ae33059bdd1d4caee170f9118cc0aff2f213cf60b7eda9`, source head `ce61d0d41058d0505deef5c08c22d68c27f144d2` (same source tree as the verified squash merge).

The first Target A sat mid-page and could not be positioned behind a cat at the bottom of the screen. That is a test-fixture usability limitation, not a click-through pass or a demonstrated click-through failure. The corrected [fixture](../../../Tests/Fixtures/InputSafety.html) fixes Target A to the browser's bottom edge. Its [guided session](../../runbooks/input-safety-session.md) distinguishes pointer/keyboard variants, foreign-window-origin drags and deliberately owned mat-background drags.

Rows absent from this table remain **not run**, including applicable cancellation, physical VoiceOver and desktop-transition trials. The typing pass applies to the original binary; it has not been silently carried over to a later build. FZ-01 remains open. Re-run affected rows after any S1-CORE host adapter change.

## Next package and authority

The bounded S1-CORE-01 plan prepares typed session identity, stale/duplicate rejection, explicit cancellation and replay evidence using the existing feasibility controls. It may execute only after its separate exact plan-acceptance operation is applied. It does not accept the broader foundation drafts or production S1. S0-ART remains a draft reference/model-sheet intake; Sterling-specific appearance and personal traits remain unknown until sourced and reviewed.

Production S1 still requires applicable FZ-01/FZ-04 evidence, recorded D-01/D-02/D-05/D-06 decisions, passing care fixtures and a valid real initial asset manifest. No source merge or green CI substitutes for those gates.
