"""Check direction from rendered frames, independent of shader/path math.

Run tools/run_menu_atmosphere_verify.py --record first. Temporal demeaning
removes the fixed painting; block correlation then tracks moving smoke detail.
"""
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / 'Temp/menu_atmosphere_verify'
REGIONS = {
    'upper_right_rises': ((248, 65, 292, 125), lambda dx, dy: dy <= -2),
    'middle_front_wraps_left': ((80, 170, 150, 195), lambda dx, dy: dx <= -2 and dy <= 0),
    'lower_front_wraps_right': ((85, 500, 155, 535), lambda dx, dy: dx >= 2 and dy <= 0),
}


def main():
    for name, (box, correct_direction) in REGIONS.items():
        frames = np.array([np.array(Image.open(ROOT/f'spiral_{i:03}.png').convert('L').crop(box),
                                   dtype=np.float32) for i in range(0, 288, 4)])
        frames -= frames.mean(axis=0)
        scores = []
        # One-second progression, including the end->start seam of the loop.
        next_frames = np.roll(frames, -3, axis=0)
        a = frames[:, 8:-8, 8:-8]
        for dy in range(-7, 8):
            for dx in range(-7, 8):
                b = next_frames[:, 8+dy:frames.shape[1]-8+dy, 8+dx:frames.shape[2]-8+dx]
                score = float(np.sum(a*b)/(np.sqrt(np.sum(a*a)*np.sum(b*b))+1e-9))
                scores.append((score, dx, dy))
        score, dx, dy = max(scores)
        ok = score > .55 and correct_direction(dx, dy)
        print(f'[{"PASS" if ok else "FAIL"}] {name}: rendered motion ({dx}, {dy}) px/s, correlation={score:.3f}')
        if not ok:
            raise SystemExit(1)


if __name__ == '__main__':
    main()
