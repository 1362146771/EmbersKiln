"""2026-08-28 user-authorized local cutout, latest v8 enemy selections only.

inspect -> cutout -> manual visual QA -> install -> verify.
No generative model; never change source drawings, player assets or Sagger.
Dependencies: Pillow, NumPy. Run from any working directory.
"""
import argparse
from collections import deque
from hashlib import sha256
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "art/enemies/review_20260827_v8/manifest.json"
OUTPUT = ROOT / "art/enemies/production_20260828"
QA = ROOT / "Temp/enemy-art-verify"
BACKUP = ROOT / "art/_archive/enemies_before_20260828"
# Image-space seeds are added only after visually inspecting enclosed gaps.
HOLES = {
    "EmberEater": [(900, 195), (411, 240), (910, 665), (853, 945)],
    "KilnheartEmber": [(910, 650)],
    "Embermoth": [(445, 810)],
    "Ashcantor": [(1025, 961), (177, 1041)],
    "Kilnward": [(790, 610)],
    "Slagbeast": [(844, 675)],
    "Kilnwarden": [(800, 530), (380, 850)],
    "Meltgolem": [(856, 600), (840, 780)],
    "KilnCaptain": [(700, 515)],
    "Cinderfiend": [(877, 530), (941, 840), (984, 895)],
    "ChiTheFirst": [(870, 650), (390, 560), (925, 1020), (1103, 1055)],
}


def expand(mask, radius=1):
    return np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).filter(
        ImageFilter.MaxFilter(radius * 2 + 1))) > 0


def flood(possible, seeds):
    h, w = possible.shape
    seen = np.zeros_like(possible)
    queue = deque()
    for x, y in seeds:
        if possible[y, x] and not seen[y, x]:
            seen[y, x] = True
            queue.append((y, x))
    while queue:
        y, x = queue.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and possible[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                queue.append((ny, nx))
    return seen


def cutout(e):
    rgb = np.array(Image.open(e["source_path"]).convert("RGB"))
    h, w = rgb.shape[:2]
    possible = (rgb.min(2) >= 165) & (np.ptp(rgb, axis=2) <= 22)
    seeds = [(x, y) for y in range(h) for x in (0, w - 1)]
    seeds += [(x, y) for x in range(w) for y in (0, h - 1)]
    seeds += HOLES.get(e["key"], [])
    for x, y in HOLES.get(e["key"], []):
        assert possible[y, x], f'Invalid gap seed: {e["key"]} {(x, y)}'
    outside = flood(possible, seeds)
    alpha = np.where(outside, 0, 255).astype(np.uint8)
    result = rgb.copy()
    band = expand(outside, 2) & expand(~outside, 1)
    clean_bg = outside & ~expand(~outside, 2)
    dark_outline = (~expand(outside, 1)) & (rgb.max(2) < 85)
    for y, x in np.argwhere(band):
        pixel = rgb[y, x].astype(float)
        if pixel.max() < 40 or np.ptp(pixel) > 30:
            continue
        y0, y1 = max(0, y - 6), min(h, y + 7)
        x0, x1 = max(0, x - 6), min(w, x + 7)
        bg_pos = np.argwhere(clean_bg[y0:y1, x0:x1])
        fg_pos = np.argwhere(dark_outline[y0:y1, x0:x1])
        if not len(fg_pos):
            continue
        center = np.array([y - y0, x - x0])
        samples = []
        for positions in (bg_pos, fg_pos):
            if not len(positions):
                samples.append(np.median(rgb[0], axis=0))
                continue
            nearest = positions[np.argsort(((positions - center) ** 2).sum(1))[:3]]
            samples.append(np.median(rgb[y0 + nearest[:, 0], x0 + nearest[:, 1]], axis=0))
        background, foreground = samples
        direction = foreground - background
        coverage = float(np.clip(np.dot(pixel - background, direction) / np.dot(direction, direction), 0, 1))
        if coverage < 0.025:
            alpha[y, x] = 0
        elif coverage < 0.98:
            alpha[y, x] = round(coverage * 255)
            unmatted = (pixel - (1 - coverage) * background) / coverage
            result[y, x] = np.clip(np.rint(np.clip(unmatted, foreground - 5, foreground + 5)), 0, 255)
    result[alpha == 0] = 0
    im = Image.fromarray(np.dstack((result, alpha)))
    dest = OUTPUT / e["production_path"].name
    im.save(dest)
    assert np.array_equal(result[alpha == 255], rgb[alpha == 255])
    assert not alpha[0].any() and not alpha[-1].any()
    assert not alpha[:, 0].any() and not alpha[:, -1].any()
    for x, y in HOLES.get(e["key"], []):
        assert alpha[y, x] == 0, f'Gap seed not fully transparent: {e["key"]} {(x, y)}'
    assert 0.08 < (alpha > 0).mean() < 0.85
    for title, color in (("dark", (27, 22, 28, 255)), ("white", (255, 255, 255, 255))):
        preview = Image.new("RGBA", im.size, color)
        preview.alpha_composite(im)
        preview.convert("RGB").save(QA / f'{e["key"]}_{title}.png')
    # Annotated retained pale components help review holes WITHOUT deleting
    # enclosed pale pottery. Only source-inspected gap seeds can remove them.
    remain = possible & ~outside
    labels = []
    while remain.any():
        y, x = np.argwhere(remain)[0]
        component = flood(remain, [(int(x), int(y))])
        remain[component] = False
        if component.sum() < 60:
            continue
        ys, xs = np.where(component)
        labels.append({"seed": [int(x), int(y)], "area": int(component.sum()),
                       "box": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]})
    marked = Image.open(QA / f'{e["key"]}_dark.png')
    draw = ImageDraw.Draw(marked)
    font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 23)
    for idx, component in enumerate(labels):
        box = component["box"]
        draw.rectangle(box, outline="#ff20b0", width=2)
        draw.text((box[0], box[1]), str(idx), font=font, fill="#ff20b0")
    marked.save(QA / f'{e["key"]}_holes.png')
    (QA / f'{e["key"]}_holes.json').write_text(json.dumps(labels, indent=2), encoding="utf-8")
    return {"key": e["key"], "name": e["name"], "source": e["source_path"].relative_to(ROOT).as_posix(),
            "source_sha256": digest(e["source_path"]), "production": e["production_path"].relative_to(ROOT).as_posix(),
            "output_sha256": digest(dest), "size": list(im.size), "alpha_bbox": list(im.getbbox()),
            "transparent": int((alpha == 0).sum()), "partial": int(((alpha > 0) & (alpha < 255)).sum()),
            "opaque": int((alpha == 255).sum()), "opaque_rgb_unchanged": True,
            "gap_seeds": HOLES.get(e["key"], [])}


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def selections():
    entries = json.loads(REVIEW.read_text(encoding="utf-8"))["images"]
    assert len(entries) == 20 and len({e["key"] for e in entries}) == 20
    for e in entries:
        source = (REVIEW.parent / e["file"]).resolve()
        assert source.is_relative_to(ROOT / "art/enemies")
        assert digest(source) == e["sha256"].lower(), f"Source changed: {source}"
        e["source_path"] = source
        e["production_path"] = ROOT / f'art/enemies/SPR_Enemy_{e["key"]}.png'
        assert e["production_path"].is_file()
    return entries


def sheet(entries, mode, color=(27, 22, 28, 255)):
    # QA composites only; no resampling of production assets.
    for page in range((len(entries) + 7) // 8):
        canvas = Image.new("RGB", (1280, 700), color[:3])
        draw = ImageDraw.Draw(canvas)
        font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 19)
        for slot, e in enumerate(entries[page * 8:page * 8 + 8]):
            p = e["source_path"] if mode == "source" else OUTPUT / e["production_path"].name
            if mode == "holes":
                p = QA / f'{e["key"]}_holes.png'
            im = Image.open(p).convert("RGBA")
            im.thumbnail((312, 312), Image.Resampling.LANCZOS)
            x, y = (slot % 4) * 320, (slot // 4) * 350
            tile = Image.new("RGBA", (320, 320), color)
            tile.alpha_composite(im, ((320 - im.width) // 2, (320 - im.height) // 2))
            canvas.paste(tile.convert("RGB"), (x, y))
            draw.text((x + 8, y + 322), f'{e["index"]:02} {e["key"]}', font=font,
                      fill="white" if color[0] < 100 else "black")
        canvas.save(QA / f"{mode}_{page + 1}.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["inspect", "cutout", "install", "verify", "sheets", "combat-sheets"])
    parser.add_argument("--keys", nargs="*")
    args = parser.parse_args()
    entries = selections()
    if args.keys:
        entries = [e for e in entries if e["key"] in args.keys]
    QA.mkdir(parents=True, exist_ok=True)
    if args.mode == "combat-sheets":
        data = json.loads((ROOT / "data/enemies.json").read_text(encoding="utf-8"))["enemies"]
        ids = {ed["sprite"]: ed["id"] for ed in data}
        for page in range(3):
            canvas = Image.new("RGB", (1440, 690), (27, 22, 28))
            for slot, e in enumerate(entries[page * 8:page * 8 + 8]):
                eid = ids[e["production_path"].stem]
                capture = Image.open(QA / f"single_{eid}.png")
                # QA contact sheet of actual viewport captures; full originals
                # remain alongside it. Crop only the upper enemy area here.
                tile = capture.crop((0, 0, 720, 690)).resize((360, 345), Image.Resampling.LANCZOS)
                canvas.paste(tile, ((slot % 4) * 360, (slot // 4) * 345))
            canvas.save(QA / f"combat_sheet_{page + 1}.png")
        return
    if args.mode == "sheets":
        sheet(entries, "holes")
        sheet(entries, "dark")
        sheet(entries, "white", (255, 255, 255, 255))
        return
    if args.mode == "inspect":
        sheet(entries, "source")
        baseline = QA / "protected_hashes.json"
        if not baseline.exists():
            paths = list((ROOT / "art/player").rglob("*"))
            paths += list((ROOT / "scripts").rglob("*.gd")) + list((ROOT / "data").glob("*.json"))
            paths += list((ROOT / "art/enemies").glob("*.import"))
            paths += [ROOT / "art/enemies/SPR_Enemy_SaggerMatron.png", ROOT / "project.godot"]
            baseline.write_text(json.dumps({p.relative_to(ROOT).as_posix(): digest(p)
                                           for p in paths if p.is_file()}, indent=2), encoding="utf-8")
        print("Source sheets and protected asset baseline:", QA)
        return
    if args.mode == "cutout":
        OUTPUT.mkdir(parents=True, exist_ok=True)
        previous = OUTPUT / "manifest.json"
        if previous.exists():
            assert json.loads(previous.read_text(encoding="utf-8"))["status"] != "installed", "Already installed; preserve the production audit record"
        records = []
        for e in entries:
            record = cutout(e)
            records.append(record)
            print(e["key"], record["alpha_bbox"], record["transparent"], flush=True)
        if args.keys and previous.exists():
            old = json.loads(previous.read_text(encoding="utf-8"))["images"]
            updated = {r["key"]: r for r in records}
            records = [updated.get(r["key"], r) for r in old]
        previous.write_text(json.dumps({"date": "2026-08-28", "status": "cutout_pending_visual_qa",
            "authorization": "用户批准全部新版怪物实装并沿用本地抠图；主角明确排除，匣母保持不变。",
            "method": "local_exterior_flood_and_narrow_edge_unmatting", "images": records},
            ensure_ascii=False, indent=2), encoding="utf-8")
        if not args.keys:
            sheet(entries, "dark")
            sheet(entries, "white", (255, 255, 255, 255))
        return
    if args.mode == "verify":
        protected = json.loads((QA / "protected_hashes.json").read_text(encoding="utf-8"))
        manifest = json.loads((OUTPUT / "manifest.json").read_text(encoding="utf-8"))
        scoped = manifest.get("presentation_changes", {})
        assert set(scoped) <= {"scripts/combat/EnemyPanel.gd", "scripts/combat/EnemyViewManager.gd"}
        for path, expected in protected.items():
            if path in scoped:
                assert scoped[path]["before"] == expected
                expected = scoped[path]["after"]
            assert digest(ROOT / path) == expected, f"Out-of-scope change: {path}"
        print("Protected files unchanged:", len(protected) - len(scoped), "; scoped presentation files verified:", len(scoped))
        for r in manifest["images"]:
            assert digest(ROOT / r["source"]) == r["source_sha256"]
            candidate = OUTPUT / Path(r["production"]).name
            assert digest(candidate) == r["output_sha256"], f"Output/manifest mismatch: {candidate}"
            src = np.array(Image.open(ROOT / r["source"]).convert("RGB"))
            rgba = np.array(Image.open(candidate))
            assert rgba.shape == (*src.shape[:2], 4)
            assert np.array_equal(rgba[:, :, :3][rgba[:, :, 3] == 255], src[rgba[:, :, 3] == 255])
            if manifest["status"] == "installed":
                assert digest(ROOT / r["production"]) == r["output_sha256"]
                assert digest(ROOT / r["backup"]) == r["previous_sha256"]
        print("Source / production / backup hashes verified:", len(manifest["images"]))
        return
    if args.mode == "install":
        manifest_path = OUTPUT / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        assert manifest["status"] in ("visual_qa_approved", "installed"), "Inspect dark/white composites before installing"
        assert len(manifest["images"]) == 20
        BACKUP.mkdir(parents=True, exist_ok=True)
        # Validate the complete batch before replacing any production file.
        for r in manifest["images"]:
            target = ROOT / r["production"]
            assert target.parent == ROOT / "art/enemies" and target.name != "SPR_Enemy_SaggerMatron.png"
            assert digest(OUTPUT / target.name) == r["output_sha256"]
            assert digest(ROOT / r["source"]) == r["source_sha256"]
            backup = BACKUP / target.name
            if backup.exists():
                assert digest(target) in (digest(backup), r["output_sha256"]), f"Unexpected target change: {target}"
        for r in manifest["images"]:
            target = ROOT / r["production"]
            backup = BACKUP / target.name
            if not backup.exists():
                shutil.copy2(target, backup)
            r["previous_sha256"] = digest(backup)
            r["backup"] = backup.relative_to(ROOT).as_posix()
            shutil.copy2(OUTPUT / target.name, target)
        manifest["status"] = "installed"
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
        print("Installed 20 portraits; originals preserved:", BACKUP)
        return


if __name__ == "__main__":
    main()
