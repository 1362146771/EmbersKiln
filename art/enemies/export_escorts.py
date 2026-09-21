"""Export approved imagegen portraits: matte cleanup and 3:2 visible bounds.

No repainting. Uniform scaling/padding is baked into equal-sized PNG canvases,
so the existing combat TextureRects preserve the ratio, including recruits.
"""
import hashlib
import importlib.util
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/enemies'
CONFIG = json.loads((ART / 'escort-export.json').read_text(encoding='utf-8'))
SOURCE = ROOT / CONFIG['source_directory']
PROCESSOR = Path.home() / '.codex/skills/generate2dsprite/scripts/generate2dsprite.py'
spec = importlib.util.spec_from_file_location('sprite_processor', PROCESSOR)
processor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(processor)


def cutout(image):
    image = image.convert('RGBA')
    if image.getchannel('A').getextrema()[0] < 255:
        return image  # Preserve native alpha.
    original = np.array(image)
    image = processor.remove_bg_magenta(image, CONFIG['key_threshold'], CONFIG['edge_threshold'])
    pixels = np.array(image)
    radius = CONFIG['fringe_radius']
    alpha = image.getchannel('A')
    interior = np.array(alpha.filter(ImageFilter.MinFilter(radius * 2 + 1))) == 255
    rgb = original[:, :, :3].astype(float)
    matte = np.array(CONFIG['matte_rgb'], dtype=float)
    # Only edge pixels contaminated by the key color; never recolor interior.
    excess = np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1]
    ys, xs = np.where((pixels[:, :, 3] > 0) & ~interior & (excess > 25))
    for y, x in zip(ys, xs):
        y0, y1 = max(0, y-radius*2), min(image.height, y+radius*2+1)
        x0, x1 = max(0, x-radius*2), min(image.width, x+radius*2+1)
        ny, nx = np.where(interior[y0:y1, x0:x1])
        if not len(nx):
            continue
        nearest = np.argmin((ny+y0-y)**2 + (nx+x0-x)**2)
        foreground = rgb[ny[nearest]+y0, nx[nearest]+x0]
        direction = foreground - matte
        opacity = np.clip(np.dot(rgb[y, x]-matte, direction) / max(1, np.dot(direction, direction)), 0, 1)
        pixels[y, x, :3] = foreground
        pixels[y, x, 3] = round(255 * opacity)
    pixels[pixels[:, :, 3] == 0, :3] = 0
    return Image.fromarray(pixels)


def main():
    candidate = json.loads((SOURCE / 'candidates.json').read_text(encoding='utf-8'))
    manifest = json.loads((ART / 'manifest.json').read_text(encoding='utf-8'))
    data_path = ROOT / 'data/enemies.json'
    enemy_data = json.loads(data_path.read_text(encoding='utf-8'))
    enemies = {e['id']: e for e in enemy_data['enemies']}
    images = {r['id']: cutout(Image.open(SOURCE / r['file'])) for r in candidate['images']}
    crops = {key: image.crop(image.getbbox()) for key, image in images.items()}
    width, height = CONFIG['canvas_size']
    margin = CONFIG['safe_margin']
    weights = CONFIG['area_weights']
    # Largest shared bounding area that fits every role at its approved weight.
    limits = []
    for key, crop in crops.items():
        weight = weights['leader' if key in CONFIG['groups'] else 'escort']
        fit = min((width-margin*2)/crop.width, (height-margin*2)/crop.height)
        limits.append(crop.width * crop.height * fit**2 / weight)
    area_unit = min(limits)
    records = []
    output_images = {}
    for record in candidate['images']:
        key = record['id']
        crop = crops[key]
        role = 'leader' if key in CONFIG['groups'] else 'escort'
        scale = math.sqrt(area_unit * weights[role] / (crop.width * crop.height))
        resized = crop.resize((round(crop.width*scale), round(crop.height*scale)), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (width, height))
        canvas.paste(resized, ((width-resized.width)//2, height-margin-resized.height))
        name = 'Escort' + ''.join(word.title() for word in key.removeprefix('escort_').split('_'))
        filename = f'SPR_Enemy_{name}.png'
        target = ART / filename
        canvas.save(target)
        enemies[key]['sprite'] = target.stem
        output_images[key] = canvas
        bounds = canvas.getbbox()
        records.append({
            'key': name, 'name': record['name'], 'enemy_id': key,
            'production': f'art/enemies/{filename}',
            'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
            'size': [width, height], 'gap_seeds': [],
            'source': f"{CONFIG['source_directory']}/{record['file']}",
            'visible_bounds': list(bounds), 'area_weight': weights[role],
        })
    replaced = {r['key'] for r in records}
    manifest['images'] = [r for r in manifest['images'] if r['key'] not in replaced] + records
    manifest['count'] = len(manifest['images'])
    (ART / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    # Keep the existing JSON formatting; only replace the relevant sprite fields.
    previous = data_path.read_text(encoding='utf-8')
    import re
    for record in records:
        pattern = r'("id": "' + record['enemy_id'] + r'"[\s\S]*?"sprite": ")[^"]+(")'
        previous, count = re.subn(pattern, lambda m: m[1]+enemies[record['enemy_id']]['sprite']+m[2], previous, count=1)
        assert count == 1, record['enemy_id']
    data_path.write_text(previous, encoding='utf-8')
    candidate['status'] = 'approved_and_installed'
    candidate['runtime_installed'] = True
    (SOURCE / 'candidates.json').write_text(json.dumps(candidate, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    preview = Image.new('RGB', (1600, 1250), '#d3c7ae')
    draw = ImageDraw.Draw(preview)
    font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 23)
    for group, (leader, escorts) in enumerate(CONFIG['groups'].items()):
        for slot, key in enumerate([leader]+escorts):
            thumb = output_images[key].resize((285, 285), Image.Resampling.LANCZOS)
            x, y = slot*510+110, group*310
            preview.paste(thumb, (x, y), thumb)
            draw.text((x, y+282), enemies[key]['name'], font=font, fill='#20252b')
    preview.save(SOURCE / 'production-preview.png')
    for record in records:
        print(record['enemy_id'], record['visible_bounds'], record['area_weight'])


if __name__ == '__main__':
    main()
