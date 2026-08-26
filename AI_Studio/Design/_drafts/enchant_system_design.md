# 卡牌附魔（Enchantment）系统设计稿

> 项目：Godot 4.x 2D 卡牌爬塔 Roguelike（杀戮尖塔/StS1 风格）
> 职业：战士「炭之郎」（陶土 / 窑 / 火 / 灰 主题）· 手机端竖屏 720×1280 · 数据驱动（全部数值进 JSON）
> 参考模型：杀戮尖塔2 的"附魔 Enchantments"——独立、叠加于"升级 upgrade"之上的卡牌第二定制层，永久留存、进入长期牌组。

---

## 0. 设计锚点（已读取的基线数据）

| 维度 | 基线值 | 来源 |
|---|---|---|
| 玩家 max_hp | 80 | balance.json `player.max_hp` |
| 能量 / 回合 | 3 | balance.json `energy_per_turn` |
| 抽牌 / 回合 | 5 | balance.json `draw_per_turn` |
| 手牌上限 | 10 | balance.json `hand_max` |
| 单回合标准伤害 | 2 费 14–18；3 费 titan_strike=30 | cards.json heavy_slash/execute/titan_strike |
| 单回合格挡 | 1 费 defend=5；2 费 iron_wall=12 | cards.json |
| 治疗 | 单卡 6–9；余温炭每战 +6 | cards.json bandage/second_wind、relics.json emberheart |
| 升级幅度 | 一次性 +3~+10（劈薪 6→9 / 重劈 14→18 / 末薪 30→40） | cards.json `upgrade` 字段 |
| 敌人威胁 | 普通 9–28；精英 13–19；Boss 阶段2 大招 26 | enemies.json |
| 升级机制 | **覆盖式改写** `effects` 数组（非增量） | cards.json `upgrade.effects` |
| 窑温阈值 | 阈值 5，达阈值穿透伤害 5 | balance.json `kiln_temperature` |

**附魔数值铁律**：单次附魔的 +数值增益 ≤ 升级幅度的 60%。典型升级 delta=+3~+4，其 60%≈+1.8~+2.4 → **标准附魔取 +2 档**；仅高风险型允许 +3（对应末薪 +10 的 30%，但仍属"风险换收益"档）。所有附魔一律**加法**，不引入乘法/百分比类，规避与 `heat`/`temper` 等状态机制的叠加冲突。

---

## 1. 系统定位与获取

### 1.1 系统定位
附魔是**独立于"升级"的第二定制层**。升级改"卡牌本身的数值模板"（覆盖式），附魔改"该卡每次被打出时的附加修正/附加效果"。两者正交、互不替代、可并存。

### 1.2 与升级的关系（结论先行）
- 一张卡可同时处于「已升级 + 有附魔」状态。
- 已升级的卡**可以再附魔**。
- 附魔**进入长期牌组**，跨战斗永久保留（写进卡牌运行时数据 `enchants:[]`，见 §4）。
- 单卡**最多持有 1 个附魔**，`enchants` 数组内**禁止同 id 重复**；平衡上不允许一张卡叠多个附魔造成数值失控。

### 1.3 获取时机（推荐来源，按权重）
| 来源 | 形式 | 说明 | 建议权重 |
|---|---|---|---|
| **Boss / 精英战后奖励** | 在战利品界面新增「附魔」页签：从 3 选 1 的指派附魔里挑一个，应用到牌组中任意一张已拥有卡 | **主来源**。精英/Boss 战是强度跃迁点，配附魔符合 StS2 节奏 | 高（主） |
| **商店** | 付费附魔服务（建议价 75–120 金，对齐 balance `remove_card_cost=75` / `relic_cost=120` 区间） | 可控、可重复获取 | 中 |
| **休息点（营火）** | 在"锻造"之外新增"淬炼"选项：消耗休息机会为一张卡附魔（与升级二选一或并存） | 慢节奏强化，呼应"窑/淬火"主题 | 中 |
| **事件** | 特定陶瓷/窑主题事件给予附魔或附魔机会 | 调味来源 | 低 |
| 普通战后奖励 | 普通战斗**不**直接给附魔，仅精英/Boss/商店/事件给 | 控制附魔密度，避免前期过强 | — |

> 理由：附魔是永久滚雪球资源，若普通战斗也 3 选 1 附魔会过早膨胀；锚定"精英/Boss=质变点"发放，与 `enemy_scaling`/奖励结构一致。

### 1.4 存档承载要点
- 需在 `RunState` 的牌组记录中为每张卡保存 `{card_id, upgraded:bool, enchants:[id]}`。
- 附魔 id 引用 `data/enchants.json`，运行时只存 id 不存数值（数值以 JSON 为准，禁止硬编码）。
- 跨战斗、跨场景（商店/休息/事件）均需从 `RunState` 读取并回写，保证"永久留存到本局结束"。
- 存档结构需标注：**需存档承载**（本稿不展开 `RunState` 具体字段，仅声明承载需求）。

---

## 2. 附魔清单（10 种，覆盖全类型）

> 命名遵循 陶土/窑/火/灰 主题。
> 字段说明：
> - `restriction`：可选，限定该附魔能贴到哪些 `type` 的卡（attack/skill/power）。无则任意。
> - `mods`：叠加规则（见 §3）：`damage_bonus` / `block_bonus` / `aoe_damage_bonus` / `draw_bonus` / `heal_bonus` 为对基础值的加法修正；`extra_effects` 为打出时追加的效果（复用 `effect_kinds` 与状态 id）；`condition` 为触发前置条件。

### 2.1 窑淬 kiln_quench（common · 伤害增益）
- **描述**：打出的攻击牌伤害 +2。
- **effect**：
```json
{ "restriction": { "card_type": ["attack"] }, "mods": { "damage_bonus": 2 } }
```
- **依据**：升级典型 delta=+3~+4（劈薪 +3、重劈 +4），取 60% 下限 +2，不超升级幅度；重劈(18 升级后)+2=20，仍低于 3 费 titan_strike=30 的爆发基准，无溢出。

### 2.2 釉封 glaze_seal（common · 格挡增益）
- **描述**：打出的防御/技能牌获得格挡 +2。
- **effect**：
```json
{ "restriction": { "card_type": ["skill", "power"] }, "mods": { "block_bonus": 2 } }
```
- **依据**：护坯升级 +3（5→8），附魔取 +2（≈60%）；升级后护坯 8+2=10，对比 2 费 iron_wall=12 仍合理，未越级。

### 2.3 余烬 ember_return（common · 抽牌）
- **描述**：打出的牌额外抽 1 张。
- **effect**：
```json
{ "mods": { "extra_effects": [ { "kind": "draw", "value": 1 } ] } }
```
- **依据**：火钳刺/绕炉进阶均含"抽 1"，war_cry 抽 2~3；单卡附魔"打出的该牌每次+1 抽"为小幅，且受手牌上限 10 与抽牌 5/回合约束，不破坏牌序节奏。

### 2.4 风引 wind_lead（uncommon · 能量）
- **描述**：打出的牌获得 1 点能量（仅对费用 ≥1 的牌生效，防 0 费卡无限循环）。
- **effect**：
```json
{ "mods": { "extra_effects": [ { "kind": "energy", "value": 1 } ] }, "condition": { "min_cost": 1 } }
```
- **依据**：增焰(0 费)给 1 能量、遗物抽风口每战首回合 +1 能量为同类量级；限定 `min_cost:1` 是**关键防作弊**——避免给 0 费 charge 贴附魔后"打出净 +1 能量"无限续航。

### 2.5 炽痕 heat_trace（uncommon · 状态联动·自增益）
- **描述**：打出攻击牌后，自身获得 1 层炽热（heat）。
- **effect**：
```json
{ "restriction": { "card_type": ["attack"] }, "mods": { "extra_effects": [ { "kind": "gain_strength", "value": 1, "target": "self" } ] } }
```
- **依据**：守窑式给 +2 炽热（升级 +3）、炉怒 power +3；单卡每次攻击 +1 炽热为温和成长，类比"每次攻击"类 power，但仅作用于该附魔卡，强度可控。

### 2.6 釉裂 ember_craze（uncommon · 状态联动·敌减益）
- **描述**：打出攻击牌时，对目标敌人施加 1 层釉裂（crazed）。
- **effect**：
```json
{ "restriction": { "card_type": ["attack"] }, "mods": { "extra_effects": [ { "kind": "apply_status", "status": "crazed", "value": 1, "target": "enemy" } ] } }
```
- **依据**：敲釉基础施加 2 层釉裂（升级 3）、震窑/群釉咒 2~3 层；附魔 +1 层为小幅补充。釉裂使受伤 +50%，与现有控制体系协同但不溢出（一次仅 +1 层）。

### 2.7 回火 anneal_glow（common · 状态联动·自治疗）
- **描述**：打出防御牌时，自身获得 1 层回火（anneal，回合开始回血）。
- **effect**：
```json
{ "restriction": { "card_type": ["skill", "power"] }, "mods": { "extra_effects": [ { "kind": "apply_status", "status": "anneal", "value": 1, "target": "self" } ] } }
```
- **依据**：余温炭每战 +6 治疗为基准；回火每回合开始回 =层数 生命，附魔 +1 层≈每回合 +1 治疗，温和且契合"退火回复"主题。

### 2.8 窑温 kiln_warmth（uncommon · 窑温联动）
- **描述**：打出的牌积累 1 点窑温（kiln_heat）。
- **effect**：
```json
{ "mods": { "extra_effects": [ { "kind": "gain_kiln_heat", "value": 1 } ] } }
```
- **依据**：燃窑轰击积累 2~3 点、炽潮积累 1 点窑温；附魔 +1 助快速达阈值 5（balance `kiln_temperature.threshold`）触发穿透 5，属节奏加速而非数值膨胀。

### 2.9 灰蚀 ash_bite（rare · 高风险高回报）
- **描述**：攻击牌伤害 +3，但打出后自身获得 2 层灰蚀（ashrot，回合开始失血）。
- **effect**：
```json
{ "restriction": { "card_type": ["attack"] }, "mods": { "damage_bonus": 3, "extra_effects": [ { "kind": "apply_status", "status": "ashrot", "value": 2, "target": "self" } ] } }
```
- **依据**：升级一次性幅度上限 +10（末薪），附魔 +3 属风险档（≈重劈升级 +4 的 75%，但因带自伤故放行）；自伤 2 层灰蚀≈余温炭 +6 治疗的 1/3，风险可控。每次打出叠 2 层灰蚀，逼迫玩家控制该卡使用频率——典型"高回报换自损"。

### 2.10 塑形 temper_bind（uncommon · 状态联动·自增益）
- **描述**：打出获得格挡的牌时，自身获得 1 层塑形（temper）。
- **effect**：
```json
{ "restriction": { "card_type": ["skill", "power"] }, "mods": { "extra_effects": [ { "kind": "apply_status", "status": "temper", "value": 1, "target": "self" } ] } }
```
- **依据**：大匠之姿(warlord)给 +2 塑形、塑形使"获得格挡 +层数"；附魔 +1 层为温和成长，与格挡体系形成滚雪球但幅度小（单卡每次 +1）。

### 类型覆盖核对
| 类型 | 覆盖附魔 |
|---|---|
| 伤害增益 | 窑淬、灰蚀(风险型) |
| 格挡增益 | 釉封 |
| 抽牌/能量 | 余烬、风引 |
| 状态联动（敌减益） | 釉裂 |
| 状态联动（自增益） | 炽痕、回火、塑形 |
| 窑温联动 | 窑温 |
| 高风险高回报 | 灰蚀 |

---

## 3. 附魔与升级的叠加规则（结算管线）

**核心原则：先算升级（覆盖），再叠附魔（加法），最后结算状态/力量。全链路加法，无乘法类附魔。**

结算顺序（以一张卡被打出为例）：
1. **模板解析**：读取卡牌 `effects`；若 `upgraded==true`，用 `upgrade.effects` **整体覆盖**（沿用现有升级机制，覆盖式改写）。
2. **附魔修正（加法）**：对该卡 `enchants` 中每个附魔，按 `mods` 处理：
   - `damage_bonus` / `block_bonus` / `aoe_damage_bonus` / `draw_bonus` / `heal_bonus` **加**到对应 `kind` 效果的 `value` 上（每个 damage 效果各 +bonus，非只加一次）。
   - `extra_effects` 列表**追加**到本卡本次打出的效果序列末尾（复用 `effect_kinds` 与状态 id）。
   - `condition`（如 `min_cost:1`）不满足则跳过该附魔。
3. **状态/力量结算**：最终伤害 = (基础值 + 升级delta + 附魔bonus) 之后，再叠加 `heat` 炽热层数、`temper` 塑形层数、`strength` 等。即**附魔加法位于状态乘法/百分比之前**，确保附魔不放大状态收益，也不被状态放大——互不溢出。

**冲突说明**：
- **+数值 vs ×数值**：本设计**不引入任何乘法/百分比类附魔**（不存在 ×伤害、×格挡），因此与 `heat`(+层数伤害)/`temper`(+层数格挡) 的"类乘法"状态**无冲突**，全部为可预测加法。
- **同卡多附魔**：已规定单卡 ≤1 附魔、禁同 id，故不存在附魔间 delta 叠加失控。
- **与 upgrade 并存示例**：重劈(heavy_slash) 升级后 damage=18，贴「窑淬」→ 打出 18+2=20；再叠加 heat 3 层 → 20+3=23。全程加法，清晰可追溯。
- **灰蚀自伤叠加**：每次打出「灰蚀」附魔卡都追加 2 层 ashrot，属设计预期风险，不视为 bug。

---

## 4. 数据 Schema 草案

### 4.1 data/enchants.json（新增文件）
```json
{
  "version": 1,
  "enchants": [
    {
      "id": "kiln_quench",
      "name": "窑淬",
      "rarity": "common",
      "description": "打出的攻击牌伤害 +2。",
      "restriction": { "card_type": ["attack"] },
      "mods": { "damage_bonus": 2 }
    },
    {
      "id": "glaze_seal",
      "name": "釉封",
      "rarity": "common",
      "description": "打出的防御/技能牌获得格挡 +2。",
      "restriction": { "card_type": ["skill", "power"] },
      "mods": { "block_bonus": 2 }
    },
    {
      "id": "ember_return",
      "name": "余烬",
      "rarity": "common",
      "description": "打出的牌额外抽 1 张。",
      "mods": { "extra_effects": [ { "kind": "draw", "value": 1 } ] }
    },
    {
      "id": "wind_lead",
      "name": "风引",
      "rarity": "uncommon",
      "description": "打出的牌获得 1 点能量（仅费用≥1 的牌）。",
      "mods": { "extra_effects": [ { "kind": "energy", "value": 1 } ] },
      "condition": { "min_cost": 1 }
    },
    {
      "id": "heat_trace",
      "name": "炽痕",
      "rarity": "uncommon",
      "description": "打出攻击牌后，自身获得 1 层炽热。",
      "restriction": { "card_type": ["attack"] },
      "mods": { "extra_effects": [ { "kind": "gain_strength", "value": 1, "target": "self" } ] }
    },
    {
      "id": "ember_craze",
      "name": "釉裂",
      "rarity": "uncommon",
      "description": "打出攻击牌时，对目标敌人施加 1 层釉裂。",
      "restriction": { "card_type": ["attack"] },
      "mods": { "extra_effects": [ { "kind": "apply_status", "status": "crazed", "value": 1, "target": "enemy" } ] }
    },
    {
      "id": "anneal_glow",
      "name": "回火",
      "rarity": "common",
      "description": "打出防御牌时，自身获得 1 层回火。",
      "restriction": { "card_type": ["skill", "power"] },
      "mods": { "extra_effects": [ { "kind": "apply_status", "status": "anneal", "value": 1, "target": "self" } ] }
    },
    {
      "id": "kiln_warmth",
      "name": "窑温",
      "rarity": "uncommon",
      "description": "打出的牌积累 1 点窑温。",
      "mods": { "extra_effects": [ { "kind": "gain_kiln_heat", "value": 1 } ] }
    },
    {
      "id": "ash_bite",
      "name": "灰蚀",
      "rarity": "rare",
      "description": "攻击牌伤害 +3，但打出后自身获得 2 层灰蚀。",
      "restriction": { "card_type": ["attack"] },
      "mods": {
        "damage_bonus": 3,
        "extra_effects": [ { "kind": "apply_status", "status": "ashrot", "value": 2, "target": "self" } ]
      }
    },
    {
      "id": "temper_bind",
      "name": "塑形",
      "rarity": "uncommon",
      "description": "打出获得格挡的牌时，自身获得 1 层塑形。",
      "restriction": { "card_type": ["skill", "power"] },
      "mods": { "extra_effects": [ { "kind": "apply_status", "status": "temper", "value": 1, "target": "self" } ] }
    }
  ]
}
```

### 4.2 卡牌运行时数据如何挂附魔（RunState 内牌组条目）
```json
{
  "card_id": "heavy_slash",
  "upgraded": true,
  "enchants": ["kiln_quench"]
}
```
- `enchants` 为 id 数组，**实际运行约束为长度 ≤1、元素唯一**（策划层规定，实现层强制）。
- 数值一律从 `data/enchants.json` 按 id 查表，**禁止硬编码**到 GDScript。

---

## 5. 结论与落地检查清单
- [x] 附魔独立于升级、可并存、可后进、跨战斗永久保留（写 `enchants:[]`）。
- [x] 主来源 = 精英/Boss 战后附魔祭坛 + 商店 + 休息点淬炼；普通战不给。
- [x] 10 种附魔覆盖：伤害/格挡/抽牌能量/敌减益/自增益/窑温/风险型。
- [x] 数值全部锚定基线：标准 +2（升级 60%），风险型 +3（带自伤）；无乘法类。
- [x] 叠加规则：升级覆盖 → 附魔加法 → 状态/力量结算；加法优先于状态，无 ×类冲突。
- [x] 存档承载：`RunState` 牌组条目 `{card_id, upgraded, enchants:[id]}` 需持久化。
- [ ] 实现侧（GDScript）不在本稿范围；仅需确保结算管线与 `condition`/`restriction` 在出牌逻辑中生效。
