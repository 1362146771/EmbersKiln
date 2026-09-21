"""Extract generated poses and composite one rigid generated axe, without pose warping."""
from pathlib import Path
import json
import math
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageChops
from hd_anchors import right_foot
from brightness_match import match_brightness

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'attack5_source'
sys.path.insert(0, str(Path.home()/'.codex/skills/generate2dsprite/scripts'))
from generate2dsprite import remove_bg_magenta

TIMING = json.loads((ROOT.parents[2]/'data/vfx.json').read_text(encoding='utf-8'))['attack']['frame_duration_ticks']
GIF_TIMING = [100,270,70,160,200,200,200,200]
CELL, ANCHOR, SCALE = 768, (240, 700), 545/478
BOXES = [(3,3,510,507),(514,3,1021,507),(3,515,510,990),
         (514,515,1021,990),(3,1000,510,1533)]
GRIPS = [(167,306),(624,97),(420,735),(898,765),(162,1295)]
ANGLES = [-166,-48,-65,-75,-167]
# Only hand occlusion masks; all visible artwork comes from generated source pixels.
HANDS = [[(150,283),(175,281),(181,299),(182,314),(174,325),(157,324),(147,310)],
         [(606,84),(617,75),(632,77),(645,88),(642,103),(630,116),(610,115),(603,102)],
         [(352,769),(368,761),(380,772),(392,794),(385,805),(365,807),(352,799)],
         [(849,797),(864,789),(878,799),(893,821),(888,834),(872,840),(853,829)],
         [(146,1275),(165,1271),(176,1282),(181,1301),(174,1314),(157,1317),(142,1303)]]
HANDS[2] = [(405,716),(424,716),(438,725),(442,740),(429,754),(413,752),(399,741)]
HANDS[3] = [(883,745),(902,745),(916,754),(921,770),(907,784),(890,783),(876,769)]

def clean(image):
    result = remove_bg_magenta(image.convert('RGBA'))
    pixels = np.array(result)
    r,g,b,a = (pixels[:,:,c].astype(int) for c in range(4))
    spill = (a>0)&(a<255)&(r>g+20)&(b>g+20)
    pixels[:,:,0][spill] = np.minimum(r,g+10)[spill]
    pixels[:,:,2][spill] = np.minimum(b,g+10)[spill]
    return Image.fromarray(pixels)

def build():
    body = clean(Image.open(SOURCE/'body-upright-raw.png'))
    corrected = clean(Image.open(SOURCE/'body-twist-raw.png'))
    neutral_reference = body.crop(BOXES[4])
    corrected = match_brightness(corrected, corrected.crop(BOXES[4]), neutral_reference)
    # Replace impact/follow-through with generated shoulder and torso rotation.
    for box in BOXES[2:4]:
        body.paste(corrected.crop(box),box[:2])
    axe = clean(Image.open(SOURCE/'axe-raw.png')).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    axe_scale = 0.166
    axe = axe.resize(tuple(round(v*axe_scale) for v in axe.size),Image.Resampling.LANCZOS)
    pivot = ((1024-610)*axe_scale,1040*axe_scale)
    master = Image.new('RGBA',(512,512))
    master.alpha_composite(axe,(round(256-pivot[0]),round(256-pivot[1])))
    master.save(SOURCE/'axe-master.png')
    frames, measurements = [], []
    out = ROOT/'attack'
    out.mkdir(exist_ok=True)
    for i,(box,grip,angle,hand) in enumerate(zip(BOXES,GRIPS,ANGLES,HANDS)):
        x0,y0,_,_ = box
        cropped = body.crop(box)
        # Weapon may extend beyond a source cell; preserve it before foot alignment.
        padding = 128
        pose = Image.new('RGBA',(cropped.width+padding*2,cropped.height))
        pose.alpha_composite(cropped,(padding,0))
        weapon = master.rotate(angle,resample=Image.Resampling.BICUBIC,center=(256,256))
        pose.alpha_composite(weapon,(grip[0]-x0-256+padding,grip[1]-y0-256))
        mask = Image.new('L',body.size)
        ImageDraw.Draw(mask).polygon(hand,fill=255)
        fingers = body.copy()
        fingers.putalpha(ImageChops.multiply(body.getchannel('A'),mask))
        pose.alpha_composite(fingers.crop(box),(padding,0))
        # One shared scale for ALL poses, never bbox-normalize individual frames.
        pose = pose.resize(tuple(round(v*SCALE) for v in pose.size),Image.Resampling.LANCZOS)
        foot = right_foot(pose)
        delta = tuple(round(ANCHOR[j]-foot[j]) for j in range(2))
        bounds = pose.getbbox()
        assert bounds and bounds[0]+delta[0]>0 and bounds[1]+delta[1]>0
        assert bounds[2]+delta[0]<CELL and bounds[3]+delta[1]<CELL
        frame = Image.new('RGBA',(CELL,CELL))
        frame.alpha_composite(pose,delta)
        measured = right_foot(frame)
        error = max(abs(measured[j]-ANCHOR[j]) for j in range(2))
        assert error <= 1, (i,measured)
        frame.save(out/f'attack-{i+1}.png')
        frames.append(frame)
        measurements.append({'frame':i+1,'right_foot':measured,'anchor_error_px':error,
            'shared_scale':SCALE,'weapon_angle_degrees':angle,'weapon_scale':axe_scale,
            'bbox':frame.getbbox()})
    from recovery_frames import build_recovery
    extra, extra_metrics = build_recovery(ROOT, clean, master, SCALE, neutral_reference)
    frames = frames[:4] + extra + frames[4:]
    measurements = measurements[:4] + extra_metrics + measurements[4:]
    from portrait_palette import attack_palette, export_hurt
    frames = attack_palette(frames)
    for i, frame in enumerate(frames):
        frame.save(out/f'attack-{i+1}.png')
        measurements[i]['frame'] = i+1
    sheet = Image.new('RGBA',(CELL*2,CELL*4))
    contact = Image.new('RGB',(320*4,384*2),'#272831')
    for i,f in enumerate(frames):
        sheet.paste(f,((i%2)*CELL,(i//2)*CELL))
        thumb=f.resize((320,320),Image.Resampling.LANCZOS)
        contact.paste(thumb,((i%4)*320,(i//4)*384+30),thumb)
        ImageDraw.Draw(contact).text(((i%4)*320+12,(i//4)*384+12),str(i+1),fill='white')
    sheet.save(out/'atlas-8.png')
    sheet.save(out/'sheet-transparent.png')
    contact.save(out/'contact-8.png')
    frames[0].save(out/'animation-8.png',save_all=True,append_images=frames[1:],duration=GIF_TIMING,loop=0,disposal=0,blend=0)
    preview=[]
    for f in frames:
        small=f.resize((384,384),Image.Resampling.LANCZOS)
        bg=Image.new('RGB',small.size,'#272831'); bg.paste(small,mask=small.getchannel('A'))
        preview.append(bg)
    preview[0].save(out/'preview-8.gif',save_all=True,append_images=preview[1:],duration=GIF_TIMING,loop=0)
    frames[0].save(out/'animation-8.gif',save_all=True,append_images=frames[1:],duration=GIF_TIMING,loop=0,disposal=2,optimize=False)
    qc={'frames':measurements,'frame_count':8,'empty_frames':[], 'edge_touch_frames':[],
        'paste_clamped_frames':[],'max_right_foot_error_px':max(m['anchor_error_px'] for m in measurements),
        'scale_strategy':'one_shared_scale','weapon_source':'attack5_source/axe-master.png'}
    (out/'pipeline-meta.json').write_text(json.dumps(qc,indent=2))
    manifest=json.loads((ROOT/'manifest.json').read_text())
    for key in ('frames_per_action','grid','native_pixel_scale'):
        manifest.pop(key,None)
    manifest['actions']['attack']={'frame_count':8,'grid':[2,4],'frame_duration_ticks':TIMING,
        'sheet':'attack/sheet-transparent.png','atlases':['attack/atlas-8.png'],
        'frames':[f'attack/attack-{i}.png' for i in range(1,9)],'qc':qc}
    manifest['duration_seconds']={'attack':sum(TIMING)/30,'hurt':1}
    manifest['actions']['hurt'].update(frame_count=30,grid=[6,5],frame_duration_ticks=1)
    (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2))
    resource=['[gd_resource type="SpriteFrames" load_steps=42 format=3]','',
        '[ext_resource type="Texture2D" path="res://art/player/animations/attack/atlas-8.png" id="1"]',
        '[ext_resource type="Texture2D" path="res://art/player/animations/hurt/atlas-hd-1.png" id="2"]',
        '[ext_resource type="Texture2D" path="res://art/player/animations/hurt/atlas-hd-2.png" id="3"]']
    for action,count in [('attack',8),('hurt',30)]:
        for i in range(count):
            cols,slot,page=(2,i,1) if action=='attack' else (3,i%15,2+i//15)
            resource.extend(['',f'[sub_resource type="AtlasTexture" id="{action}_{i+1}"]',
                f'atlas = ExtResource("{page}")',f'region = Rect2({slot%cols*CELL}, {slot//cols*CELL}, {CELL}, {CELL})','filter_clip = true'])
    resource.extend(['','[resource]','animations = ['])
    for action,count,ticks in [('attack',8,6),('hurt',30,1)]:
        entries=',\n'.join('{"duration": '+str(TIMING[i] if action=='attack' else ticks)+'.0, "texture": SubResource("'+action+'_'+str(i+1)+'")}' for i in range(count))
        resource.append('{"frames": [\n'+entries+'\n], "loop": false, "name": &"'+action+'", "speed": 30.0}'+(',' if action=='attack' else ''))
    resource.append(']')
    (ROOT/'PlayerCombatFrames.tres').write_text('\n'.join(resource)+'\n')
    export_hurt()
    print('Attack: 8 poses; shared scale',SCALE,'; fixed foot error',qc['max_right_foot_error_px'])

if __name__ == '__main__':
    build()
