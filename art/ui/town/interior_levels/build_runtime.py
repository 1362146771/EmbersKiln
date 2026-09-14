from pathlib import Path
from PIL import Image
import json

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
        image.resize(size, Image.Resampling.LANCZOS).save(target, optimize=True)
    before += source.stat().st_size
    after += target.stat().st_size
print(f'{len(files)} images: {before / 1048576:.2f} MiB -> {after / 1048576:.2f} MiB; 1024x683')
