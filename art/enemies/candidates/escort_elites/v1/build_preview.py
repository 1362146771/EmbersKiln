"""Arrange generated portraits for art review; never redraw or alter source pixels."""
import json
import importlib.util
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FONT = 'C:/Windows/Fonts/msyh.ttc'
PROCESSOR = Path('C:/Users/Administrator/.codex/skills/generate2dsprite/scripts/generate2dsprite.py')
spec = importlib.util.spec_from_file_location('sprite_preview_processor', PROCESSOR)
processor = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = processor
spec.loader.exec_module(processor)
def font(size): return ImageFont.truetype(FONT, size)

GROUPS = [
    ('act2_command', '第二幕 · 指挥编队', ['escort_commander', 'escort_assault', 'escort_assault']),
    ('act2_guard', '第二幕 · 护卫干扰编队', ['escort_vanguard', 'escort_guard', 'escort_disruptor']),
    ('act3_bombs', '第三幕 · 倒计时编队', ['escort_deployer', 'escort_bomb', 'escort_bomb']),
    ('act3_observers', '第三幕 · 监视编队', ['escort_overseer', 'escort_skill_observer', 'escort_power_observer']),
]

def main():
    manifest = json.loads((ROOT / 'candidates.json').read_text(encoding='utf-8'))
    records = {item['id']: item for item in manifest['images']}
    summaries = []
    for slug, title, ids in GROUPS:
        canvas = Image.new('RGB', (1260, 710), '#232a32')
        draw = ImageDraw.Draw(canvas)
        draw.text((30, 19), title, font=font(32), fill='#eee6d4')
        draw.line((30, 70, 1230, 70), fill='#59616a', width=2)
        for slot, eid in enumerate(ids):
            item = records[eid]
            image = Image.open(ROOT / item['file']).convert('RGBA')
            # Temporary flat-key preview only. Raw candidate and its original alpha remain untouched.
            # Production edge cleanup/import/QA follows art approval.
            if image.getchannel('A').getextrema() == (255, 255):
                image = processor.remove_bg_magenta(image.copy())
            bbox = image.getchannel('A').getbbox()
            crop = image.crop(bbox)
            crop.thumbnail((378, 505), Image.Resampling.LANCZOS)
            x = slot * 420 + (420 - crop.width) // 2
            canvas.paste(crop, (x, 596 - crop.height), crop)
            draw.text((slot*420 + 210, 612), f"{item['number']:02d}  {item['name']}", anchor='mt', font=font(27), fill='#f1e8d5')
            draw.text((slot*420 + 210, 655), item['role'], anchor='mt', font=font(20), fill='#a8b8c9')
        canvas.save(ROOT / f'{slug}.png')
        summaries.append(canvas)
    overview = Image.new('RGB', (1800, 1100), '#171c23')
    draw = ImageDraw.Draw(overview)
    draw.text((30, 15), '精英与随从 · 10种独立立绘候选', font=font(34), fill='#eee6d4')
    for i, image in enumerate(summaries):
        image = image.resize((882, 497), Image.Resampling.LANCZOS)
        overview.paste(image, (12 + (i % 2)*894, 74 + (i // 2)*509))
    overview.save(ROOT / 'overview.png')

if __name__ == '__main__': main()
