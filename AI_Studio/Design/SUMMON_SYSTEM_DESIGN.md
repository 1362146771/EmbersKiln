# 随从 / 召唤系统 设计稿（SUMMON_SYSTEM_DESIGN）

> 状态：`已 ratify v1` → **实现落地 + 闭环完成**（2026-08-24 吴总拍板：Q1/Q2/Q3 通过、随从寿命放宽 ≤5 回合、召主写入第 5 Build；2026-08-25 实现完成，SummonVerify 全 8 项通过、召主 build 接入 BalanceSweep）
> 配套：本稿 §9 全部数值登记于 `NUMERIC_LEDGER.md` 第 **F** 节（状态=「闭环完成」，2026-08-25）。
> 设计约束：所有数值来自 `data/*.json`；脚本不硬编码（见 `NUMERIC_CONVENTION.md`）。

---

## 0. 一句话定位

随从 = 战场上**临时存在的友方实体**：有独立 HP / 格挡 / 意图，占一个"召唤槽"，在战斗内按回合行动，战斗结束即清空。它和「状态 / 遗物 / 卡牌效果」的本质区别是——**它是一个会动、会挨打、会消失的单位**，而不是一层持续数值。

新增第 5 个 Build 方向「**召主 Summoner**」，与现有 速攻 / 防御 / 控场 / 燃烧 并列。

---

## 1. 为什么做（设计目标）

1. 给战士职业补一个"铺场 / 分担火力 / 持续输出"的玩法轴，丰富构筑维度。
2. 复用现有 `effects` 列表 + 敌人 `moves/ai` 数据模型，不另起炉灶——随从的意图系统直接复用敌人意图 schema。
3. v1 控制复杂度：**随从是战斗内临时单位**，不进卡组、不存档、不跨战斗携带（与 RunState 解耦，避免存档膨胀）。

---

## 2. 三个核心抉择（设计团队已定稿，待吴总 ratify）

| # | 抉择点 | 采用方案（推荐） | 否决方案 | 理由 |
|---|--------|------------------|----------|------|
| Q1 | **随从行动时机** | **玩家回合开始阶段**（抽牌之后、玩家出牌之前）插入 `Summon Phase` | 玩家结束回合后 / 敌人前 | 玩家在"自己回合"下令（出召唤卡），随从"下个自己回合开始"先动，符合"并肩作战先发制人"；且与 `蓄焰 stoke`（只作用于玩家下一张攻击牌）解耦清晰，给玩家预判空间。 |
| Q2 | **存续 / 死亡模型** | **有 HP + 寿命双约束；敌人单体 AI 不打随从，仅 AoE 可伤** | 纯寿命制（无 HP）/ 敌人主动锁定随从 | 敌人单体始终打玩家 → 不重写 `EnemySystem` 目标选择（v1 性价比最高）；AoE 敌人能清场 → 有博弈；寿命兜底 → 不无限铺场。最简洁可落地。 |
| Q3 | **上场上限** | **MAX_SUMMONS = 3**；满场时禁止再召唤并提示 | 超出则顶掉最旧 | 顶替会制造"意外弃子"困惑；满场禁止更直白，热区提示即可。 |

> 说明：Q2 的否决项"敌人主动锁定随从"列为 **v1 之后扩展**（见 §10），不做进 v1。

---

## 3. 随从生命周期

```
[召唤卡打出] → 随从入场（占一个召唤槽，初始化 HP/格挡/寿命/意图）
      ↓
[每个玩家回合开始 · Summon Phase]
   1. 存活随从按各自意图行动（attack / defend / buff）
   2. 随从身上 turn_start 状态结算（回火/灰蚀）
   3. 所有随从 寿命 -1；寿命 ≤ 0 → 消失（淡出）
   4. 随从自身格挡清空（扛过敌人回合后，下个 Summon Phase 前清空）
      ↓
[敌人回合] → 敌人行动；AoE 意图可伤随从；玩家受击
      ↓
随从 HP ≤ 0（被 AoE 打死）→ 消失
战斗结束 → 所有随从清空（不继承）
```

**关键边界**
- 随从**不受玩家格挡影响**、有**自己的格挡**，独立于玩家。
- 召唤卡在玩家回合打出 → 当回合不行动，下个 Summon Phase 首动（需要"一回合到场"，直觉自然）。
- 随从是战斗内临时单位：**不进 RunState.deck / relics，不写存档**。

---

## 4. 数据模型（草案 schema，待数值确认后落地 data/minions.json）

### 4.1 新增 `data/minions.json`
```json
{
  "version": 1,
  "minions": [
    {
      "id": "emberhound",
      "name": "窑犬",
      "hp": 10,
      "block": 0,
      "lifetime": 3,
      "tier": "summon",
      "ai": "fixed",
      "moves": [
        { "id": "bite", "intent": "attack", "value": 5, "chance": 1.0 }
      ],
      "sprite": "SPR_Minion_Emberhound"
    }
  ]
}
```
- `moves` 复用敌人意图 schema（`intent`: attack/defend/charge/buff；`value`；`chance`；`next` 等）。
- `ai: "fixed"` = 固定循环（v1 不引入加权随机，降低不确定性）；未来可加 `weighted_random`。
- `lifetime` = 以"玩家回合数"计，到 0 消失。

### 4.2 新增卡牌 effect kind：`summon`
在 `data/cards.json → effect_kinds` 追加 `"summon"`。卡牌 effects 写法：
```json
{ "kind": "summon", "minion_id": "emberhound", "count": 1 }
```
- `count` 默认 1；多体召唤（如"窑犬群"）= 2。
- 与现有 `exhaust` 字段兼容（一次性强力召唤可设 exhaust）。
- 召唤卡本身受 `cost` / `target` / `build` 约束，与现有卡牌同构。

### 4.3 新增玩家状态（可选增益）：`command`（指挥）
- `type`: buff；`stacks`: true；`decay`: false；`applies_to`: player
- 效果：你的随从攻击 / 获得格挡时 **+层数**（类 `heat`/`temper` 但作用于随从）。
- 让"召主"Build 有成长轴心（指挥号 +X → 全随从同步变强）。

---

## 5. 战斗循环集成（CombatSystem 改动点）

| 阶段 | 现有 | 新增 |
|------|------|------|
| 玩家回合开始 | 抽牌 → 能量恢复 | 抽牌 → **Summon Phase** → 能量恢复 → 玩家出牌 |
| Summon Phase | — | 随从行动 → turn_start 状态结算 → 寿命-1/到期消失 → 清随从格挡 |
| 敌人回合 | 敌人按意图行动 | 不变；AoE 意图命中随从（新增"随从也在可伤列表"） |
| 胜利 / 失败 | 敌全灭 / 玩家 HP≤0 | 不变（随从存活与否不影响胜负判定） |

- **目标选择**：敌人单体 attack 仍只打玩家（Q2）；`aoe_damage` 类意图需扩展到"玩家 + 所有随从"（按现有 AoE 逻辑遍历友方列表即可）。
- **StatusSystem 复用**：随从是"可中状态单位"，`heat/temper/crazed/damp/ashrot/anneal` 对其生效（与玩家/敌人同构）。`stoke`（蓄焰）**明确不作用于随从攻击**（只作用于玩家下一张攻击牌）。
- **VFXSystem**：随从攻击 / 受击 / 消失 复用现有轻量反馈（信息优先）。

---

## 6. UI（手机竖屏，强制遵循 GAME_SPEC UI 规范）

- 在**敌人区下方、玩家区上方**插入一条横向「**召唤栏**」带，高约 **140px @720 基准**，最多 3 个随从 chip。
- 每个随从 chip **≥ 80×80**（满足可点热区下限）：
  - 立绘缩略（占位文字图标，同药水/附魔占位风格）
  - HP 条（数值 ≥26px）
  - 格挡盾标
  - 意图图标（**友方底色，与敌人红/橙意图区分**——用蓝/青）
  - 寿命数字（剩余回合）
- 长按/点开：随从详情（数值 ≥26px）。
- 满场再召唤：按钮置灰 + Toast 提示"召唤栏已满（上限 3）"。
- 敌人意图区不变；随从意图用不同底色，避免与敌人意图混淆。

### 6.1 登场 / 行动 遮挡与亮度机制（吴总 2026-08-24 指定）

随从 chip 的**层级（z-index）与亮度**随战斗阶段变化，制造"它在场但平时退居玩家身后、行动时冲到前面"的视觉叙事：

1. **登场瞬间**：高亮（白光 flash + scale 轻微放大 ~1.15）→ 持续约 0.4s。
2. **登场后常态（暗态）**：亮度回落，alpha ≈ 0.6（半透明暗态）；chip 的 **z-index 低于玩家立绘**，被玩家立绘**遮挡一部分**（关键信息 HP 条 / 意图仍露出）。
3. **轮到该随从行动（Summon Phase 命中它）**：亮度提至全亮（alpha 1.0）+ 轻微前移/放大；**z-index 提升到玩家立绘之上**，临时盖在玩家上方，表示"它现在行动"。
4. **该随从行动结束**（攻击/防御结算完）：亮度回落、z-index 降回玩家之下，**恢复被遮挡状态**。
5. **消失 / 战斗结束**：淡出（modulate→透明 + 缩放到 0）。

> 实现要点：随从 chip 是 `Control` 节点，`z_index` 切换 + `modulate.a` 渐变用 `Tween`；玩家立绘为固定 z 基准。常态随从层 < 玩家层 < 行动态随从层。该机制纯表现层，不影响战斗数值/顺序。

---

## 7. 内容草案（Build：召主 Summoner，已写入 GAME_SPEC / GAMEPLAY_DESIGN 第 5 Build）

> 以下数值为**草案值**，全部登记于 `NUMERIC_LEDGER.md` **F** 节（状态=「闭环完成」，2026-08-25 实现落地 + 验证通过）。

### 7.1 随从（minions.json）
| id | 名 | HP | 起始格挡 | 寿命 | 意图 | 定位 |
|----|----|----|---------|------|------|------|
| emberhound | 窑犬 | 10 | 0 | 3 | attack 5 | 廉价铺场 / 稳定输出 |
| glazeward | 釉卫 | 14 | 5 | 3 | defend self 5（或给玩家 block 4） | 抗线 / 分摊 |
| spark | 火灵 | 6 | 0 | 2 | attack 4 | 短命高性价比 |

### 7.2 卡牌（cards.json，build 含 summoner）
| id | 名 | 费用 | 效果 | 稀有度 |
|----|----|------|------|--------|
| summon_hound | 召窑犬 | 1 | summon emberhound ×1 | common |
| hound_pack | 窑犬群 | 2 | summon emberhound ×2 | uncommon |
| glaze_ward | 釉卫结界 | 1 | summon glazeward ×1 | common |
| command_horn | 指挥号 | 1 | apply_status command self 2 | uncommon |
| spark_call | 引火 | 0 | summon spark ×1 | common（低费铺场） |

### 7.3 遗物候选（RelicSystem 战斗开始触发，复用入场效果）
| id | 名 | 效果 |
|----|----|------|
| kilnmark | 窑主印记 | 战斗开始 summon emberhound ×1 |

---

## 8. 平衡护栏（硬红线，设计层）

1. **上场上限 3**（SM-01）—— 防无限铺场。
2. **寿命 2~5 回合（默认 3，上限 5，SM-02）** —— 临时单位，不滚雪球（吴总 2026-08-24 拍板：寿命放宽至 ≤5 回合）。
3. **随从单次攻击 ≤ 7**（SM-03）—— 不超过玩家同类直伤（strike 6 / 升级 9），避免随从碾压卡牌价值。
4. **召唤卡费用与直伤卡对齐**：cost 1 ≈ 5~6 伤的随从（SM-08），不白送。
5. **AoE 敌人是天然 counter**：多随从铺场会被 `aoe_damage` 敌人一波清，构成博弈（Q2 设计意图）。

---

## 9. 数值台账索引（全部「闭环完成」，2026-08-25 实现落地 + 验证通过）

见 `NUMERIC_LEDGER.md` **第 F 节**：SM-01 ~ SM-09。
实现落地时写入 `data/minions.json` / `data/cards.json`(summon kind) / `data/statuses.json`(command) / `data/balance.json`(summon.*) / `data/relics.json`(kilnmark)。

---

## 10. Out of Scope（v1 不做）

- 敌人主动锁定 / 攻击随从（Q2 否决项的"完全体"，列为后续扩展）。
- 随从升级 / 随从专属遗物 / 随从跨战斗携带。
- 随从合成 / 进化 / 融合。
- 随从的稀有度抽取池（v1 随从由卡牌直接召唤，不走奖励三选一）。

---

## 11. 落地步骤（已全部实现，2026-08-25 闭环完成）

1. ✅ 数值确认 → 写 `data/minions.json` + `cards.json` 加 `summon` kind + `statuses.json` 加 `command` + `balance.json` 加随从上限。
2. ✅ `GameData` 加载 minions；`CombatController` 加 `SummonPhase` + 友方列表 + AoE 扩面。
3. ✅ `StatusSystem` 支持随从为 status 宿主（ally_status_applied 信号）。
4. ✅ `CombatUI` 加随从 chip + §6.1 遮挡/亮度动画 + 满场提示横幅。
5. ✅ `run_and_verify` 出 `SummonVerify` 套件（数据加载 / 召唤 / 行动 / 寿命到期 / AoE 清场 / 满场拒绝 / 指挥加成 / 召主 build，全 8 项通过）。
6. ✅ BalanceSweep 加「召主」build（接入完成；全量模拟因耗时未单次跑完，build 配置与 6 张卡均经 SummonVerify 校验通过）。

---

## 12. 与吴总的对齐点（已 ratify，2026-08-24）

- [x] Q1 行动时机（玩家回合开始）✅ 吴总认可。
- [x] Q2 存续模型（有HP+寿命，敌人不打随从）✅ 吴总认可。
- [x] Q3 上限 3 + 满场拒绝 ✅ 吴总认可。
- [x] §7 / §8 草案数值（随从攻击≤7、召唤卡费用等）✅ 按提议值落地；**寿命放宽至 ≤5 回合**（SM-02）。
- [x] 「召主」作为第 5 个正式 Build 写入 `GAME_SPEC` / `GAMEPLAY_DESIGN` ✅。
- [x] UI 遮挡/亮度机制（§6.1）✅ 吴总指定，已采纳。
- [x] 同意转 Programmer 排期实现（§11 步骤 + `SummonVerify` 套件）。

> 已回填：`GAME_SPEC` Build 列表 + `GAMEPLAY_DESIGN` §8；F 节数值置「闭环完成」（2026-08-25 实现落地 + SummonVerify 全 8 项通过 + 召主 build 接入 BalanceSweep）。
