"""Assemble native HD redraws with a fixed anatomical right-foot contact point."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image, ImageDraw
from hd_anchors import right_foot
from hd_calibration import mask_length

ROOT = Path(__file__).resolve().parent
if '--install' in sys.argv and (ROOT/'attack5_source/body-raw.png').exists():
    from build_attack5 import build
    build()
    sys.exit(0)
ANCHOR = (240, 700)
CELL = 768
REFERENCE_MASK_LENGTH = mask_length(Image.open(ROOT/'hd_source/attack/01/processed-hd/attack-1.png'))
actions = ('attack', 'hurt')
destination = ROOT if '--install' in sys.argv else ROOT/'hd_preview'
destination.mkdir(exist_ok=True)
manifest = {'fps':30,'duration_seconds':1,'frames_per_action':30,'cell_size':[CELL,CELL],
    'grid':[6,5], 'origin':ANCHOR,'anchor':'anatomical_right_boot_sole',
    'native_pixel_scale':0.768,'loop':False,'actions':{}}
resource = ['[gd_resource type="SpriteFrames" load_steps=65 format=3]', '']
for a, action in enumerate(actions):
    for page in range(2):
        resource.append(f'[ext_resource type="Texture2D" path="res://art/player/animations/{action}/atlas-hd-{page+1}.png" id="{a*2+page+1}"]')
for a, action in enumerate(actions):
    records = sorted((ROOT/'hd_source'/action).glob('*/generation.json'))
    if len(records) != 15:
        if '--install' in sys.argv:
            raise ValueError(f'{action}: incomplete source set {len(records)}/15')
        continue
    frames, measurements = [], []
    out = destination/action
    out.mkdir(exist_ok=True)
    for record in records:
        directory = record.parent/'processed-hd'
        meta = json.loads((directory/'pipeline-meta.json').read_text())
        assert not any(meta[k] for k in ('empty_frames','edge_touch_frames','paste_clamped_frames')), record
        for slot in range(1,3):
            source = Image.open(directory/f'{action}-{slot}.png').convert('RGBA')
            # The mask is rigid; body/weapon bounding boxes change with the pose.
            original_mask_length = mask_length(source)
            source_index = (int(record.parent.name)-1)*2+slot
            # Mask perspective must not shrink a crouch's entire skeleton.
            drawing_scale = float(np.clip(REFERENCE_MASK_LENGTH / original_mask_length, 0.95, 1.05))
            neutral = (action == 'attack' and (source_index <= 2 or source_index >= 22)) or (action == 'hurt' and source_index in (1,2,3,5))
            if neutral:
                bounds = source.getbbox()
                drawing_scale = 545.0 / (bounds[3]-bounds[1])
            assert 0.7 < drawing_scale < 1.3, (record,slot,drawing_scale)
            source = source.resize(tuple(round(v*drawing_scale) for v in source.size),Image.Resampling.LANCZOS)
            anchor = right_foot(source)
            dx,dy = round(ANCHOR[0]-anchor[0]), round(ANCHOR[1]-anchor[1])
            box = source.getbbox()
            assert box[0]+dx>0 and box[1]+dy>0 and box[2]+dx<CELL and box[3]+dy<CELL, (record,slot,box,dx,dy)
            frame = Image.new('RGBA',(CELL,CELL))
            frame.alpha_composite(source,(dx,dy))
            # Chroma spill is confined to semitransparent antialiased edges.
            pixels = np.array(frame)
            r,g,b,alpha = (pixels[:,:,c].astype(int) for c in range(4))
            spill = (alpha>0)&(alpha<255)&(r>g+20)&(b>g+20)
            pixels[:,:,0][spill] = np.minimum(r,g+10)[spill]
            pixels[:,:,2][spill] = np.minimum(b,g+10)[spill]
            frame = Image.fromarray(pixels)
            measured = right_foot(frame)
            error = max(abs(measured[j]-ANCHOR[j]) for j in range(2))
            assert error <= 1, (record,slot,measured)
            frames.append(frame)
            measurements.append({'frame':len(frames),'source':str(record.relative_to(ROOT)),
                'drawing_scale_correction':drawing_scale,'source_mask_length':original_mask_length,
                'output_mask_length':mask_length(frame),
                'right_foot':measured,'anchor_error_px':error,'bbox':frame.getbbox()})
    assert len(frames)==30 and len({f.tobytes() for f in frames})==30
    # One small recoil and recovery, with held drawings on a 30 fps timeline.
    order = list(range(1,31)) if action == 'attack' else [1]*2 + [2]*2 + [3]*3 + [5]*4 + [3]*5 + [2]*5 + [1]*9
    assert len(order) == 30 and all(1 <= i <= 30 for i in order)
    frames = [frames[i-1] for i in order]
    measurements = [dict(measurements[i-1], source_frame=i, frame=j+1) for j,i in enumerate(order)]
    atlases = [Image.new('RGBA',(CELL*3,CELL*5)) for _ in range(2)]
    sheet = Image.new('RGBA',(CELL*6,CELL*5))
    contact = Image.new('RGB',(192*6,192*5),'#272831')
    for i, frame in enumerate(frames):
        frame.save(out/f'{action}-{i+1}.png')
        atlases[i//15].paste(frame,((i%15%3)*CELL,(i%15//3)*CELL))
        sheet.paste(frame,((i%6)*CELL,(i//6)*CELL))
        thumb=frame.resize((192,192),Image.Resampling.LANCZOS)
        contact.paste(thumb,((i%6)*192,(i//6)*192),thumb)
        ImageDraw.Draw(contact).text(((i%6)*192+5,(i//6)*192+5),str(i+1),fill='white')
        resource.extend(['',f'[sub_resource type="AtlasTexture" id="{action}_{i+1}"]',
            f'atlas = ExtResource("{a*2+i//15+1}")',
            f'region = Rect2({(i%15%3)*CELL}, {(i%15//3)*CELL}, {CELL}, {CELL})', 'filter_clip = true'])
    for page, atlas in enumerate(atlases):
        atlas.save(out/f'atlas-hd-{page+1}.png')
    sheet.save(out/'sheet-transparent.png')
    contact.save(out/'contact.png')
    frames[0].save(out/'animation.png',save_all=True,append_images=frames[1:],duration=1000/30,loop=0,disposal=0,blend=0)
    frames[0].save(out/'animation.gif',save_all=True,append_images=frames[1:],duration=[30,30,40]*10,loop=0,disposal=2,optimize=False)
    qc={'frames':measurements,'max_right_foot_error_px':max(m['anchor_error_px'] for m in measurements),
        'reference_mask_length':REFERENCE_MASK_LENGTH,
        'mask_length_cv':float(np.std([m['output_mask_length'] for m in measurements])/np.mean([m['output_mask_length'] for m in measurements])),
        'empty_frames':[], 'edge_touch_frames':[], 'paste_clamped_frames':[],
        'scale_strategy':'preserve','native_pixel_scale':0.768}
    (out/'pipeline-meta.json').write_text(json.dumps(qc,indent=2))
    manifest['actions'][action]={'sheet':f'{action}/sheet-transparent.png','atlases':[f'{action}/atlas-hd-{i}.png' for i in (1,2)],
        'frames':[f'{action}/{action}-{i}.png' for i in range(1,31)], 'qc':qc}
    print(action,'30 HD frames, right foot drift <=',qc['max_right_foot_error_px'],flush=True)
resource.extend(['','[resource]','animations = ['])
for a,action in enumerate(actions):
    entries=',\n'.join('{"duration": 1.0, "texture": SubResource("'+action+'_'+str(i)+'")}' for i in range(1,31))
    resource.append('{"frames": [\n'+entries+'\n], "loop": false, "name": &"'+action+'", "speed": 30.0}'+(',' if a==0 else ''))
resource.append(']')
if len(manifest['actions'])==2:
    (destination/'PlayerCombatFrames.tres').write_text('\n'.join(resource)+'\n',encoding='utf-8')
(destination/'manifest.json').write_text(json.dumps(manifest,indent=2))
