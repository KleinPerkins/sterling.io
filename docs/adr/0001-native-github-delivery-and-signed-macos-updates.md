---
{"approval":null,"authority":"semantic","github_repository_id":1439196929,"id":"ADR-01b2bbbc-da9d-4602-ac03-ccfd6b484f11-b7b6ccf7-187a-56a3-b9ba-96a1a939cb53","lifecycle":"draft","mutability":"frozen_after_approval","provenance":[],"relations":[],"repository_key":"01b2bbbc-da9d-4602-ac03-ccfd6b484f11","schema":"doc-warden/artifact/v2","supersedes":null,"type":"adr","version":1}
---
# ADR 0001: Native GitHub delivery and signed macOS updates

## Decision

The owner requested native GitHub Actions, workflows and hosted runners for Sterling's intended public repository, App-driven ordinary PR approval/merge, and Apple Developer ID releases following Chaos Scheduler. This repository-specific direction replaces Sterling's earlier private runnerless setup. It does not change the private-repository policy or configure the PR automation controller.

Use GitHub Actions CI with the stable required `ci-required` aggregate, an installed reviewer GitHub App, squash auto-merge for verified ordinary same-repository heads, release-please version PRs, and a manually approved `release` environment. Release PRs and protected automation paths remain manual. Never arm a newer head using old CI or approval.

Release universal arm64/x86_64 macOS apps signed with the owner's Developer ID Application certificate, hardened runtime, Apple notarization and stapled tickets. Native Swift uses Sparkle 2.10.1 with a Sterling-specific Ed25519 update key. The Apple certificate and Sparkle key are independent trust requirements. Secrets remain in GitHub's encrypted settings and an ephemeral runner keychain.

Release-please creates an existing version tag and a draft release. Signing, packaging and public asset verification complete before promoting Latest. The previous release remains the updater target during approval and build; a failed live-feed verification restores the previous Latest when one exists. Published assets cannot be overwritten by this pipeline. The first published release has no earlier target to restore.

## Why

Reference: [Chaos Scheduler at e9519dd](https://github.com/KleinPerkins/chaos-scheduler/tree/e9519ddfa5c2fb5fd6017da8255729f7dfab3677), specifically `.github/workflows/app-auto-merge.yml`, `release-please.yml`, `release.yml`, and `docs/RELEASING.md`. This is read-only reference use; no Chaos Scheduler content or settings are changed.

Its Tauri updater cannot run inside Sterling's Swift/AppKit host. Sparkle supplies the corresponding native updater while retaining the same owner approval, Apple signing, notarization and release-feed checks. Sterling publishes a DMG, a signed update ZIP and `appcast.xml` instead of Tauri's tarball and `latest.json`. An App token creates release PRs so their CI runs. A draft release plus explicit tag creation prevents an empty release from taking over Latest.

Automatic update checks are opt-in from the owner-operated menu. Local feasibility builds and `--probe` never start Sparkle. Silent update installation is disabled. This distribution-only network capability does not authorize screen/document access, input injection, or network use by the simulation.

## Consequences and activation gates

The owner must explicitly approve public exposure of the repository and its history. Configure the App installation, required branch checks, owner-reviewed release environment, Apple credentials and a new Sterling update key. Do not reuse Chaos Scheduler's updater key. No actual credential values belong in source, logs, artifacts, or chat.

The reviewed implementation may be applied after the exact doc-warden consent. This ADR remains draft until separately accepted; it records the owner's requested direction and proposed implementation details without inventing product acceptance. CI setup and a signed pipeline do not close S0, supported-platform validation, accessibility, likeness, external beta or release approval.

The managed private SECURITY template is replaced by a repository-specific public policy in the same reviewed change. This is an explicit local baseline deviation; the global baseline and its owner registry are not silently rewritten. See the release runbook for prerequisites and failure recovery.
