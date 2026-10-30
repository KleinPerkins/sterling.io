#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p work outputs
Scripts/swift.sh test > work/test.log 2>&1 || { tail -n 80 work/test.log; exit 1; }
cp work/test.log outputs/test-results.txt
python3 - <<'PY'
from pathlib import Path
import hashlib,json,datetime
from Scripts.test_reporting import parse_summary
root=Path.cwd()
log=(root/'outputs/test-results.txt').read_text()
test_count,suite_count=parse_summary(log)
def digest(paths):
    h=hashlib.sha256()
    for p in sorted(paths): h.update(str(p.relative_to(root)).encode()+b'\0'+p.read_bytes())
    return h.hexdigest()
receipt={'kind':'sterling-tests/v1','checkedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
  'testCount':test_count,'suiteCount':suite_count,'passed':True,
  'domainSHA256':digest((root/'Sources/SterlingCore').glob('*.swift')),
  'testsSHA256':digest((root/'Tests').rglob('*.swift')),
  'updateSupportSHA256':digest((root/'Sources/SterlingUpdateSupport').glob('*.swift')),
  'resultLogSHA256':hashlib.sha256(log.encode()).hexdigest()}
(root/'outputs/test-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(f'Passed {test_count} tests in {suite_count} suites; evidence saved in outputs/.')
PY
