# 项目变更日志（CHANGELOG）

> 由 19 份进度/任务报告合并精简而来（2026-08-20）。细节追溯见 git 历史。
> 当前真相以 `DESIGN_KNOWLEDGE_BASE.md` + 运行期 `data/` 为准。

## 2026-08-14 · 基础搭建与战斗骨架
- **T1 数据层与基础设施**：世界观重构 `WORLD_SETTING.md` v2（67 项设定自洽）；Resource 数据类 ×4；Autoload 三件套（SignalBus/GameData/RunState）；占位美术；`Boot.tscn` 冒烟 6/6 通过。收敛为"数据层+基础设施+占位美术"，战斗/地图归入 T2+。
- **T2 战斗系统骨架**：回合/能量/出牌/格挡/状态/14 种 effect 落地。关键决策：**格挡在玩家下回合开始时清空**（先扛过敌人攻击），修正初版"攻击前清空格挡形同虚设"。
- **T3 地图生成**：地图生成 + 地图UI + 进入闭环 12/12 PASS；`MapPlay` 打通"地图→战斗→返回"完整闭环。通过 `pending_enemy_ids` 钩子复用 CombatUI 支持任意编成。
- **QA VFX 验收**：VFXSystem + CombatUI 六信号接线 + `_refresh_enemy` in-place 根因修复（面板重建野指针）；加载规模 卡43/敌20/状态9/遗物10。决策落实：震屏保留 / 飘字分别 / vfx.json 验收后迁 / 立绘不做。无阻塞，建议发版前一次人工目视。

## 2026-08-17 · 内容深化 + 难度归位
- **P1 内容深化**：新增意图类型 `charge`（蓄力/telegraph 预告）；事件系统数据驱动。TelegraphVerify 6 + EventsVerify 5 通过，84 断言 0 FAIL，无回归。
- **P2 新机制**：战斗内新增资源**窑温 kiln_heat**；`data/statuses.json` 新增 3 状态（蓄焰/釉光/焦渴）；灰颂者新增 `drain`→焦渴 debuff。P2Verify 9 断言全过。
- **P3 内容扩展**：新增 8 张 per-build 终盘卡；编成表 A/B/C/D + 楼层门控 + 加权抽选；Boss 三阶段（`phase_index`）。难度系数不变。
- **难度系数归位（关键）**：撤销开发期折扣（伤害 ×0.65→×1.0、HP ×0.8→×1.0、单场 ≤2→≤3、精英频率 0.1→0.18），调回设计值。新增第 3 精英敌「熔渣兽 slagbeast」。`DifficultyVerify` 套件；PlaythroughTest 正式难度下仍 11/0 打通。
- **数值管理规范落地**：`AGENTS.md` §10 新增强制引用 `NUMERIC_CONVENTION.md` / `NUMERIC_LEDGER.md`（"文档==代码"铁律）。
- **策划案两处冲突对齐**：格挡清空时机、卡牌数量 36 vs 35 → 三处文档现已一致。

## 2026-08-18 · 存档 + 多幕扩展（P-A~P-E 全完）
- **P4 存档读档**：运行态落盘 `user://save.json`，支持中途退出续玩（`SAVE_VERSION=1`）。范围约定：本轮只做存档读档，多幕交由策划出详细设计。
- **P4 退出/续玩 UI**：退出与续玩界面落地。
- **多幕扩展 P-A 数据层**：`map.json` 原地改为 `acts` 数组（破坏旧单幕结构）；`SAVE_VERSION` 1→2 拒绝并删除 v1 旧档；新增 `ActVerify` 验证场景。
- **P-B 流程层**：地图逐幕绘制、幕间转场、非终幕 Boss 进下一幕、顶部"第 N 幕"标签；移除 `RunState.map` 兼容 getter，调用方改 `current_map()`。
- **P-C 存档层**：`SignalBus.act_changed` 连接 `_on_act_changed` → 自动 `save_game()`；ActVerify 修复 is_active 残留缺陷后零 FAIL。
- **P-D 内容层**：Act2/3 新敌池 + 新 Boss「窑心·烬」+ 每幕缩放系数（Act1 1.0 / Act2 1.15 / Act3 1.30）实装。数值走完整闭环：草案入台账 §D → 吴总批准 → 写入数据 → 验收。formations 增 `acts` 字段（A-E→Act1；F/G→Act2；H/I→Act3）；`scaled_enemy_hp/damage` ×当前幕乘子；编成按幕数值比较过滤。ActVerify 43/0 PASS。
- **P-E 验证层收官**：补齐 ActVerify 缺口断言（§7.1/7.3/7.4），最终全套件回归确认 Act1 基线未被破坏。`MULTIACT_EXPANSION_DESIGN.md` 状态置"全部完成"。

## 2026-08-20 · 知识库整理与残留清理
- **策划案知识库**：新建 `DESIGN_KNOWLEDGE_BASE.md` 单一入口（文档清单/运行期真相/已拍板决策/系统状态矩阵/未完成项）。
- **Design JSON 镜像修复**：`Design/*.json` 此前与 `data/` 脱节（10敌/6状态/35卡/单幕/easy×0.65），重新生成为 `data/` 精确副本（20敌/9状态/43卡/3幕/normal×1.0）。
- **状态旗翻转（已确定）**：GAME_SPEC（多幕/世界观入 Confirmed、难度归位 normal、规模 3幕）；MULTIACT §0/§5 待拍板→已确定；GAMEPLAY_ENRICH_PLAN §6/§7 全完；WORLD_SETTING §10 Boss悲剧/卡名已定；GameIdentity 难度与规模同步、多幕移出 Pending。
- **残留清理**：删 `logs/` 临时调试产物（balance_sweep_*.txt + 各验证 log + 探针 py）；修正文档/代码中"单幕/×0.65"陈旧表述（WORLD_SETTING/GAMEPLAY_DESIGN/SYSTEM_DESIGN/GAMEPLAY_ENRICH_PLAN/MapGenerator.gd）为 3幕/normal×1.0；知识库 O9/O11 收敛。
- **文档合并**：19 份进度/任务报告合并为本文档。
- **Design JSON 镜像删除**：`Design/*.json`（CARD_LIST/ENEMY_LIST/STATUS_LIST/RELIC_LIST/MAP_DESIGN/BALANCE_TABLE）删除，统一以运行期 `data/` 为权威源，杜绝再次脱节。

## 仍待决策（未清，需用户/Art/数值策划）
- O1 正式游戏名 ✅ 已确认：中文《炽窑》/ 英文 *Ember's Kiln*（工程名"杀戮尖塔1"已弃用）
- O2 音效与音乐方向
- O4 原创角色/敌人立绘（用户决策"先不做"）
- O5 窑口镇可见起始场景
- O6 VFX 人工目视验收（自动化 9/9 通过，NOT VERIFIED）
- O7 `data/vfx.json` 迁移（验收后数据驱动）
- O8 BalanceSweep 残留"过易"WARN（~25，卡 0.85 边界，数值策划决定）
