#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p work outputs
python3 - <<'PY'
from pathlib import Path
import subprocess, json, sys, hashlib, datetime
root=Path.cwd()
app=root/'outputs/Sterling Feasibility.app/Contents/MacOS/SterlingPrototype'
if not app.exists(): sys.exit('Run Scripts/build-app.sh first.')
receipt=root/'outputs/native-probe.json'
# A failed run must not accidentally reuse an old passing receipt.
if receipt.exists(): receipt.unlink()
with (root/'work/native-probe.log').open('w') as log:
    try:
        result=subprocess.run([str(app),'--probe','--output',str(receipt),
            '--preview',str(root/'outputs/shape-study.png'),
            '--care-preview',str(root/'outputs/care-window.png')],
            stdout=log,stderr=subprocess.STDOUT,timeout=30)
    except subprocess.TimeoutExpired:
        sys.exit('Probe timed out; its process was terminated. See work/native-probe.log.')
if result.returncode != 0 or not receipt.exists(): sys.exit('Probe failed. See work/native-probe.log.')
r=json.loads(receipt.read_text())
checks=['appWasInactiveWhileRendering','foregroundUnchanged','overlayIgnoresMouseEvents',
'overlayCannotBecomeKey','previewWritten','hiddenFramesStopped','hiddenTimerStopped',
'resumeRenders','pausedFramesStopped','careControlsFit','careOpaqueWindow','oneVisibleCat',
'carePreviewWritten','keyboardPetting','keyboardStopsContact','keyboardPlay','keyboardStopsPlay','escapeClosesCare',
'wakePreservesManualPause','suspensionStopsTimer','wakeResumesAvailableSession']
failed=[k for k in checks if r.get(k) is not True]
if r.get('inactiveRenderingFrames',0)<=0: failed.append('inactiveRenderingFrames')
for i,d in enumerate(r.get('displayPlacementChecks',[])):
    if d['expectedScale']!=d['actualScale'] or not d['withinVisibleBounds']: failed.append(f'display {i}')
if not r.get('displayPlacementChecks'): failed.append('displayPlacementChecks')
r['binarySHA256']=hashlib.sha256(app.read_bytes()).hexdigest()
r['checkedAt']=datetime.datetime.now(datetime.timezone.utc).isoformat()
r['automatedChecksPassed']=not failed
r['booleanCheckCount']=len(checks)
r['carePreviewMethod']='Own AppKit view hierarchy with own Metal scene bitmap; not a desktop screenshot'
receipt.write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r,indent=2))
if failed: sys.exit('Failed checks: '+', '.join(failed))
print(f'Passed {len(checks)} Boolean checks, nonzero inactive rendering, and {len(r["displayPlacementChecks"])} connected-display placements.')
PY
