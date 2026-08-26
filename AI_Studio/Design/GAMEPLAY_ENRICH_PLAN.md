# 玩法丰富化方案 v2（策划团队版）

> 目标：**在难度已归位至 `normal` 的基础上**，通过「接入已埋好的资产 + 新增机制与内容」让单局更有厚度与抉择。（历史背景：归位前曾为 ×0.65/×0.8/≤2，已于 2026-08-17 撤销）
> 难度低的根因不是数值，而是**系统没串起来**（遗物没接入、战后没收益、卡组不会变强、永远单弱怪）。本方案先补"厚度"；**难度系数归位已于 2026-08-17 作为独立步骤执行完成**（见 §5.3：伤害 ×0.65→1.0、HP ×0.8→1.0、单场上限 2→3、精英频率 0.1→0.18、新增第 3 精英敌熔渣兽与 3 敌编成 E）。

## 0. 一页纸摘要

| 角色 | 本轮负责 | 核心交付 |
|------|----------|----------|
| 战斗策划 | 让每场战斗更有变化与策略 | 遗物接入战斗、多敌+目标选择、意图多样化、窑温共鸣机制、2~3 个新状态 |
| 系统策划 | 让单局循环完整、有成长 | 战后奖励、卡牌升级、商店、休息增强、事件、宝箱、存档读档 |
| 内容策划 | 让内容更丰富、更"陶原" | 卡池按 build 深化、多敌编成表、Boss 第三觉醒阶段、世界观叙事注入 |
| 数值策划 | 让收益曲线合理（不碰系数） | 经济/掉落曲线、build 间平衡、难度系数归位清单（留后续） |

落地后预期：单局从"一直打单弱怪→直接回地图"变成"打怪→三选一变卡组→商店/事件抉择→休息升级→多敌取舍→Boss 多阶段"，**build 多样性立起来，难度感自然上升**，但敌人数值仍按当前系数。

---

## 1. 现状盘点：已埋好但未生效的资产（最高性价比来源）

| 资产 | 数量 | 当前状态 |
|------|------|----------|
| 遗物 `RELIC_LIST.json` | 10 | 数据齐全，**0 个接入战斗**（无 RelicSystem） |
| 卡牌 `CARD_LIST.json` | 35 | `upgrade` 字段齐全，**无升级流程**；无奖励三选一 |
| 状态 `STATUS_LIST.json` | 6 | 釉裂/受潮/灰蚀/炽热/塑形/回火；结算需确认是否全部接通 |
| 多敌结构 | — | `BALANCE_TABLE.enemy_scaling.max_enemies_per_combat=2`，**无战斗实际生成 2 敌** |
| 节点内容 | shop/rest/event/treasure | 地图节点已有，进入后多为占位（仅给金币） |

> 结论：先把"已埋资产"接上，难度厚度立刻上来，几乎不增数值。

---

## 2. 战斗策划（Combat Designer）

### 2.1 遗物系统接入战斗（P0，最高性价比）
新增 `RelicSystem`（Autoload 或挂在 CombatController），在 `CombatController` 的对应钩子触发 10 个遗物：

| 遗物 | 触发点 | 效果 | 接入钩子 |
|------|--------|------|----------|
| 余温炭 emberheart | after_combat | 战斗结束 +6 HP | `combat_ended(victory)` |
| 风箱手套 bellows_glove | combat_start | 开局 +1 炽热 | `start_combat` |
| 炭票袋 charcoal_chit | reward_gold | 金币 +25% | `grant_reward` |
| 抽风口 draft_flue | combat_start_first_turn | 第一回合 +1 能量 | `start_player_turn(turn==1)` |
| 陶片背心 sherd_vest | on_hit | 受击对攻击者反 3 | `apply_damage(player)` |
| 守窑围裙 keeper_apron | combat_start | 开局多抽 1 | `start_combat` |
| 汲热钳 heat_siphon | on_attack_damage | 造成攻击伤害后 +2 HP | `deal_attack_damage` |
| 补陶泥 mending_slip | after_rest | 休息额外 +5 HP | `rest_heal` |
| 劈薪斧 firewood_axe | first_attack_each_combat | 首张攻击牌 +4 伤 | `play_card(attack, first)` |
| 围炉小灶 hearth_totem | combat_start | 开局 +5 格挡 | `start_combat` |

> 仅这一项就引入 10 种 build 变体（能量流/反伤流/续航流/首杀流…），且完全不动敌人系数。

### 2.2 多敌编成 + 目标选择 UI（P0）
- 允许 combat/elite 节点按 `max_enemies_per_combat` 生成 1~2 敌（见 §4.2 编成表）。
- 战斗 UI 增加**敌人列表 + 选中高亮**；攻击牌点选后弹目标箭头/点敌；AOE 牌（aoe_damage）自动打全体。
- 敌人意图条逐个显示，避免信息过载（竖屏热区 ≥64px，符合 GAME_SPEC）。

### 2.3 敌人意图多样化（P1）
在现有 `attack/defend/buff/debuff` 基础上补充意图类型（不改数值，只改"读起来更有戏"）：
- **多段攻击**：`times>1`（已有，需 UI 明确显示 "×N"）。
- **蓄力**：本回合显示"蓄"，下回合固定大招（telegraph，给玩家决策窗口）。
- **增益+攻击组合**：灰颂者式 buff 后接 hex，已有可保留。
- **debuff 意图**：受潮/灰蚀/釉裂 的施加意图需有独立图标（避免和攻击混淆）。

### 2.4 新机制：窑温·共鸣（P2，新增核心机制）
- 战斗内新增资源 **窑温**（0 起）。每打出 1 张 `attack` 牌 +1 窑温。
- 阈值触发"窑变"：每累计 5 点窑温，立即对所有敌人造成 5 点**贯穿伤害（无视格挡）**，并消耗这 5 点。
- 设计目的：给 aggro 一条"攒温→爆发"的节奏线，制造"现在爆发还是再攒一轮"的抉择，**纯玩家侧增益，不影响敌人系数**。
- 数值后续由数值策划校准（本方案仅定机制骨架）。

### 2.5 状态体系扩展（P2，提议 2~3 个，贴合陶原设定）
| 新状态 | 类型 | 效果（提议） |
|--------|------|--------------|
| 蓄焰 stoke | buff | 你的下一张攻击牌伤害 +层数；出手后 -层数（不按时衰减） |
| 釉光 glaze | buff | 受到攻击时减伤等于层数，仅触发 1 次后 -1（类护盾） |
| 焦渴 thirst | debuff | 若回合结束未打出攻击牌，下回合 -1 能量（惩罚空过） |
> 需 `CombatController` 增加对应结算分支 + 卡牌 effect 支持；属 P2，先做 2.1~2.3。

---

## 3. 系统策划（Systems Designer）

### 3.1 战后奖励结算（P0，build 成长主引擎）
- 战斗胜利 → **卡牌三选一**（按 `card_pool_weights` 稀有度权重抽池）+ 金币（`combat_gold`）+（精英/Boss）遗物。
- 奖励面板做成独立场景 `RewardScene`，结算数据来自 `RunState` + `GameData`。
- `CardData.get_effects(upgraded)` 已就绪，三选一直接加进 `RunState.deck`。

### 3.2 卡牌升级流程（P0）
- 入口 1：休息点二选一之"升级一张卡"（已预留 `can_upgrade`）。
- 入口 2：奖励三选一里出现"升级版"卡牌选项；商店提供"升级服务"。
- 升级即切换到该卡 `upgrade` 字段，无需新卡 id。

### 3.3 商店 Shop（P1）
- 真实场景：售卖 3~5 张随机卡（50/75/100）、1~2 遗物（120/200）、**移除卡**（75）。
- 经济来自 `RunState.gold`，价格来自 `BALANCE_TABLE.shop`。

### 3.4 休息点增强（P1）
- 二选一：回血 30%（+补陶泥遗物额外 5）/ 升级一张卡。
- 后续可加第三选项"移除一张卡"（先不做，避免过强）。

### 3.5 事件系统 Event（P1）
- 2~3 选项 + 后果网络：±金币、获得/失去卡（含 curse）、获得/失去状态、获得遗物。
- 先写 4~5 个贴合世界观的事件（如"废窑异响""守窑人遗骸""炽窑裂隙"），数据驱动于 `events.json`。

### 3.6 宝箱 Treasure（P1）
- 进入直接给随机遗物（或三选一），复用奖励面板。

### 3.7 存档/读档（P4）
- `user://save.json` 存 `RunState`（卡组/HP/金币/层数/地图进度），支持中途退出续玩。
- Meta 进度（已通关次数/解锁）留作后续。

**实现落地（2026-08-18）**：
- `RunState.to_save_dict()` / `from_save_dict()`：全字段序列化。所有 `StringName` 经 `String()` 转换后落盘，`MapNode` 重建为 `RefCounted` 实例；`from_save_dict` 含 `SAVE_VERSION` 版本校验，不匹配直接拒绝并 `return false`。
- `SaveManager`（新增 Autoload，`project.godot [autoload]`）：`save_game/load_game/has_save/delete_save` + 测试用 `save_to_file/load_from_file`（任意路径）。`StringName`↔`String` 经 `JSON.stringify`/`JSON.parse_string` 往返；损坏文件 `load_from_file` 返回空 `Dictionary` 被拒绝。
- 自动存档钩子：`_ready` 连接 `SignalBus.floor_entered` / `combat_ended` → `save_game()`（增量存档）；`run_ended` → `delete_save()`（胜/败清档，避免读回已结束的局）。
- 验证：`scenes/combat/SaveVerify.tscn` 真跑 21 项断言（存档写入、读档解析、HP/金币/层/牌组/遗物/地图结构/visited/ enemy_ids/links 全字段往返、`is_active`、损坏 JSON 拒绝、版本不匹配拒绝、删档），`SAVE_RESULT:PASS`（21/0）。
- **多幕扩展：P-A~P-E 全部完成（2026-08-18，3 幕串联 + 幕间回血 + 存档 v2 + 幕缩放 + 敌池隔离）**——见 `MULTIACT_EXPANSION_DESIGN.md`（状态：全部完成，ActVerify 49/0）。

**退出UI 落地（2026-08-18，配合存档读档）**：
- `MainMenu.tscn` + `MainMenu.gd`（新 `main_scene`，替换原 `Boot.tscn` 冒烟测试）：启动检测 `SaveManager.has_save()`，「新游戏」清旧档+`start_new_run`，「继续游戏」`load_game`；无存档时「继续游戏」禁用。
- `MapUI.start_new_map()` 改为：若 `RunState.is_active` 已为真（续玩载入）则**不再** `start_new_run`，并依据地图节点 `visited` 重建已选路径 `chosen[]`，避免覆盖存档。
- `PauseManager`（新增 Autoload）：游戏内右上角常驻暂停按钮（手机端 80×80、字号≥30）；暂停弹窗「继续游戏 / 保存并返回主菜单 / 保存并退出游戏」。暂停时 `get_tree().paused=true`，CanvasLayer 用 `PROCESS_MODE_ALWAYS` 保证菜单在暂停态可点。
- `SaveManager` 增 `NOTIFICATION_WM_CLOSE_REQUEST` 钩子：`auto_accept_quit=false` 拦截关窗，活跃局先 `save_game()` 再 `quit()`（关窗强存档）。
- 验证：`scenes/combat/PauseVerify.tscn` 真跑 13 项断言（新游戏清档、`load_game` 续玩全字段一致、暂停保存、关窗钩子存档），`PAUSE_RESULT:PASS`（13/0）。
- 踩坑：autoload `_ready` 内向 `get_tree().root` 直接 `add_child` 会报 "Parent node is busy" 失败 → CanvasLayer 改为挂在 autoload 自身节点下。

---

## 4. 内容策划（Content Designer）

### 4.1 卡池按 build 深化（P3）
当前 35 张已覆盖四系，但每系"终端卡"偏少。建议每系补 2~3 张高稀有度卡，强化 archetype 辨识度：
- **aggro**：更高费爆发 / 窑温联动卡（吃 §2.4）。
- **defense**：格挡转伤 / 反伤联动（吃陶片背心）。
- **control**：群体釉裂/受潮 / 状态叠加。
- **burn**：灰蚀强化 / 回合结束 AOE 升级。

### 4.2 多敌编成表（P0/P1，用现有 7 个普通敌）
| 编成 | 敌人 | 出现层 |
|------|------|--------|
| A | 陶泥团 + 煤灰仔 | 普通层 |
| B | 火蛾 ×2 | 普通层 |
| C | 釉蛭 + 陶片兵 | 普通层 |
| D | 灰颂者 + 陶泥团 | 偏后期普通层 |
> 精英（陶偶将/釉裂兽）维持单怪或双怪组合；Boss 单怪。

### 4.3 Boss 第三觉醒阶段（P3）
- 窑主·熾 当前 2 阶段（hp<50% 进二阶段）。
- 新增 **hp<25% 觉醒阶段**：自身 +3 炽热，每回合 AOE 6 + 对全体施加 2 层釉裂，作为收尾高潮（属内容/演出，不调前期系数）。

### 4.4 世界观叙事注入（P1~P3）
- 事件文本、节点进入提示、Boss 前独白，统一用"陶原世界/炽窑/灰壳陶化/守窑人炭"语汇，提升代入感（美术/文案协同）。

---

## 5. 数值策划（Balance Designer）

### 5.1 经济与掉落曲线（不改系数）
- 校验 `combat_gold`(10~20) / `elite_gold`(25~40) / `boss_gold`(50~80) 与商店价格的"可负担感"。
- 遗物掉率：精英必掉 1，Boss 必掉 1，宝箱 1，普通战斗低概率掉（提议 8%）。
- 卡池权重 `common 0.6 / uncommon 0.32 / rare 0.08` 与奖励三选一结合，保证前中期能成型。

### 5.2 Build 间平衡（P2~P3）
- 四条线（aggro/defense/control/burn）在中后期应有各自通关路径，避免某系明显超模。
- 窑温、新状态上线后做一轮内部对推。

### 5.3 难度系数归位（**✅ 完成 2026-08-17**）
- 用户于 P3 之后拍板执行。已撤销开发期折扣：
  - 伤害系数 ×0.65 → **1.0**，HP 系数 ×0.8 → **1.0**，`difficulty` 由 `easy` → `normal`。
  - 单场敌人上限 2 → **3**，新增 3 敌编成 E（embermoth×2 + sootling，楼层 5–6）。
  - 精英节点频率 0.1 → **0.18**，并新增第 3 种精英敌「熔渣兽 slagbeast」（含 P2 釉裂 debuff）。
- 系数与 §2~§4 的"厚度"叠加后难度显著上升；一键打通到 Boss 的自动战斗仍能通关（PlaythroughTest 11/0），闭环未被打崩。
- 新增 `scripts/combat/DifficultyVerify.gd` + 场景，断言上述归位项，真实运行 `DIFF_RESULT:PASS`。

### 5.4 敌人基础属性偏易修正（**✅ 完成 2026-08-17**）
- 归位后 BalanceSweep 实测发现敌人表整体偏易（普通单怪 1.6–2.4 回合被秒、终局残血≈1.0；非单 build 过强，全 build 均满血碾压）。经分析从**怪物基础属性**下手，用户确认「草稿 v1」落地 `data/enemies.json`：
  - 普通敌 HP×1.8、攻击×1.4（如 claylump 24→44 / tackle 6→9）；精英适度提（kilnward 60→84、glazemaw 70→82、slagbeast 54→82）；Boss 轻调（140→150，swipe/inferno 等+2）。
  - 重跑 BalanceSweep：**1 PASS / 0 FAIL / 34 WARN（原 68 减半）**，无不可战胜、无 Boss 秒杀；trivial(≤2 回合) WARN 全消除，普通敌 avgT 升至 2.75–4.08。残留 34 WARN 为普通单怪「过易」(终局HP≥0.85)，属**伤害侧**未压够（HP 已够长、伤害被格挡盖住），非 build 失衡。
  - 下一步待决策：① 普通怪伤害再提约 ×1.3 清 过易；② 或接受「普通单怪=热身、压力在精英/Boss/多敌」（当前已合理）。详见 `NUMERIC_LEDGER.md` §C。
  - 断言同步：CombatTest 敌人初始HP 24→44、P3Verify Boss fixture 140→150、DifficultyVerify 缩放断言 44/150；全 11 套件零回归。

### 5.5 普通怪伤害再平衡 v1.1（**✅ 完成 2026-08-17**）
- 用户决策：「再提升普通单怪伤害，或给某个技能高伤，不至于一直被护盾防掉」。5.4 残留 34 WARN 根因为普通怪伤害仅×1.4、单段 ≤13 被自动战斗护盾（起手护坯=5、防御 build 双护盾≈13~17/回合）全数盖掉。
- 方案：HP 沿用 5.4 不变（维持 2.75–4 回合战斗时长），仅重做**伤害结构**——为每个普通怪新增/提升一个**高伤技能（≥16，超过护盾净伤）**，并保留小攻击/减益。首版高伤 18~22 仍偏易（v3 普通怪终局 0.87~0.97），二次加大到 **22~26 + 提高频率** 后落地（详见 `NUMERIC_LEDGER.md` §C-b）：
  - claylump heavy_slam **24**(0.4)；sootling searing_jab **26**(0.35)；embermoth ember_heavy **22**(0.2)；glazetick venom_bite **24**(0.35)；potsherd crush **26**(0.3)；kilnstatue pillar_slam **24**；ashcantor grand_hex **26**。基线攻击同步微提（tackle12/stab14/bite9×2/sting11/slash14/slam10/hex15）。
- 验证（v4 重跑 + 全 12 套件回归）：**BALANCE_SWEEP 1 PASS / 0 FAIL / 25 WARN**；普通怪终局残血降至 **0.85~0.89**（护盾被压过、真实承伤 7~12 点），用户痛点「打不出伤害/被护盾全防」已解决；无不可战胜 FAIL、无 Boss 秒杀；全 12 套件零回归（CombatTest20/P3Verify30/DifficultyVerify14/PlaythroughTest11/其余 PASS）。
- 残留 ~25 WARN 全卡在 0.85 边界，属前期热身怪的合理预期；再加压会伤手感或触发不可战胜，故保留。如需进一步收紧，由数值策划决定放宽 `too_easy_hp_ratio` 探针或继续收窄普通怪耐性（同走 §C 闭环）。

---

## 6. 实施路线图（先接入、后新增、再扩展）

| 阶段 | 内容 | 难度影响 |
|------|------|----------|
| **P0 接入已有资产** | ✅ 完成（2026-08-17~18：遗物系统接入战斗 `_apply_relics_*` 全钩子 + RelicTest；奖励三选一 RewardBuilder+RewardUI 接入战斗胜利；卡牌升级 RewardUI/RestUI→`RunState.upgrade_card_at`；多敌编成 MapGenerator+目标选敌 `play_card(target_index)`；P0Verify 零 SCRIPT ERROR） | 仅玩家侧增益，敌系数不变 |
| **P1 节点内容** | 3.3 商店 / 3.4 休息增强 / 3.5 事件 / 3.6 宝箱 / 2.3 意图多样化 / 4.4 叙事 | ✅ 完成（2026-08-17：事件改数据驱动 events.json；蓄力/telegraph 意图机制已落地） |
| **P2 新机制** | 2.4 窑温共鸣 / 2.5 新状态（蓄焰/釉光/焦渴）/ 5.2 build 平衡 | ✅ 完成（2026-08-17：窑温共鸣资源+贯穿窑变、3 个新状态结算分支、起始卡 strike/defend 接入蓄焰/釉光、灰颂者加焦渴意图；P2Verify 9/0） |
| **P3 内容扩展** | 4.1 卡池深化 / 4.2 编成表落地 / 4.3 Boss 三阶段 | ✅ 完成（2026-08-17：卡池 35→43 共 8 张 per-build 终盘卡；编成表 4 组 A/B/C/D 落地 MapGenerator + GameData 楼层门控；Boss 三觉醒阶段 <25%HP 自+3 窑温 + aoe_debuff AOE6+2 焦躁；P3Verify 29/0，全 10 套件零回归） |
| **P4 Meta** | 3.7 存档读档 / 多幕扩展 / 退出UI | ✅ 全部完成（2026-08-18）：存档读档 + 退出UI + 多幕扩展 P-A~P-E（3 幕串联 / 幕间回血 / 存档 v2 / 幕缩放 / 敌池隔离）；`MULTIACT_EXPANSION_DESIGN.md` 状态「全部完成」，ActVerify 49/0 |
| **（后续独立）难度归位** | 系数回调 / 多敌上限 3 / 精英增量 | ✅ 完成（2026-08-17：伤害×0.65→1.0、HP×0.8→1.0、上限2→3、精英频率0.1→0.18、新增第3精英敌熔渣兽与3敌编成E；DifficultyVerify 14/0，全 11 套件零回归） |

---

## 7. 关键抉择结果（均已拍板并落地，2026-08-17~18）

| # | 原抉择 | 结果 |
|---|--------|------|
| 1 | 先做 P0 接入还是 P1 内容？ | **P0 先行**（遗物+奖励+升级+多敌UI）已落地，单局立刻有"变强"感；P1~P4 紧随全部完成 |
| 2 | 窑温共鸣机制要不要做？ | **做**，已落地（P2）：战斗内窑温资源 + 阈值 5 贯穿 5 伤「窑变」，纯玩家侧增益 |
| 3 | 多敌是否现在就开？ | **开**，已落地（P0）：`max_enemies_per_combat=3` + 目标选敌 UI + 编成表 A~I |
| 4 | Boss 三阶段是否纳入？ | **纳入**，已落地（P3）：熾 hp<25% 觉醒阶段（自+3 窑温 + AOE6+2 釉裂） |

> 全部经 Godot headless 真跑验证通过（见各 `P*Verify` / `ActVerify` 报告）。**无遗留决策项。**
