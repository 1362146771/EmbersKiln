# 多幕扩展策划设计（Multi-Act Expansion Design）

> 状态：**全部完成（2026-08-18）**——P-A 数据层 ✅ / P-B 流程层 ✅ / P-C 存档层 ✅ / P-D 内容层 ✅ / P-E 验证层 ✅。多幕扩展（3 幕串联 + 幕间回血 + 存档 v2 + 幕缩放 + 敌池隔离）已按本设计全量落地并通过 headless 全量回归。
> **P-A 已实现交付**：`data/map.json` 改 `acts` 数组（3 幕）；`GameData.act_configs`；`RunState` 多幕容器 + `generate_acts/current_map/current_act_config/is_last_act/advance_act` + 当前幕版 `total_floors/is_boss_floor` + `to_save_dict/from_save_dict` 升 v2；`MapGenerator` 加 `boss_id`；`SaveManager` 升 v2 + 旧档清理；`SignalBus` 新增 `act_changed/run_won`。验证：`ActVerify` 25/0（`ACT_RESULT:PASS`），全套件回归零 FAIL。
> **P-B 已实现交付（流程层，2026-08-18）**：`MapUI` 顶部新增"第 N 幕 · 幕标题"标签（`top_act`，随 `current_act`/`current_act_config().title` 刷新）；非终幕 Boss 胜利 → `RunState.advance_act()` + 幕间转场屏（`_show_act_transition`，展示幕名与幕间回血 HP X/max），点「进入第 N 幕」调 `start_new_map()` 重建本幕；终幕 Boss 胜利 → `end_run(true)` + 广播 `run_won`；`chosen[]` 改为按当前幕重建（逐幕重置）；移除遗留的 `RunState.map` 兼容 getter，全部引用（MapUI/MapTest/SaveVerify/PauseVerify/PlaythroughTest）迁到 `current_map()`；覆盖面板内容改挂到 VBox 容器修正层叠。验证：`PlaythroughTest` 改造为遍历全幕（10+9+8 层）打通，`PLAYTHROUGH_RESULT:PASS`；`MapPlay` 干净启动；`ActVerify/SaveVerify/PauseVerify/CombatTest/P3Verify/DifficultyVerify/MapTest` 全套件回归零 FAIL。
> **P-C 已实现交付（存档层，2026-08-18）**：`SaveManager._ready` 新增 `SignalBus.act_changed.connect(_on_act_changed)` → `save_game()`，非终幕 Boss 胜利进入新幕时立即落档（捕获回血后 HP 与新 current_act，覆盖 floor_entered 之前的窗口）；修复 `RunState.start_new_run()` 开局装配期 `is_active` 残留上一局为 true 导致 `act_changed(0)` 被误存的问题（装配期间显式置 false，收尾才置 true）。验证：`ActVerify` 扩 P-C 断言 5 项（开局瞬间不误存 / advance_act 触发自动存档 / 存档 current_act=1 / 存档 HP=幕间回血后），30/0 `ACT_RESULT:PASS`；全套件（PlaythroughTest/MapTest/MapPlay/SaveVerify/PauseVerify/CombatTest/P3Verify/DifficultyVerify）回归零 FAIL。
> 背景：P4 存档读档已完成（单幕，`user://save.json`，`SAVE_VERSION=1`）。多幕扩展此前按约定「留作单独策划任务」，本文即该任务的设计。
> 目标：把"一局 = 一张 10 层地图打到 Boss"扩展为"一局 = N 张幕地图串联"，每张幕末为 Boss，击败**最后一幕** Boss 才算整局胜利；幕间继承牌组/遗物/金币/（部分）HP。
>
> ✅ **关键抉择已拍板（2026-08-18）**：① 幕数 = **3 幕**（Act1 陶原初探 / Act2 炽窑升焰 / Act3 窑主终焰）；② 幕间回血 = **比例回血（Act2 进 +30% / Act3 进 +20%，占 max_hp）**；③ 终幕 Boss = **复用「窑主·熾」**（Act2 新增 1 个 Boss「窑心·烬」，Act3 复用熾并加更高幕缩放）；④ `SAVE_VERSION` 升 2 后 **直接拒绝 v1 旧档**（开发期干净）；⑤ `data/map.json` **原地改为 `acts` 数组**（破坏旧单幕结构，最干净）。其余数值（层数/缩放系数/敌池）已在 P-D 由数值策划校准落地（见 `NUMERIC_LEDGER.md §D`），无需再校准。

---

## 0. 一页纸结论

| 项 | 本方案建议 |
|----|-----------|
| 幕数 | **3 幕**（Act1 陶原初探 / Act2 炽窑升焰 / Act3 窑主终焰） |
| 继承 | 牌组、遗物、金币全继承；HP 幕间回血（Act2 +30% / Act3 +20% max_hp，已拍板，见 `NUMERIC_LEDGER.md §D` MA-01~MA-03） |
| 胜利 | 仅击败**最后一幕 Boss** 触发 `end_run(true)`；非终幕 Boss 触发 `advance_act()` 进下一幕 |
| 数据层 | `RunState.map`(单张) → `act_maps`(Array) + `current_act`；`generate_map()` → `generate_acts()`；`MapGenerator.generate()` 复用（逐幕调用） |
| 配置 | `data/map.json` 由单幕对象改为 `{ "acts": [ act1, act2, act3 ] }`，`GameData.map_config` → `GameData.act_configs: Array` |
| 存档 | `SAVE_VERSION` 1 → 2；新增 `current_act` / `act_cleared_flags` / `act_maps`（逐幕序列化） |
| 工作量 | 纯数据+流程改造，无新战斗机制；最大风险点是"全局 `map` 引用面"与"存档兼容"，见 §6/§7 |

> 全文所有数值（层数、回血%、幕缩放）均为**占位提议**，须数值策划在 P-D 阶段按 §5 校准，脚本不写死。

---

## 1. 现状盘点（改造前的接缝，均为已读代码事实）

| 文件 | 当前行为 | 多幕要改的点 |
|------|----------|--------------|
| `scripts/core/RunState.gd` | `var map: Array`（单张 `Array[floor]→Array[MapNode]`）；`generate_map()` 调 `MapGenerator.generate(GameData.map_config)` 生成**一张**；`is_boss_floor()`/`total_floors()` 取 `GameData.map_config` 单幕字段 | 改为多幕容器 + 逐幕生成；boss/floor 判定改按**当前幕**配置 |
| `scripts/map/MapGenerator.gd` | `generate(config)` 生成单幕地图，按 `config.fixed/type_weights/nodes_per_floor/boss_floor` 生成 | **基本复用**，逐幕调用即可；Boss 分支需支持 `config.boss_id` 指定本幕 Boss |
| `scripts/map/MapUI.gd` | 全程读 `RunState.map` 画整张地图；`_on_reward_done()` 中 `pending_boss` → `RunState.end_run(true)`（直接结束整局） | 改为读"当前幕地图"；非终幕 Boss 改为 `advance_act()` + 转场屏；`chosen[]` 逐幕重置 |
| `scripts/core/SaveManager.gd` + `RunState.to_save_dict/from_save_dict` | 序列化单张 `map`，`SAVE_VERSION=1` | 升级 v2，序列化多幕 |
| `data/map.json` | 单幕对象（`act:1, floor_count:10, boss_floor:9, fixed, type_weights, formations`） | 改 `acts` 数组；新增每幕 `boss_id / enemy_pool / act_hp_mult / act_dmg_mult / transition_heal` |
| `scripts/data/GameData.gd` | `map_config: Dictionary`；`scaled_enemy_hp/damage` 仅全局 `balance.enemy_scaling` | 新增 `act_configs: Array`；缩放改为 全局 × 当前幕局部乘子 |
| `scripts/integration/PlaythroughTest.gd` | 直接遍历 `RunState.map` 跑 10 层 | 改为遍历 `act_maps` 全幕 |
| `scripts/combat/SaveVerify.gd` / `PauseVerify.gd` | 引用 `RunState.map` / `to_save_dict` | 改读 `RunState.current_map()`，断言补多幕字段 |

---

## 2. 数据模型变更（DTO，核心交付）

### 2.1 `RunState.gd` 字段变更
```
# —— 移除（或保留为兼容 getter 弃用）——
# var map: Array = []                         # 旧：单张地图

# —— 新增（多幕容器）——
var act_maps: Array = []                      # Array[act] -> Array[floor] -> Array[MapNode]
var current_act: int = 0                      # 当前幕索引（0-based）
var act_cleared_flags: Array[bool] = []       # 每幕是否已通关（Boss 已击败）
var run_act_count: int = 0                    # = act_maps.size()，便捷读取

# 以下保留不变：deck / relic_ids / max_hp / hp / gold / current_floor / current_node_type / is_active / victory / defeated
```
> `current_floor` 语义明确为**当前幕内**层数（进下一幕重置为 0）。如需全局"已清层数"用于展示，新增 `var total_floors_cleared: int = 0`（可选，默认不展示）。

### 2.2 `RunState.gd` 方法变更
- `generate_map() -> void` → 保留为薄封装或直接改名 `generate_acts()`：
  ```gdscript
  func generate_acts() -> void:
      if not GameData.is_loaded:
          push_error("[RunState] GameData 未就绪，无法生成多幕地图"); return
      act_maps.clear()
      act_cleared_flags.clear()
      for cfg in GameData.act_configs:
          act_maps.append(MapGenerator.generate(cfg))
          act_cleared_flags.append(false)
      current_act = 0
      SignalBus.act_changed.emit(current_act)
      SignalBus.map_generated.emit(current_map())
  ```
- 新增便捷读取（供 `MapUI`/`topbar` 使用）：
  ```gdscript
  func current_map() -> Array:                       # 当前幕地图
      return act_maps[current_act] if current_act < act_maps.size() else []
  func current_act_config() -> Dictionary:           # 当前幕配置
      return GameData.act_configs[current_act] if current_act < GameData.act_configs.size() else {}
  func total_floors() -> int:                        # 改为按当前幕
      return int(current_act_config().get("floor_count", 10))
  func is_boss_floor() -> bool:                      # 改为按当前幕
      return current_floor >= int(current_act_config().get("boss_floor", total_floors() - 1))
  func is_last_act() -> bool:
      return current_act >= act_maps.size() - 1
  ```
- 新增 `advance_act()`（幕间推进 + 回血）：
  ```gdscript
  func advance_act() -> void:
      act_cleared_flags[current_act] = true
      current_act += 1
      if current_act >= act_maps.size():
          end_run(true); return                       # 理论上 is_last_act 的 Boss 已先行处理
      var heal_pct: float = float(current_act_config().get("transition_heal", 0.0))
      if heal_pct > 0.0:
          heal(int(round(max_hp * heal_pct)))
      current_floor = 0
      current_node_type = &""
      SignalBus.act_changed.emit(current_act)
      SignalBus.map_generated.emit(current_map())     # MapUI 据此重建本幕视图
  ```
- `start_new_run()`：`generate_map()` → `generate_acts()`；其余（deck/relic/hp/gold 初始化）不变。
- `end_run(is_victory)`：不变（整局结束，清档由 `SaveManager` 处理）。

### 2.3 `MapGenerator.gd` 变更（小）
- Boss 分支支持指定本幕 Boss：
  ```gdscript
  &"boss":
      var bid: StringName = StringName(config.get("boss_id", ""))
      var bs := GameData.get_enemies_by_tier(&"boss")
      if bid != &"":
          node.enemy_ids = [bid]
      elif not bs.is_empty():
          node.enemy_ids = [bs[0].id]
  ```
  > 注：`config` 需作为参数透传进 `_assign_enemies`（当前已传 `config`，仅需补 `boss_id` 分支）。
- 可选·每幕敌池：`config.get("enemy_pool", {normal:[...], elite:[...]})` 非空时，`_assign_enemies` 的 normal/elite 抽取限定在该池内（Act2/3 内容隔离用，Act1 留空=全池）。**仅内容阶段(P-D)需要，数据层(P-A)可先不做。**

---

## 3. 流程变更（胜利 / 幕间转场）

### 3.1 `SignalBus.gd` 新增信号
```
signal act_changed(act_index: int)        # 进入新幕（含开局 act=0）
signal run_won()                           # 击败最后一幕 Boss（可选；也可复用 run_ended(true)）
```
> `SaveManager` 需连接 `act_changed` → `save_game()`，确保幕间点也安全落盘。

### 3.2 `MapUI.gd` 改动
- 全部 `RunState.map` → `RunState.current_map()`（`_build_map_view` / `_is_reachable` / `_on_node_pressed` / `_on_map_draw` / `start_new_map` 的 `visited` 重建）。
- `start_new_map()`：`chosen[]` 改为**仅按当前幕**重建（`RunState.current_map()` 的 `visited`），不再跨幕。
- `_on_reward_done()`（原 `pending_boss → end_run(true)`）改为：
  ```gdscript
  if pending_boss:
      if RunState.is_last_act():
          RunState.end_run(true)
          _show_result(true)                       # 整局胜利
      else:
          RunState.advance_act()
          _show_act_transition(RunState.current_act)   # 幕间转场屏
      return
  _show_continue_panel("战斗胜利！获得战利品。", "继续前进")
  ```
- 新增 `_show_act_transition(act_idx: int)`：全屏覆盖层显示「第 N 幕 · {act_title}」+ 回血摘要 +「进入」按钮；点击后 `start_new_map()` 重建本幕地图（`chosen` 已随 `advance_act` 重置）。
- 顶部状态栏新增 `top_act` 标签（"第 N 幕"，字号 ≥20，符合 `GAME_SPEC` 手机端规范）。

### 3.3 胜利/失败边界
- 仅 `is_last_act()` 的 Boss 胜利 → 整局胜利（`end_run(true)` + `SaveManager.delete_save()`）。
- 任何幕内 `take_damage` 致死 → `end_run(false)`（整局失败），与现行为一致。
- `advance_act()` 后 `is_active` 仍为 `true`，存档保留（续玩从新幕首层开始）。

---

## 4. 存档升级（`SAVE_VERSION` 1 → 2）

### 4.1 `RunState.to_save_dict()` 变更
- 新增字段：`"current_act"`, `"act_cleared_flags"`, `"act_maps": [ ... ]`（逐幕，每幕结构同旧 `map` 的序列化）。
- 移除/替换旧 `"map"` 字段（v2 不再写单 `map`）。
- `SAVE_VERSION` 常量 `1 → 2`。
- 版本校验：`from_save_dict` 仅接受 `version == 2`；`< 2` 直接 `push_error` + `return false`（旧单幕存档视为过期，由 `SaveManager` 提示"存档版本过旧，请新游戏"）。
  > 兼容选项（可选，非必须）：若 `version == 1` 且存在旧 `map`，做一次一次性迁移——把旧 `map` 包成 `act_maps[0]`、`current_act=0`。仅在你想保住现有测试档时做；开发期建议直接拒绝旧档。

### 4.2 `SaveManager.gd` 变更
- 连接 `SignalBus.act_changed` → `_on_act_changed` → `save_game()`（幕间增量化存档）。
- `has_save()` / `load_game()` 不变（读 `to_save_dict`/`from_save_dict`）。
- 损坏 JSON / 版本不匹配 的拒绝逻辑已在 v1 实现，v2 沿用。

### 4.3 序列化示例（v2 草稿）
```json
{
  "version": 2,
  "current_act": 1,
  "act_cleared_flags": [true, false, false],
  "deck": [{"id":"strike","upgraded":false}],
  "relic_ids": ["emberheart"],
  "max_hp": 80, "hp": 52, "gold": 120,
  "current_floor": 0, "current_node_type": "",
  "defeated": ["claylump"], "victory": false, "is_active": true,
  "act_maps": [
    [ /* act0 的 floors→nodes，同旧 map 结构 */ ],
    [ /* act1 的 floors→nodes */ ],
    [ /* act2 的 floors→nodes */ ]
  ]
}
```

---

## 5. 数值（已全部确定，闭环完成 2026-08-18）

> 以下数值已由吴总批准草案实施并落地 `data/map.json` / `data/enemies.json`，闭环记录在 `NUMERIC_LEDGER.md §D`（MA-01~MA-24 均为「闭环完成」）。脚本不写死，全部数据驱动。

| 项 | 确认值 | 说明 |
|----|--------|------|
| 幕数 / 每层 | Act1=10 层；Act2=9 层；Act3=8 层 | 越往后越短，浓缩压力 |
| 幕间回血 `transition_heal` | Act2 进 =30% / Act3 进 =20%（Act1 进=0） | 比例回血，保张力 |
| 幕内缩放 `act_hp_mult` / `act_dmg_mult` | Act1=1.0 / Act2=1.15 / Act3=1.3（乘全局 `enemy_scaling`） | `GameData.scaled_enemy_hp/damage` 读当前幕局部乘子 |
| 每幕 Boss | Act1=窑主·熾（复用）；Act2=窑心·烬（新增）；Act3=窑主·熾（复用 + 更高幕缩放） | 终幕复用熾（抉择③） |
| 每幕敌池隔离 | Act2/3 各引入 2~3 个新普通敌 + 1 精英（炽窑卫/烬蝶/熔心傀儡；精英：窑卫长/烬噬） | 已落地，编成按幕隔离 F/G/H/I |

> 缩放实现：`scaled_enemy_hp(base)` 改为 `round(base * global_hp_mult * current_act_config().get("act_hp_mult",1.0))`，`damage` 同理。运行时已由 `CombatController._roll_enemy_intent` 接线（P-D 修复了此前未调用的缺陷）。

---

## 6. 影响面清单（改造必扫的引用）

| 引用点 | 文件:行（估算） | 动作 |
|--------|----------------|------|
| `RunState.map` 字段读写 | `RunState.gd`（to_save_dict/from_save_dict/advance_floor 等） | 改 `act_maps`/`current_map()` |
| `RunState.map` 直接遍历 | `MapUI.gd`（6+ 处）、`PlaythroughTest.gd:90`、可能 `SaveVerify.gd`/`PauseVerify.gd` | 改 `current_map()` |
| `is_boss_floor()/total_floors()` | `RunState.gd:180-185` | 改按当前幕配置 |
| `generate_map()` 调用 | `RunState.gd:58` | 改 `generate_acts()` |
| 非终幕 Boss 胜利 | `MapUI.gd:362-368` | 改 `advance_act()` + 转场 |
| `GameData.map_config` | `GameData.gd:22,71`、各 verify | 改 `act_configs` |
| `scaled_enemy_hp/damage` | `GameData.gd:226-233`、`CombatController.gd` | 增加当前幕局部乘子 |
| `map.json` 结构 | `data/map.json` | 改 `acts` 数组 |
| `SaveManager` 钩子 | `SaveManager.gd:16` | 加 `act_changed` |
| 顶部栏/转场 UI | `MapUI.gd` | 加 `top_act` 标签 + `_show_act_transition` |

---

## 7. 验证方案（ActVerify headless，沿用现有真跑方式）

新增 `scripts/combat/ActVerify.gd` + `scenes/combat/ActVerify.tscn`，断言：
1. **继承一致**：`generate_acts()` 后 `deck/relic_ids/gold` 与开局相同；`advance_act()` 后三者在幕间不变。
2. **回血**：`advance_act()` 后 `hp == prev + round(max_hp*heal_pct)`（且不超过 `max_hp`）。
3. **幕推进**：`advance_act()` 后 `current_act+1`、`current_floor==0`、`current_map()` 为下一幕生成地图（结构非空、含 boss 节点）。
4. **非终幕 Boss ≠ 胜利**：模拟 Act1 Boss 胜利 → `is_active==true`、`victory==false`、`act_cleared_flags[0]==true`。
5. **终幕 Boss = 胜利**：模拟最后一幕 Boss 胜利 → `end_run(true)`、`victory==true`、`is_active==false`。
6. **存档 v2 往返**：`to_save_dict`→写盘→`from_save_dict`，断言 `current_act` / `act_cleared_flags` / 每幕 `visited`/`enemy_ids`/`links` 全字段一致；`SAVE_VERSION==2`。
7. **拒绝**：损坏 JSON 拒绝；`version==1` 拒绝（或迁移，按 §4.1 决策）。
8. **回归**：`SaveVerify`(改后) / `CombatTest` / `P3Verify` / `DifficultyVerify` / `PauseVerify` / `PlaythroughTest`(改遍历 act_maps) 全绿。

> 输出 `ACT_RESULT:PASS/FAIL`，与现有 `SAVE_RESULT`/`PAUSE_RESULT` 一致。

---

## 8. 实施优先级（按你"先设计→逐层确认→再实现"的工作流）

| 阶段 | 内容 | 关键文件 | 验收 |
|------|------|----------|------|
| **P-A 数据层 ✅(2026-08-18)** | `map.json`→`acts` 数组；`GameData.act_configs`；`RunState` 加 `act_maps/current_act/act_cleared_flags` + `generate_acts/current_map/current_act_config/is_last_act/advance_act` + 当前幕版 `total_floors/is_boss_floor`；`MapGenerator` 加 `boss_id`；`to_save_dict/from_save_dict` 升 v2（`current_act/act_cleared_flags/act_maps`）；`SaveManager` 升 v2 + 旧档清理 | `data/map.json`, `GameData.gd`, `RunState.gd`, `MapGenerator.gd`, `SaveManager.gd`, `SignalBus.gd` | ✅ 已验证：`ActVerify` 25/0（`ACT_RESULT:PASS`） |
| **P-B 流程层 ✅(2026-08-18)** | `SignalBus.run_won`（终幕胜利广播）；`RunState.advance_act`；`MapUI` 逐幕绘制 + 幕间转场屏 + 非终幕 Boss→进幕 + 顶部"第 N 幕"标签；移除 `map` getter | `SignalBus.gd`, `RunState.gd`, `MapUI.gd`, `PlaythroughTest.gd`, `MapTest.gd`, `SaveVerify.gd`, `PauseVerify.gd` | ✅ 已验证：`PlaythroughTest` 全幕打通（`PLAYTHROUGH_RESULT:PASS`）；`MapPlay` 干净启动；全套件回归零 FAIL |
| **P-C 存档层 ✅(2026-08-18)** | `SAVE_VERSION` 1→2（P-A 已做）；`SaveManager` 接 `act_changed`→`save_game()`；`RunState.start_new_run` 装配期 `is_active=false` 防误存 | `RunState.gd`, `SaveManager.gd`, `ActVerify.gd` | ✅ 已验证：`ActVerify` 30/0（`ACT_RESULT:PASS`）；全套件回归零 FAIL |
| **P-D 内容层 ✅(2026-08-18)** | 8 新敌 + Boss 窑心·烬（enemies.json 共 20 敌）；三幕 `enemy_pool/act_hp_mult/act_dmg_mult`（1.0/1.15/1.30）；Act2 boss_id=kilnheart_ember；编成 acts 隔离 + F/G/H/I；`scaled_enemy_hp/damage` 乘幕乘子；`_roll_enemy_intent` 接伤害缩放；数值闭环见台账 §D | `data/enemies.json`, `data/map.json`, `GameData.gd`, `MapGenerator.gd`, `CombatController.gd`, `ActVerify.gd` | ✅ 已验证：`ActVerify` 43/0；数据校验零 error；15 套件回归零 FAIL |
| **P-E 验证层 ✅(2026-08-18)** | `ActVerify` 补齐 §7 缺口断言（幕间继承一致/current_floor 重置/非终幕不结束），共 49 断言；全套件最终回归 + BalanceSweep 基线 | `ActVerify.gd` | ✅ 已验证：`ACT_RESULT:PASS`（49/0）；16 套件回归零 FAIL；BalanceSweep PASS（Act1 基线未破） |

> 严格逐层：P-A 完成并确认 → P-B → P-C → P-D → P-E。每层用 Godot headless 真跑验证，沿用 `--headless --path . <scene> --quit-after N` + grep `PASS/FAIL`。

---

## 9. 关键抉择（已拍板，2026-08-18）

| # | 抉择 | 结论 |
|---|------|------|
| 1 | 幕数 | **3 幕**：Act1 陶原初探(复用现 10 层) / Act2 炽窑升焰(9 层) / Act3 窑主终焰(8 层) |
| 2 | 幕间回血 | **比例回血**：进 Act2 +30% max_hp、进 Act3 +20% max_hp（`transition_heal` 字段） |
| 3 | 终幕 Boss | **复用「窑主·熾」**（Act3 加更高 `act_hp_mult/act_dmg_mult`）；Act2 新增 1 个 Boss「窑心·烬」 |
| 4 | 旧档兼容 | **拒绝 v1 旧档**：`from_save_dict` 仅接受 `version==2`，`<2` 直接 `return false` + 提示"版本过旧请新游戏" |
| 5 | `map.json` 改造 | **原地改 `acts` 数组**：`{ "acts": [act1, act2, act3] }`；`GameData.map_config`→`GameData.act_configs`；旧单幕结构不再保留 |

> 以上确认后，按 P-A→P-E 逐层实现并用 headless 真跑验收（沿用 P0~P4 已建立的验证习惯）。占位数值（层数/缩放/敌池）在 P-D 由数值策划校准，脚本不写死。
