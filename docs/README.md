# Documentation map

The repository uses the existing doc-warden v2 operating model. Its policy remains in `KleinPerkins/dev` at `_ops/doc-warden/POLICY.md`; the local profile is `.planning/doc-warden.json`. This page is a navigation map, not a replacement policy.

## Preserved product authority

[Approved product specification v1](reference/approved-product-specification-v1.md) is the exact document approved in this chat before the S0 prototype was implemented. SHA-256: `16b6b4bf4c471e456d98d4f04d9b2f26ba100f049d39d0616b6ec5f600f1c15d`.

Its 48 R-numbered requirements, 72-behavior catalog, proposed architecture, validation gates and full delivery scope remain intact. Importing it does not close unresolved founder decisions or promote the temporary artwork to approved design. Future canonical authoring must preserve those IDs and explicitly map them if a tool needs a different identifier syntax.

The `.planning` roadmap retains S0–S4 and expansion from the preserved specification. The canonical PRD is accepted as the planning baseline, with one-to-one `REQ-STERLING-001`–`REQ-STERLING-048` aliases for the original `R-001`–`R-048` identifiers. The source identifiers and full specification body are unchanged. The accepted PRD is frozen; semantic changes require reviewed successors through the validated doc-warden preview/consent procedure. Proposed defaults and unresolved founder decisions keep their existing status. Design, S0 exit and release approval remain separate.

## Architecture and execution

- Product modules, alternative rendering approaches, interfaces, arbitration and persistence proposals: specification section 8.
- Feasibility gates, phases, acceptance, budgets and risks: specification sections 9–10.
- New architecture decisions: `docs/adr/`, using doc-warden's numbered ADR authoring route.
- New phase plans: canonical v2 records with phase views under `.planning/phases/`; approved versions remain immutable.
- Test growth, exact CI coverage, configurable sharding and performance evidence: [testing runbook](runbooks/testing.md).
- Builds and exact local verification: `Makefile` and `Scripts/`; native runtime tests require a logged-in Mac desktop.
- Merge and automation authority: repository `AGENTS.md`, [signed release runbook](runbooks/releasing.md), and the repository-specific public delivery ADR in `docs/adr/`. Private controller policy remains owned by its existing sources.

## Historical evidence

[The S0 evidence folder](evidence/2026-10-29-s0/) contains the original verification narrative, small build/test/native receipts, own-app rendered images, and an import manifest. The narrative is a historical snapshot: statements that no repository existed were true at that time. Repository creation is a later event and does not rewrite that receipt.

The original narrative used paths such as `Docs/ApprovedProductSpecification.md` and `outputs/native-probe.json`. `import-manifest.json` records their new repository locations and original hashes. Source/tests are imported unchanged. Build and packaging scripts use lowercase `docs/` paths for case-sensitive filesystems. Packaging also includes the repository verification entrypoints and documentation profile so the exported source can pass its repository checks.

Current app bundles, zip archives, caches and raw logs are reproducible outputs and are not committed. The evidence images are temporary artwork and do not establish likeness, animation or accessibility acceptance.

[Repository import verification](evidence/2026-10-29-repository-import/README.md) records the fresh checks from the canonical checkout, separately from the preserved original S0 evidence.
