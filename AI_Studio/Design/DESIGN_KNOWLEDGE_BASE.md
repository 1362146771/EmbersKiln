# 策划案知识库总览（Design Knowledge Base）

> **用途**：把《炽窑》（*Ember's Kiln*）项目至今所有策划案汇集为单一可检索入口，区分「已确定 / 未确定」，并汇总未完成内容。
> **整理日期**：2026-08-20
> **整理动作**：① 把各设计文档中因实现完成而失效的「待拍板 / 待确认 / Pending」状态翻为「已确定」；② 汇总未完成项；③ 2026-08-20 残留清理——删除 `Design/*.json` 文档镜像（已与 `data/` 对齐后**直接删除**，杜绝再次脱节）、19 份进度报告合并为 `Reports/CHANGELOG.md`。
>
> **唯一事实来源（Source of Truth）**：运行时数据以 `res://data/*.json` 为准（由 `GameData` 加载）。`AI_STUDIO/Design/*.json` 文档镜像已删除，任何数值以 `data/*.json` + `NUMERIC_LEDGER.md` 为准；人读摘要见本文「运行期真相表」。

---

## 0. 文档清单（Inventory）

| 文件 | 类型 | 职责 | 状态 |
|------|------|------|------|
| `GAME_SPEC.md` | 主规格 | 范围 / Confirmed / Pending / UI 规范 | ✅ 已更新（多幕入 Confirmed，难度归位） |
| `SYSTEM_DESIGN.md` | 系统架构 | 16 个系统职责与边界 | ✅ 稳定 |
| `GAMEPLAY_DESIGN.md` | 玩法 | 核心循环 / 回合 / 结算 / 节点 | ✅ 稳定 |
| `WORLD_SETTING.md` | 世界观 | 陶土世界·炽窑设定 v2 | ✅ 已更新 §10 |
| `ART_STYLE.md` | 美术 | 明亮扁平卡通风 / 色板 | ✅ 稳定（立绘细化未做） |
| `VFX_DESIGN.md` | 视觉反馈 | VFX 架构 v2（解耦根因修复） | ✅ 已实现（人工目视 NOT VERIFIED） |
| `GAMEPLAY_ENRICH_PLAN.md` | 玩法丰富化 | P0~P4 路线图 + 数值闭环 | ✅ 已更新 §6/§7 |
| `MULTIACT_EXPANSION_DESIGN.md` | 多幕扩展 | 3 幕串联设计 | ✅ 状态「全部完成」，§5 待拍板已清 |
| `NUMERIC_CONVENTION.md` | 数值纪律 | 硬性原则 + 闭环工作流 | ✅ 稳定 |
| `NUMERIC_LEDGER.md` | 数值台账 | 每个数值的闭环追踪（唯一可追溯） | ✅ 稳定 |
| `../Memory/GameIdentity.md` | 长期记忆 | 项目身份 / 已确认规则 | ✅ 已更新 §9/§10 |

> 注：`Design/*.json` 文档镜像已于 2026-08-20 **删除**（与 `data/` 对齐后直接移除，避免再次脱节）；人读摘要见本节「运行期真相表」。配套报告已合并为 `AI_STUDIO/Reports/CHANGELOG.md`。

---

## 1. 运行期真相表（Ground Truth，来自 `data/`）

| 维度 | 当前值 | 来源 |
|------|--------|------|
| 引擎 / 语言 | Godot 4.7.1 / GDScript，mobile 渲染器，数据驱动 | `GAME_SPEC` / `project.godot` |
| 职业 | 仅「战士」单职业 | `GAME_SPEC` |
| 平台 | 手机端竖屏优先（720×1280，9:16） | `GAME_SPEC` UI 规范 |
| 幕结构 | **3 幕串联**：Act1 陶原初探(10 层) / Act2 炽窑升焰(9 层) / Act3 窑主终焰(8 层)，每幕 1 Boss | `data/map.json` acts |
| 敌人总数 | **20**（11 原生 + 9 新增：slagbeast/kilnwarden/cindermoth/meltgolem/kiln_captain/cinderfiend/magmawhelp/coalseer/ember_eater + Boss 窑心·烬） | `data/enemies.json` |
| Boss | Act1/Act3 = 窑主·熾（chi_the_first）；Act2 = 窑心·烬（kilnheart_ember） | `data/map.json` boss_id |
| 状态数 | **9**（heat/temper/crazed/damp/ashrot/anneal/stoke/glaze/thirst） | `data/statuses.json` |
| 遗物数 | **10**（emberheart 为 starter） | `data/relics.json` |
| 卡牌数 | **43**（35 原生 + 8 per-build 终盘卡） | `data/cards.json` |
| 玩家 | max_hp 80 / 能量 3 / 抽牌 5 / 手牌上限 10 / 格挡下回合开始清空 | `data/balance.json` |
| 难度 | `normal`：敌人伤害 ×1.0、HP ×1.0、单场最多 3 敌、精英频率 0.18→0.24（按幕递增） | `data/balance.json` + `data/map.json` |
| 幕缩放 | Act1 1.0 / Act2 1.15 / Act3 1.30（乘全局 enemy_scaling） | `data/map.json` acts |
| 窑温机制 | 阈值 5 → 对全体贯穿 5 伤；常量已迁入 `data/balance.json → kiln_temperature` | `data/balance.json` |
| 事件 | 5 个（数据驱动 `data/events.json`） | `data/events.json` |
| 存档 | `user://save.json`，`SAVE_VERSION=2`；拒绝 v1 旧档 | `SaveManager` / `RunState` |

---

## 2. 已拍板 / 已确定（原「未确定」→ 因实现完成翻为确定）

> 每项标注落地日期与验证证据。优先级高到低。

| # | 决策 | 原状态 | 结果 | 证据 |
|---|------|--------|------|------|
| 1 | 多幕扩展（Act2/3） | Pending / 待实现 | ✅ **P-A~P-E 全完**（3 幕串联 + 幕间回血 + 存档 v2 + 幕缩放 + 敌池隔离） | `MULTIACT_EXPANSION_DESIGN.md`「全部完成」；`UPDATE13`；ActVerify 49/0 |
| 2 | 难度归位 | 独立步骤待做 | ✅ 伤害 ×0.65→1.0、HP ×0.8→1.0、上限 2→3、精英频率 0.1→0.18、+第 3 精英敌熔渣兽 + 编成 E | `GAMEPLAY_ENRICH_PLAN §5.3`；DifficultyVerify 14/0；台账 G-01~G-05 |
| 3 | 敌人偏易修正 v1 + v1.1 高伤 | 待决策 | ✅ 普通怪 HP×1.8/攻击×1.4 → 再补 ≥22 高伤技压过护盾；Boss 140→150 | `NUMERIC_LEDGER §C / §C-b`；BalanceSweep v4 1PASS/0FAIL/25WARN |
| 4 | 世界观 / 叙事 | Pending | ✅ v2「陶土世界·炽窑」落地（与暖色卡通风一致） | `WORLD_SETTING.md` |
| 5 | Boss 为悲剧型前辈 | 待确认 | ✅ 已落地（两阶段 + P3 觉醒阶段） | `WORLD_SETTING §6.4` / `GAMEPLAY_ENRICH_PLAN §4.3` |
| 6 | 卡牌 v2 中文名 | 待确认 | ✅ 43 张全量采用（敲釉/引火/收火/熔身…） | `WORLD_SETTING §7.4` / `CARD_LIST.json` |
| 7 | 窑温共鸣机制 | 待拍板 | ✅ P2 落地；阈值/贯穿已迁入 `balance.json`（G-11/G-12 闭环） | `GAMEPLAY_ENRICH_PLAN §2.4`；P2Verify 9/0；台账 §B |
| 8 | 多敌 + 目标选敌 UI | 待拍板 | ✅ P0 落地（max_enemies=3 + 编成 A~I） | `GAMEPLAY_ENRICH_PLAN §2.2/§4.2` |
| 9 | Boss 三阶段觉醒 | 待拍板 | ✅ P3 落地（<25%HP 自+3 窑温 + AOE6+2 釉裂） | `GAMEPLAY_ENRICH_PLAN §4.3`；P3Verify 29/0 |
| 10 | 遗物系统接入战斗 | 待做 | ✅ 10 遗物全钩子接入 | RelicTest 9/0 |
| 11 | 奖励三选一 / 升级 / 商店 / 休息 / 事件 / 宝箱 | 待做 | ✅ P0~P1 落地 | EventsVerify 5/0 等 |
| 12 | 存档读档 | 待做 | ✅ P4 落地（v2，全字段往返 + 版本拒绝） | SaveVerify 21/0 |
| 13 | 退出 UI（MainMenu / Pause） | 待做 | ✅ P4 落地（续玩重建 / 关窗强存档） | PauseVerify 13/0 |
| 14 | VFX 视觉反馈系统 | 待做 | ✅ 已实现（自动化 9/9 + 进战斗冒烟 PASS） | `VFX_DESIGN §13`；`QA_REPORT_VFX`；VFXVerify 9/9 |
| 15 | 新状态（蓄焰/釉光/焦渴） | 待做 | ✅ P2 落地 | P2Verify 9/0 |
| 16 | 编成表按幕隔离（F/G/H/I） | 待做 | ✅ P-D 落地 | `NUMERIC_LEDGER §D` MA-24 |

---

## 3. 系统状态矩阵（按 P0~P4 + 独立扩展）

| 系统 | 阶段 | 状态 | 验证证据 |
|------|------|------|----------|
| 遗物接入战斗 | P0 | ✅ | RelicTest 9/0 |
| 战后奖励三选一 | P0 | ✅ | RewardUI 接入战斗胜利 |
| 卡牌升级 | P0 | ✅ | `RunState.upgrade_card_at` |
| 多敌编成 + 目标选敌 | P0 | ✅ | MapGenerator + `play_card(target_index)` |
| 商店 / 休息增强 / 事件 / 宝箱 | P1 | ✅ | EventsVerify 5/0 / MapTest / Shop |
| 意图多样化（蓄力 / telegraph） | P1 | ✅ | TelegraphVerify 6/0 |
| 窑温共鸣 | P2 | ✅ | P2Verify 9/0 |
| 新状态（蓄焰/釉光/焦渴） | P2 | ✅ | P2Verify 9/0 |
| 卡池深化（43 卡） | P3 | ✅ | P3Verify 29/0 |
| Boss 三阶段觉醒 | P3 | ✅ | P3Verify 29/0 |
| 难度归位 | 独立 | ✅ | DifficultyVerify 14/0 |
| 敌人偏易修正 | 独立 | ✅ | BalanceSweep v4 + CombatTest 20/0 |
| 存档读档 | P4 | ✅ | SaveVerify 21/0 |
| 退出 UI | P4 | ✅ | PauseVerify 13/0 |
| 多幕扩展（P-A~P-E） | 独立 | ✅ | ActVerify 49/0；PlaythroughTest 全幕 27 层打通 |
| VFX 系统 | 独立 | ✅ 自动化 / ⏳ 人工目视 | VFXVerify 9/9；人工目视 NOT VERIFIED |

> 全量回归：最近一次（2026-08-18）16 套件零 FAIL；VFX（2026-08-20）9/9 PASS。

---

## 4. 未确定 / 未完成项汇总（Open / Incomplete）

> 这些是**真正还没定或没做**的，不应由 Agent 自行假设。

### 4.1 需人工拍板的「未确定」
| # | 项 | 现状 | 影响 |
|---|----|------|------|
| O1 | **正式游戏名** | ✅ 已确认：中文《炽窑》/ 英文 *Ember's Kiln*（原工程名「杀戮尖塔1」已弃用） | 已闭环 |
| O2 | **音效与音乐方向** | 从未定义 | 影响整体体验，需 Audio 策划 |
| O3 | **Meta 进度（跨局成长）** | 明确**不做**，留作后续 | 已决策；非阻塞 |
| O4 | **角色 / 敌人原创立绘细化** | sprite 为占位名，UI 当前不消费；立绘替换属 Art 独立排期 | 影响美术完成度（玩法不阻塞） |
| O5 | **窑口镇可见起始场景** | 当前为纯 UI 教学，未列入 v1 | 影响沉浸感，非阻塞 |

### 4.2 已做自动化、待人工确认的「未完成」
| # | 项 | 状态 | 下一步 |
|---|----|------|--------|
| O6 | **VFX 人工目视验收** | NOT VERIFIED | 编辑器 `Reload Current Project` 后进战斗目视（飘字/震屏/死亡淡出观感） |
| O7 | **data/vfx.json 迁移** | MVP 参数写在 `VFXSystem` 常量 | 验收后迁 `data/vfx.json`，Designer 可调不碰代码 |

### 4.3 数值 / 平衡待决策
| # | 项 | 现状 | 建议 |
|---|----|------|------|
| O8 | **BalanceSweep 残留「过易」WARN（~25，卡 0.85 边界）** | v4 起即存在的热身怪边界项，无不可战胜 / 无 Boss 秒杀 | 由数值策划决定：继续加压普通怪耐性，或放宽 `too_easy_hp_ratio` 探针 |
| O9 | 世界观「火种低难度」叙事 vs 难度归位值 | ✅ **已收敛**：2026-08-20 `WORLD_SETTING §3/§5.4` 已随归位更新（3 幕分层、系数 ×1.0/×1.0/≤3，火种保留为叙事性解释） |

### 4.4 文档 / 工程一致性（本次整理已处理 / 待确认）
| # | 项 | 现状 |
|---|----|------|
| O10 | **Design JSON 镜像脱节** | ✅ **已删除**：2026-08-20 对齐 `data/` 后直接删除 `Design/*.json` 6 个镜像副本，统一以运行期 `data/` 为权威源，杜绝再次脱节 |
| O11 | `scenes/map/MapTest.gd` 重复文件 | ✅ **已确认无重复**：两次 `find` 仅 `scenes/map/MapTest.tscn` + `scripts/map/MapTest.gd`(+.uid) 一套，`UPDATE13` 所述疑似误报 |
| O12 | `AI_STUDIO/Tasks/` 空目录 | 任务由 TaskCreate 工具管理（非文件），符合 AGENTS.md；非缺陷 |

---

## 5. 数值闭环速查（详见 `NUMERIC_LEDGER.md`）

- **A 组**（BalanceSweep 探针参数，11 项，闭环完成）
- **B 组**（关键既有玩法值，G-01~G-14，含难度归位 / 玩家 / Boss / 起始牌组 / 窑温阈值）
- **C 组**（敌人基础属性偏易修正 v1 + v1.1，E-01~E-11a，全落地）
- **D 组**（多幕扩展 P-D 内容层，MA-01~MA-24，全闭环完成）

> 铁律：代码数值必须与 `data/*.json` + `NUMERIC_LEDGER.md` + 策划案三处一致；QA 负责核对。

---

## 6. 一句话结论

**玩法层（战斗 / 多幕 / 数值 / 存档 / VFX）已全量可玩并通过自动化验证；剩下的都是「上层包装」——正式命名、音效、原创立绘、窑口镇场景，以及一次 VFX 人工目视。** 策划案文档本身已从「v1 单幕草案」同步到「3 幕已落地」现状，文档与代码数值现已一致。
