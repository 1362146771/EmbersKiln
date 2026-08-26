# 药水系统（Potions）设计稿

> 项目：Godot 4.x 2D 卡牌爬塔 Roguelike（杀戮尖塔风格）· 单职业战士「炭之郎」
> 主题：陶土 / 窑 / 火 / 灰 · 手机竖屏 720×1280 · 数据驱动（全部数值进 `data/potions.json`）
> 作者：游戏策划（系统/内容方向）· 状态：设计草案 v1
> 关联基线文件：`balance.json` / `cards.json` / `statuses.json` / `relics.json` / `enemies.json`

---

## 0. 设计原则与锚定口径

所有药水数值一律**对照下方基线保守取值**，**绝不超过**同功能卡牌/遗物在「同成本」下的数值；药水是**一次性、不占能量、不占手牌**的消耗品，因此单瓶可略高于某张 1~2 费卡，但不得超过该卡牌中**最高费**（3 费）的爆发值，更不得让已有核心遗物（余温炭 / 末薪 / 不裂 / 余烬之心等）显著贬值。

**核心基线（务必锚定）**
- 玩家：`max_hp=80`，能量 3/回合，抽 5/回合，手牌上限 10，格挡下回合清空。
- 伤害：1 费劈薪 6、火钳刺 7；2 费重劈 14、execute 18；3 费 titan_strike 30。
- 格挡：1 费护坯 5、挡钳 8；2 费窑壁 12、不裂 20（消耗）；3 费末薪 30/40（消耗）。
- 治疗：补釉 6~9（1 费卡）、余温炭每战 +6（遗物）、休息 30%≈24。
- 状态基准：受潮(damp) -25% 攻击、釉裂(crazed) 受伤 +50%、灰蚀(ashrot) 回合开始掉血并递减、塑形(temper)=格挡+层数、炽热(heat)=攻击+层数、蓄焰(stoke)=下张攻击+X。
- 敌人威胁：普通 9~28（多段 8×3/9×2/10×2/11×2）；精英 13~19；Boss 二阶段 charge 大招 26、三阶段 AOE。
- 战斗节奏：普通 3~5 回合、精英 5~8、Boss 8~12。

**效果原子复用**：药水 `effects` 严格只用 `cards.json` 顶层 `effect_kinds` 中的原子（`damage / aoe_damage / block / draw / energy / heal / gain_strength / gain_dexterity / apply_status / exhaust / power_* / gain_kiln_heat`），不新增引擎概念。

---

## 1. 系统总览

### 1.1 药水如何获取（出现权重建议）

| 途径 | 建议权重 | 说明与数值 |
|---|---|---|
| 战斗奖励（随机掉落） | **45** | 普通/精英/Boss 战后按概率在奖励中出现 1 瓶（不与其他卡牌奖励互斥）。掉落触发概率建议：普通 25%、精英 40%、Boss 必给。理由：战斗是地图主循环，权重最高保证"每几场必见一瓶"，但低于 50% 避免药水泛滥压低卡牌价值。 |
| 宝箱（Chest） | **25** | 开箱时 100% 获得 1 瓶（或从 2~3 瓶中三选一）。理由：宝箱本就是"确定性补给"节点，权重次之。 |
| 商店（Shop） | **20** | 每间商店固定上架 1~2 瓶，售价建议 35~75 金（锚定 `balance.shop.card_cost` 50/75/100 的下沿，药水为消耗品应显著低于永久卡）。理由：给"金币富余"的 build 一条明确消费线，权重控在 20 防止商店被药水刷屏。 |
| 事件（Event） | **10** | 部分事件提供"喝下/赠予/合成"药水的分支选项。理由：事件偶发，权重最低，做调味而非主来源。 |

> 生成时**瓶内稀有度**沿用 `balance.card_pool_weights` 口径：`common 0.55 / uncommon 0.33 / rare 0.12`（药水比卡牌略偏稀有，因一次性消耗品应更"金贵"）。此分布需登记台账。

### 1.2 携带上限：建议 **3 格**

- 竖屏 720×1280 下，底部/侧栏放 3 个圆形药水槽在视觉与点击热区上都充裕（StS1 同为 3）。
- 2 格会过度压缩"囤货博弈"（留一瓶等 Boss 还是现在用），3 格给玩家"存一瓶应急"的决策空间，又不至于像 4+ 格那样让补给溢出、削弱战斗张力。
- 备选（更硬核）：若觉得前期过强，可降到 **2 格**并观察首测数据；本文按 3 格设计，所有数值已按"3 格上限"保守标定。

### 1.3 使用时机与规则

1. **仅可在战斗中**使用（与 StS1 一致，保留地图层的资源张力；不建议开放地图/休息点使用，避免药水替代休息）。
2. **不消耗回合行动（Free Action）**：不打断出牌序列、不结束回合、不触发"空过=焦渴"惩罚（因为药水本身不是"打出攻击牌"行为，焦渴仍由是否打出攻击牌判定，药水不豁免焦渴——见下方冲突说明）。
3. **不消耗能量**：`cost` 恒为 0，使用时只校验携带格与目标合法性。
4. **使用后消耗（exhaust=true）**：从携带格移除，不可回收。
5. **使用时机**：可在我方出牌阶段任意时刻、甚至敌方 intent 已亮出后使用（例如看到 Boss charge 26 再喝格挡瓶），这正是不占能量的价值所在。

### 1.4 与现有遗物 / 卡牌的冲突规避（重点）

| 相关项 | 风险 | 本文对策 |
|---|---|---|
| 补釉（bandage，1 费，heal 6/9，每战可重复） | 治疗瓶若过高会贬低补釉 | 治疗瓶**单次最高 18**，且为一次性 vs 补釉每战可打，定位不同；不设计 >20 的治疗瓶（休息 24 是地图层恢复，不冲突）。 |
| 余温炭（emberheart，每战 +6） | 战斗内治疗瓶与之重叠 | 余温炭是**战后**被动；药水是**战中**主动，互补不替代。 |
| 末薪（last_stand，2 费，block 30/40，消耗） | 格挡瓶若接近 30 会贬值末薪 | 本文**最高格挡瓶仅 12**（=2 费窑壁），远低于末薪 30，末薪仍是无可替代的"救命大墙"。 |
| 不裂（unbreakable，2 费，block 20/26，消耗） | 格挡瓶若 =20 会等值替代 | 格挡瓶封顶 12，明确低于不裂 20，避免贬值。 |
| 余烬之心（draft_flue，首回合 +1 能量） | +2 能量瓶会贬低 | +2 能量瓶仅作 **rare 极限翻盘**设计，且为一次性；+1 能量瓶（common）数值等同于 draft_flue 但限定任意回合，二者并存不矛盾。 |
| 焦渴（thirst，空过 -1 能量） | 担心用药水"刷"豁免 | 药水不计入"打出攻击牌"，因此**喝能量/抽牌瓶不会解除焦渴惩罚**，仅真正打出攻击牌才能豁免，规则一致。 |
| 蓄焰（stoke，strike/bash 自带） | 蓄焰瓶叠加过强 | 蓄焰瓶只给 **+3 层**，且 stoke 每用一张攻击牌 -1，天然自限，不会超过一回合一张攻击的收益。 |

### 1.5 使用互斥规则（策划硬性规定，2026-08-20 补充）

> 目的：防止状态类/持续类药水叠加滚雪球，进一步锁死数值红线中的“叠加/频率”风险。**即时型药水（结算即消散：heal / block / damage / draw / energy / aoe_damage）不受本规则影响**——它们喝完即结算，无残留、无“同时生效”概念。

1. **同类型药水不重复生效**：对【持续型】药水（即 `effects` 含 `apply_status` 给自身/敌人、或施加 `stoke / anneal / glaze / temper / heat` 等持续状态者），若目标已带有该药水所施加的**同一种状态**（无论层数来自卡牌/遗物/其他药水），再次饮用同类药水 **不叠加层数、不刷新持续时间**。
   - 实现建议：药水施加的状态以来源标记 `potion`；目标已有该 `potion` 来源状态则跳过施加（或取 `max(现有, 新)`，默认不叠加）。
   - 例：已喝 `釉裂粉 craze_dust`（敌 2 层 crazed），再喝一瓶 `釉裂粉` → 敌仍为 2 层，不叠到 4 层。
2. **同时仅一瓶持续效果生效（全局唯一）**：玩家同一时刻至多由【一瓶】持续型药水提供残留效果。喝下新的持续型药水时，先清除上一瓶药水施加的所有残留状态，再施加本次效果（新的顶旧的）。
   - 例：先喝 `蓄焰酒 stoke_brew`（自身 stoke 3），未消费前再喝 `塑形膏 temper_paste`（自身 temper 2）→ 清除 stoke，仅留 temper 2。
   - 规则 1 与规则 2 互补：同类型靠规则 1 不动，异类型靠规则 2 互斥。

> 这两条规则将状态/持续类药水的实战价值严格限制为“单瓶窗口”，无法靠囤多瓶同类或异类叠加突破红线，与 §4 数值红线一致；也呼应 `crazed` 经引擎实测为固定 ×1.5（层数仅续时）的口径——即便同类型被误叠加，倍率也不会随层数放大。

**结论**：补齐药水系统后，玩家获得 StS1 级别的"战中应急资源层"，提升单场决策深度与翻盘爽点，同时通过上述封顶规则**不侵蚀**现有卡牌/遗物的核心地位。

---

## 2. 药水清单（12 种，陶土/窑/火/灰主题）

> 命名与主题映射：窑火/灰烬=火与燃烧；陶瓮/陶釉/陶土=陶艺；湿泥/窑壁=土与防护；蓄焰/余温=温度。

### 2.1 治疗类

#### P01 · 灰烬膏 `ash_salve`
- **rarity**：common · **target**：self · **exhaust**：true
- **effect**：`[{"kind":"heal","value":12}]`
- **description**：恢复 12 点生命。
- **依据**：单卡补釉 6~9（耗 1 费），本瓶免能量一次性；取 12 高于补釉上限但低于休息 24，且补釉可每战复用，定位不冲突。

#### P02 · 余温瓶 `warmth_vial`
- **rarity**：uncommon · **target**：self · **exhaust**：true
- **effect**：`[{"kind":"heal","value":14},{"kind":"apply_status","status":"anneal","target":"self","value":2}]`
- **description**：恢复 14 点生命，并获得 2 层回火（回合开始回血后递减）。
- **依据**：治疗主值 14 锚定"略高于灰烬膏、仍远低于休息 24"；附加 2 层回火（状态基准 `anneal` 每回合回血=层数后 -1，约再回 2+1=3）做差异化，总回血量 ≈17，仍 < 休息，安全。

### 2.2 格挡类

#### P03 · 窑壁釉 `kiln_plaster`
- **rarity**：common · **target**：self · **exhaust**：true
- **effect**：`[{"kind":"block","value":12}]`
- **description**：获得 12 点格挡。
- **依据**：等于 2 费卡窑壁（12）的免能量版；明确低于不裂 20 / 末薪 30，不贬值二者。格挡下回合清空，现值仅作用于当前战斗节奏。

### 2.3 能量 / 抽牌类

#### P04 · 引火油 `tinder_oil`
- **rarity**：common · **target**：self · **exhaust**：true
- **effect**：`[{"kind":"energy","value":1}]`
- **description**：获得 1 点能量。
- **依据**：等于遗物 draft_flue 首回合 +1，但可在**任意回合**触发；封顶 1 点避免破坏 3 能量经济（一回合 4 能量仅等于多打一张 1 费牌）。

#### P05 · 醒神陶土 `waking_clay`
- **rarity**：common · **target**：self · **exhaust**：true
- **effect**：`[{"kind":"draw","value":2}]`
- **description**：抽 2 张牌。
- **依据**：等于 2 费卡 war_cry（抽 2）的免费用版；锚定"手牌上限 10"不会溢出风险，且一次性。

#### P06 · 余烬之心 `ember_heart`
- **rarity**：rare · **target**：self · **exhaust**：true
- **effect**：`[{"kind":"energy","value":2}]`
- **description**：获得 2 点能量。
- **依据**：仅 rare 出，作为极限翻盘（如空过回合后补 2 能量打出 titan_strike 30）；上限 2 点（对照基线"能量 1~2"），仍低于"一回合白嫖 3 费爆发"的破坏阈值，因仅一次且需先囤到 rare 瓶。

### 2.4 伤害类

#### P07 · 窑火油 `kiln_fire_oil`
- **rarity**：uncommon · **target**：all_enemies · **exhaust**：true
- **effect**：`[{"kind":"aoe_damage","value":8}]`
- **description**：对所有敌人造成 8 点伤害。
- **依据**：等于 1 费卡扫炭（aoe 8）的免费用版；AOE 上限 8 低于焚原 11（3 费）、火暴 14（3 费），安全。

#### P08 · 巨窑圣油 `titan_anoint`
- **rarity**：rare · **target**：enemy · **exhaust**：true
- **effect**：`[{"kind":"damage","value":18}]`
- **description**：造成 18 点伤害。
- **依据**：等于 2 费卡 execute（18）免费用版；封顶 18 低于 3 费 titan_strike 30，rare 一次性爆发合理，不替代核心大招。

### 2.5 状态类（给敌人施加 debuff）

#### P09 · 湿泥弹 `mud_bolt`
- **rarity**：common · **target**：all_enemies · **exhaust**：true
- **effect**：`[{"kind":"apply_status","status":"damp","target":"all_enemies","value":2}]`
- **description**：对所有敌人施加 2 层受潮（攻击 -25%）。
- **依据**：等于 1 费卡引火（damp 2 全体）免费用版；damp 按回合衰减 1，2 层仅压制 2 回合，不超基准。

#### P10 · 釉裂粉 `craze_dust`
- **rarity**：common · **target**：enemy · **exhaust**：true
- **effect**：`[{"kind":"apply_status","status":"crazed","target":"enemy","value":2}]`
- **description**：对目标敌人施加 2 层釉裂（受伤 +50%）。
- **依据**：等于 2 费卡敲釉（crazed 2 单体）免费用版；crazed 衰减 1/回合，2 层窗口短，安全。

#### P11 · 灰蚀瓶 `ashrot_vial`
- **rarity**：uncommon · **target**：all_enemies · **exhaust**：true
- **effect**：`[{"kind":"apply_status","status":"ashrot","target":"all_enemies","value":2}]`
- **description**：对所有敌人施加 2 层灰蚀（回合开始掉血后递减）。
- **依据**：灰蚀是强 DOT（每层回合开始掉血=层数），2 层全体 ≈ 总 2+1=3 点/敌，低于灰颂者/釉蛭单次施放（ashrot 2 单体），且全体压制在 rare 以下，平衡。

### 2.6 特殊类（强化"下一张/本场"）

#### P12 · 蓄焰酒 `stoke_brew`
- **rarity**：uncommon · **target**：self · **exhaust**：true
- **effect**：`[{"kind":"apply_status","status":"stoke","target":"self","value":3}]`
- **description**：获得 3 层蓄焰（你的下一张攻击牌伤害 +3，出手后 -1 层）。
- **依据**：复用 `stoke` 状态（strike/bash 自带 1 层）；+3 让下一张攻击（如 titan 30→33 或重劈 14→17）小幅增伤，因 stoke 每攻击 -1 天然自限，不会滚雪球。

#### P13 · 塑形膏 `temper_paste`（备选第 12~13 瓶，满足"本场获得塑形"特殊型）
- **rarity**：uncommon · **target**：self · **exhaust**：true
- **effect**：`[{"kind":"gain_dexterity","value":2}]`
- **description**：获得 2 层塑形（此后获得格挡时额外 +2）。
- **依据**：复用 `gain_dexterity`（=塑形 temper，warlord rare 给 +2）。+2 与 warlord 同级但为一次性消耗，配合护坯/窑壁可多拿 4~24 格挡视后续挡牌数，封顶 2 层不超 warlord，不贬值稀有卡。

> 说明：若严格只做 12 瓶，可二选一保留 P12 或 P13；本文建议**保留 P12（蓄焰酒）+ P13（塑形膏）共 13 瓶**以更完整覆盖"特殊"类型，或删去 P13 回到 12 瓶。两种口径数值均已保守标定。

---

## 3. `data/potions.json` 建议 Schema

与 `cards.json` 同构（`version` + 主数组），每瓶含 `id / name / rarity / target / exhaust / effects / description`。药水**无能量消耗**，故不保留 `cost` 字段；`exhaust` 恒为 true（用后消耗）。建议额外字段：`combat_only`（默认 true，标记仅战斗中可用，便于未来扩展地图用药水）。

```json
{
  "version": 1,
  "potions": [
    {
      "id": "ash_salve",
      "name": "灰烬膏",
      "rarity": "common",
      "target": "self",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "heal", "value": 12 }
      ],
      "description": "恢复 12 点生命。"
    },
    {
      "id": "warmth_vial",
      "name": "余温瓶",
      "rarity": "uncommon",
      "target": "self",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "heal", "value": 14 },
        { "kind": "apply_status", "status": "anneal", "target": "self", "value": 2 }
      ],
      "description": "恢复 14 点生命，并获得 2 层回火（回合开始回血后递减）。"
    },
    {
      "id": "kiln_plaster",
      "name": "窑壁釉",
      "rarity": "common",
      "target": "self",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "block", "value": 12 }
      ],
      "description": "获得 12 点格挡。"
    },
    {
      "id": "tinder_oil",
      "name": "引火油",
      "rarity": "common",
      "target": "self",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "energy", "value": 1 }
      ],
      "description": "获得 1 点能量。"
    },
    {
      "id": "waking_clay",
      "name": "醒神陶土",
      "rarity": "common",
      "target": "self",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "draw", "value": 2 }
      ],
      "description": "抽 2 张牌。"
    },
    {
      "id": "ember_heart",
      "name": "余烬之心",
      "rarity": "rare",
      "target": "self",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "energy", "value": 2 }
      ],
      "description": "获得 2 点能量。"
    },
    {
      "id": "kiln_fire_oil",
      "name": "窑火油",
      "rarity": "uncommon",
      "target": "all_enemies",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "aoe_damage", "value": 8 }
      ],
      "description": "对所有敌人造成 8 点伤害。"
    },
    {
      "id": "titan_anoint",
      "name": "巨窑圣油",
      "rarity": "rare",
      "target": "enemy",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "damage", "value": 18 }
      ],
      "description": "造成 18 点伤害。"
    },
    {
      "id": "mud_bolt",
      "name": "湿泥弹",
      "rarity": "common",
      "target": "all_enemies",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "apply_status", "status": "damp", "target": "all_enemies", "value": 2 }
      ],
      "description": "对所有敌人施加 2 层受潮（攻击 -25%）。"
    },
    {
      "id": "craze_dust",
      "name": "釉裂粉",
      "rarity": "common",
      "target": "enemy",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "apply_status", "status": "crazed", "target": "enemy", "value": 2 }
      ],
      "description": "对目标敌人施加 2 层釉裂（受伤 +50%）。"
    },
    {
      "id": "ashrot_vial",
      "name": "灰蚀瓶",
      "rarity": "uncommon",
      "target": "all_enemies",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "apply_status", "status": "ashrot", "target": "all_enemies", "value": 2 }
      ],
      "description": "对所有敌人施加 2 层灰蚀（回合开始掉血后递减）。"
    },
    {
      "id": "stoke_brew",
      "name": "蓄焰酒",
      "rarity": "uncommon",
      "target": "self",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "apply_status", "status": "stoke", "target": "self", "value": 3 }
      ],
      "description": "获得 3 层蓄焰（你的下一张攻击牌伤害 +3，出手后 -1 层）。"
    },
    {
      "id": "temper_paste",
      "name": "塑形膏",
      "rarity": "uncommon",
      "target": "self",
      "combat_only": true,
      "exhaust": true,
      "effects": [
        { "kind": "gain_dexterity", "value": 2 }
      ],
      "description": "获得 2 层塑形（此后获得格挡时额外 +2）。"
    }
  ]
}
```

---

## 4. 落地备注（供程序/平衡对接）

1. **需登记台账**：本系统新增/调整数值（12~13 瓶、掉落权重、商店售价 35~75、各途径概率）须登记 `NUMERIC_LEDGER.md`，本文不再直接改写该文件。
2. **引擎侧需支持**：药水槽 UI（3 格）、Free Action 使用入口、战斗内 `effects` 执行（复用现有 `effect_kinds` 解析），以及 `combat_only` 开关。
3. **数值安全红线**（程序可加断言）：治疗 ≤24、格挡 ≤12（本系统）、能量 ≤2、抽牌 ≤3、单体伤害 ≤18、AOE ≤8；任何瓶不得使同功能卡牌一次性收益超过其最高费版本。
4. **未实现**：本文仅产出设计与 JSON 草案，不含 GDScript 代码（按任务要求）。
