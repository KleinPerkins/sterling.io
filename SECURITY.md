# Security policy

This repository is owned by **KleinPerkins**. There is no public bug-bounty program or response SLA.

Report vulnerabilities through GitHub's private vulnerability reporting when enabled, or contact the owner through an existing private channel. Do not include credentials or personal data in a public issue. Provide impact, reproduction steps and suggested remediation if known.

Fixes follow reviewed PRs and required verification. Public automation executes untrusted PR source only in CI with a read-only token and no release credentials. The privileged App workflow reads PR metadata and runs only the default branch's script; it does not consume PR artifacts. Release and automation changes remain owner-controlled.

Release signing keys are restricted to the owner-reviewed GitHub `release` environment. Releases require Developer ID Application signing, hardened runtime, notarization, stapling and a separate Sparkle archive signature. Published release assets are not overwritten by the pipeline. A compromised signing or updater key requires an owner-led rotation and reviewed recovery; never silently generate a replacement key.

Scope covers this repository's code and configuration; report third-party vulnerabilities upstream. The project is still an S0 feasibility prototype and is not approved for production distribution.

This repository-specific policy replaces the managed private-repository SECURITY template under the owner's public-delivery direction. It is an explicit baseline deviation, not a change to the global private-repository policy.
