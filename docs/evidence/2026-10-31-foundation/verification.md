# Foundation and FND-01 delivery evidence — 2026-10-31

Status: implementation delivery verified. The foundation specifications and plan remain drafts; PRD v1 remains the accepted, frozen planning baseline. This is not S0 exit, production design, likeness, accessibility, distribution or release acceptance.

## Delivered source and authority

- Repository: `KleinPerkins/sterling.io`; [PR #9](https://github.com/KleinPerkins/sterling.io/pull/9) merged to main at `7890267bd0973d7519e2a513983e2d1f16490f8b` on 2026-10-31 at 09:02:56 UTC.
- Latest reviewed PR head: `e710f24037b71191b1ee57eed3a0c9b7cc24bd2a`. The installed App approved that exact head at 09:02:53 UTC, after required CI, and completed squash merging. No agent pre-armed auto-merge or used an administrative bypass. App approval is policy-based; independent technical review separately found no material findings before delivery, and the lead reviewed the subsequent one-literal compiler compatibility correction.
- Four linked deliverables are in the [documentation map](../../README.md): ecosystem, 48-requirement/72-behavior product plan, system/product design architecture, and execution/validation plan. All 48 R/REQ aliases and all 72 classifications (61 L / 11 E) were checked. Accepted PRD and preserved specification hashes remained unchanged.
- Exact doc-warden operations `6f6bad7a-0bc9-4b7b-9bdd-f78b85d5555d` and `78678eae-51f3-4db1-b2c9-8a8266c2cdc2` applied the approved drafts and one scan-safe wording correction. Their source-controlled events and receipts preserve the authorization boundary. Neither operation accepted a design or phase.

## FND-01 behavior and tests

`SterlingCore/SimulationReplay.swift` adds bounded synthetic replay inputs, exact schema/code/content/tuning identity, contiguous sequence validation and a pure runner from a seeded default initial state. The entire envelope is checked before execution. This is an R-044 reproducibility subset, not a durable save format, production event bus, arbitrary-snapshot loader or cross-platform floating-point guarantee.

Attention grace now starts only on an effective unavailable-to-available transition, including Quiet/Focus exit. Nested Hide/Pause/Quiet/Focus restrictions and redundant Resume/Unpause cannot restart or bypass it. The existing prototype duration is unchanged and remains proposed tuning.

Eight replay tests cover care round-trip/direct-reducer equality, petting rise/boundary/re-entry, retained play fatigue, hidden/paused state, forgiving return, incompatible schema/identity, bad sequence/time/quality and work/import limits. Four availability regressions failed against the old reducer and passed after the fix. The first hosted run exposed integer inference in one duration fixture on the older Swift compiler; the explicit Double literal repair passed subsequent local and hosted checks. No failed check was bypassed.

## Verification at the delivered revision

| Evidence | Observed result | Limits |
| --- | --- | --- |
| Local `make verify` after the compiler correction | Exit 0; 33 Swift tests in 4 suites, 58 Python tests, update-signature self-test, source checks and release-configuration local app build. macOS 26.7.2 (25G332), Apple Swift 6.4, arm64. | Ad-hoc local feasibility app; no production signing or desktop UAT. |
| [PR CI 41186868316](https://github.com/KleinPerkins/sterling.io/actions/runs/41186868316) | Quality, native macOS 15/26 and `ci-required` passed on head `e710f24`. Every discovered Swift test executed exactly once on each OS. | One shard per OS; no physical input or energy proof. |
| [Merged-main CI 41187056561](https://github.com/KleinPerkins/sterling.io/actions/runs/41187056561) | Quality, both native jobs and `ci-required` passed on merge `7890267`. The merged tree matched the reviewed PR tree. | A merge/build is not a release. |
| Review and static checks | Independent technical review had no material findings; pinned actionlint 1.7.12 and gitleaks 8.30.1 passed, including committed history; source/test whitespace and local links checked. | Three approved Markdown two-space hard breaks are the only full-diff whitespace findings. |

Downloaded PR coverage receipts and xUnit reports were independently revalidated against the delivered source tree using the repository's coverage validator. Both receipts identify GitHub's tested merge checkout `d7ebe62beaee6b14ff2557adea3cc0a1e2c8895e`, with identical inventory and source digest; report hashes and executed identities matched. The separate merged-main run above verifies the actual squash revision.

| Platform | Executed/discovered | Discovery/build seconds | Execution seconds | xUnit SHA-256 |
| --- | --- | --- | --- | --- |
| macOS 15 | 33/33 | 35.269 | 2.285 | `3dcafbf7a880c86886e81da8e8a58e854ac856460ea81d3b10fb8c029bd079f2` |
| macOS 26 | 33/33 | 41.973 | 4.673 | `394ed7e9cbe7d0146c0b0c5ac7650a785466d4b562425b8860e6d6d6e5633db1` |

- Delivered source digest: `20374fc20f1d032d6f4000967c82fe1c504050da50aa7457bce607c4fd9c2586`.
- Test-inventory digest: `b917305d201daf76ff45aa8c3308f9249f44f43dc3b5b608c5dba9f101cedf7e`.
- Local verification-log digest: `3c1b9ac6d368b27687d2aa0c0ca70ecae0789766595d91f2afa54181a812f891`.

Timings describe this run only. Execution is still small relative to discovery/build; no shard increase is justified. Raw local logs and app bundles remain ignored. Hosted raw artifacts follow the existing 14-day retention; these small observations retain the identities and limits.

## Remaining gates and next package

S0 remains active. Physical input/typing/click-through/drag cancellation, actual display/Space/full-screen/sleep transitions, VoiceOver usability, sustained resources and product distribution proof remain open. Production S1 still requires applicable FZ-01/FZ-04 evidence, recorded D-01/D-02/D-05/D-06 choices, passing care curves and a valid real initial asset manifest. Fixture replay is not founder likeness or production asset approval.

Next: prepare the S0-INPUT physical evidence session and S0-ART founder/reference packet; continue S1-CORE interaction-session/cancellation planning independently. Neither production UI nor invented art is authorized by this delivery. Release PR #5 remains manual; no product was published, notarized, installed on a clean machine or automatically updated by this work. Existing credential readiness remains diagnostic evidence only. Actual dependency branch refresh/merge remains unobserved.
