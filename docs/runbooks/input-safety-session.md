# Guided S0 input-safety session

Status: prepared session; physical results are **not run** until a person supplies observations. Use with the [remaining manual checks](feasibility-manual-checks.md). This is an engineering fixture procedure, not production UI, design approval, accessibility acceptance or S0 exit.

## Start from a known build

1. From a clean reviewed source revision, run `make verify`, then `make probe`, then `make package`. Keep their matching build/test/probe receipts. The probe invokes Sterling's own handlers and automatically exits; it cannot substitute for physical input.
2. Record source revision, executable SHA-256, macOS build, display sizes/scales, input device, test date and observer. Record separate results when changing displays, input devices or builds.
3. Close any earlier Sterling preview using its paw menu. Do not kill an unknown process or replace a running test build. The local ad-hoc app does not start Sparkle or request desktop permissions.
4. Open an empty unsaved text document, or open [InputSafety.html](../../Tests/Fixtures/InputSafety.html) in a browser. Use disposable text only. The fixture has a typing area, two click counters and selectable text; it makes no network requests, stores no data, and never synthesizes input. Reload clears its state.
5. The observer begins typing before the test operator launches `outputs/Sterling Feasibility.app` without activating it. Keep typing for 30 seconds. Do not run automated browser actions or another native probe during physical trials.

The fixture is a harmless observation surface, not a pass/fail oracle. Its own browser self-check proves only that its counters and reset work. Never count automated browser clicks as physical Sterling input evidence.

## Observe in small groups

For Hide/Pause/Quit menu trials, use keyboard-started contact so the pointer is available for the menu. Record keyboard-owned and held-pointer variants separately. If a command cannot be invoked while the pointer is held, mark that variant **not run** or **inconclusive**; a keyboard pass does not establish pointer cancellation. Escape, app switching, Space changes and display loss can exercise their applicable held-pointer variants without inventing global shortcuts.

Record **pass**, **fail**, **not run**, or **inconclusive** for every row, with what actually happened. A concern or accidental action stops that trial; use Hide or Quit Sterling, preserve a small reproduction and leave the gate open. Do not use send/delete/purchase controls or valuable files as targets.

| ID | Physical action | Expected observation | Initial result |
| --- | --- | --- | --- |
| INP-01 | Type continuously while the passive app launches; continue while it moves. | Insertion point stays in the document, all intended text lands there, and Care does not open. | Not run |
| INP-02 | Resize the fixture browser to the bottom of the usable desktop (macOS full-screen off). Target A is fixed at the viewport bottom. Note count, click once through the cat body, then once through its transparent margin. | Exactly +1 for each physical click; intended browser target responds; no care window appears. | Not run |
| INP-03 | Select fixture text, drag through the passive cat and release beyond it; repeat both directions and fast crossings. | Selection remains owned by the browser, with no pet/play action. | Not run |
| INP-04 | Open Care deliberately via the paw menu. Begin a drag in the other window, enter Care while holding, then release. | A foreign-window-origin drag never starts petting/play. The underlying window receives no replayed click. | Not run |
| INP-04b | In Pet mode, press on care-mat background and move into head/back while holding. | Record separately: the current harness treats the whole deliberately opened mat as its ownership area and may start contact upon entering the body. This is not equivalent to a foreign drag and does not by itself fail INP-04. Direct silhouette touch remains gated. | Not run / observation |
| INP-05 | Begin a valid stroke, then release outside Care. | Contact ends; no unrelated underlying action occurs on release. | Not run |
| INP-06 | Begin contact; press Escape in a separate trial. | Care closes and contact stops; no later queued sample restarts it. | Not run |
| INP-07 | Begin contact; use Hide in a separate trial. Resume explicitly afterward. | Cat and care surface hide, contact stops, and resume does not restore an old gesture. | Not run |
| INP-08 | Begin contact; use Pause in a separate trial, then Continue Sterling. | Simulation freezes; old contact does not restart. A new deliberate action is required. | Not run |
| INP-09 | Begin contact, then activate the harmless other window. | Contact stops on Care losing keyboard ownership; no focus is stolen back. | Not run |
| INP-10 | Begin contact, then change Spaces; repeat with a display disconnect when practical. | Gesture cancels, stale support is not used, and no unsolicited focus/Space switch occurs. Record actual configuration; full FZ-02 remains separate. | Not run |
| INP-11 | In Care, use Space to start/stop; hold Space; use arrows in Play; press Escape. | Space does not repeatedly toggle while held; arrows affect the toy only in Play; Escape closes Care. Verify actual physical keyboard behavior. | Not run |
| INP-12 | Alternate Pet/Play and Done/reopen quickly. | Previous gesture/sample cannot restart the next mode; only one deliberate interaction owns care. | Not run |
| INP-13 | Use VoiceOver to reach the paw menu, mode selector, controls, care area and custom actions. | Names, help, response feedback and control order are usable. Record missing/unclear feedback; metadata alone does not pass this row. | Not run |
| INP-14 | Begin contact, then Quit Sterling. | App, menu and owned windows disappear; no later response occurs. Operator can separately check the known process exited. | Not run |
| INP-15 | Pet until a boundary, then re-enter; play, leave and re-enter. | Satisfaction/fatigue survive re-entry in this launch. This is a prototype behavior observation, not likeness or full C/D acceptance. | Not run |

Rows INP-01–14 support R-026/R-027/R-035/R-036/R-039/R-042, scenarios I/K and FZ-01; INP-10 also supports the corresponding FZ-02 configuration. INP-15 supports only the observed subset of R-006/R-008 and C/D. Receptiveness may legitimately prevent contact; separate a character refusal from a missing input response.

## Record without inferring acceptance

For each trial record: ID, build/binary identity, display and input device, preconditions, exact action, observed result, pass/fail/not-run/inconclusive, and a short reproduction when needed. Do not capture another app's contents or store typed text, private titles or raw event trails. A user's report is evidence, not automatic phase acceptance.

At the end, Quit Sterling unless the person explicitly wants to keep the preview running. Record which rows remain open. FZ-01 remains open if any required trial failed, was not run, or was inconclusive. A clean pass on one setup does not approve all displays/OSes, production UI, D-02 direct touch, D-06 support or accessibility as a whole.

S0-ART and S1-CORE planning continue independently while physical observations are pending. No likeness is inferred from the temporary geometric cat.
