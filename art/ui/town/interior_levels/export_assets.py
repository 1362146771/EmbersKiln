"""Copy image_gen art unchanged; verify files and compose review thumbnails."""
from pathlib import Path
import json, shutil, hashlib, zipfile
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent

def main():
    source = json.loads((ROOT/'source_manifest.json').read_text(encoding='utf-8'))
    assert len(source['assets']) == 20
    preview = ROOT/'preview'
    preview.mkdir(exist_ok=True)
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 24)
    images, names, records = {}, {}, []
    for a in source['assets']:
        target = ROOT/a['id']/f"{a['id']}_interior_level_{a['level']}.png"
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(a['path'], target)
        with Image.open(target) as check:
            check.verify()
        im = Image.open(target).convert('RGB')
        assert im.size == (1536,1024), (target,im.size)
        images[a['id'],a['level']] = im
        names[a['id']] = a['name']
        records.append({'id':a['id'], 'name':a['name'], 'level':a['level'],
                        'path':target.relative_to(ROOT).as_posix(), 'size':list(im.size),
                        'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
    sheet = Image.new('RGB',(2048,1910),'#ede4d2')
    d = ImageDraw.Draw(sheet)
    for row,(slug,name) in enumerate(names.items()):
        pair = Image.new('RGB',(1536,1104),'#ede4d2')
        pd = ImageDraw.Draw(pair)
        for level in range(4):
            im = images[slug,level]
            x,y = level*512,row*382
            d.text((x+12,y+8),f'{name} · {level}级',font=font,fill='#493323')
            sheet.paste(im.resize((512,341),Image.Resampling.LANCZOS),(x,y+38))
            px,py = (level%2)*768,(level//2)*552
            pd.text((px+12,py+8),f'{name} · {level}级',font=font,fill='#493323')
            pair.paste(im.resize((768,512),Image.Resampling.LANCZOS),(px,py+40))
        pair.save(preview/f'{slug}_levels.jpg',quality=94)
    sheet.save(preview/'all_interior_levels.jpg',quality=94)
    manifest = {'status':'candidate_art_not_runtime_integrated','generator':'built-in image_gen',
                'scene':'courtyard_with_player_and_workers','source_manifest':'source_manifest.json',
                'assets':records,'runtime_verification':'NOT VERIFIED'}
    (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    with zipfile.ZipFile(ROOT/'town_interiors_levels_0-3.zip','w',zipfile.ZIP_DEFLATED) as z:
        for a in records:
            z.write(ROOT/a['path'],a['path'])
        for p in ['README.md','manifest.json','source_manifest.json']:
            z.write(ROOT/p,p)
        for p in preview.glob('*.jpg'):
            z.write(p,p.relative_to(ROOT))
    with zipfile.ZipFile(ROOT/'town_interiors_levels_0-3.zip') as z:
        assert z.testzip() is None
        assert len([p for p in z.namelist() if p.endswith('.png')]) == 20
    print('Verified 20 original 1536x1024 PNGs; 6 review previews and ZIP exported.')

if __name__ == '__main__':
    main()
