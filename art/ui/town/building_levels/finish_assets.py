"""Deterministic chroma-edge cleanup, metadata and previews of generated art."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont
import numpy as np

ROOT = Path(__file__).resolve().parent
SPECS = [('hearth', '炉心'), ('card_mold_workshop', '牌模工坊'), ('relic_shelf', '遗珍架'), ('glaze_apothecary', '药釉坊'), ('bellows_station', '风箱台')]
TOWN = ROOT.parents[2] / 'backgrounds' / 'town_progression'
FONT = 'C:/Windows/Fonts/msyh.ttc'

def despill(im):
    a = np.array(im).astype(np.float32)
    r, g, b, alpha = [a[:, :, i] for i in range(4)]
    spill = (r > g + 15) & (b > g + 12) & (alpha > 0)
    good = (alpha > 128) & ~spill
    nearest = a[:, :, :3].copy()
    resolved = good.copy()
    for _ in range(12):
        for dy, dx in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
            neighbor = np.roll(resolved, (dy,dx), axis=(0,1))
            take = spill & ~resolved & neighbor
            color = np.roll(nearest, (dy,dx), axis=(0,1))
            nearest[take] = color[take]
            resolved[take] = True
        if np.all(resolved[spill]):
            break
    assert np.all(resolved[spill]), 'Unresolved chroma spill requires manual review'
    # Solve the magenta contribution against neighboring uncontaminated paint.
    fg_diff = nearest[:, :, 0] - nearest[:, :, 1]
    contamination = np.clip(((r - g) - fg_diff) / np.maximum(255 - fg_diff, 1), 0, 1)
    a[spill, :3] = nearest[spill]
    a[spill, 3] *= (1 - contamination[spill])
    a[a[:, :, 3] < 1] = 0
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)), int(spill.sum())

def main():
    preview = ROOT / 'preview'
    preview.mkdir(exist_ok=True)
    manifest = {'status': 'candidate_art_not_runtime_integrated', 'canvas': [1024, 1024],
                'generator': 'built-in image_gen', 'art_levels': [0, 1, 2, 3],
                'note': 'Visual level requests only; gameplay facility levels are unchanged.', 'assets': []}
    images, crop_boxes = {}, {}
    for slug, name in SPECS:
        boxes = []
        for level in range(4):
            processed = ROOT / 'processed' / slug / f'level_{level}'
            meta = json.loads((processed / 'pipeline-meta.json').read_text(encoding='utf-8'))
            assert not any(meta[k] for k in ['empty_frames', 'output_edge_touch_frames', 'paste_clamped_frames'])
            im, cleaned = despill(Image.open(processed / 'sheet-transparent.png').convert('RGBA'))
            final = ROOT / slug / f'{slug}_level_{level}.png'
            im.save(final)
            box = im.getbbox()
            assert box and box[0] > 0 and box[1] > 0 and box[2] < 1024 and box[3] < 1024
            assert im.getchannel('A').getextrema() == (0, 255)
            a = np.asarray(im).astype(int)
            assert not np.any((a[:,:,0]>a[:,:,1]+15)&(a[:,:,2]>a[:,:,1]+12)&(a[:,:,3]>0))
            images[slug,level] = im
            boxes.append(box)
            manifest['assets'].append({'id':slug, 'name':name, 'level':level,
                'path':final.relative_to(ROOT).as_posix(), 'size':[1024,1024], 'alpha_bbox':list(box),
                'origin':meta['output_origin'], 'edge_pixels_despilled':cleaned,
                'qc':{'transparent':True,'clipped':False,'magenta_residue':False},
                'source':f'processed/{slug}/level_{level}/raw-sheet.png',
                'prompt':f'processed/{slug}/level_{level}/prompt-used.txt'})
        crop_boxes[slug] = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
    titlefont = ImageFont.truetype(FONT, 28)
    font = ImageFont.truetype(FONT, 20)
    sheet = Image.new('RGB', (1440, 1840), '#e9dfc9')
    d = ImageDraw.Draw(sheet)
    d.text((30,18),'窑口镇 · 五设施 0–3 级透明图',font=titlefont,fill='#493323')
    for row, (slug,name) in enumerate(SPECS):
        for level in range(4):
            x,y = level*360,row*352+65
            d.rounded_rectangle((x+8,y,x+352,y+341),radius=10,fill='#f7efde')
            d.text((x+20,y+10),f'{name} · {level} 级',font=font,fill='#493323')
            im=images[slug,level].crop(crop_boxes[slug])
            im.thumbnail((320,292),Image.Resampling.LANCZOS)
            sheet.paste(im,(x+(360-im.width)//2,y+336-im.height),im)
    sheet.save(preview/'all_building_levels.jpg',quality=94)
    # Fixed geometry for all levels, solely for visual composition review.
    placements={'bellows_station':(310,505,325), 'relic_shelf':(720,470,270),
                'card_mold_workshop':(215,845,410), 'glaze_apothecary':(750,845,370), 'hearth':(470,1070,330)}
    manifest['preview_placement_reference_size']=[941,1673]
    manifest['preview_placements']={s:{'center_x':p[0],'bottom_y':p[1],'union_width':p[2], 'shared_crop':list(crop_boxes[s])} for s,p in placements.items()}
    for level in range(4):
        bg=Image.open(TOWN/f'town_level_{level}_base_preview.png').convert('RGBA')
        sx,sy=bg.width/941,bg.height/1673
        for slug in placements:
            x,y,w=placements[slug]
            im=images[slug,level].crop(crop_boxes[slug])
            width=round(w*sx)
            im=im.resize((width,round(im.height*width/im.width)),Image.Resampling.LANCZOS)
            bg.alpha_composite(im,(round(x*sx-width/2),round(y*sy-im.height)))
        bg.convert('RGB').save(preview/f'town_composite_level_{level}.jpg',quality=94)
    (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('20 RGBA PNGs verified: transparent, no output clipping, no magenta residue. 4 town composites and contact sheet written.')

if __name__ == '__main__':
    main()
