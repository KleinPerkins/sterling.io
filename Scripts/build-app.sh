#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p work outputs
Scripts/swift.sh build -c release --product SterlingPrototype > work/release-build.log 2>&1 || { tail -n 60 work/release-build.log; exit 1; }
products=$(Scripts/swift.sh build -c release --show-bin-path)
staging="$products/Sterling Feasibility.app"
mkdir -p "$staging/Contents/MacOS" "$staging/Contents/Resources"
cp "$products/SterlingPrototype" "$staging/Contents/MacOS/SterlingPrototype"
chmod +x "$staging/Contents/MacOS/SterlingPrototype"
python3 - "$staging" <<'PY'
from pathlib import Path
import plistlib, sys
info={
    'CFBundleName':'Sterling Feasibility',
    'CFBundleDisplayName':'Sterling Feasibility',
    'CFBundleIdentifier':'io.sterling.feasibility',
    'CFBundleExecutable':'SterlingPrototype',
    'CFBundlePackageType':'APPL',
    'CFBundleShortVersionString':'0.0.1',
    'CFBundleVersion':'1',
    'LSMinimumSystemVersion':'15.0',
    'LSUIElement':True,
    'NSHighResolutionCapable':True,
    'NSPrincipalClass':'NSApplication',
}
with (Path(sys.argv[1])/'Contents/Info.plist').open('wb') as f: plistlib.dump(info,f)
PY
codesign --force --sign - --options runtime "$staging"
codesign --verify --strict "$staging"
ditto --norsrc --noextattr "$staging" "outputs/Sterling Feasibility.app"
# Only remove generated bundle Finder metadata if File Provider adds it on copy.
if xattr "outputs/Sterling Feasibility.app" | rg -q '^com.apple.FinderInfo$'; then
    xattr -d com.apple.FinderInfo "outputs/Sterling Feasibility.app"
fi
codesign --verify --strict "outputs/Sterling Feasibility.app"
codesign -d --verbose=4 "outputs/Sterling Feasibility.app" 2> work/signing-receipt.txt
python3 - <<'PY'
from pathlib import Path
import hashlib,json,subprocess,datetime
root=Path.cwd()
paths=[root/'Package.swift']+sorted((root/'Sources').rglob('*.swift'))
h=hashlib.sha256()
for p in paths:
    h.update(str(p.relative_to(root)).encode()+b'\0'+p.read_bytes())
binary=root/'outputs/Sterling Feasibility.app/Contents/MacOS/SterlingPrototype'
receipt={
  'kind':'sterling-build/v1','createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
  'configuration':'release','architecture':subprocess.check_output(['uname','-m'],text=True).strip(),
  'compiler':subprocess.check_output(['xcrun','swift','--version'],text=True).strip(),
  'sdk':subprocess.check_output(['xcrun','--show-sdk-version'],text=True).strip(),
  'binarySHA256':hashlib.sha256(binary.read_bytes()).hexdigest(),'sourceSHA256':h.hexdigest(),
  'approvedSpecificationSHA256':hashlib.sha256((root/'docs/reference/approved-product-specification-v1.md').read_bytes()).hexdigest(),
  'signing':'Ad-hoc with hardened runtime; codesign --verify --strict passed',
  'notarized':False,'sandboxEntitlementProven':False,'externalBetaReady':False,
}
(root/'outputs/build-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('Built outputs/Sterling Feasibility.app — local feasibility preview only.')
PY
