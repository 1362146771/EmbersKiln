> **⚠️ 已作废（v2）**：美术风格已升级至 v3「暗黑地牢手绘漫画风」，见 `ART_STYLE.md`（锚点 `art/_ref/REF_style_darkest_cel.png`）。
> 本文档色板/比例全部失效，须按 v3 重写后方可用于批量生成；重写前禁止使用本文档出图。

# ART_PROMPT_ENCHANT.md — 附魔图标 Prompt 规范（v2，轻量化暗黑地牢）

> 由 Art Director 统一产出，供 ImageGen 生成 `art/icons/enchant/ICO_Enchant_*.png`。
> 对应数据：`data/enchants.json`（10 个附魔）。
> 风格基线：见 `ART_STYLE.md`（v2 轻量化暗黑地牢：粗黑勾边 + 中性褐灰钢 + 锈红/琥珀点缀）。

## 一、统一视觉语言（同套必有）

附魔 = 施加于卡牌的「窑印符」。所有图标共享**同一画框语言**，仅中央发光符文（glyph）随效果变化，保证套内一致、与药水图标（窑瓶）风格同源但造型区分。

- **画框**：圆角方形的陶土印符（kiln-fired clay seal / medallion），**深褐（C2 #3D2B1F）陶土平涂 + C1 墨黑粗勾边**，带 C5 米白/C4 浅褐灰釉面高光（无纯白、无假阴影贴纸感）。
- **中央符文**：bold 浮雕感（embossed）发光符文，颜色按「效果色彩逻辑」着色（见下表，全部落到 v2 允许色，严禁 v1 暖橙/青绿/珊瑚）。
- **faction 标记**：印符四角之一带极小的**完整锈红（C6）窑印点**——附魔属玩家增益体系，与敌人效果区分。
- **渲染**：v2 扁平手绘、平涂色块、粗黑勾边、加分色二分阴影、无做旧、无写实阴影、透明背景、居中、64×64、缩小仍清晰。

## 二、BASE_STYLE（所有图标复用）

```
Flat dark-dungeon game icon, lighted clean non-horror style inspired by Darkest Dungeon,
bold uniform black ink contour outline (consistent 1px line weight), flat color blocks with simple two-tone shadow,
neutral palette dominated by dark-brown, steel-gray and pale gray, small accents of rusty red and amber only,
kiln-fired clay medallion look, no pure white highlight, transparent background, centered composition, high readability at tiny 64x64 size.
```

每张图标完整 prompt = `BASE_STYLE` + 画框描述 + 符文描述 + 着色（限 C1~C7 / §4.2 辅助色）+ `transparent background, 64x64`。

## 三、效果色彩逻辑（v2 重映射，与 ART_STYLE §8.2 卡牌类型色对齐）

> **v2 更正**：v1 用的暖橙 #F0997B / 青绿 #5DCAA5 / 琥珀 #EF9F27 / 珊瑚红 #D85A30 全部属 §4.3 黑名单，已废止。
> 重映射为 v2 允许色，并与卡牌类型底色（攻击=锈红 / 技能=钢灰 / 能力=深褐 / 状态诅咒=暗紫）保持一致：

| 类别 | v1 旧色（废止） | **v2 新色** | 用途 |
|------|----------------|-------------|------|
| 攻击增益（伤害/攻击触发） | 暖橙 #F0997B | **C6 锈红 #A8442A** | 窑淬、炽痕 |
| 防御/技能增益（格挡/技能触发） | 青绿 #5DCAA5 | **C3 钢灰 #6E7378** | 釉封、回火、塑形 |
| 通用/资源增益（抽牌/能量/窑温） | 琥珀 #EF9F27 | **C7 琥珀 #D9A441** | 余烬、风引、窑温 |
| 减益施加（对敌/自损型） | 珊瑚红 #D85A30 | **C10 暗紫 #7A3D6E** | 釉裂、灰蚀 |

## 四、逐图标 Prompt（英文，ImageGen 直喂）

> 通用前缀（合成时拼接）：
> `BASE_STYLE` + `A rounded-square ceramic medallion (kiln-fired clay seal) in dark-brown #3D2B1F with bold black ink contour outline and pale gray-brown glaze highlights, a tiny intact rusty-red #A8442A kiln mark at one corner, embossed with a bold glowing rune glyph in the center: `

### 1. 窑淬 KilnQuench（攻击伤害 +2）— 锈红
`a downward teardrop of flame being quenched with a small splash. Rune color rusty red #A8442A. Transparent background, 64x64.`

### 2. 釉封 GlazeSeal（防御/技能格挡 +2）— 钢灰
`a rounded shield shape with a subtle highlight. Rune color steel-gray #6E7378. Transparent background, 64x64.`

### 3. 余烬 EmberReturn（打出的牌抽 1）— 琥珀
`a small flame curving back into a circular return arrow (cycle). Rune color amber #D9A441. Transparent background, 64x64.`

### 4. 风引 WindLead（获得 1 能量）— 琥珀
`a wind swirl with an upward chevron arrow. Rune color amber #D9A441. Transparent background, 64x64.`

### 5. 炽痕 HeatTrace（攻击后获 1 层炽热）— 锈红
`a burning footprint trail with rising heat waves. Rune color rusty red #A8442A. Transparent background, 64x64.`

### 6. 釉裂 EmberCraze（攻击施加 1 层釉裂·敌）— 暗紫
`jagged cracked glaze lines spreading across a surface. Rune color dark purple #7A3D6E. Transparent background, 64x64.`

### 7. 回火 AnnealGlow（防御牌获 1 层回火）— 钢灰
`radiant sunburst glow lines emanating from center. Rune color steel-gray #6E7378. Transparent background, 64x64.`

### 8. 窑温 KilnWarmth（积累 1 点窑温）— 琥珀
`rising heat bars / a small thermometer with climbing mercury. Rune color amber #D9A441. Transparent background, 64x64.`

### 9. 灰蚀 AshBite（攻击 +3 但自获 2 层灰蚀）— 暗紫
`a biting jaw with ash particles eroding away. Rune color dark purple #7A3D6E. Transparent background, 64x64.`

### 10. 塑形 TemperBind（获格挡牌获 1 层塑形）— 钢灰
`a molded clay blob being shaped by two stylized hands. Rune color steel-gray #6E7378. Transparent background, 64x64.`

## 五、生成与接入要求

- `size`: `1024x1024`，`background`: `transparent`，`quality`: `high`。
- 输出先落 `gen/<id>/`，缩放 64×64 后覆盖 `art/icons/enchant/ICO_Enchant_<Name>.png`。
- 覆盖后删除旧 `.import` 与 `gen/` 临时目录，触发 Godot 重新导入。
- Godot 导入：透明 PNG，`Filter` 按扁平图选 `Linear`，`Compress = VRAM/Lossless`。
- 不与药水图标（带木塞窑瓶）造型混淆；二者同源 v2 地牢风，但附魔用「印符框+符文」，药水用「瓶身+木塞」。

## 六、尚未确认

- 附魔图标为「印符框」造型（非瓶子），已与药水区分；若吴总希望附魔也走瓶子造型，需改本规范第三节。
- UI 层（CombatUI/ShopUI/RewardUI/AltarUI）TextureRect 显示图标为后续任务，不在本次生成范围。
- v1 旧附魔图标（暖橙/青绿配色）按 ART_STYLE §15 视为弃用，须按本 v2 规范重新出图。
