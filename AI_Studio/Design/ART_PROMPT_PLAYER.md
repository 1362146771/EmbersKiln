# ART_PROMPT_PLAYER.md — 主角立绘 Prompt 规范（v3.2，暗黑地牢手绘漫画风）

> 由 Art Director 统一产出，供 ImageGen 生成 `art/player/SPR_Player_Tannaro_*.png`。
> 风格基线：**`ART_STYLE.md` v3**（锚点 `art/_ref/REF_style_darkest_cel.png`：粗黑勾边 / 平涂二分阴影 / 冷中性去饱和色板 / 5~6 头身）。
> 文案/设定基线：`WORLD_SETTING.md §6.1`（炭之郎人设，**不可改**）。
> 本文档取代 v2 版（v2 全部弃用）。
> **v3.1 变更**：新增面具设定（守窑人身份标识，与半陶化左手同源）；全套立绘改透明背景交付。
> **v3.2 变更**：面具形状改为几何全脸面甲（形状锚点 `art/_ref/REF_mask_ironclad_shape.png`），**陶瓷质感保留**；主角改为较长头发（过颈中长发）。

---

## 一、角色设定（**不可改**，源自 WORLD_SETTING §6.1）

| 维度 | 内容 |
|------|------|
| 名字 | **炭之郎（Tannaro）** |
| 身份 | 末代守窑学徒 |
| 武器 | **薪斧**（右手）+ **风箱**（左腰挎挂，**两件都必须清晰可见**） |
| 关键锚点 ★ | **左手已半陶化**——手腕到指尖呈苍白釉面陶质，带黑色开片细纹；**不可藏在身体后**、不可只露手背 |
| 气质 | 话少、动手快、匠人感；**不**英雄 pose、**不**怒吼、**不**史诗光晕 |
| 性别 | 偏匠人硬朗青年男性（中性） |

---

## 二、v3 调色板映射（**严格落 8 色板**，详见 ART_STYLE §4.1）

| 角色部位 | v3 色（编号 / HEX） | 说明 |
|----------|---------------------|------|
| 主勾边 / 最深阴影 | **C1 墨黑 `#1B1612`** | 外轮廓 2~2.5px，内部结构线 ≤ 50%，带手绘抖动感 |
| 围裙 / 冷色布料 | **C2 板岩蓝灰 `#3A4554`** | v3 主色 |
| 护腕金属件 / 斧刃 / 风箱喷嘴 | **C3 铁灰 `#68665E`** | 不加反光高光 |
| 皮革束带 / 木柄 / 靴子 | **C4 褐灰 `#94826F`** | |
| 皮肤 / 半陶化左手底色 | **C5 肤粉 `#E0C1AC`** | 陶化手在此基础上更白、带釉面光泽 + C1 开片细纹 |
| 徽记 / 风箱挂带（唯一点缀） | **C6 暗赭红 `#7E504E`** | **占比 ≤ 6%** |
| 工作裤 / 破败织物 | **C7 橄榄绿 `#35392C`** | 偏暗勿提亮 |
| 深阴影补充 / 发色暗部 | **C8 暗紫黑 `#332831`** | 仅阴影层与局部 |

### 2.1 严禁（v3 黑名单，ART_STYLE §4.3）
- ❌ 纯白 `#FFFFFF` 高光（角色亮部用 C5 浅变体）
- ❌ v1 主导色：奶油白 / 暖橙 / 青绿 / 珊瑚 / 蓝
- ❌ v2 古铜暖褐大面积回潮（v3 是冷中性基调）
- ❌ Q 版粉彩、渐变色块、血迹、脏污做旧

---

## 三、BASE_STYLE（所有主角立绘复用，v3）

```
2D character portrait in the exact art style of the reference image: hand-drawn
dark-dungeon comic style, bold black ink contour outlines with slight hand-drawn wobble
(uniform outer line weight, thinner inner detail lines), flat cel color blocks with hard
two-tone shadows (no gradients), desaturated cold-neutral palette of slate blue-gray
#3A4554, iron gray #68665E, tan brown-gray #94826F, olive green #35392C, skin tone
#E0C1AC, with only one small dark brick-red #7E504E accent; realistic comic proportion
5-6 heads tall, NOT chibi. Transparent background.
```

---

## 四.1 面具设定（v3.2 改版，**身份标识，不可改**）

| 维度 | 内容 |
|------|------|
| 名称 | **窑面（Kiln Mask）** |
| 形状 | **几何全脸面甲**（形状锚点 `art/_ref/REF_mask_ironclad_shape.png`）：锐利几何板块拼接、尖下颌、眉骨处上扬的斜切角板、**单条窄眼缝**（露出左眼） |
| 材质表现 | **陶瓷质感保留（v3.1 不变）**：苍白釉面（C5 肤粉更白的浅变体）、细黑开片纹（C1 细线）、微光泽；与半陶化左手同源 |
| 徽记 | 额心刻**暗赭红 C6 窑徽**（与胸前徽记同纹） |
| 头发 | **较长头发（v3.2 变更）**：深色过颈中长发，从面甲下缘/后颈露出，向后自然垂落 |
| 设定含义 | 守窑人的身份面具 + 陶化从左手蔓延至左脸的暗示——身份与诅咒一体 |
| 严禁 | ❌ 金属质感（必须是陶瓷釉面）；❌ 发光眼缝（眼缝内是普通眼睛，非光效）；❌ 戏曲脸谱化彩绘 |

英文描述块（MASK_BLOCK v3.2，并入 CHARACTER_BLOCK 使用）：

```
He wears the Kiln Mask: a FULL-FACE angular geometric face mask (shape like the Ironclad
helmet mask reference — sharp pointed chin, sweeping angular brow plates, one narrow
angular eye slit revealing his left eye), but made of PALE GLAZED CERAMIC identical to
his ceramic left hand, with fine dark crackle texture lines and a slight gloss — NOT
metal, NO glowing eye. A small dark brick-red #7E504E kiln emblem carved on the mask's
forehead. His hair is now LONGER: dark shoulder-length hair flowing out from under the
back and lower edge of the mask.
```

---

## 四、角色造型描述（CHARACTER_BLOCK，所有姿态复用，**一字不改**）

```
Tannaro, a young kiln-keeper craftsman: lean hardy young man, short dark hair, calm tired
eyes, light stubble and a soot smudge on cheek. He wears a craftsman's work outfit:
layered slate-blue-gray cloth apron over tan leather straps with buckles, olive-green
work pants, heavy dark boots, iron-gray metal bracers with rivets, small brick-red
kiln-keeper emblem on chest strap.
RIGHT hand holds a wood-handled hand axe (iron-gray blade, no shiny reflections).
A large hand BELLOWS hangs at his left waist with a dark brick-red #7E504E strap: two
flat wooden boards hinged at one end with clearly visible dark brown leather folds
between them, a metal nozzle tip and a handle — it must read as a bellows even at small
size, NOT a bag or pouch.
CRITICAL KEY FEATURE: his LEFT HAND is half-ceramic — from wrist to fingertips pale
glazed ceramic, lighter and slightly glossy, distinct from his skin tone, with fine dark
ceramic crackle texture lines (porcelain crackle) across fingers and palm drawn as thin
black detail lines; the ceramic hand must stay fully visible.
```

---

## 五、生成流程（已验证，三轮迭代踩坑记录）

### 5.1 流程

1. **Idle（文生图 + 风格参考图）**：`BASE_STYLE + CHARACTER_BLOCK + 姿态描述`，`image` 传 `art/_ref/REF_style_darkest_cel.png`，`input_fidelity: low`（借风格不借内容）。
2. **修正迭代（图生图）**：以上一版为输入图，`input_fidelity: high`，prompt 写"Keep ... exactly as is. Only N changes: ..."，一次最多改 2 处。
3. **姿态扩展（图生图）**：以 idle 定稿为输入图，`input_fidelity: high`，只改姿势/表情/破损程度。

### 5.2 踩坑记录（勿重蹈）

| 坑 | 现象 | 规避写法 |
|----|------|----------|
| 风箱被画成腰包 | "bellows at waist" 被理解成皮袋 | 必须写全结构："two flat wooden boards hinged at one end with clearly visible dark brown leather folds between them, a metal nozzle tip and a handle"，并显式否定 "NOT a bag or pouch" |
| 陶瓷手太弱 | 仅肤色变浅，看不出陶化 | 显式要求 "lighter and slightly glossy, distinct from his skin tone, with fine dark ceramic crackle texture lines (porcelain crackle)" |
| 斧头被要求保持时勿加修饰 | — | 图生图修正时不要附带未要求的改动项 |

### 5.3 参数

- 工具：`ImageGen`；`size`: `1024x1536`（全身立绘）；`quality`: `high`。
- 输出落 `art/player/`，定稿后按 §11 命名规则改名（`SPR_Player_Tannaro_<Pose>.png`）。
- **去背（强制）**：用 `rembg`（venv `C:\Users\Administrator\.workbuddy\binaries\python\envs\default`，已装 rembg 2.0.81 + onnxruntime）模型抠图；抠完将右下角 `x>78%, y>92%` 水印区置透明。**禁止用颜色阈值法去背**（`tools/remove_bg.py` 已弃用：釉面高光/开片纹与背景近色，会被误穿出洞）。
- 接入 Godot 前再缩放到 256×256（ART_STYLE §3），走独立接入任务。

---

## 六、逐姿态 Prompt（英文，ImageGen 直喂）

> v3.1 起：全部图生图、输入上一版对应姿态图、`input_fidelity: high`、`background: transparent`；
> 每张 prompt = 保持声明 + MASK_BLOCK + 姿态描述。

### #0 Idle
```
Keep this character exactly as is — same pose, same outfit, same axe, same bellows at
waist, same ceramic left hand with crackle texture, same colors, same art style. Only
ONE change: add the Kiln Mask to his face. [MASK_BLOCK] Transparent background.
```

### #1 Attack
```
Keep this character exactly as is — same pose, same outfit, same axe, same bellows at
waist, same ceramic left hand with crackle texture, same colors, same art style. Only
ONE change: add the Kiln Mask to his face. [MASK_BLOCK] Transparent background.
```

### #2 Hit
```
Keep this character exactly as is — same pose, same outfit, same axe, same bellows at
waist, same ceramic left hand with crackle texture, same colors, same art style. Only
ONE change: add the Kiln Mask to his face. [MASK_BLOCK] Transparent background.
```

### #3 Death（克制表现：不血腥，陶化蔓延 + 跪倒）
```
Keep this character exactly as is — same pose (collapsing to one knee, axe on the
ground, head bowed), same outfit, same bellows, same ceramic left hand with crackle
texture spreading up the forearm, same colors, same art style. Only ONE change: add
the Kiln Mask to his face. [MASK_BLOCK] Transparent background.
```

### v3（无面具米白底版，存档备查）
- Idle：`Standing pose, both feet grounded, low center of gravity, weapon held casually at side — NOT a heroic pose, no shouting, no epic glow.`（文生图 + 风格参考图，input_fidelity: low）
- Attack / Hit / Death：图生图输入 idle 定稿，仅改 POSE（挥斧横斩 / 受击后仰防御 / 跪倒斧头脱手+陶化蔓延小臂）。

---

## 七、风格一致性自检清单（每张交付前）

- [ ] 外轮廓统一 C1 墨黑，线宽一致，带手绘抖动感
- [ ] 全图色值 100% 落在 §2 色板内（取色器采 5 点验证）
- [ ] 无 §2.1 任意禁用色（重点：无纯白高光、无古铜暖褐回潮）
- [ ] C6 暗赭红占比 ≤ 6%
- [ ] 窑面：几何全脸面甲（尖下颌/斜切角板/单窄眼缝露左眼）、**陶瓷釉面**（非金属）+ 开片纹、额心 C6 窑徽、眼缝不发光
- [ ] 头发：深色过颈中长发，从面甲下缘/后颈露出
- [ ] 左手半陶化（苍白釉面 + 开片细纹）清晰可见，不在身后
- [ ] 薪斧 + 风箱两件都明确可辨（风箱有木板 + 皮囊褶皱 + 喷嘴结构）
- [ ] 5~6 头身（非 Q 版、非写实照片）
- [ ] 缩小至 128×128 仍可读为"持斧匠人"
- [ ] 与 idle 定稿角色一致性：脸 / 发型 / 服装 / 装备位置一致

---

_本文档为强约束。姿态扩展、复刻生成都必须复用 §三 BASE_STYLE 与 §四 CHARACTER_BLOCK，禁止临场改写角色描述。_
