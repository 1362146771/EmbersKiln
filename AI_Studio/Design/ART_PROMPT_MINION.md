> **⚠️ 已作废（v2）**：美术风格已升级至 v3「暗黑地牢手绘漫画风」，见 `ART_STYLE.md`（锚点 `art/_ref/REF_style_darkest_cel.png`）。
> 本文档色板/比例全部失效，须按 v3 重写后方可用于批量生成；重写前禁止使用本文档出图。

# ART_PROMPT_MINION.md — 随从立绘 Prompt 规范（v2，轻量化暗黑地牢）

> 由 Art Director 统一产出，供 ImageGen 生成 `art/minions/SPR_Minion_*.png`。
> 对应数据：`data/minions.json`（3 个随从：emberhound / glazeward / spark）。
> 风格基线：见 `ART_STYLE.md`（v2 轻量化暗黑地牢：粗黑勾边 + 中性褐灰钢 + 锈红/琥珀点缀）。
> 文案/设定基线：见 `WORLD_SETTING.md`、`SUMMON_SYSTEM_DESIGN.md`。

## 一、随从的定位与配色逻辑（v2 更正）

随从 = 玩家（守窑人·炭之郎）召唤的**友方临时单位**。

> **v2 重要更正（废止 v1 旧规）**：原 v1 规范要求"严禁敌方紫灰、友方走暖色+釉青绿"——这条**整体色温区分规则已在 ART_STYLE v2 §7 彻底废止**。
> 在 v2 中，随从与敌人、玩家**共用同一 7 色中性板（C1~C7）**，不再用颜色表达"友方=暖/青绿"。
> 随从的"友方身份"改由以下手段表达（≥2 种）：
> 1. **窑印徽记**：随从均带**完整锈红（C6）窑印徽记**（玩家 faction 标记），敌人徽记污损或缺失——据此一眼区分敌我。
> 2. **材质工艺感**：随从是"窑烧守护灵/陶塑"，呈现 crafted 陶/金属质感，而非野生怪物的有机变异。
> 3. **姿态**：随从为警戒/守护/亲昵态，非攻击性张扬；战斗内置于**召唤栏（友方侧）**，UI 位置天然区隔。
> 4. 锈红（C6）作为玩家 faction 色可在随从上略高于 8% 上限使用（徽记 + 火苗），但仍以中性褐灰钢为体。

## 二、BASE_STYLE（所有立绘复用）

```
2D game character sprite, lighted dark-dungeon style inspired by Darkest Dungeon art direction but clean and non-horror,
hand-drawn illustration with bold uniform black ink contour outlines (consistent 1.5-2px line weight),
flat color blocks with simple hard two-tone shadow (no soft gradients),
neutral palette dominated by dark-brown, steel-gray and pale gray, with only small accents of rusty red and amber.
Material read: metal as flat steel-gray with rivets, ceramic as pale gray-brown matte with no glossy highlight,
leather as dark-brown with buckle stitching. High readability silhouette, no pure white highlight,
transparent background, centered full-body standing pose facing forward, bold minimal facial features.
```

每张完整 prompt = `BASE_STYLE` + 角色造型描述 + 着色（限 C1~C7）+ `transparent background, 1024x1024`。

## 三、逐张 Prompt（英文，ImageGen 直喂）

### 1. 窑犬 Emberhound（攻击 5 / HP10 / 寿命 3）— 窑烧守护犬灵
`A kiln hound guardian spirit: a sturdy quadruped hound made of dark-brown #3D2B1F fired clay with pale gray-brown #A89484 clay highlights,
a flat steel-gray #6E7378 metal collar with rivets around the neck, small flame-shaped ears and a flame-tipped tail rendered in amber #D9A441
with rusty-red #A8442A core (fire material, allowed beyond 8 percent as it is the hound's living flame),
a small intact rusty-red #A8442A kiln emblem on the collar as faction mark,
alert but friendly expression, proud standing stance, bold black ink contour outline, centered full-body facing forward.
Transparent background, 1024x1024.`

### 2. 釉卫 Glazeward（防御 5 / HP14 / 寿命 3）— 釉陶守护像
`A sturdy glaze guardian golem made of pale gray-brown #A89484 matte glazed ceramic with off-white #F2E8D5 glaze highlights,
a wide flat dark-brown #3D2B1F base, holding a rounded shield in front made of flat steel-gray #6E7378 with rivets and a small rusty-red #A8442A kiln emblem,
calm protective stance, minimal embossed face, an intact rusty-red #A8442A kiln emblem on the chest as faction mark,
bold black ink contour outline, centered full-body facing forward.
Transparent background, 1024x1024.`

### 3. 火灵 Spark（攻击 4 / HP6 / 寿命 2）— 火苗精
`A tiny floating fire spirit: a small flame body in amber #D9A441 with rusty-red #A8442A core (fire material, allowed beyond 8 percent),
two dot eyes and a tiny smile in off-white #F2E8D5, wispy flame tips, trailing spark particles rising upward,
lightweight hovering pose, no legs, a tiny intact rusty-red #A8442A kiln emblem floating beside it as faction mark,
cute friendly look, bold black ink contour outline, centered.
Transparent background, 1024x1024.`

## 四、生成与接入要求

- 工具：`ImageGen`；`size`: `1024x1024`，`background`: `transparent`，`quality`: `high`。
- 输出先落 `gen/minions/`，缩放至 **256×256**（普通单位基准 128 的 2x，移动端 @720 清晰）后覆盖 `art/minions/SPR_Minion_<Id>.png`
  （保留透明通道）。
- 命名严格对应 `minions.json` 的 `sprite` 字段：
  - `SPR_Minion_Emberhound.png`
  - `SPR_Minion_Glazeward.png`
  - `SPR_Minion_Spark.png`
- 覆盖后删除旧 `.import` 与 `gen/` 临时目录，触发 Godot 重新导入。
- Godot 导入：透明 PNG，`Filter = Linear`（矢量扁平化手绘），`Compress = VRAM/Lossless`。
- 战斗内随从以 chip 形式（≥80×80）显示在召唤栏，立绘缩略 + HP 条 + 格挡盾 + 友方意图，见 `SUMMON_SYSTEM_DESIGN.md` §6 / §6.1 遮挡亮度机制。
- **素材来源**：v1 早前生成的窑犬/釉卫/火灵立绘（暖橙/青绿配色）按 ART_STYLE §15 视为弃用，须按本 v2 规范重新出图，禁止复用。

## 五、风格一致性校验清单

- [ ] 粗黑勾边（C1 #1B1612）统一线宽，无 v1"无描边"残留
- [ ] 落色 100% 在 C1~C7（火焰用 C6/C7 材质允许超 8%）；无 v1 奶油白 #FBF3E4 / 暖橙 #F0997B / 青绿 #5DCAA5 / 珊瑚 #D85A30 / 蓝 #378ADD
- [ ] 无纯白 #FFFFFF 高光（用 C5 米白）
- [ ] 三随从均带**完整锈红窑印徽记**（faction 标记），与敌人区分
- [ ] 透明背景干净（无杂色边）
- [ ] 居中、正视、缩小至 80px 仍可读
