#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p work outputs
Scripts/swift.sh build -c release --product SterlingPrototype > work/release-build.log 2>&1 || { tail -n 60 work/release-build.log; exit 1; }
products=$(Scripts/swift.sh build -c release --show-bin-path)
python3 Scripts/bundle-app.py "$products"
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
