# Test growth and CI operations

## Required coverage

Every pull request and main push runs the same required `ci-required` gate. Weekly and manual CI runs exercise the full configuration as well. Ubuntu runs repository/specification integrity, all Python delivery and CI-contract tests, pinned actionlint, and a redacted gitleaks scan of committed history. macOS 15 and 26 each run every discovered Swift Testing test and build the release configuration of the local feasibility app. The update-signature verifier self-test and native shell checks run once per OS.

CI does not run desktop input probes, create production-signed releases, or prove accessibility, likeness, installation or S0 acceptance. Those require their own evidence. `make verify` remains the unfiltered local/release gate, including all Swift tests, Python tests, source checks, signature-verifier self-test and local app build.

## Exact sharding contract

`.github/test-shards.json` controls `native_shards`, an integer from 1 through 8. Its default is 1 per OS. `Scripts/ci.py` discovers tests from the compiler with `swift test list`, sorts their canonical IDs, and assigns each using the first eight SHA-256 bytes, big-endian, modulo the shard count. This is deterministic and independent of discovery order. Empty shards fail and require a smaller count.

Each runner builds during discovery, runs its assigned tests using `--skip-build`, and emits xUnit evidence. The receipt records the commit, source digest, complete inventory, selected and executed IDs, report digest, and separate discovery/build and execution timings. Exact executed IDs must match the assignment. Duplicate, skipped, failed, zero-test and unsupported discovery/report formats fail closed. A successful process exit alone is insufficient.

The always-running `ci-required` job first requires every upstream job to succeed, then downloads all shard evidence. It requires exactly one receipt for every configured OS/shard, identical inventories/source snapshots, current-commit evidence, intact reports, and complete disjoint test coverage per OS. Missing artifacts, cancellation, changed inventories or unexpected tests cannot turn into a green aggregate. Raw reports and timing receipts are retained for 14 days; the aggregate writes a timing table to the run summary.

## Expanding the codebase

Add domain behavior to `SterlingCore` and its Swift Testing suites. Add update configuration behavior to `SterlingUpdateSupport` tests. Keep native UI/input tests separate from deterministic domain tests. New Swift Testing targets are discovered automatically; no hand-maintained test-file list or changed-path skip rule can silently omit them. Keep tests independent of execution order and shared writable fixtures; use isolated temporary directories, deterministic seeds and explicit time inputs.

The existing Swift wrapper disables XCTest. Use Swift Testing for these targets. If adding XCTest, parameterized tests or a toolchain changes discovery/xUnit identity semantics, extend the discovery/report adapter with a real failing fixture and prove complete hosted coverage before adoption. Do not strip unfamiliar lines or fall back to successful exit status. Platform-specific tests need an explicit coverage contract; the default deliberately requires the same inventory on both OS versions.

Add Python contract tests for release, credential, App and CI trust boundaries. They run in one inexpensive Ubuntu job today. Split them only if measured duration warrants it, preserving exact discovery/coverage evidence. Keep ordinary behavior tests close to the module they protect. Avoid tests that merely repeat implementation expressions.

Dependabot checks Actions pins and Swift dependencies weekly. Its patch, minor and major upgrades use the [automatic dependency maintenance policy](releasing.md#automatic-dependency-maintenance), with stale-branch recovery, current-commit `ci-required`, explicit commit-bound approval and native squash merging. These are policy approvals, not substantive code review. Other PRs touching workflow, package, signing or updater paths remain owner-controlled; ordinary eligible changes use the App's exact-head approval path. Python regression tests cover both automation paths, including release exclusion, races, repeated passes and visible per-PR failures. GitHub secret scanning and push protection supplement the redacted CI history scan; full-SHA Action pins are required by both repository checks and GitHub settings. Preserve the approved specification and accepted planning records when expanding requirements; use successor records through doc-warden.

## Scaling from measurements

At initial setup there are 21 Swift tests, with execution under one second locally; dependency resolution and compilation dominate. One shard per OS avoids paying for duplicate builds without a demonstrated latency benefit. This is an initial measurement, not a lasting performance promise.

Use **Actions → CI → Run workflow → native_shards** to compare 1 versus 2 (then higher counts only when justified) at the same commit. Compare wall-clock critical path, per-shard discovery/build versus execution, queue time, and total runner minutes. Repeat enough runs to separate cold dependencies/runner variation from test savings. Raise the committed count only when execution is a meaningful bottleneck and the measured wall-clock gain justifies duplicated build cost. Limit native concurrency to four; higher counts queue deliberately.

For skewed runtimes, measure slow tests before introducing duration-weighted assignments. For expensive compilation, measure module boundaries, dependency caching or building once per OS before increasing shards. Any cache must be keyed by toolchain, OS/architecture and resolved dependencies and must not replace test/report verification. No cross-PR executable artifacts enter privileged App/release workflows.

Local reproduction on a matching Mac:

```sh
make verify
python3 Scripts/ci.py plan --shards 2
make test-shard PLATFORM=macos-26 SHARD_COUNT=2 SHARD_INDEX=0
make test-shard PLATFORM=macos-26 SHARD_COUNT=2 SHARD_INDEX=1
```

Use `PLATFORM=macos-15` on macOS 15. The local command runs only the specified partition; full coverage still requires both partitions and both hosted OS jobs. If sharding fails, revert `native_shards` to 1 and rerun CI. Never remove or weaken `ci-required`, accept skipped coverage, or mark a flaky failure successful. Fix or explicitly redesign the test with reviewed evidence.
