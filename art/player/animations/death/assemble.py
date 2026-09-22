"""Finish generate2dsprite's keyed frames; preserve one anatomical scale."""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
HOLDS = [5, 6, 6, 5, 4, 10]  # 30 fps: 1.2 seconds including a grounded final hold.


def main():
    frames = []
    for index in range(1, 7):
        frame = Image.open(ROOT / f"death-{index}.png").convert("RGBA")
        pixels = np.array(frame)
        rgb = pixels[:, :, :3].astype(np.int16)
        # Remove residual magenta spill from keyed edge pixels (no creative redraw).
        excess = np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1]
        mask = (excess > 12) & (pixels[:, :, 3] > 0)
        rgb[:, :, 0][mask] -= excess[mask]
        rgb[:, :, 2][mask] -= excess[mask]
        pixels[:, :, :3] = rgb.clip(0, 255).astype(np.uint8)
        frame = Image.fromarray(pixels)
        frames.append(frame)
    atlas = Image.new("RGBA", (768 * 3, 768 * 2))
    for index, frame in enumerate(frames):
        atlas.paste(frame, ((index % 3) * 768, (index // 3) * 768))
    atlas.save(ROOT / "atlas.png")
    frames[0].save(ROOT / "preview.gif", save_all=True, append_images=frames[1:],
                   duration=[round(hold / 30 * 1000) for hold in HOLDS],
                   loop=0, disposal=2)
    resource = ROOT.parent / "PlayerCombatFrames.tres"
    text = resource.read_text(encoding="utf-8")
    if 'id="death_atlas"' not in text:
        text = text.replace('[sub_resource',
            '[ext_resource type="Texture2D" path="res://art/player/animations/death/atlas.png" id="death_atlas"]\n\n[sub_resource', 1)
        subs = ""
        for index in range(6):
            subs += (f'[sub_resource type="AtlasTexture" id="death_{index + 1}"]\n'
                     'atlas = ExtResource("death_atlas")\n'
                     f'region = Rect2({index % 3 * 768}, {index // 3 * 768}, 768, 768)\n'
                     'filter_clip = true\n\n')
        text = text.replace('[resource]', subs + '[resource]')
        entries = ', '.join('{"duration": %.1f, "texture": SubResource("death_%d")}' %
                            (hold, index + 1) for index, hold in enumerate(HOLDS))
        text = text.replace('animations = [', 'animations = [{"frames": [' + entries +
                            '], "loop": false, "name": &"death", "speed": 30.0}, ', 1)
        resource.write_text(text, encoding="utf-8")
    meta = json.loads((ROOT / "pipeline-meta.json").read_text(encoding="utf-8"))
    meta["input"] = "art/player/animations/death/raw-sheet-corrected.png"
    meta["runtime"] = {"atlas": "atlas.png", "holds_at_30_fps": HOLDS,
                       "duration_seconds": sum(HOLDS) / 30, "edge_despill": True,
                       "note": "Collapse changes body bounding height; all frames retain shared scale.",
                       "frame4_axe_corrected": True, "other_five_frames_unchanged": True}
    (ROOT / "pipeline-meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
