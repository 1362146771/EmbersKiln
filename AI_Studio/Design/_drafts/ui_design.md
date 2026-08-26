# UI 设计方案（药水系统 / 附魔系统）

> 作者：主设计师（整合团队产出）· 状态：UI 草案 v1
> 依据：`CombatUI.gd` / `ShopUI.gd` 实读布局、`GAME_SPEC.md` UI 规范（L36-46）、`art/icons/*` 现有资产体系
> 关联草稿：`potion_system_design.md` / `enchant_system_design.md` / `balance_review.md`

---

## 0. 现状盘点（先说清家底，避免凭空设计）

| 模块 | 现状 | 对 UI 的影响 |
|---|---|---|
| 战斗界面 | `CombatUI.gd` 已实现。竖屏 VBox：`enemy_area`（顶）→ `log_panel` → `hand_area`（能量条+手牌 ScrollContainer）→ `bottom`（HBox：左 `player_panel` + 右 `end_turn_btn`） | 药水槽有现成嵌入点 |
| 商店界面 | `ShopUI.gd` 已实现（买卡/买遗物/移除），但 **`scenes/map/` 无 `Shop.tscn`**，地图流程未挂接 | 需先补场景挂接，再加药水/附魔货架 |
| 图标资产 | `art/icons/status/ICO_Status_*`(9) / `art/icons/relic/ICO_Relic_*`(10) 存在 | 复用同风格、同路径规律新增 potion/enchant |
| 配色 | `ShopUI.gd` 顶部 `CREAM/ORANGE/RED/AMBER/PURPLE/GREEN/DARK/BG_DARK` | 新 UI 必须复用此色板 |
| UI 规范 | `GAME_SPEC` L36-46：720×1280 竖屏、正文≥20px、重要≥26px、热区≥64×64、容器自适应 | 所有新增 UI 强制合规 |

> 结论：**之前三份草稿只做了系统+数值，UI 完全空缺**。本文件补齐。

---

## 1. 图标风格规范（战斗/商店/卡面统一）

**风格**：沿用现有 `ICO_Status_*` / `ICO_Relic_*` 的**扁平卡通图标**风格（陶土/窑/火主题，暖色描边、无写实光影）。

**路径与命名**（严格对齐现有规律）：
- 药水：`art/icons/potion/ICO_Potion_<Name>.png`（如 `ICO_Potion_AshSalve.png`）
- 附魔：`art/icons/enchant/ICO_Enchant_<Name>.png`（如 `ICO_Enchant_KilnTemper.png`）；多数附魔优先用**卡面角标**（见 §4），仅少数核心附魔产独立图标。

**规格**：
- 透明 PNG，沿用现有 `ICO_*` 同尺寸（建议 128×128 设计、256×256 交付，圆角/无边框，96×96 安全区）。
- 配色复用 UI 色板：底色陶土棕 `DARK`、主色暖橙 `ORANGE`/红 `RED`、点缀琥珀 `AMBER`；**稀有度色框**：common=灰白 `CREAM`、uncommon=绿 `GREEN`、rare=琥珀 `AMBER`（或紫 `PURPLE`）。
- 命名 `snake_case` 与数据 `id` 一致。
- 交付清单：13 瓶药水各 1 图标；附魔约 10 种按需产（角标为主、图标为辅）。

> 战斗内药水槽直接引用 `ICO_Potion_X`；商店货架同；卡面附魔用 `ICO_Enchant_X` 或纯文字角标。

---

## 2. 战斗界面：药水槽位置

**嵌入点**：在 `CombatUI.gd` 的 `bottom`（HBoxContainer）中，于 `end_turn_btn` **左侧**新增 `potion_bar`（HBoxContainer，容纳 3 格）。

**布局**：
```
[ 玩家面板 | 药水槽① ② ③ | 结束回合 ]
```
- 每格：圆形/方槽，**尺寸 ≥72×72**（满足热区 ≥64×64），显示 `ICO_Potion_X` + 名称 tooltip；空格显示"空陶瓮"轮廓。
- 竖屏右手握持时，药水槽紧邻结束回合按钮，拇指可达，符合"战中应急、不耗能量"的定位。

**交互**：
- 点击槽 → 立即生效（Free Action，不耗能量/回合）→ 从槽移除（exhaust）→ 效果经现有机制呈现：
  - 即时型（heal/block/dmg/draw/energy/aoe）：直接结算，无残留。
  - 持续型（stoke/anneal/glaze 等）：施加状态，在现有 `player_status` / `enemy_status` 区显示。

**互斥规则（§药水稿1.5）的 UI 体现**：
- 逻辑层已处理（喝新持续型清旧状态）。UI 上无需额外"生效中"指示——玩家在 `player_status` 区看到 stoke 被 temper 顶掉，状态区自然刷新即足够。药水槽只反映"携带/未用"，使用后即空。

**合规**：热区≥64×64✓、竖屏单列✓、容器自适应（不写死坐标）✓。

---

## 3. 商店界面：药水 / 附魔展示

> 前置：先补 `scenes/map/Shop.tscn` 并把 `ShopUI` 实例挂入地图流程（目前脚本孤立）。

**3.1 药水货架（仿现有 `_relic_offer`）**
- `_generate_stock()` 增加 `potion_stock`：从 `data/potions.json` 随机取 N 瓶（建议 2~3），价格取 `balance.shop.potion_cost`（建议 `[35, 55, 75]`，低于永久卡，因药水为消耗品）。
- `_build_main()` 的 VBox 中，在"遗物"货架后加"药水"标签 + 横向 `ScrollContainer` + 每瓶 `_potion_offer`（结构仿 `_card_offer` 的 180×250 盒，但更紧凑）：`ICO_Potion_X` 图标 + 名称 + 稀有度色框 + 价格按钮（买后 disable）。

**3.2 附魔在商店（非消耗品，不走货架）**
- 附魔是**卡牌永久强化**，不是一瓶瓶卖的消耗品。两种落地方式二选一：
  - **方案 A（商店内"附魔服务"）**：商店新增一个高价按钮"为一张卡附魔（X 金）"，弹窗列出可选附魔（`ICO_Enchant_X` + 名 + 效果 + 价），玩家选己方一张卡 + 一个附魔，立即永久生效。价格 ≥ 稀有卡价 100（呼应平衡红线"附魔永久，频率须低于药水"）。
  - **方案 B（独立附魔祭坛节点）**：地图新增"附魔祭坛"节点，每幕 ≤1 次（全局 ≤3），UI 同方案 A 弹窗，但免费/低价换取"限次"控制。
- 推荐 **方案 B**（祭坛），因附魔永久，用"限次节点"比"商店金币"更易锁死频率（见平衡红线 §5）。

---

## 4. 卡面附魔标记（附魔不在战斗界面单独显示）

**关键澄清**：药水与附魔显示位置完全不同——
- **药水** → 战斗界面底部 `potion_bar` 药水槽（§2）。
- **附魔** → 不在战斗界面单开 UI，而是**印在卡牌卡面上**（附魔是卡牌永久属性）。

**卡面附魔徽章**：
- 位置：卡名下方 / 右下角，加"附魔角标" = `ICO_Enchant_X`（或纯文字）+ 附魔名 + 稀有度色框。
- 复用：HandUI（手牌渲染）、RewardUI（奖励三选一）、DeckView（牌组查看）共用同一卡面组件，均需显示附魔角标。
- 多数附魔用**文字角标 + 色框**即可（美术成本低），仅核心/高稀有附魔产 `ICO_Enchant_X` 图标。

> 视觉上：战斗中药水槽（底部）与卡面附魔（卡牌上）互不干扰，玩家一眼能区分"这瓶药水"和"这张卡被附魔了"。

---

## 5. 合规检查（对照 GAME_SPEC L36-46）

| 项 | 要求 | 本方案 |
|---|---|---|
| 基准分辨率 | 720×1280 竖屏 | ✓ 全部容器锚点自适应 |
| 最小字号 | 正文≥20 / 重要≥26 | ✓ 药水名/价≥20，稀有度/状态≥26 |
| 最小热区 | ≥64×64（优先80） | ✓ 药水槽 ≥72×72 |
| 卡面宽 | ≥120 | ✓ 沿用现有卡牌组件 |
| 自适应 | 不写死像素 | ✓ 全用 Container/Anchor |
| 数据驱动 | 数值/路径/配色 JSON 化 | ✓ 图标路径、价格、稀有度色全部进 JSON，不硬编码 |

---

## 6. 落地备注（供程序/美术）

1. **美术**：产 `art/icons/potion/*`（13）、`art/icons/enchant/*`（按需）；沿用 `ICO_*` 扁平卡通 + UI 色板。
2. **程序（战斗）**：`CombatUI._build_main` 的 `bottom` 加 `potion_bar`；新增 `PotionBar.gd` 管理 3 槽点击→生效→exhaust；复用 `CombatController` 的 `effects` 执行。
3. **程序（商店）**：补 `Shop.tscn` 挂接；`ShopUI` 加 `potion_stock` + `_potion_offer`；附魔走祭坛节点（方案 B）或商店服务（方案 A）。
4. **程序（卡面）**：卡牌组件加附魔角标渲染，HandUI/RewardUI/DeckView 同步。
5. **台账**：药水价、附魔价/限次、图标规格须登记 `NUMERIC_LEDGER.md`。
6. **未实现**：本文件仅设计+标注，不含 GDScript/美术资源（按任务要求）。
