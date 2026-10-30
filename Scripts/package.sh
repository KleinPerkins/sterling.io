#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
python3 - <<'PY'
from pathlib import Path
import hashlib,json,zipfile
root=Path.cwd()
read=lambda name:json.loads((root/'outputs'/name).read_text())
build=read('build-receipt.json');probe=read('native-probe.json');tests=read('test-receipt.json')
def digest(paths):
    h=hashlib.sha256()
    for p in paths: h.update(str(p.relative_to(root)).encode()+b'\0'+p.read_bytes())
    return h.hexdigest()
binary=root/'outputs/Sterling Feasibility.app/Contents/MacOS/SterlingPrototype'
actual=hashlib.sha256(binary.read_bytes()).hexdigest()
assert build['binarySHA256']==probe['binarySHA256']==actual,'Build/probe binary mismatch'
assert build['sourceSHA256']==digest([root/'Package.swift']+sorted((root/'Sources').rglob('*.swift'))),'Source changed since build'
assert tests['domainSHA256']==digest(sorted((root/'Sources/SterlingCore').glob('*.swift'))),'Domain changed since tests'
assert tests['testsSHA256']==digest(sorted((root/'Tests').rglob('*.swift'))),'Tests changed since run'
assert tests['passed'] and probe['automatedChecksPassed'],'Evidence is not passing'
assert build['approvedSpecificationSHA256']==hashlib.sha256((root/'docs/reference/approved-product-specification-v1.md').read_bytes()).hexdigest(),'Approved specification changed'
kit=root/'outputs/Sterling-S0-preview-kit.zip'
paths=[root/'README.md',root/'Package.swift',root/'Makefile',root/'AGENTS.md',root/'SECURITY.md',root/'.gitignore',root/'.github/CODEOWNERS']
for folder in ['Sources','Tests','Scripts','docs','.planning']:
    paths+=sorted(p for p in (root/folder).rglob('*') if p.is_file())
paths+=sorted(p for p in (root/'outputs/Sterling Feasibility.app').rglob('*') if p.is_file())
for name in ['build-receipt.json','native-probe.json','test-receipt.json','test-results.txt','shape-study.png','care-window.png']:
    paths.append(root/'outputs'/name)
with zipfile.ZipFile(kit,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for p in paths:
        z.write(p,Path('Sterling S0 Preview')/p.relative_to(root))
with zipfile.ZipFile(kit) as z:
    assert z.testzip() is None
    assert len(z.namelist())==len(set(z.namelist()))
sha=hashlib.sha256(kit.read_bytes()).hexdigest()
(root/'outputs/Sterling-S0-preview-kit.sha256').write_text(sha+'  '+kit.name+'\n')
print(f'Packaged {len(paths)} files, {kit.stat().st_size:,} bytes. Evidence matches current source and executable.')
print(sha)
PY
