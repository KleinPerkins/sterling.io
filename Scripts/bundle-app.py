#!/usr/bin/env python3
"""Bundle local previews or Developer ID releases; release signing never falls back."""
from pathlib import Path
import base64, os, plistlib, re, shutil, subprocess, sys

root = Path(__file__).resolve().parent.parent
products = Path(sys.argv[1]).resolve()
release = os.environ.get("STERLING_DISTRIBUTION_BUILD") == "1"
version = (root / "VERSION").read_text().strip()
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise SystemExit("VERSION must be a three-part release version.")
identity = os.environ.get("APPLE_SIGNING_IDENTITY", "") if release else "-"
public_key = os.environ.get("SPARKLE_PUBLIC_ED_KEY", "") if release else ""
if release:
    if not identity.startswith("Developer ID Application:"):
        raise SystemExit("A Developer ID Application signing identity is required.")
    try:
        assert len(base64.b64decode(public_key, validate=True)) == 32
    except Exception:
        raise SystemExit("A valid Sparkle public Ed25519 key is required.")
name = "Sterling" if release else "Sterling Feasibility"
bundle = products / (name + ".app")
if bundle.exists(): shutil.rmtree(bundle)
macos = bundle / "Contents/MacOS"
resources = bundle / "Contents/Resources"
frameworks = bundle / "Contents/Frameworks"
for directory in (macos, resources, frameworks): directory.mkdir(parents=True, exist_ok=True)
shutil.copy2(products / "SterlingPrototype", macos / "SterlingPrototype")
# Locate the binary target resolved by SwiftPM inside this package's scratch root.
scratch = products
while scratch.parent != scratch and scratch.name != "build": scratch = scratch.parent
candidates = sorted((scratch / "artifacts").rglob("Sparkle.framework"))
if not candidates:
    raise SystemExit("SwiftPM's Sparkle.framework was not found.")
framework = candidates[0]
subprocess.run(["ditto", "--norsrc", "--noextattr", str(framework), str(frameworks / "Sparkle.framework")], check=True)
shutil.copy2(root / "ThirdPartyNotices/Sparkle-LICENSE.txt", resources / "Sparkle-LICENSE.txt")
info = {
    "CFBundleName": name, "CFBundleDisplayName": name,
    "CFBundleIdentifier": "io.sterling.app" if release else "io.sterling.feasibility",
    "CFBundleExecutable": "SterlingPrototype", "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": version, "CFBundleVersion": version,
    "LSMinimumSystemVersion": "15.0", "LSUIElement": True,
    "NSHighResolutionCapable": True, "NSPrincipalClass": "NSApplication",
    "SterlingDistributionBuild": release, "SUEnableAutomaticChecks": False,
    "SUAutomaticallyUpdate": False, "SUAllowsAutomaticUpdates": False, "SUEnableSystemProfiling": False,
}
if release:
    info.update(SUFeedURL="https://github.com/KleinPerkins/sterling.io/releases/latest/download/appcast.xml", SUPublicEDKey=public_key)
with (bundle / "Contents/Info.plist").open("wb") as f: plistlib.dump(info, f)
# Sparkle's helpers are signed inside out with the application's identity.
sparkle = frameworks / "Sparkle.framework/Versions/B"
for relative in ("XPCServices/Downloader.xpc", "XPCServices/Installer.xpc", "Autoupdate", "Updater.app"):
    target = sparkle / relative
    if target.exists():
        command = ["codesign", "--force", "--sign", identity, "--options", "runtime"]
        if release: command.append("--timestamp")
        subprocess.run(command + [str(target)], check=True)
command = ["codesign", "--force", "--sign", identity, "--options", "runtime"]
if release: command.append("--timestamp")
subprocess.run(command + [str(frameworks / "Sparkle.framework")], check=True)
if not release: command += ["--entitlements", str(root / "Configuration/development.entitlements")]
subprocess.run(command + [str(bundle)], check=True)
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(bundle)], check=True)
outputs = root / "outputs"; outputs.mkdir(exist_ok=True)
destination = outputs / (name + ".app")
if destination.exists(): shutil.rmtree(destination)
subprocess.run(["ditto", "--norsrc", "--noextattr", str(bundle), str(destination)], check=True)
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(destination)], check=True)
print(str(destination))
