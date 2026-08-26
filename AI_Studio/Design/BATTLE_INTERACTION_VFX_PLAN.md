# 战斗交互与演出升级方案 v1（BATTLE_INTERACTION_VFX_PLAN）

> 状态：待策划评审（吴总拍板后进入实现分期）
> 范围：仅战斗内交互与演出层；**不重写战斗内核**，数值继续走 GameData 不可硬编码。

---

## 0. 目标与硬约束

**目标**
1. 出牌从"点击卡牌触发"改为 **拖拽卡牌到目标角色释放**（敌人/玩家/全场）。
2. 敌人攻击玩家时，从敌方面板 **浮现一张"攻击卡"飞向玩家并碰撞**，撞击后才结算伤害并播 VFX。
3. 所有演出（出牌、敌人碰撞、死亡）**全部播完，才进入下一回合**。
4. 整体表现提升一个层次，但遵守现有 ART 原则：**信息优先，不做全屏大特效**（沿用 VFX_DESIGN）。

**硬约束（不可破）**
- 手机竖屏 720×1280 基准；拖拽热区 ≥ 64×64；字号下限满足 GAME_SPEC（数值/意图 ≥ 26px）。
- `CombatController` 的结算逻辑（伤害/格挡/状态/遗物钩子）尽量**原样保留**，只拆"前置 / 结算"边界以穿插动画。
- 所有数值仍取自 GameData / balance，脚本不写死（含新增演出时长常量，验收后迁 `data/vfx.json`）。

---

## 1. 现状诊断（为什么现在做不到）

| 项 | 现状 | 问题 |
|---|---|---|
| 出牌 | `Button.pressed` 直接 `controller.play_card` | 无目标感、无因果演出；先点敌人再点卡，流程割裂 |
| 敌人攻击 | `_enemy_phase()` 同步跑完，`damage_dealt` 信号同帧触发 VFX | 无法编排时序；多敌/多段攻击全挤在一帧 |
| 回合推进 | `end_player_turn()` 内联跑完敌人阶段后立刻 `_start_player_turn()` | **没有任何"等动画播完"的环节** |
| VFX | `VFXSystem` 有 `spawn_damage/heal/block/status/death/card_played/hit_shake` | 都是"瞬时触发原子特效"，缺少**带时序的演出原语**（飞行/碰撞/序列）|

结论：缺两层东西 —— **拖拽交互层** 和 **演出序列器（BattleDirector）**。

---

## 2. 总体架构（三层 + 一个序列器）

```
┌─────────────────────────────────────────────┐
│ 交互层  CardView（替代 Button）+ DropLayer     │  ← 拖拽、落点命中、高亮
├─────────────────────────────────────────────┤
│ 演出层  BattleDirector（新增，async）           │  ← 按 Beat 顺序 await 演出
│         play_card_cast / play_strike_card      │     持有 input_locked 输入锁
│         run_enemy_turn                         │
├─────────────────────────────────────────────┤
│ 模型层  CombatController（保持，仅拆边界）       │  ← 数值结算唯一来源
├─────────────────────────────────────────────┤
│ VFX 层  VFXSystem（扩展 strike_card/cast_burst）│  ← 原子特效复用
└─────────────────────────────────────────────┘
```

**关键解耦原则**：模型结算不负责"好看"，只负责"算对"；演出层负责"演完"，并用 `await` 串起每个 Beat，全部 Beat 清空后才放开输入、进入玩家回合。

---

## 3. 改动 A — 拖拽出牌（Drag-to-Cast）

**CardView（新增 `scripts/combat/CardView.gd`）**
- 替代 `_build_card_button` 里的 `Button`，自身是 `Control`（不用 Button，避免按下即触发 pressed）。
- `gui_input` 自管指针：
  - `pointer_down` 记录起点 + 卡数据（idx、CardData、enchants）。
  - 移动超过阈值（≈14px）进入**拖拽态**：生成跟随指针的半透明 ghost 卡；同时通知 `DropLayer` 高亮合法落点。
  - `pointer_up`：
    - 命中合法落点 → 触发施放（见下）。
    - 未命中 / 非法 → tween 弹回手牌原位。
  - 轻点（未达阈值）→ 对 `self`/`none`/`all_enemies` 类自动对自己施放；`enemy` 类若已选目标则对其放，否则弹回并提示选目标。

**DropLayer（新增 `scripts/combat/DropLayer.gd`）**
- 一个覆盖战场的 `Control`，维护注册表 `DropTarget{ node, rect(全局), accepts(card)->bool }`。
- 敌方面板（attack/enemy/all_enemies 卡可落）、玩家面板（self/block/none 卡可落）注册为落点。
- 拖拽中实时高亮合法落点（脉冲描边）；释放时按指针位置命中测试，返回目标索引（-1=玩家）。

**施放演出**：命中合法落点 → `await BattleDirector.play_card_cast(card_view, target_panel)`：
1. CardView 飞向目标（cast motion，tween 0.18s）。
2. 到达瞬间 `VFXSystem.spawn_cast_burst(target, 元素色)`（attack=橙、block/heal=绿/蓝）。
3. **此刻**才调 `controller.play_card(idx, target_index)` 真正结算，既有信号触发飘字/血条等 VFX。
4. 卡牌缩进弃牌堆，Beat 结束。

后端 `play_card(idx, target_index)` 接口**完全不变**，仅交互入口改变。

---

## 4. 改动 B — 敌人攻击"碰撞卡"演出（Enemy Strike Card）

这是表现提升的核心钩子，且**叙事自洽**：卡牌游戏里，敌人本来就是"打出一张攻击牌"打你。

**攻击意图（attack / aoe_debuff）**
`BattleDirector._play_strike_card(enemy_panel, player_panel, intent)` → 返回 travel 完成：
1. 从敌方面板浮现一张 **"攻击卡"**（红/橙卡面，绘该敌人攻击图标 + 数值，复用 `_card_style` 与现有意图图标，**不新增美术资产**）。
2. 沿**抛物线弧**飞向玩家面板（tween + 每帧 y 偏移做弧；途中轻微旋转/放大）。
3. **撞击瞬间**：`VFXSystem.screen_shake` 轻微震屏 + 玩家 `spawn_hit_shake` 红闪 + 卡面碎裂（scale→0 + 淡出）。
4. **撞击点才真正结算伤害**（`_execute_enemy_intent` 在撞击后调用），飘字与血条下落与撞击同步。
5. 多段攻击（times>1）：连续飞 N 张，或单张显示 ×N 后重复撞击。

**非攻击意图（defend / buff / charge）**
- 不飞撞击卡。改为敌方面板**自身"出牌"演出**：一张小卡在敌人头顶浮现、溶入自身（buff 青绿、defend 蓝），给玩家"敌人在做什么"的因果，不抢玩家注意力。

**复用**：`VFXSystem.spawn_strike_card(from, to, intent_dict)` 新建；`screen_shake` / `spawn_hit_shake` / `spawn_damage` 直接复用。

---

## 5. 改动 C — 演出时序（全部播完才进下一回合）

**核心改造**：`CombatController.end_player_turn()` 不再同步跑完敌人阶段，改为触发 `BattleDirector.run_enemy_turn(controller)`（async）。

`run_enemy_turn` 伪码（导演视角，await 串起）：
```
input_locked = true
for e in controller.enemies:
    if not e.is_alive(): continue
    _enemy_pre(e)                       # 清旧格挡 + turn_start 状态触发（travel 前）
    if not e.is_alive(): death_anim; continue
    await _play_strike_or_self_action(e)  # 攻击=碰撞卡飞行；非攻击=自身出牌
    controller._enemy_apply(e)            # 撞击后结算（原 _execute_enemy_intent 内部逻辑）
    await impact_settle()                 # 等撞击 VFX（≈0.3s）
    _decay_and_roll(e)                    # 衰减 + roll 下一意图
    if controller._check_combat_end(): await death_anim; break
if not ended:
    await controller._start_player_turn()  # 发 turn_started，刷新手牌
input_locked = false
```

**正确性保证（跨敌状态一致）**：plan 与 apply **逐敌交错**，不是先全 plan。敌人意图数值在玩家回合末已 roll（`_roll_enemy_intent`），`travel` 前只做"是否存活/清格挡/状态触发"前置，撞击后才结算——这样 `crazed`（易伤）、`glaze`（釉光）等跨敌/跨步状态与现有同步版本行为一致。

**最小侵入拆分**：保留 `_execute_enemy_intent` 函数名与内部逻辑，只把"前置（清格挡/状态触发/死亡判）"与"结算"在调用处用两个薄包装 `_enemy_pre` / `_enemy_apply` 分隔，供 Director 在撞击点调用。

---

## 6. 输入锁与竞态（避免演出中误触）

- `BattleDirector.input_locked`：拖拽、结束回合、药水按钮在锁定时一律忽略。
- 战斗结束/玩家死亡：旅行中触发 `combat_end` 时，先 `await` 死亡演出，再发 `combat_ended`（沿用现有 `_on_unit_died` 延迟释放逻辑）。
- 演出超时保护：每个 Beat 用 `await tween.finished` 或带上限的 `create_timer`，防止某步卡死导致永久锁输入（兜底超时强解 input_locked）。

---

## 7. 文件改动清单（精确）

| 文件 | 动作 | 内容 |
|---|---|---|
| `scripts/combat/CardView.gd` | 新增 | 拖拽卡视图（替代 Button）；pointer_down/move/up 状态机；ghost 卡 |
| `scripts/combat/DropLayer.gd` | 新增 | 落点注册表 + 命中测试 + 合法落点高亮 |
| `scripts/combat/BattleDirector.gd` | 新增 | 演出序列器；`play_card_cast` / `play_strike_card` / `run_enemy_turn`；`input_locked` |
| `scripts/core/VFXSystem.gd` | 修改 | 新增 `spawn_strike_card(from,to,intent)`、`spawn_cast_burst(anchor,element)`、弧线飞行辅助 |
| `scripts/combat/CombatUI.gd` | 修改 | `_build_card_button`→套用 `CardView`；`_on_card_pressed`→拖拽流程；`_on_end_turn`→fire `BattleDirector.run_enemy_turn`；禁用逻辑接 `input_locked`；落点高亮刷新 |
| `scripts/combat/CombatController.gd` | 修改 | `end_player_turn` 改为触发 async 演出；`_enemy_phase` 拆 `_enemy_pre`/`_enemy_apply` 薄包装（内部逻辑不变） |
| `data/vfx.json` | 可选 | 验收后把演出时长常量（TRAVEL/IMPACT/弧高）从脚本常量化 |

---

## 8. 实施分期（最小风险，每期可独立验收）

- **P1 交互**：仅做拖拽出牌（不改结算），独立验收手感与热区。
- **P2 演出**：`VFXSystem` 加 `strike_card` / `cast_burst`；`BattleDirector` 先包装现有 `play_card` 的 cast 演出（不碰敌人时序）。
- **P3 时序**：`enemy_phase` 异步化 + `run_enemy_turn` 串联，落地"碰撞卡 + 全播完进回合"。
- 每期配 Verify 场景 + `run_and_verify` 回归（沿用 P-D/ActVerify 套件思路）。

---

## 9. 验收标准

1. 拖拽 attack 卡到敌人 → 卡飞向敌人 + 元素爆发 + 伤害飘字；拖到非法区弹回原位。
2. 结束回合 → 每个敌人**依次**"攻击卡"飞向玩家并撞击 → 红闪/轻震/伤害飘字 → **全部播完才**回到玩家回合。
3. 多段攻击逐次撞击；敌人 defend/buff 有"自身出牌"演出。
4. 演出期间无法点击/拖拽（input_locked 生效）；高速无卡死；headless `run_and_verify` 全过。
5. 手机竖屏 720×1280 下拖拽热区 ≥ 64×64、字号满足 GAME_SPEC。

---

## 10. 风险与权衡

- **最大改动点**：`enemy_phase` 异步化（涉及 1000 行文件）。缓解：保留 `_execute_enemy_intent` 不变，只拆"前置/结算"边界，新增薄包装。
- **拖拽 vs Button 体系**：CardView 必须自己管 `gui_input`，不能吞掉 pressed 语义；落点检测用独立 DropLayer，避免与 Container 布局重排冲突。
- **节奏**：演出时长设可调常量，默认克制（单步 ≤ 0.8s），符合"信息优先"原则，不喧宾夺主。
- **零新美术资产**：碰撞卡复用现有意图图标 + 卡框样式，成本可控。
