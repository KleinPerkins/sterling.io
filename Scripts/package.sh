#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
python3 - <<'PY'
from pathlib import Path
import hashlib,json,zipfile,tempfile,subprocess,shutil
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
assert tests['updateSupportSHA256']==digest(sorted((root/'Sources/SterlingUpdateSupport').glob('*.swift'))),'Update configuration changed since tests'
assert tests['testsSHA256']==digest(sorted((root/'Tests').rglob('*.swift'))),'Tests changed since run'
assert tests['passed'] and probe['automatedChecksPassed'],'Evidence is not passing'
assert build['approvedSpecificationSHA256']==hashlib.sha256((root/'docs/reference/approved-product-specification-v1.md').read_bytes()).hexdigest(),'Approved specification changed'
kit=root/'outputs/Sterling-S0-preview-kit.zip'
paths=[root/'README.md',root/'Package.swift',root/'Makefile',root/'AGENTS.md',root/'SECURITY.md',root/'.gitignore',root/'.github/CODEOWNERS',root/'Package.resolved',root/'VERSION',root/'release-please-config.json',root/'.release-please-manifest.json',root/'CHANGELOG.md',root/'.gitleaks.toml']
for folder in ['Sources','Tests','Scripts','docs','.planning','Configuration','ThirdPartyNotices','.github/workflows']:
    paths+=sorted(p for p in (root/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
paths+=sorted(p for p in (root/'outputs/Sterling Feasibility.app').rglob('*') if p.is_file() and '__pycache__' not in p.parts)
for name in ['build-receipt.json','native-probe.json','test-receipt.json','test-results.txt','shape-study.png','care-window.png']:
    paths.append(root/'outputs'/name)
# ditto preserves framework symlinks; zipfile.write would dereference them and
# break the embedded framework's code signature after extraction.
with tempfile.TemporaryDirectory(prefix='sterling-preview-kit-') as temporary:
    stage=Path(temporary)/'Sterling S0 Preview'
    for p in paths:
        if 'Sterling Feasibility.app' in p.parts: continue
        destination=stage/p.relative_to(root);destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(p,destination)
    app=stage/'outputs/Sterling Feasibility.app'
    subprocess.run(['ditto',str(root/'outputs/Sterling Feasibility.app'),str(app)],check=True)
    subprocess.run(['ditto','-c','-k','--sequesterRsrc','--keepParent',str(stage),str(kit)],check=True)
    unpacked=Path(temporary)/'unpacked'
    subprocess.run(['ditto','-x','-k',str(kit),str(unpacked)],check=True)
    subprocess.run(['codesign','--verify','--deep','--strict',str(unpacked/'Sterling S0 Preview/outputs/Sterling Feasibility.app')],check=True)
with zipfile.ZipFile(kit) as z:
    assert z.testzip() is None
    assert len(z.namelist())==len(set(z.namelist()))
sha=hashlib.sha256(kit.read_bytes()).hexdigest()
(root/'outputs/Sterling-S0-preview-kit.sha256').write_text(sha+'  '+kit.name+'\n')
print(f'Packaged {len(paths)} files, {kit.stat().st_size:,} bytes. Evidence matches current source and executable.')
print(sha)
PY
