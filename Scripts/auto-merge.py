#!/usr/bin/env python3
"""Base-branch-only workflow_run handler. Never executes pull request content."""
import fnmatch, json, os, subprocess
from pathlib import Path

REPO = "KleinPerkins/sterling.io"
PROTECTED = (".github/*", ".gitleaks*", "Makefile", "AGENTS.md", "SECURITY.md", "Scripts/*", "Configuration/*",
             "Package.*", "VERSION", "release-please*", ".release-please*",
             "Sources/SterlingUpdateSupport/*", "Sources/SterlingPrototype/AppUpdater.swift")

def eligible(pr, run, files):
    if run.get("event") != "pull_request" or run.get("conclusion") != "success": return False
    if run.get("head_repository", {}).get("full_name") != REPO: return False
    if pr.get("state") != "open" or pr.get("draft") or pr.get("base", {}).get("ref") != "main": return False
    if pr.get("head", {}).get("repo", {}).get("full_name") != REPO: return False
    if pr["head"]["sha"] != run.get("head_sha"): return False
    if pr["head"]["ref"].startswith("release-please--"): return False
    if pr.get("author_association") not in ("OWNER", "MEMBER", "COLLABORATOR") and pr.get("user", {}).get("login") != "dependabot[bot]": return False
    return bool(files) and not any(fnmatch.fnmatchcase(path, pattern) for path in files for pattern in PROTECTED)

def api(path, *, payload=None, token=None, paginate=False):
    command = ["gh", "api", path]
    if paginate: command += ["--paginate", "--slurp"]
    if payload is not None: command += ["--method", "POST", "--input", "-"]
    env = dict(os.environ)
    if token: env["GH_TOKEN"] = token
    result = subprocess.run(command, input=json.dumps(payload) if payload is not None else None,
                            text=True, capture_output=True, check=True, env=env)
    return json.loads(result.stdout)

def main():
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    run = event["workflow_run"]
    if event["repository"]["full_name"] != REPO: raise SystemExit("Unexpected repository")
    # Resolve through the commit rather than interpolating an untrusted branch name.
    prs = api(f"repos/{REPO}/commits/{run['head_sha']}/pulls")
    for candidate in prs:
        number = int(candidate["number"])
        path = f"repos/{REPO}/pulls/{number}"
        pr = api(path)
        pages = api(path + "/files?per_page=100", paginate=True)
        entries = [f for page in pages for f in page]
        # A rename must not evade protected-path review by moving the old path.
        files = [path for f in entries for path in (f["filename"], f.get("previous_filename")) if path]
        if len(entries) != pr["changed_files"] or not eligible(pr, run, files):
            print(f"PR #{number}: manual review or newer head; skipped.")
            continue
        jobs = api(f"repos/{REPO}/actions/runs/{int(run['id'])}/jobs?per_page=100", token=os.environ["CI_READ_TOKEN"])
        if not any(j["name"] == "ci-required" and j["conclusion"] == "success" for j in jobs["jobs"]):
            raise SystemExit("The completed run has no successful ci-required gate")
        head = pr["head"]["sha"]
        if api(path)["head"]["sha"] != head: continue
        api(path + "/reviews", payload={"event": "APPROVE", "commit_id": head})
        # Exact commit review plus stale-review dismissal and the CLI's head guard
        # keep a later push from inheriting this approval.
        subprocess.run(["gh", "pr", "merge", str(number), "--repo", REPO,
                        "--auto", "--squash", "--match-head-commit", head], check=True)
        print(f"PR #{number}: App approval recorded; GitHub evaluates merge rules.")

if __name__ == "__main__": main()
