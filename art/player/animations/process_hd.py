"""Deterministic splitting, keying and left-foot registration of generated art."""
from pathlib import Path
import json
import sys
import subprocess
import numpy as np
from PIL import Image
from hd_anchors import left_foot

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT/'hd_source'
SKILL = Path('C:/Users/Administrator/.codex/skills/generate2dsprite/scripts')
sys.path.insert(0, str(SKILL))
from generate2dsprite import remove_bg_magenta

for record in sorted(SOURCE.glob('*/*/generation.json')):
    directory = record.parent
    if (directory/'registered.png').exists() and '--force' not in sys.argv:
        continue
    meta = json.loads(record.read_text(encoding='utf-8'))
    original = Image.open(meta['path']).convert('RGBA')
    original.save(directory/'raw-generated.png')
    cleaned = remove_bg_magenta(original)
    alpha = np.asarray(cleaned.getchannel('A'))
    row_count = (alpha > 64).sum(axis=1)
    mid = original.height//2
    empty = np.flatnonzero(row_count == 0)
    candidates = empty[(empty > mid-original.height//8) & (empty < mid+original.height//8)]
    assert len(candidates), f'No clear separator in {record}'
    cut = int(candidates[np.argmin(abs(candidates-mid))])
    sheet = Image.new('RGBA', (1000,2000), '#ff00ff')
    measurements = []
    for slot, (top,bottom) in enumerate(((0,cut),(cut,original.height))):
        frame = cleaned.crop((0,top,original.width,bottom))
        box = frame.getbbox()
        assert box, record
        anchor = left_foot(frame)
        x = round(570-anchor[0]+box[0])
        y = round(890-anchor[1]+box[1])
        subject = frame.crop(box)
        assert x >= 0 and y >= 0 and x+subject.width < 1000 and y+subject.height < 1000, (record,slot,box,x,y)
        sheet.alpha_composite(subject, (x,y+slot*1000))
        measurements.append({'source_bbox':box,'left_foot':anchor,'translation':[x-box[0],y-box[1]],'native_subject_height':subject.height})
    sheet.convert('RGB').save(directory/'registered.png')
    (directory/'registration.json').write_text(json.dumps({'source_size':original.size,'source_cut':cut,'frames':measurements,'scale_applied':1.0},indent=2))
    print(meta['action'],meta['batch'],'native heights',[v['native_subject_height'] for v in measurements],flush=True)

if '--process' in sys.argv:
    for record in sorted(SOURCE.glob('*/*/generation.json')):
        directory=record.parent
        previous = directory/'processed-hd/pipeline-meta.json'
        if previous.exists() and '--force' not in sys.argv:
            qc = json.loads(previous.read_text())
            if not qc.get('paste_clamped_frames') and not qc.get('edge_touch_frames'):
                continue
        command=[sys.executable,str(SKILL/'generate2dsprite.py'),'process','--input',str(directory/'registered.png'),'--target','player','--mode',directory.parent.name,'--output-dir',str(directory/'processed-hd'),'--rows','2','--cols','1','--cell-size','768','--trim-border','0','--fit-scale','1','--align','center','--scale-strategy','preserve','--component-mode','largest','--shared-scale','--duration','33','--strict-qc','--max-body-scale-cv','0.08','--max-anchor-y-std','0.05']
        # Shared pixel scale is 768/1000 for every action/batch, with no bbox fitting.
        result=subprocess.run(command,capture_output=True,text=True,errors='replace')
        print(directory.parent.name,directory.name,'QC',result.returncode, result.stderr[-600:],flush=True)
