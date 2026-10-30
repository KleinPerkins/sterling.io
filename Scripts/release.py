#!/usr/bin/env python3
"""Developer ID + notarization + Sparkle publication. Runs only after release approval."""
from pathlib import Path
import base64
import hashlib
import json
import os
import plistlib
import re
import secrets
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
REPO = "KleinPerkins/sterling.io"
FEED = f"https://github.com/{REPO}/releases/latest/download/appcast.xml"
SPARKLE = "2.10.1"
TOOLS_SHA256 = "1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27"
NS = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
REQUIRED_SECRETS = ("APPLE_CERTIFICATE", "APPLE_CERTIFICATE_PASSWORD", "APPLE_SIGNING_IDENTITY",
                    "APPLE_ID", "APPLE_PASSWORD", "APPLE_TEAM_ID", "SPARKLE_PRIVATE_ED_KEY", "SPARKLE_PUBLIC_ED_KEY")


def run(*args, input=None, env=None):
    result = subprocess.run([str(a) for a in args], input=input, capture_output=True, text=True, env=env, cwd=ROOT)
    if result.returncode:
        # Command arguments may contain secrets. Never include them or subprocess output.
        raise RuntimeError(f"{Path(str(args[0])).name} failed (exit {result.returncode}); release stopped")
    return result.stdout


def api(path, payload=None):
    args = ["gh", "api", f"repos/{REPO}/{path}"]
    if payload is not None: args += ["--method", "PATCH", "--input", "-"]
    return json.loads(run(*args, input=json.dumps(payload) if payload is not None else None))


def version_for(tag):
    match = re.fullmatch(r"sterling-v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag)
    if not match: raise ValueError("Expected sterling-vX.Y.Z release tag")
    return tag.removeprefix("sterling-v")


def version_tuple(tag):
    return tuple(map(int, version_for(tag).split(".")))


def download(url, path):
    request = urllib.request.Request(url, headers={"User-Agent": "Sterling-release-verifier"})
    with urllib.request.urlopen(request, timeout=60) as response, Path(path).open("wb") as output:
        if response.status != 200: raise ValueError("Release asset did not return HTTP 200")
        shutil.copyfileobj(response, output)


def validate_feed(data, tag):
    version = version_for(tag)
    if b"<!DOCTYPE" in data.upper() or b"<!ENTITY" in data.upper(): raise ValueError("Unexpected XML declaration")
    items = ET.fromstring(data).findall("./channel/item")
    if len(items) != 1: raise ValueError("Expected exactly one full update")
    item = items[0]
    if item.findtext(NS + "version") != version: raise ValueError("Feed version mismatch")
    if item.findtext(NS + "minimumSystemVersion") != "15.0.0": raise ValueError("Minimum OS mismatch")
    enclosure = item.find("enclosure")
    if enclosure is None: raise ValueError("Missing update archive")
    expected = f"https://github.com/{REPO}/releases/download/{tag}/Sterling-{version}-universal.zip"
    if enclosure.get("url") != expected: raise ValueError("Unexpected update URL")
    signature = enclosure.get(NS + "edSignature", "")
    if len(base64.b64decode(signature, validate=True)) != 64: raise ValueError("Invalid signature")
    length = int(enclosure.get("length", "0"))
    if length <= 0: raise ValueError("Invalid archive length")
    return expected, signature, length


def verify_archive(path, signature, public_key):
    cache = ROOT / "work/swift-script-cache"; cache.mkdir(parents=True, exist_ok=True)
    run("xcrun", "swift", "-module-cache-path", cache, ROOT / "Scripts/verify-update.swift", public_key, signature, path)


def prepare(tag):
    version = version_for(tag)
    if api("")["private"]: raise ValueError("Public updater publishing requires a public repository")
    revision = run("git", "rev-parse", f"refs/tags/{tag}^{{commit}}").strip()
    run("git", "merge-base", "--is-ancestor", revision, "origin/main")
    if run("git", "show", f"{revision}:VERSION").strip() != version: raise ValueError("Tag/version mismatch")
    release = api(f"releases/tags/{tag}")
    if not release["draft"] or release["prerelease"]: raise ValueError("Only an unpublished stable release can be built")
    # The manual approval may arrive before the push's CI finishes. Wait for the
    # actual tag commit, never a check from a previous revision.
    for attempt in range(45):
        checks = api(f"commits/{revision}/check-runs?check_name=ci-required&filter=latest")["check_runs"]
        gates = [c for c in checks if c["app"]["slug"] == "github-actions"]
        if gates and all(c["conclusion"] == "success" for c in gates): break
        if any(c["status"] == "completed" and c["conclusion"] != "success" for c in gates):
            raise ValueError("Release commit CI failed")
        if attempt == 44: raise ValueError("Release commit CI did not complete")
        time.sleep(20)
    run("git", "checkout", "--detach", revision)
    print(f"Validated {tag} at {revision}; signed release remains unpublished.")


def tools_directory(temp):
    archive = temp / "sparkle.tar.xz"
    download(f"https://github.com/sparkle-project/Sparkle/releases/download/{SPARKLE}/Sparkle-{SPARKLE}.tar.xz", archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != TOOLS_SHA256: raise ValueError("Sparkle tool checksum mismatch")
    tools = temp / "sparkle"; tools.mkdir()
    run("tar", "-xf", archive, "-C", tools)
    return tools


def notarize(path, keychain):
    result = json.loads(run("xcrun", "notarytool", "submit", path, "--keychain-profile", "sterling-release",
                            "--keychain", keychain, "--wait", "--timeout", "20m", "--output-format", "json"))
    if result.get("status") != "Accepted": raise ValueError("Apple did not accept notarization")
    return result["id"]


def package(tag):
    version = version_for(tag)
    missing = [key for key in REQUIRED_SECRETS if not os.environ.get(key)]
    if missing: raise ValueError("Missing release configuration: " + ", ".join(missing))
    if (ROOT / "VERSION").read_text().strip() != version: raise ValueError("Checked-out version mismatch")
    identity = os.environ["APPLE_SIGNING_IDENTITY"]
    team = os.environ["APPLE_TEAM_ID"]
    if not re.fullmatch(r"[A-Z0-9]{10}", team) or not identity.startswith("Developer ID Application:") or not identity.endswith(f"({team})"):
        raise ValueError("Developer ID identity must belong to the configured Apple team")
    public_key = os.environ["SPARKLE_PUBLIC_ED_KEY"]
    if len(base64.b64decode(public_key, validate=True)) != 32: raise ValueError("Invalid public update key")
    dist = ROOT / "outputs/release"; dist.mkdir(parents=True, exist_ok=True)
    if any(dist.iterdir()): raise ValueError("Release output must be empty; use a fresh runner for retries")
    old_keychains = shlex.split(run("security", "list-keychains", "-d", "user"))
    with tempfile.TemporaryDirectory(prefix="sterling-signing-") as name:
        temp = Path(name); keychain = temp / "release.keychain-db"
        password = secrets.token_urlsafe(32)
        p12 = temp / "certificate.p12"
        p12.write_bytes(base64.b64decode(os.environ["APPLE_CERTIFICATE"], validate=True)); p12.chmod(0o600)
        try:
            run("security", "create-keychain", "-p", password, keychain)
            run("security", "set-keychain-settings", "-lut", "3600", keychain)
            run("security", "unlock-keychain", "-p", password, keychain)
            run("security", "import", p12, "-k", keychain, "-P", os.environ["APPLE_CERTIFICATE_PASSWORD"],
                "-T", "/usr/bin/codesign", "-T", "/usr/bin/security")
            run("security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", password, keychain)
            run("security", "list-keychains", "-d", "user", "-s", keychain, *old_keychains)
            run("xcrun", "notarytool", "store-credentials", "sterling-release", "--keychain", keychain,
                "--apple-id", os.environ["APPLE_ID"], "--password", os.environ["APPLE_PASSWORD"], "--team-id", team)
            tools = tools_directory(temp)
            run("zsh", "Scripts/swift.sh", "build", "-c", "release", "--product", "SterlingPrototype", "--arch", "arm64", "--arch", "x86_64")
            products = run("zsh", "Scripts/swift.sh", "build", "-c", "release", "--show-bin-path", "--arch", "arm64", "--arch", "x86_64").strip()
            env = dict(os.environ, STERLING_DISTRIBUTION_BUILD="1")
            run(sys.executable, "Scripts/bundle-app.py", products, env=env)
            app = ROOT / "outputs/Sterling.app"
            binary = app / "Contents/MacOS/SterlingPrototype"
            if set(run("lipo", "-archs", binary).split()) != {"arm64", "x86_64"}: raise ValueError("Universal binary required")
            detail = subprocess.run(["codesign", "-d", "--verbose=4", str(app)], capture_output=True, text=True, check=True).stderr
            if f"TeamIdentifier={team}" not in detail or "runtime" not in detail: raise ValueError("Wrong team or missing hardened runtime")
            entitlements = run("codesign", "-d", "--entitlements", ":-", app)
            if "disable-library-validation" in entitlements or "get-task-allow" in entitlements: raise ValueError("Development entitlement in release")
            submission = temp / "submission.zip"
            run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, submission)
            app_ticket = notarize(submission, keychain)
            run("xcrun", "stapler", "staple", app)
            run("xcrun", "stapler", "validate", app)
            run("spctl", "--assess", "--type", "execute", app)
            archive = dist / f"Sterling-{version}-universal.zip"
            run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, archive)
            signature = run(tools / "bin/sign_update", "--ed-key-file", "-", "-p", archive,
                            input=os.environ["SPARKLE_PRIVATE_ED_KEY"] + "\n").strip()
            verify_archive(archive, signature, public_key)
            # Build a deterministic, single-version full-update feed; no delta files.
            ET.register_namespace("sparkle", NS[1:-1])
            rss = ET.Element("rss", {"version": "2.0"}); channel = ET.SubElement(rss, "channel")
            ET.SubElement(channel, "title").text = "Sterling updates"
            ET.SubElement(channel, "link").text = f"https://github.com/{REPO}"
            ET.SubElement(channel, "description").text = "Signed Sterling macOS releases"
            item = ET.SubElement(channel, "item"); ET.SubElement(item, "title").text = f"Sterling {version}"
            ET.SubElement(item, NS + "version").text = version
            ET.SubElement(item, NS + "shortVersionString").text = version
            ET.SubElement(item, NS + "minimumSystemVersion").text = "15.0.0"
            ET.SubElement(item, "enclosure", {"url": f"https://github.com/{REPO}/releases/download/{tag}/{archive.name}",
                NS + "edSignature": signature, "length": str(archive.stat().st_size), "type": "application/octet-stream"})
            feed = dist / "appcast.xml"; ET.ElementTree(rss).write(feed, encoding="utf-8", xml_declaration=True)
            validate_feed(feed.read_bytes(), tag)
            stage = temp / "dmg"; stage.mkdir()
            run("ditto", app, stage / "Sterling.app"); (stage / "Applications").symlink_to("/Applications")
            dmg = dist / f"Sterling-{version}-universal.dmg"
            run("hdiutil", "create", "-volname", "Sterling", "-srcfolder", stage, "-fs", "APFS", "-format", "ULFO", dmg)
            run("codesign", "--force", "--sign", identity, "--timestamp", dmg)
            dmg_ticket = notarize(dmg, keychain)
            run("xcrun", "stapler", "staple", dmg); run("xcrun", "stapler", "validate", dmg)
            receipt = {"version": version, "commit": run("git", "rev-parse", "HEAD").strip(), "teamID": team,
                       "architectures": ["arm64", "x86_64"], "appNotarizationID": app_ticket, "dmgNotarizationID": dmg_ticket,
                       "sha256": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (archive, dmg, feed)}}
            (dist / "release-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
        finally:
            # Restore the runner keychain search list, even on a signing/notary failure.
            try: run("security", "list-keychains", "-d", "user", "-s", *old_keychains)
            finally:
                if keychain.exists(): run("security", "delete-keychain", keychain)
    print("Developer ID signatures, notarization tickets, universal binary and update signature verified.")


def public_smoke(tag, directory, public_key, *, latest=False):
    prefix = f"https://github.com/{REPO}/releases/download/{tag}/"
    feed_file = directory / "appcast.xml"
    download(FEED if latest else prefix + "appcast.xml", feed_file)
    url, signature, length = validate_feed(feed_file.read_bytes(), tag)
    archive = directory / "update.zip"; download(url, archive)
    if archive.stat().st_size != length: raise ValueError("Downloaded update length mismatch")
    verify_archive(archive, signature, public_key)


def publish(tag):
    version_for(tag)
    release = api(f"releases/tags/{tag}")
    if not release["draft"]: raise ValueError("Refusing to replace assets of a published release")
    previous = subprocess.run(["gh", "api", f"repos/{REPO}/releases/latest"], capture_output=True, text=True)
    old = json.loads(previous.stdout) if previous.returncode == 0 else None
    if previous.returncode and "404" not in previous.stderr: raise ValueError("Could not determine previous Latest release")
    if old and version_tuple(old["tag_name"]) >= version_tuple(tag): raise ValueError("Refusing a non-increasing release")
    dist = ROOT / "outputs/release"
    receipt = json.loads((dist / "release-receipt.json").read_text())
    if receipt["commit"] != run("git", "rev-parse", f"refs/tags/{tag}^{{commit}}").strip(): raise ValueError("Tag moved after build")
    for filename, expected in receipt["sha256"].items():
        if hashlib.sha256((dist / filename).read_bytes()).hexdigest() != expected: raise ValueError("Asset changed after signing")
    # Only draft assets may be replaced on a retry. A published release is immutable here.
    assets = [dist / name for name in (*receipt["sha256"].keys(), "release-receipt.json")]
    run("gh", "release", "upload", tag, *assets, "--repo", REPO, "--clobber")
    public_key = os.environ["SPARKLE_PUBLIC_ED_KEY"]
    # Publish with Latest explicitly false; old clients keep their working feed.
    api(f"releases/{release['id']}", {"draft": False, "make_latest": "false"})
    if old: api(f"releases/{old['id']}", {"make_latest": "true"})
    with tempfile.TemporaryDirectory(prefix="sterling-smoke-") as name:
        temp = Path(name)
        for attempt in range(6):
            try:
                public_smoke(tag, temp, public_key)
                break
            except Exception:
                if attempt == 5: raise
                time.sleep(15)
        api(f"releases/{release['id']}", {"make_latest": "true"})
        try:
            for attempt in range(6):
                try:
                    public_smoke(tag, temp, public_key, latest=True)
                    break
                except Exception:
                    if attempt == 5: raise
                    time.sleep(15)
        except Exception:
            if old: api(f"releases/{old['id']}", {"make_latest": "true"})
            raise
    print(f"Published {tag}; public feed and downloaded update signature verified.")


if __name__ == "__main__":
    try:
        command = {"prepare": prepare, "package": package, "publish": publish}[sys.argv[1]]
        command(os.environ["RELEASE_TAG"])
    except Exception as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
