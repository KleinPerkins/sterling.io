#!/usr/bin/env python3
"""Small repository checks; native tests and builds remain separate explicit gates."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parent.parent
spec = root / "docs/reference/approved-product-specification-v1.md"
expected = "16b6b4bf4c471e456d98d4f04d9b2f26ba100f049d39d0616b6ec5f600f1c15d"
if hashlib.sha256(spec.read_bytes()).hexdigest() != expected:
    raise SystemExit("The approved v1 specification changed. Restore it and author a successor.")
required_workflows = {"ci.yml", "app-auto-merge.yml", "release-please.yml", "release.yml", "credential-readiness.yml"}
workflows = {p.name for p in (root / ".github/workflows").glob("*.yml")}
if not required_workflows.issubset(workflows):
    raise SystemExit("The native GitHub delivery workflows are incomplete.")
for workflow in (root / ".github/workflows").glob("*.yml"):
    for action in re.findall(r"uses:\s*([^\s#]+)", workflow.read_text()):
        if not action.startswith("./") and not re.fullmatch(r"[^@]+@[a-f0-9]{40}", action):
            raise SystemExit(f"External action must be pinned by commit: {workflow.name}")
profile = root / ".planning/doc-warden.json"
if not profile.is_file():
    raise SystemExit("The doc-warden repository profile is missing.")
if json.loads(profile.read_text())["schema"] != "doc-warden/config/v2":
    raise SystemExit("Unexpected repository documentation profile.")
for name in ["AGENTS.md", "SECURITY.md", ".github/CODEOWNERS", "Package.swift"]:
    if not (root / name).is_file():
        raise SystemExit(f"Required repository entrypoint is missing: {name}")
print("Approved specification integrity, repository entrypoints and native GitHub workflow entrypoints checked.")
