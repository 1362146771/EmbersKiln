"""Copy image_gen art unchanged; verify files and compose review thumbnails."""
from pathlib import Path
import json, shutil, hashlib
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
        source_path = Path(a['path'])
        if not source_path.is_absolute():
            source_path = ROOT.parents[3] / source_path
        # The editor may have the already-current texture mapped for import.
        if not target.exists() or hashlib.sha256(source_path.read_bytes()).digest() != hashlib.sha256(target.read_bytes()).digest():
            shutil.copy2(source_path, target)
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
    manifest = {'status':'runtime_integrated','generator':'built-in image_gen',
                'scene':'courtyard_with_player_and_workers','source_manifest':'source_manifest.json',
                'assets':records,'runtime_verification':'NOT VERIFIED'}
    (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Verified 20 original 1536x1024 PNGs and rebuilt 6 review previews.')

if __name__ == '__main__':
    main()
