"""Approved local cutout of Sagger Matron; never redraw or overwrite the source.

Run from the project root with Pillow and NumPy installed. Thresholds are specific
to this approved gray-background image, not a general monster batch processor.
"""
from collections import deque
from hashlib import sha256
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/enemies/review_20260828_sagger/21_SaggerMatron_candidate.png"
OUTPUT = SOURCE.with_name("21_SaggerMatron_alpha.png")
QA = ROOT / "Temp/sagger-verify"
EXPECTED_SOURCE = "bbfefa0e6f13bd9bcd4dc92f00251b3054fb4d840c2754d137324db0eda3138a"


def expand(mask, radius=1):
    return np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).filter(
        ImageFilter.MaxFilter(radius * 2 + 1))) > 0


def main():
    assert sha256(SOURCE.read_bytes()).hexdigest() == EXPECTED_SOURCE, "Source changed; review required"
    rgb = np.array(Image.open(SOURCE).convert("RGB"))
    height, width = rgb.shape[:2]
    # Only exterior-connected light neutral pixels: pale pottery stays enclosed.
    possible = (rgb.min(2) >= 165) & (np.ptp(rgb, axis=2) <= 22)
    hole = rgb[211:230, 811:847]
    possible[211:230, 811:847] |= (hole.min(2) >= 100) & (np.ptp(hole, axis=2) <= 22)
    outside = np.zeros((height, width), dtype=bool)
    queue = deque()
    # The one enclosed see-through hole in the upper-right handle was visually
    # checked against the source. Chest/vent interiors are not background seeds.
    for y, x in [(y, x) for y in range(height) for x in (0, width - 1)] + [
            (y, x) for x in range(width) for y in (0, height - 1)] + [(214, 823)]:
        if possible[y, x] and not outside[y, x]:
            outside[y, x] = True
            queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < height and 0 <= nx < width and possible[ny, nx] and not outside[ny, nx]:
                outside[ny, nx] = True
                queue.append((ny, nx))

    alpha = np.where(outside, 0, 255).astype(np.uint8)
    result_rgb = rgb.copy()
    # Unmix the gray matte only in a narrow silhouette band. Local dark outline
    # and clean background samples reconstruct antialias coverage, not detail.
    band = expand(outside, 2) & expand(~outside, 1)
    clean_bg = outside & ~expand(~outside, 2)
    dark_outline = (~expand(outside, 1)) & (rgb.max(2) < 85)
    for y, x in np.argwhere(band):
        pixel = rgb[y, x].astype(float)
        if pixel.max() < 40 or np.ptp(pixel) > 30:
            continue
        y0, y1 = max(0, y - 6), min(height, y + 7)
        x0, x1 = max(0, x - 6), min(width, x + 7)
        bg_positions = np.argwhere(clean_bg[y0:y1, x0:x1])
        fg_positions = np.argwhere(dark_outline[y0:y1, x0:x1])
        if not len(fg_positions):
            continue
        center = np.array([y - y0, x - x0])
        bf = []
        for positions in (bg_positions, fg_positions):
            if not len(positions):
                # Narrow handle hole has no deep interior background sample.
                bf.append(np.median(rgb[0], axis=0))
                continue
            distances = ((positions - center) ** 2).sum(1)
            nearest = positions[np.argsort(distances)[:3]]
            bf.append(np.median(rgb[y0 + nearest[:, 0], x0 + nearest[:, 1]], axis=0))
        background, foreground = bf
        direction = foreground - background
        coverage = float(np.clip(np.dot(pixel - background, direction) / np.dot(direction, direction), 0, 1))
        if coverage < 0.025:
            alpha[y, x] = 0
        elif coverage < 0.98:
            alpha[y, x] = round(coverage * 255)
            unmatted = (pixel - (1 - coverage) * background) / coverage
            # Near-zero alpha amplifies background noise; constrain it to the
            # adjacent existing outline, never introduce a blue/gray fringe.
            result_rgb[y, x] = np.clip(np.rint(np.clip(unmatted, foreground - 5, foreground + 5)), 0, 255)

    result_rgb[alpha == 0] = 0
    output = Image.fromarray(np.dstack((result_rgb, alpha)))
    output.save(OUTPUT)
    QA.mkdir(parents=True, exist_ok=True)
    for name, color in (("dark", (27, 22, 28, 255)), ("white", (255, 255, 255, 255))):
        preview = Image.new("RGBA", output.size, color)
        preview.alpha_composite(output)
        preview.convert("RGB").save(QA / f"alpha_{name}.png")
        for tag, box in (("rim", (630, 135, 900, 280)), ("feet", (570, 1010, 885, 1140))):
            crop = preview.crop(box)
            crop.resize((crop.width * 3, crop.height * 3), Image.Resampling.NEAREST).save(
                QA / f"alpha_{name}_{tag}.png")
    # Do not change framing or resample the approved drawing.
    assert output.size == (1254, 1254)
    assert np.all(alpha[0] == 0) and np.all(alpha[-1] == 0)
    assert np.all(alpha[:, 0] == 0) and np.all(alpha[:, -1] == 0)
    assert np.array_equal(result_rgb[alpha == 255], rgb[alpha == 255])
    # Key approved subject details must remain opaque, while leg gaps disappear.
    for x, y in ((329, 633), (283, 947), (532, 203), (814, 215), (745, 1090), (1175, 799)):
        assert alpha[y, x] == 255, ("Lost subject", x, y)
    for x, y in ((946, 1019), (510, 1130), (10, 800), (600, 50), (823, 214)):
        assert alpha[y, x] == 0, ("Background retained", x, y)
    print("OUTPUT", OUTPUT)
    print("MODE", Image.open(OUTPUT).mode, "SIZE", output.size, "BBOX", output.getbbox())
    print("ALPHA transparent / partial / opaque", *(int(np.count_nonzero(test)) for test in (
        alpha == 0, (alpha > 0) & (alpha < 255), alpha == 255)))
    print("OPAQUE_RGB_UNCHANGED", True)
    print("SOURCE_SHA256", sha256(SOURCE.read_bytes()).hexdigest())
    print("OUTPUT_SHA256", sha256(OUTPUT.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
