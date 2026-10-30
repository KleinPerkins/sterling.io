#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p work outputs
Scripts/swift.sh test > work/test.log 2>&1 || { tail -n 80 work/test.log; exit 1; }
cp work/test.log outputs/test-results.txt
python3 - <<'PY'
from pathlib import Path
import hashlib,json,re,datetime
root=Path.cwd()
log=(root/'outputs/test-results.txt').read_text()
match=re.search(r'Test run with (\d+) tests in (\d+) suites passed',log)
if not match: raise SystemExit('No passing Swift Testing summary found.')
def digest(paths):
    h=hashlib.sha256()
    for p in sorted(paths): h.update(str(p.relative_to(root)).encode()+b'\0'+p.read_bytes())
    return h.hexdigest()
receipt={'kind':'sterling-tests/v1','checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
  'testCount':int(match[1]),'suiteCount':int(match[2]),'passed':True,
  'domainSHA256':digest((root/'Sources/SterlingCore').glob('*.swift')),
  'testsSHA256':digest((root/'Tests').rglob('*.swift')),
  'resultLogSHA256':hashlib.sha256(log.encode()).hexdigest()}
(root/'outputs/test-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(f'Passed {match[1]} tests in {match[2]} suites; evidence saved in outputs/.')
PY
