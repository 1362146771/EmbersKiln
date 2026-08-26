# SYSTEM_DESIGN.md — 系统架构（v1）

> 每个系统定义：Purpose / Responsibilities / Input / Output / Main Rules / Data / Dependencies / Edge Cases。
> 所有数值来自 `Design/*.json`，代码不硬编码。

## 1. RunState（Autoload 单例）
- **Purpose**：跨场景保存当前单局（Run）状态。
- **Responsibilities**：持有卡组、遗物、金币、当前地图进度、玩家 HP、种子。
- **Data**：`RunStateData`（Resource）；`deck: Array[CardData]`、`relics: Array[RelicData]`、`gold: int`、`hp/max_hp: int`、`map_index: int`、`seed: int`。
- **Dependencies**：所有系统读它；地图 / 战斗 / 奖励写它。
- **Edge Cases**：新游戏重置；死亡清空；读档恢复。

## 2. DataLoader
- **Purpose**：从 JSON / .tres 加载并缓存数据。
- **Responsibilities**：启动时加载卡 / 敌 / 状态 / 遗物 / 地图定义到内存字典（`id → data`）。
- **Edge Cases**：缺字段报错并定位；重复 id 冲突告警。

## 3. CombatSystem（战斗控制器）
- **Purpose**：主持单场战斗流程。
- **Main Rules**：
  1. 战斗开始：洗牌入抽牌堆；玩家能量恢复至上限；应用遗物入场效果。
  2. 每回合：玩家回合（出牌 → 结束）→ 敌人按意图行动 → 状态结算 → 下一回合。
  3. 格挡在「下一个玩家回合开始时」清零（敌人格挡在其自身回合开始时清零）；格挡须先扛过敌人攻击才有意义（与《杀戮尖塔》一致，见 GAMEPLAY_DESIGN.md §4）。
  4. 胜利：所有敌人 HP ≤ 0；失败：玩家 HP ≤ 0。
- **Dependencies**：CardSystem、EnemySystem、StatusSystem、EnergySystem、RelicSystem、VFXSystem。

## 4. EnergySystem
- **Responsibilities**：每回合恢复能量到上限（默认 3）；出牌扣费；能量不足禁止出牌。
- **Edge Cases**：费用为 0 的卡可免费打出；消耗（exhaust）卡不回手牌。

## 5. CardSystem
- **Responsibilities**：抽牌 / 手牌 / 弃牌 / 消耗堆管理；执行卡牌 effects 列表。
- **Main Rules**：抽空时洗回弃牌堆；手牌上限默认 10；升级卡替换原卡。
- **Data**：`CardData`（id/name/type/cost/rarity/target/effects[]/upgrade/description/exhaust/build）。

## 6. EnemySystem（意图 + AI）
- **Responsibilities**：生成并显示敌人意图；按 AI 模式执行行动。
- **AI 模式**：`weighted_random`（普通）、`scripted_phases`（Boss）。
- **Edge Cases**：意图在玩家回合计为「下回合行动」，玩家出牌不刷新敌人意图。

## 7. StatusSystem
- **Responsibilities**：维护增益 / 减益层数、结算顺序、衰减。
- **Main Rules**：力量/敏捷持久叠加；易伤/虚弱按回合衰减；中毒回合开始扣血并 -1。

## 8. RelicSystem
- **Responsibilities**：按触发点（战斗开始/结束、受击、出牌等）应用遗物效果。
- **Edge Cases**：同触发点多遗物按固定顺序结算。

## 9. MapSystem
- **Responsibilities**：逐幕生成多幕地图、节点连接、玩家位置推进。
- **Data**：`MAP_DESIGN.json`（层数、节点类型概率、Boss 层）。

## 10. RewardSystem
- **Responsibilities**：战斗后给出卡牌三选一 / 金币 / 遗物（精英、Boss）。
- **Edge Cases**：卡池按稀有度权重抽取；遗物去重。

## 11. ShopSystem
- **Responsibilities**：用金币购买卡 / 遗物、移除卡牌。

## 12. RestSystem
- **Responsibilities**：休息点二选一：回血 30% 或 升级一张卡。

## 13. EventSystem
- **Responsibilities**：事件节点给出 2-3 个选项与后果（金币/卡/状态）。

## 14. UISystem
- **Responsibilities**：战斗 HUD（HP/能量/格挡/手牌/意图/状态）、地图、奖励、商店、休息界面。
- **约束**：所有 UI 必须遵循 `GAME_SPEC.md`《UI 规范（手机端，强制）》——竖屏 720×1280 基准、最小字号 20px、可点热区 ≥ 64px、竖屏单列布局；禁止依赖横屏。

## 15. VFXSystem
- **Responsibilities**：出牌 / 伤害 / 格挡 / 状态变化 / 死亡 的轻量反馈（信息优先于华丽）。

## 16. SaveSystem
- **Responsibilities**：Run 状态序列化到 `user://save.json`（v1 可选，预留接口）。
