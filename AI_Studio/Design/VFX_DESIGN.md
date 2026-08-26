# VFX_DESIGN.md — 视觉反馈系统设计（v2 重制版）

> **修订说明（为什么重做）**：v1 的 VFX 方案在 `_refresh_enemy()` 上踩了生命周期坑——
> 该函数（CombatUI.gd:354-355）每次刷新都 `for c in enemy_area.get_children(): c.queue_free()`
> 整体销毁并重建敌人面板。VFX 节点挂在面板上，下一帧刷新即被释放成野指针，效果时有时无、死亡淡出
> 根本无法稳定播放。**根因是 VFX 生命周期与 UI 刷新耦合**，不是特效写法问题。本版彻底解耦。
>
> **依据**：`SYSTEM_DESIGN.md §15`（VFXSystem 职责）、`ART_STYLE.md §9`（信息优先）、
> `GAME_SPEC.md《UI 规范（手机端，强制）》`（竖屏/字号/热区约束）。
> **原则**：信息优先于华丽，不做全屏大特效，保持战斗可读（ART_STYLE §9）。

---

## 1. 设计目标

1. 战斗关键事件（出牌 / 伤害 / 格挡 / 状态 / 死亡 / 治疗）都有**稳定可复现**的轻量反馈。
2. VFX 生命周期**完全独立于** `CombatUI` 的面板刷新（`_refresh_*`），不再被 `queue_free` 误杀。
3. 目标定位用**稳定引用（CombatUnit）**，不靠会漂移的下标 `index`。
4. 全部接口数据驱动预留（`data/vfx.json`），数值可调，符合 AGENTS.md《Data Driven Rule》。
5. 竖屏 720×1280 下不挤、不溢出、热区 ≥ 64px（仅影响可点特效，飘字类无热区要求）。

---

## 2. 架构（四层，解耦）

```
SignalBus（事件源，已有）
    │  emit: damage_dealt / block_changed / status_applied / unit_died / card_played / heal 等
    ▼
VFXDirector（调度方，挂在 CombatUI 下或独立 Autoload）
    │  订阅 SignalBus → 查 unit→anchor 映射 → 调 VFXSystem
    ▼
VFXSystem（Autoload 单例，特效工具库）
    │  提供 spawn_* 方法，在 VFXLayer 上创建瞬态节点 + tween，结束 queue_free
    ▼
VFXLayer（持久容器，CombatUI 的子 CanvasLayer / Control）
    │  独立于 enemy_area / player_panel，刷新时不重建
    ▼
CombatantAnchor（每个战斗单位一个，持久 Control，战斗开始建、死亡后才释放）
    └─ VFX 节点挂在 anchor 下（或按 anchor 全局坐标落到 VFXLayer）
```

**为什么这么分**
- `VFXLayer` 与 `CombatantAnchor` 都是**持久节点**，不受 `_refresh_*` 的 `queue_free` 影响 → 根因消除。
- `VFXSystem` 只负责"给定锚点播一段 tween 再释放"，不持有任何战斗状态 → 可复用、可测、零耦合。
- `VFXDirector` 是唯一的"事件→特效"映射处，逻辑集中，改触发规则只动这一层。
- 不新增 SignalBus 信号（已有信号够用），不改动战斗数值逻辑。

---

## 3. 根因修复：UI 刷新改为 in-place 更新（前置重构）

**改动范围（仅 CombatUI，不影响任何战斗规则）**
- `_refresh_enemy()`：从「销毁全部 + 重建」改为「战斗开始时按 `controller.enemies` 一次性创建面板并存进
  `Dictionary[CombatUnit, Panel]`；之后每次刷新只更新已有面板的 HP/意图/状态文本，不 `queue_free`」。
- 新增 `Dictionary unit_panels: Dictionary`（`CombatUnit` → 其面板 `Control`）。
- 敌人死亡时：由 VFXDirector 播放死亡动画后，再统一从 `unit_panels` 移除并 `queue_free` 面板。
- 玩家面板 `player_panel` 早已提升为成员（上一轮已完成），本就持久，无需改。

**效果**：面板成为稳定目标，VFX 可安全挂靠；同时减少每回合大量 `queue_free`/`instance` 的 GC 抖动。

**风险**：仅改面板构建方式，数据来源 `controller.enemies` 不变 → 行为等价，本版验收项之一。

---

## 4. 稳定锚点（CombatantAnchor）

- 战斗开始时，`VFXDirector._setup_anchors()` 为每个 `CombatUnit`（玩家 + 每个敌人）创建一个
  `CombatantAnchor`（`Control`，大小对齐其面板，位置跟随面板），加入 `VFXLayer`。
- 维护 `Dictionary unit_anchor: Dictionary`（`CombatUnit` → `CombatantAnchor`）。
- 锚点**不随 `_refresh_*` 重建**，只在战斗结束或该单位死亡动画播完后释放。
- 目标解析：SignalBus 回调里拿到的 `CombatUnit`（或下标，在回调同步时刻仍有效）立即经
  `unit_anchor[unit]` 取到锚点 → **同步解析，避开下标漂移**。

---

## 5. 效果清单（MVP 必做）

| 效果 | 触发信号 | 视觉 | 颜色（ART_STYLE 调色板） | 时长 | 参数 |
|------|----------|------|--------------------------|------|------|
| 伤害飘字 | `damage_dealt` | 数字上浮 + 淡出（敌人受击=暖橙，玩家受击=珊瑚红） | 敌 `#F0997B` / 玩 `#D85A30` | 0.6s | 上浮 40px，缓出 |
| 格挡闪光 | `block_changed`（增加） | 盾形脉冲一下 | `#378ADD`（蓝，UI 对比冷色） | 0.35s | 缩放 1.0→1.15→1.0 |
| 状态获得 | `status_applied` | 锚点环弹 + 轻微高亮 | 增益 `#5DCAA5` / 减益 `#7F77DD` | 0.4s | 环缩放 0.8→1.2 |
| 出牌反馈 | `card_played` | 玩家锚点闪一下（短促提亮） | `#EF9F27`（琥珀） | 0.25s | 透明度 1→0.6→1 |
| 治疗飘字 | `hp_changed`（增加且非伤害） | 绿色数字上升 | `#5DCAA5`（青绿） | 0.6s | 同伤害飘字 |
| 死亡淡出 | `unit_died`（非玩家） | 缩放 1→0 + 透明度 1→0 | `#7F77DD`（紫灰） | 0.5s | 播完释放 anchor+面板 |
| 受击抖动 | `damage_dealt`（目标为玩家） | 玩家锚点小幅抖动 | — | 0.2s | 偏移 ±6px 衰减 |
| 大伤害震屏 | `damage_dealt`（单次伤害 ≥ 阈值） | 全屏轻微震屏（Camera/CanvasLayer offset） | — | 0.3s | 阈值 `BIG_HIT := 15`，强度随伤害递增，封顶 |

**明确不做（ART_STYLE §9）**：全屏粒子、镜头大爆炸、拖尾、残影等重特效。保持可读。
（震屏仅限大伤害且为轻微位移，非大爆炸；飘字每个伤害事件独立展现，不合并。）

---

## 6. 死亡流程（解决旧方案野指针）

```
unit_died(unit) 触发
  → VFXDirector 解析 unit 的 anchor（此时仍存活，因面板不再每帧重建）
  → VFXSystem.spawn_death(anchor) 播放缩放+淡出（0.5s）
  → tween 完成回调：从 unit_anchor / unit_panels 删除该 unit，queue_free(anchor) + queue_free(panel)
  → 同时通知 CombatController 从 controller.enemies 移除（现有逻辑不变，仅延后到动画后）
```

**关键**：死亡动画在面板释放**之前**播放，且面板释放由 VFX 回调触发，而非 `_refresh_enemy` 的粗暴
`queue_free` → 旧方案的"面板已没、动画挂空"彻底消失。

---

## 7. 接口设计

### 7.1 VFXSystem（Autoload，无 class_name 冲突）
```gdscript
# 全部为瞬态：在 anchor 下创建节点，tween 后自动 queue_free
func spawn_damage(anchor: Control, amount: int, to_player: bool) -> void
func spawn_heal(anchor: Control, amount: int) -> void
func spawn_block(anchor: Control) -> void
func spawn_status(anchor: Control, is_buff: bool) -> void
func spawn_card_played(anchor: Control) -> void
func spawn_death(anchor: Control, on_done: Callable) -> void
func spawn_hit_shake(anchor: Control) -> void
func screen_shake(intensity: float) -> void   # 大伤害震屏，MVP 开启：单次伤害≥BIG_HIT(15) 触发
```

### 7.2 VFXDirector（调度，订阅 SignalBus）
```gdscript
func _on_damage_dealt(is_enemy_source: bool, index: int, amount: int) -> void
    # 同步解析：index 此刻有效；玩家受伤走 player_anchor，否则 enemy_anchor[index]
    var anchor = _resolve_anchor(index, is_enemy_source)
    VFXSystem.spawn_damage(anchor, amount, is_enemy_source)
    if not is_enemy_source:  # 玩家受伤 → 抖动
        VFXSystem.spawn_hit_shake(player_anchor)

func _on_block_changed(...) -> VFXSystem.spawn_block(anchor)
func _on_status_applied(...) -> VFXSystem.spawn_status(anchor, is_buff)
func _on_card_played(...) -> VFXSystem.spawn_card_played(player_anchor)
func _on_hp_changed(...) -> 若 increase 且非伤害 VFXSystem.spawn_heal
func _on_unit_died(unit) -> VFXSystem.spawn_death(anchor, _free_unit_cb)
```

### 7.3 SignalBus（复用，不新增）
已有 `damage_dealt / block_changed / status_applied / unit_died / card_played / hp_changed`
全部复用。`damage_dealt` 首参语义混乱（当前 `not unit.is_player`）→ **建议 CombatController 改为传
`unit` 引用或显式 `target_is_player: bool`**，作为本版配套小改（不碰数值）。

---

## 8. 配置与数据驱动

- MVP 期：时长/缩放写在 `VFXSystem` 常量（`DAMAGE_DUR := 0.6` 等），集中一处。
- 验收后：`data/vfx.json` 承载全部参数（时长、颜色、位移、缩放），由 `VFXSystem` 加载 → 符合数据驱动规范，
  Designer 可调不碰代码。结构示例：
  ```json
  { "damage": {"dur": 0.6, "rise": 40, "enemy_color": "#F0997B", "player_color": "#D85A30"},
    "block":  {"dur": 0.35, "scale": 1.15, "color": "#378ADD"}, ... }
  ```

---

## 9. 性能

- 同屏并发特效 < 10 个，无需对象池；`SceneTreeTween` 自动回收，`queue_free` 在 tween 完成后。
- 飘字/闪光节点极轻（Label / ColorRect / TextureRect），不触发纹理加载。
- 抖动用 tween 改 `position`，不调物理。

---

## 10. 验收（直面"看不到"问题）

1. **编译层**：`run_and_verify` 零错误零警告（VFXSystem / VFXDirector / 接线 / autoload 注册）。
2. **运行时可见层（新增，解决旧盲区）**：建 `VFXVerify.tscn` + `VFXVerify.gd`，
   在独立锚点上依次触发 7 类效果，断言：① 节点创建数 = 预期；② tween 完成后节点已 `queue_free`；
   ③ 死亡回调确实释放了 anchor。通过 `run_and_verify`（临时切主场景或脚本指定场景）跑出 `[VFX_PASS]`。
3. **人工层**：编辑器 Reload 后进战斗，目视确认：出牌闪、敌人受击飘橙字、玩家挨打红字+抖、格挡蓝闪、
   状态环弹、敌人死亡淡出。出 `QA_REPORT_VFX.md`（PASS / NOT VERIFIED）。

> 重要：外部脚本改动后**编辑器必须 `Project → Reload Current Project`**，否则看不到任何更新（历史已踩坑）。

---

## 11. 实施步骤（拆解，严格不破坏战斗逻辑）

| # | 任务 | 范围 | 验收 |
|---|------|------|------|
| 1 | `_refresh_enemy` 改 in-place + `unit_panels` 字典 | CombatUI 仅构建逻辑 | run_and_verify 无错，战斗行为等价 |
| 2 | `VFXLayer` + `_setup_anchors` + `unit_anchor` 字典 | CombatUI 新增节点/字典 | 锚点数量 = 单位数 |
| 3 | 写 `VFXSystem.gd` + `project.godot` autoload | 新文件 | 编译通过 |
| 4 | `VFXDirector` 订阅 6 信号 + 6 回调 | CombatUI 增量 | run_and_verify 无错 |
| 5 | 死亡流程：延后释放 anchor+面板 | CombatUI + VFXDirector | 死亡淡出稳定播放 |
| 6 | `damage_dealt` 首参语义清理（建议） | CombatController 小改 | 不碰数值 |
| 7 | `VFXVerify` 场景 + `QA_REPORT_VFX` | 新文件 + 报告 | `[VFX_PASS]` + 人工目视 |

**禁止改动**：战斗数值、卡牌效果、敌人 AI、存档结构、地图生成。

---

## 12. 范围与决策（已拍板，2026-08-19）

- [x] **保留大伤害震屏**：`screen_shake` MVP 开启，仅单次伤害 ≥ `BIG_HIT(15)` 触发，强度随伤害递增并封顶；非大爆炸，符合手机可读性。
- [x] **飘字分别展现**：每个伤害/治疗事件独立生成一枚飘字，不合并（同回合多次伤害并排多枚）。
- [x] **`data/vfx.json` 验收后迁入**：MVP 期参数写 `VFXSystem` 常量；验收通过后迁 `data/vfx.json`，由 `VFXSystem` 加载，Designer 可调不碰代码。
- [x] **立绘先不做**：玩家/敌人立绘占位替换不在本 VFX 批次内（属 Art 范畴）；本方案只管特效层。此前 CombatUI 已接的玩家立绘占位节点保留，但原创立绘替换另排期。

---
*本文档由 Designer 角色基于 `SYSTEM_DESIGN §15` / `ART_STYLE §9` / 真实代码复盘重制，取代此前未考虑
面板刷新生命周期的 v1 VFX 方案。*

---

## 13. 实施状态（Programmer 实现，2026-08-20）

**状态：已实现并自动化验收通过。**

| # | 任务 | 结果 |
|---|------|------|
| 1 | `_refresh_enemy` 改 in-place + `unit_panels` 字典 | ✅ 落地，面板不再随刷新销毁（根因修复） |
| 2 | `VFXLayer` + 锚点字典（`unit_panels` 映 `CombatUnit→Panel`） | ✅ 落地，锚点按单位引用解析 |
| 3 | `VFXSystem.gd` + autoload（无 class_name，避同名冲突） | ✅ 编译通过 |
| 4 | 订阅 6 信号 + 6 回调（damage/heal/block/status/card/death/hitshake/screenshake） | ✅ 接线生效 |
| 5 | 死亡流程：动画播完释放锚点+面板 | ✅ 无野指针 |
| 6 | `damage_dealt` 首参语义清理 | ✅ 窑变伤害 emit 语义修正 |
| 7 | `VFXVerify` 场景 + `QA_REPORT_VFX` | ✅ 9/9 `[VFX_PASS]` |

**验收证据**
- `VFXVerify.tscn` run_and_verify：**9/9 PASS**，日志 `[VFX_PASS]`。
- `CombatPlay.tscn` run_and_verify：**16.5s 零错误零警告**，日志确认真正进战斗（玩家回合1、敌人=1、手牌=5）—— CombatUI 接线运行时生效。

**四项决策落实**：震屏保留（≥15 触发）/ 飘字分别展现 / `vfx.json` 验收后迁入 / 立绘不做（占位节点保留）。

**遗留（非阻塞）**
- 人工目视验收 NOT VERIFIED：需在编辑器 `Project→Reload Current Project` 后进战斗确认观感（自动化 PASS ≠ 真人体验）。
- `data/vfx.json` 迁移：验收通过后由 Designer 调参迁入。
- 原创角色/敌人立绘属 Art 排期。
