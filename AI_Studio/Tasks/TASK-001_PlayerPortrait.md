# TASK-001 主角立绘（炭之郎 / Tannaro）

> Owner: **Art Director Agent**
> Reviewer: **Producer（小腾）**
> 验收: Designer + Programmer（资源接入后）
> 创建: 2026-08-20
> 状态: **DELIVERED**（2026-08-20 10:58 出图，采用 v1 + PIL 后处理去底/水印；详见 `Reports/ART_REPORT_001.md`）

---

## Goal

为玩家角色「**炭之郎（Tannaro）**」制作一张战斗主立绘，提供替代当前 `art/player/SPR_Player_Warrior.png` 占位火柴人的**正式视觉**（占位图本身保留，本任务不动，走独立 TASK-002 替换战斗小 sprite）。

---

## Input（必读）

- `AI_STUDIO/Design/ART_STYLE.md` — 美术风格硬约束（**最强约束**）
- `AI_STUDIO/Design/WORLD_SETTING.md` §6.1 — 主角「炭之郎」人设（已改名，2026-08-20）
- `AI_STUDIO/Design/WORLD_SETTING.md` §2 — 调色板世界观依据
- `AI_STUDIO/Design/GAME_SPEC.md` — 手机端 720×1280 UI 规范（立绘在战斗 HUD 的展示位由此决定）
- `AI_STUDIO/Agents/Art.md` — Art Director 职责与产出格式
- 现状: `art/player/SPR_Player_Warrior.png`（橙色身体 + 白色圆头 + "Tan" 文字，纯占位）

---

## Requirements

### 1. 角色设定（**不可改**，源自 WORLD_SETTING §6.1）

| 维度 | 内容 |
|---|---|
| 名字 | **炭之郎（Tannaro）** |
| 身份 | 末代守窑学徒 |
| 武器 | **薪斧** + **风箱**（两件**都必须**清晰可见） |
| 关键锚点 ★ | **左手已半陶化**——手腕到指尖呈奶油白陶质（#FBF3E4），**不可藏在身体后** |
| 气质 | 话少、动手快、匠人感；**不**英雄pose、**不**怒吼、**不**史诗感 |
| 性别 | 中性 / 偏匠人硬朗青年男性（吴总拍板：「炭之郎」） |

### 2. 风格（**强制对齐 ART_STYLE §1**）

- 风格：明亮扁平卡通风（Flat Bright Cartoon），暖色系
- 笔触：**无细描边**、**粗圆角几何**、**平涂色块** + 极少假阴影
- 五官：**极简**，silhouette 优先于细节
- 调色板（**必须命中**，含色值）：

  | 角色 | 色值 | 用途 |
  |---|---|---|
  | 奶油白 | `#FBF3E4` | 陶化左手 / 陶坯底色 / 衬布 |
  | 暖橙 | `#F0997B` | 玩家主色 / 围裙 / 薪斧木柄 |
  | 青绿 | `#5DCAA5` | 风箱 / 釉料装饰 / 增益点 |
  | 琥珀 | `#EF9F27` | 斧刃反光 / 围炉小灶光斑 |
  | 珊瑚红 | `#D85A30` | 斧刃高温区 / 危险提示小点 |
  | 深褐 | `#40332E` | 五官 / 线条 / 文字（仅最小量） |
  | **紫灰** `#7F77DD` | **禁用** | 这是敌人色，**不能出现在玩家立绘** |

- **禁用**：暗黑、写实、做旧、脏污、血迹、骷髅、地牢恐怖、英雄光晕

### 3. 技术规格

- **文件名**：`SPR_Player_Tannaro_Portrait.png`（炭之郎 = Tannaro）
- **路径**：`res://art/player/SPR_Player_Tannaro_Portrait.png`
- **画布**：**1024 × 1024 px**（手机端 720×1280 战斗 HUD 放大清晰，留剧情插画 / 商店介绍页放大余量，文件约 600KB~1MB）
- **背景**：**透明 PNG**
- **Pose**：Idle 站姿 / 半身（腰以上为主，斧头可露柄脚）/ 正面略偏 3/4 侧
- **朝向**：**面朝画面右侧**（与右手持斧的常见战斗朝向一致；也方便未来 hit/attack 帧延展）
- **朝向例外**：若 Art 认为 3/4 正面更有表现力，**需在交付报告中说明**

### 4. Godot 接入（建议项，**不**由 Art 改 .tscn）

- 导入设置沿用 ART_STYLE §11：Filter = **Linear**（矢量扁平风），Compress = **VRAM**
- 推荐透明 PNG 8-bit，无 mipmap 锯齿
- 战斗 HUD 展示位由 **UI Agent / Programmer** 在 `scenes/combat/` 接入（**非本任务范围**）

---

## Acceptance Criteria

- [ ] 文件存在，**1024×1024 透明 PNG**
- [ ] 角色 silhouette 在 **64×64 缩略图**下仍可识别为「持斧 / 抱风箱的暖色调人型」
- [ ] **左手半陶化效果**清晰可见（不能藏身后、不能只露手背）
- [ ] **薪斧 + 风箱**两件装备都**明确可辨识**（斧头形状、风箱折叠结构）
- [ ] 配色**完全落在** ART_STYLE §4 调色板内（无紫灰 / 非设定色）
- [ ] 与敌人紫灰 `#7F77DD` 明显区隔，**战斗画面中不混淆**
- [ ] 无禁用视觉元素（暗黑、写实、做旧等）
- [ ] 放入 Godot 后**无白边 / 无明显锯齿**
- [ ] 命名遵循 `SPR_Player_<角色名>_<用途>` 规范（ART_STYLE §10）
- [ ] 交付 `AI_STUDIO/Reports/ART_REPORT_001.md`，含原图预览链接 / 风格自检表

---

## Allowed Changes

- 新建 `art/player/SPR_Player_Tannaro_Portrait.png`
- Godot 自动生成的 `SPR_Player_Tannaro_Portrait.png.import`
- 新建 `AI_STUDIO/Reports/ART_REPORT_001.md`（交付报告）

## Forbidden Changes

- **禁止**改动 `art/player/SPR_Player_Warrior.png`（战斗小 sprite 走独立任务 TASK-002，避免耦合）
- **禁止** Art 改动 `AI_STUDIO/Design/` 下任何文档（人设改名已由 Producer 在 WORLD_SETTING §6.1 落实，Art 无需亦不得改文档）
- **禁止**改动 Programmer 脚本 / 场景
- **禁止**改变主角人设（性别 / 装备 / 半陶化锚点）
- **禁止**使用紫灰 `#7F77DD` 或任何非调色板色

---

## Dependencies

- 上游：ART_STYLE.md / WORLD_SETTING.md §6.1（炭之郎）已确认（✅）
- 下游：Programmer 接入战斗 HUD 玩家立绘展示位（**独立排期**）
- 并行：UI Agent 同步规划战斗 HUD 玩家立绘区域（**独立排期**）

---

## 交付清单

1. `art/player/SPR_Player_Tannaro_Portrait.png`（1024×1024 透明 PNG）
2. `AI_STUDIO/Reports/ART_REPORT_001.md`（含原图、风格自检、Godot 导入建议）

---

## 决策记录（吴总拍板，2026-08-20）

> 三项待确认已确认，美术按以下执行。

1. **画布尺寸**：✅ **1024 × 1024**（留放大余量，文件约 600KB~1MB）
2. **是否同步替换 `SPR_Player_Warrior.png`**：✅ **不替换**（拆独立任务 TASK-002 处理战斗小 sprite）
3. **主角名字**：
   - 初版用过「炭治郎（Tanjiro）」，但「炭治郎」为《鬼灭之刃》主角名，存在 IP 侵权隐患。
   - ✅ **最终定名「炭之郎（Tannaro）」**（2026-08-20 10:51 拍板）——原创名，规避 IP；已同步回写 WORLD_SETTING §6.1 标题与本文档全文。

---

## Image Prompt（Art 用 AI 生图时的统一约束，**输入**非产出）

```text
Asset Type:
  2D character portrait, half-body (waist up)
Style:
  flat bright cartoon, warm color palette, no outline, rounded geometric shapes,
  solid color blocks, minimal facial features
View:
  front-facing 3/4 angle, facing right
Resolution:
  1024x1024
Background:
  transparent
Palette (strict):
  cream white #FBF3E4, warm orange #F0997B, teal #5DCAA5,
  amber #EF9F27, coral red #D85A30, dark brown #40332E
Forbidden palette:
  purple-gray #7F77DD (enemy-only), any dark/gothic tone
Character:
  Tannaro (炭之郎), the last kiln apprentice, young artisan male
Equipment (both MUST be visible):
  - firewood axe in right hand (wooden handle warm orange, blade amber with coral-red hot edge)
  - bellows slung at waist or held in left hand (teal body, cream-white fold seams)
Key visual anchor ★:
  LEFT HAND half-glazed — from wrist to fingertips in cream-white #FBF3E4 ceramic texture,
  clearly visible, NOT hidden behind body
Mood:
  quiet, artisan, focused, no hero pose, no shouting, no epic aura
Pose:
  idle stance, weight on one leg, slight forward lean
Readability:
  clear silhouette recognizable as "axe-bearer in warm tones" even at 64x64
```

---

## 备注

- 本任务为 **Producer（小腾）** 下达，遵循 AGENTS.md §3 Producer / Designer / Art 分工。
- Art 完成后**不直接改代码**，交付 PNG + Report，由 Programmer 在独立排期接入战斗 HUD。
- 立绘（portrait）与战斗小 sprite（in-combat sprite）解耦：当前是前者，后者 `SPR_Player_Warrior.png` 保留待独立任务 TASK-002。
- 主角名「炭之郎（Tannaro）」由吴总 2026-08-20 拍板，同日本同步回写 WORLD_SETTING §6.1（属 Producer/Designer 上游更新，非 Art 职责）。前序曾用「炭治郎（Tanjiro）」因 IP 风险已弃用。
