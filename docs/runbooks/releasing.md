# GitHub delivery and signed macOS releases

## Activation status

As verified on 2026-10-30, Sterling is public. Native GitHub Actions with mandatory full-SHA Action pins, the required `ci-required` gate, branch/tag protections, secret scanning and push protection, the protected `release` environment, and all required App/Apple/Sparkle setting names are configured. The installed App successfully approved and squash-merged ordinary [PR #6](https://github.com/KleinPerkins/sterling.io/pull/6) at the verified head; its main CI passed. Release-please successfully created [PR #5](https://github.com/KleinPerkins/sterling.io/pull/5), which remains owner-controlled.

The nonpublishing [Credential readiness run 41164898459](https://github.com/KleinPerkins/sterling.io/actions/runs/41164898459) succeeded at `f1f1ff3c2f3c5aa207b72a81c7ef4713173372eb`: Developer ID test signing, notarization authentication and matching Sparkle credentials passed. Do not recreate keys or request their values. Re-run the diagnostic only when credential changes or a concrete failure warrant it. No product release, notarization submission, clean installation, or installed update has been verified. S0 exit and product release approval remain separate.
The owner requested the public GitHub runner/App process and the same release controls as [Chaos Scheduler](https://github.com/KleinPerkins/chaos-scheduler/blob/e9519ddfa5c2fb5fd6017da8255729f7dfab3677/docs/RELEASING.md). Reference inspection is read-only. Sterling uses native Sparkle; Chaos uses Tauri. They share manual release PRs, owner release approval, Apple signing/notarization, verified updater assets and Latest protection, with different updater formats.

## One-time setup (established; recovery reference)

Steps 1–6 describe the existing configuration, not outstanding setup work. Read live state before changing it. Step 7 remains product distribution proof.

1. Review public exposure of all repository history and approve visibility explicitly. A secret scan is evidence, not permission to publish. This change grants no additional software license.
2. Install the reviewer GitHub App for **this repository only**, with Contents and Pull requests read/write and Metadata read. Store `AUTOMERGE_APP_ID` and `AUTOMERGE_APP_PRIVATE_KEY` as repository Actions secrets. Do not copy or display another repository's credential values. The App must not bypass branch rules.
3. Merge the workflows through the owner-controlled bootstrap PR. Verify the actual PR and main revisions have successful `CI` runs and `ci-required`. Keep deletion/force-push protection, require linear history, one approval with stale approvals dismissed, resolved conversations and strict `ci-required` from GitHub Actions. Squash merges, auto-merge availability and branch cleanup are enabled. Administrative intervention remains an explicit owner action, never a routine agent bypass.
4. Protect `sterling-v*` tags from update/deletion. Only release-please creates version tags; manual retries reuse the existing tag.
5. Create the `release` environment with required reviewer **KleinPerkins** (GitHub user ID 49759187), protected-branch deployment only, and self-review allowed for the solo owner, matching Chaos Scheduler. Do not remove the review gate to get a run through.
6. Configure the environment secrets and public key below. Keep default workflow-token permission read-only; individual trusted workflows request only what they need. Enable private vulnerability reporting after public visibility is approved.
7. Prove an initial signed install and a subsequent update on a clean test Mac before calling auto-update operational. Check both processor architectures and supported OS versions. S0/product gates remain independent.

### Release environment configuration

| Name | Kind | Purpose |
|---|---|---|
| `APPLE_CERTIFICATE` | Secret | Base64-encoded exported Developer ID Application certificate and private key in a P12 |
| `APPLE_CERTIFICATE_PASSWORD` | Secret | Password protecting that P12 |
| `APPLE_SIGNING_IDENTITY` | Secret | Exact `Developer ID Application: … (TEAMID)` identity |
| `APPLE_ID` | Secret | Your Apple Developer account email |
| `APPLE_PASSWORD` | Secret | App-specific password for notarization |
| `APPLE_TEAM_ID` | Secret | Your ten-character Apple Developer team ID |
| `SPARKLE_PRIVATE_ED_KEY` | Secret | A new Sterling-specific Ed25519 private update key exported with Sparkle's `generate_keys` tool |
| `SPARKLE_PUBLIC_ED_KEY` | Environment variable | Matching base64 public key; embedded in distributed apps |

Use the [Apple Developer certificate workflow](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/) and [Sparkle setup guide](https://sparkle-project.org/documentation/) to create or export credentials. Use the pinned Sparkle 2.10.1 tools; verify the distribution checksum in `Scripts/release.py`. Keep an encrypted owner backup. Never paste keys into chat, commit them, or reuse Chaos Scheduler's updater key. If the Apple account belongs to multiple teams, select the intended team explicitly. The build rejects identity/team mismatch, missing credentials and update key mismatch.

## Routine pull requests

Use Conventional Commit titles. CI runs repository/Python/security checks on Ubuntu and complete Swift test coverage plus a local app bundle build on macOS 15 and 26. The [test and CI runbook](testing.md) defines exact coverage, configurable sharding, timing evidence and expansion policy. `ci-required` rejects failed, skipped, cancelled, missing, duplicate and inconsistent shard evidence. Interactive desktop probes and physical-input acceptance remain manual and are not represented by CI success.

After successful CI, the App grants policy-based approval only to the exact current head of an eligible ordinary, non-draft, same-repository PR and requests native squash auto-merge. It records the explicit approval commit and uses a matching-head merge guard. Forks, newer heads, failed checks, incomplete file listings and untrusted authors are excluded. Ordinary PRs touching protected automation/signing paths remain owner-controlled. The ordinary path excludes Dependabot by PR author identity, including events triggered by an App branch refresh. Automatic approval is a policy decision backed by required CI, not substantive code review.

### Automatic dependency maintenance

The owner accepts automatic patch, minor and major dependency upgrades and prefers fixing regressions after upgrades over reviewing each update. There is no major-version human gate. Dependabot checks Actions pins and Swift dependencies weekly, with automatic rebasing explicitly enabled for both ecosystems. Dependency updates to package manifests and Action pins qualify for the separate maintenance policy even though those paths are protected from ordinary PR auto-merge. Passing CI remains mandatory; the policy does not repair code or merge a failing upgrade.

The existing **App auto-merge** workflow reconciles current open PRs after successful Dependabot PR CI, after pushes to main, on manual dispatch from main, and at minutes 17 and 47 each hour. Event triggers provide prompt progress; the roughly 30-minute schedule recovers missed events and retries failed operations. GitHub can delay scheduled runs. Shared workflow concurrency prevents overlapping maintenance passes. Each pass re-reads live PR state instead of trusting an old event payload.

Eligibility requires the actual `dependabot[bot]` identity (GitHub user ID 49699333 and Bot type), an open non-draft PR, `main` as target, source and destination in `KleinPerkins/sterling.io`, and a `dependabot/` source branch. A name or branch prefix alone is insufficient. Release-please branches and forks are excluded.

The helper compares each inspected head with an immutable main revision. A behind branch receives a GitHub update request with `expected_head_sha`; that pass stops processing the PR and waits for CI on the refreshed commit. Conflicts and permission failures remain visible. Before approval, the helper rechecks eligibility, head and main, and requires `ci-required` from the GitHub Actions App to be completed successfully on that exact head. Missing, older, pending, skipped, cancelled or failed checks cannot qualify. Approval records the explicit commit ID, and the native squash request supplies a matching-head guard. GitHub's strict branch rules remain the final gate if main or the PR changes concurrently.

Repeated passes skip an existing approval from the installed App for the current commit and do not re-enable an already-enabled squash auto-merge. Dismissed or older approvals do not count. Errors become workflow annotations and step-summary entries; processing continues for other eligible PRs, and any failed PR operation makes the run fail. A later pass retries the operation. Review **Actions → App auto-merge → dependencies** for the current pass; fix conflicts or installation/API failures without lowering CI or review requirements.

Privileged jobs check out `github.workflow_sha`, the trusted workflow revision, with credential persistence disabled. They never check out a dependency PR or execute its artifacts. The repository-scoped App token performs PR updates, approvals and merge requests; the read-only workflow token reads check runs. Existing App Contents and Pull requests write permissions are requested explicitly. The reviewer identity is derived from the installed App's returned slug and verified through GitHub, avoiding a copied repository-specific bot constant. If GitHub refuses an operation because the installation lacks a permission, the run fails visibly; token privileges and branch rules are not broadened automatically.

The helper shares dependency-free Python transport and approval gates with ordinary PR automation. This keeps one implementation of current-head checks, commit-bound approval and merge handling without adding a Node package/toolchain. Python regression tests exercise update sizes, identity boundaries, stale refresh, head/CI races, repeat runs, API and merge errors, continued processing, and release exclusion.

Dependency merging never approves or merges `chore: release main`, creates release tags, or publishes software. Release-please continues accumulating merged work in its owner-controlled release PR. Merging that PR and approving the protected `release` environment remain separate release controls.

## Checking credentials without a release

From **Actions → Credential readiness → Run workflow**, select **main**. Review and approve its `release` environment request. The workflow has a read-only GitHub token and accepts no tag or publication input. This diagnostic approval does not authorize a product release.

It imports the configured P12 into a temporary keychain, verifies the named Developer ID Application identity and team, signs and verifies a disposable binary with hardened runtime, authenticates to Apple using `notarytool history`, and signs a disposable payload with the configured Sparkle private key. An independent CryptoKit verifier must accept that signature with the public key and reject a modified payload. Keychain/search-list restoration and temporary-file cleanup must complete before success is recorded.

The artifact `credential-readiness` contains only a safe Boolean receipt and commit, not certificates, private keys, passwords, Apple history, or signed probe files. The check does not build or notarize Sterling, create tags/releases, publish assets, or prove installation/update behavior. A green run proves credential readiness only; the release gates below still apply. Failure messages name the stage or setting without exposing values. Correct the relevant encrypted environment setting and rerun; do not remove the environment approval.

## Cutting a release

1. Release-please maintains the version/changelog PR after main updates. Review and manually merge that PR once required CI and product release gates are satisfied. The App does not approve or merge it.
2. Release-please creates `sterling-vX.Y.Z` and a draft GitHub release, then directly calls the reusable signed-release workflow using the tag string. The tag is created explicitly even for a draft release; no token-generated release event is relied on.
3. Review the pending `release` environment deployment and approve only the intended tag. This approval starts signing and publishing; merging the infrastructure PR alone does not approve a product release.
4. The workflow verifies the tag is on main and has passing CI, builds both architectures, imports the P12 into a temporary keychain, signs inside out with hardened runtime, notarizes and staples the app, creates and notarizes the DMG, and signs the update ZIP with the Sterling update key. The keychain and certificate are removed on success or failure.
5. It uploads `Sterling-X.Y.Z-universal.dmg`, `Sterling-X.Y.Z-universal.zip`, `appcast.xml` and `release-receipt.json`. Draft assets may be replaced on a retry; published assets are never clobbered.
6. It publishes without changing Latest, downloads the public tag feed/archive, verifies archive length and Ed25519 signature, then promotes Latest and repeats the live-feed check. The previous Latest is restored if that final check fails. Initial publication has no previous release to restore.

Updater endpoint: `https://github.com/KleinPerkins/sterling.io/releases/latest/download/appcast.xml`.

The app exposes manual update checks and opt-in automatic checks. Silent installation is off. Local ad-hoc builds and `--probe` never create the updater. [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [Sparkle update signing](https://sparkle-project.org/documentation/publishing/) are independent requirements.

## Failure and recovery

Before publication, fix the cause and manually dispatch **Signed macOS release** from **main**, using the same existing tag and fresh runner. Do not move the tag or disable checks. The `release` environment requires approval again. A missing configuration message names the missing setting without printing its value.

After publication, assets are immutable to this pipeline. If the public smoke check failed, inspect the published assets and receipt; the previous Latest remains or is restored where available. Correct a bad artifact with a new version. For a confirmed transient endpoint problem, the owner may re-verify the existing tag/feed and promote that release manually after the same checks; the workflow deliberately refuses to overwrite it. On a first-release failure, inspect the public release directly because there is no prior Latest to restore.

Never lower the required CI check, remove environment approval, reuse a stale review, switch to ad-hoc signing, or silently rotate an updater key to make a release pass. Signing/notarization and update installation need live proof; local tests cannot certify unavailable Apple credentials.
