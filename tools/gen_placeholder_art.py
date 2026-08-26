"""生成 v1 占位美术资源（明亮扁平卡通 + 暖色系限制色板）。
遵循 ART_STYLE.md：粗圆角几何形 + 平涂色块 + 无描边，敌方冷紫灰。
用途：让程序不被美术阻塞。正式资源覆盖同名文件即可。
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art")

# ---- ART_STYLE.md 限制色板 ----
CREAM   = (251, 243, 228)
ORANGE  = (240, 153, 123)
TEAL    = (93, 202, 165)
CORAL   = (216, 90, 48)
AMBER   = (239, 159, 39)
BLUE    = (55, 138, 221)
ENEMY   = (127, 119, 221)   # 灰壳紫灰
INK     = (62, 50, 43)

TYPE_COLOR = {"attack": ORANGE, "skill": TEAL, "power": AMBER}
TIER_SIZE  = {"normal": 128, "elite": 160, "boss": 256}
# 灰壳侵蚀度：越高层的敌人越冷、越灰
TIER_TINT  = {"normal": 0.25, "elite": 0.55, "boss": 0.85}

try:
    FONT = ImageFont.truetype("arial.ttf", 13)
    FONT_S = ImageFont.truetype("arial.ttf", 10)
except OSError:
    FONT = ImageFont.load_default()
    FONT_S = ImageFont.load_default()


def mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def label(d, text, w, y, color=INK, font=FONT):
    box = d.textbbox((0, 0), text, font=font)
    d.text(((w - (box[2] - box[0])) / 2, y), text, fill=color, font=font)


def sprite(path, size, body, accent, text, tall=False):
    """角色/敌人占位：粗圆角躯干 + 极简五官，强 silhouette。"""
    w = h = size
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    pad = size * 0.14
    top = size * (0.30 if tall else 0.24)
    r = size * 0.22
    d.rounded_rectangle([pad, top, w - pad, h - pad], radius=r, fill=body)          # 躯干
    hr = size * 0.19
    d.ellipse([w / 2 - hr, top - hr * 1.55, w / 2 + hr, top + hr * 0.45], fill=accent)  # 头
    er = max(2, size * 0.028)
    ey = top - hr * 0.62
    for dx in (-hr * 0.42, hr * 0.42):
        d.ellipse([w / 2 + dx - er, ey - er, w / 2 + dx + er, ey + er], fill=INK)   # 眼
    label(d, text, w, h - size * 0.13, INK, FONT_S)
    img.save(path)


def icon(path, size, ring, core, text):
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, size - 2, size - 2], radius=size * 0.28, fill=ring)
    inset = size * 0.22
    d.rounded_rectangle([inset, inset, size - inset, size - inset],
                        radius=size * 0.18, fill=core)
    label(d, text[:4].upper(), size, size * 0.66, INK, FONT_S)
    img.save(path)


def card_art(path, size, tone, text):
    img = canvas(size, size)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=size * 0.09, fill=CREAM)
    d.rounded_rectangle([size * 0.08, size * 0.08, size * 0.92, size * 0.66],
                        radius=size * 0.06, fill=tone)                        # 插画区
    d.rounded_rectangle([size * 0.08, size * 0.72, size * 0.92, size * 0.80],
                        radius=size * 0.03, fill=mix(tone, INK, 0.18))        # 类型底色条
    d.rounded_rectangle([size * 0.06, size * 0.05, size * 0.22, size * 0.21],
                        radius=size * 0.05, fill=AMBER)                       # 费用块
    label(d, text, size, size * 0.85, INK, FONT)
    img.save(path)


def ui_panel(path, w, h, fill, border, text):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=24, fill=fill,
                        outline=border, width=4)                              # 9-slice 友好
    label(d, text, w, h / 2 - 8, INK, FONT)
    img.save(path)


def main():
    for sub in ("player", "enemies", "cards", "icons/status", "icons/relic", "ui"):
        os.makedirs(os.path.join(ART, sub), exist_ok=True)

    D = os.path.join(ROOT, "data")
    cards = json.load(open(f"{D}/cards.json", encoding="utf-8"))["cards"]
    enemies = json.load(open(f"{D}/enemies.json", encoding="utf-8"))["enemies"]
    statuses = json.load(open(f"{D}/statuses.json", encoding="utf-8"))["statuses"]
    relics = json.load(open(f"{D}/relics.json", encoding="utf-8"))["relics"]

    n = 0
    # 战士「炭」：暖橙躯干 + 奶油白头（左手半陶化的视觉锚点留给正式资源）
    sprite(f"{ART}/player/SPR_Player_Warrior.png", 128, ORANGE, CREAM, "Tan")
    n += 1

    for e in enemies:
        size = TIER_SIZE.get(e["tier"], 128)
        t = TIER_TINT.get(e["tier"], 0.25)
        body = mix(ENEMY, CREAM, 1 - t)          # 侵蚀度越高越紫灰
        accent = mix(CREAM, ENEMY, t * 0.6)
        sprite(f"{ART}/enemies/{e['sprite']}.png", size, body, accent,
               e["id"][:11], tall=(e["tier"] == "boss"))
        n += 1

    for c in cards:
        card_art(f"{ART}/cards/{c['art']}.png", 256,
                 TYPE_COLOR.get(c["type"], ORANGE), c["id"][:16])
        n += 1

    for s in statuses:
        core = TEAL if s["type"] == "buff" else ENEMY
        ring = mix(core, CREAM, 0.45)
        icon(f"{ART}/icons/status/{s['icon']}.png", 48, ring, core, s["id"])
        n += 1

    for r in relics:
        icon(f"{ART}/icons/relic/{r['icon']}.png", 64, mix(AMBER, CREAM, 0.5), AMBER, r["id"])
        n += 1

    for name, w, h in [("UI_Panel_Combat", 512, 128), ("UI_Panel_Map", 384, 256),
                       ("UI_Panel_Reward", 384, 256), ("UI_Panel_Shop", 384, 256),
                       ("UI_Panel_Rest", 320, 192)]:
        ui_panel(f"{ART}/ui/{name}.png", w, h, CREAM, ORANGE, name.replace("UI_Panel_", ""))
        n += 1

    print(f"  OK 生成 {n} 个占位资源 -> res://art/")
    for sub in ("player", "enemies", "cards", "icons/status", "icons/relic", "ui"):
        p = os.path.join(ART, sub)
        print(f"     art/{sub:16} {len(os.listdir(p))} 个")


if __name__ == "__main__":
    main()
