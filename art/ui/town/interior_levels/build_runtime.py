from pathlib import Path
from PIL import Image
import json
import hashlib
from io import BytesIO

root = Path(__file__).resolve().parent
project = root.parents[3]
files = sorted(root.glob('*/*_interior_level_*.png'))
assert len(files) == 20, len(files)
before = after = 0
for source in files:
    target = root / 'runtime' / source.relative_to(root)
    target.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        size = (1024, round(image.height * 1024 / image.width))
        buffer = BytesIO()
        image.resize(size, Image.Resampling.LANCZOS).save(buffer, format='PNG', optimize=True)
    encoded = buffer.getvalue()
    # Avoid rewriting unchanged textures while the editor has them mapped.
    if not target.exists() or target.read_bytes() != encoded:
        temporary = target.with_suffix('.png.tmp')
        temporary.write_bytes(encoded)
        temporary.replace(target)
    before += source.stat().st_size
    after += target.stat().st_size
print(f'{len(files)} images: {before / 1048576:.2f} MiB -> {after / 1048576:.2f} MiB; 1024x683')
manifest_path = root / 'manifest.json'
if manifest_path.exists():
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    changed = False
    for asset in manifest['assets']:
        runtime = root / 'runtime' / asset['path']
        digest = hashlib.sha256(runtime.read_bytes()).hexdigest()
        changed |= asset.get('runtime_sha256') != digest
        asset.update(runtime_path='runtime/' + asset['path'],
                     runtime_size=list(Image.open(runtime).size), runtime_sha256=digest)
    if changed:
        manifest['runtime_verification'] = 'NOT VERIFIED'
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
