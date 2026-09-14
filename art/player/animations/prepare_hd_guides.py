"""Layout references from existing poses, never final sprite art."""
from pathlib import Path
from PIL import Image
from hd_anchors import left_foot

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'hd_source'
for action in ('attack', 'hurt'):
    for batch in range(15):
        sheet = Image.new('RGBA', (768, 1536), '#ff00ff')
        for slot in range(2):
            frame = Image.open(ROOT/action/f'{action}-{batch*2+slot+1}.png').convert('RGBA')
            bbox = frame.getbbox()
            foot = left_foot(frame)
            scale = 522 / 150
            subject = frame.crop(bbox)
            subject = subject.resize((round(subject.width*scale), round(subject.height*scale)), Image.Resampling.LANCZOS)
            x = round(450+(bbox[0]-foot[0])*scale)
            y = round(650+(bbox[1]-foot[1])*scale)+slot*768
            sheet.alpha_composite(subject, (x, y))
        directory = OUT/action/f'{batch+1:02d}'
        directory.mkdir(parents=True, exist_ok=True)
        sheet.convert('RGB').save(directory/'pose-guide.png')
