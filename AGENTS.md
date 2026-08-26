# AGENTS.md

# AI Game Studio — Codex Project Rules

本文件是整个 AI Game Studio 项目的最高级协作规则。

所有 Codex Agent / Thread 在开始重要任务前都应该阅读本文件。

如果本文件与某个 Agent 角色文件发生冲突：

1. 优先遵守本文件
2. 再遵守当前 Task
3. 再遵守对应 Agent Role 文档
4. 最后参考其他设计文件

如果用户在当前任务中明确提出新要求，则以用户最新明确要求为准，并在必要时同步更新项目文档。

---

# 1. Project Goal

本项目使用 Codex 构建一个轻量的 Multi-Agent AI Game Studio，用于开发 **Godot 4.x 2D 卡组构筑 Roguelike 游戏**（杀戮尖塔 / Slay the Spire 风格）。

目标不是一次性生成大量代码，而是形成：

```text
需求
 ↓
设计
 ↓
开发
 ↓
Integration
 ↓
QA
 ↓
修复
 ↓
再次验证
```

的持续开发闭环。

---

# 2. Core Agents

当前核心角色：

```text
Producer
Designer
Programmer
Art
QA
```

对应文件：

```text
AI_STUDIO/Agents/

Producer.md
Designer.md
Programmer.md
Art.md
QA.md
```

---

# 3. Agent Responsibility

## Producer

负责：

- 理解需求
- 拆任务
- 排优先级
- 管理依赖
- 决定下一阶段

Producer 默认不负责大段 Coding。

---

## Designer

负责：

- System Design
- Gameplay Design
- Content
- Balance

Designer 定义：

> 游戏应该怎么工作。

不直接负责 Godot 实现。

---

## Programmer

负责：

- Godot 4 GDScript
- 战斗 / 回合 / 状态机
- 系统实现
- 数据结构
- 数据加载与 Resource
- Integration Support

Programmer 定义：

> 如何在 Godot / GDScript 中实现设计。

---

## Art

负责：

- Art Direction
- Sprite
- 卡面 / UI Art
- VFX
- Animation
- Visual Consistency

Art 不负责 Gameplay Rule。

---

## QA

负责：

- 编辑期 / 运行期 QA
- 功能 QA
- 场景 / 节点 QA
- 视觉 QA
- Bug Report

QA 默认不直接修改 Gameplay Code。

---

# 4. Shared Project Memory

Agent 不应该只依赖 Thread 对话记忆。

长期稳定信息必须写入项目文件。

核心长期记忆：

```text
AI_STUDIO/Memory/GameIdentity.md
```

开始重要任务前应优先读取。

---

# 5. Source of Truth

推荐优先级：

```text
用户最新明确要求
		↓
当前 Task
		↓
GAME_SPEC.md
		↓
System / Gameplay / Balance 等设计文档
		↓
GameIdentity.md
		↓
Agent Role 文档
```

如果发现冲突：

不要自行选择一个版本继续。

应明确报告：

```text
CONFLICT FOUND
```

并要求 Producer / Designer 统一。

---

# 6. Design Files

推荐位置：

```text
AI_STUDIO/Design/
```

可能包含：

```text
GAME_SPEC.md
SYSTEM_DESIGN.md
GAMEPLAY_DESIGN.md

CARD_LIST.json
ENEMY_LIST.json
RELIC_LIST.json
STATUS_LIST.json
MAP_DESIGN.json

CONTENT_DB.json
BALANCE_TABLE.json
ART_STYLE.md
ART_REQUIREMENTS.md
```

不是所有项目都必须一次拥有所有文件。

---

# 7. Task System

任务放：

```text
AI_STUDIO/Tasks/
```

推荐命名：

```text
TASK-001_CardPlayAndEnergy.md
TASK-002_EnemyIntent.md
TASK-003_DeckDrawDiscard.md
TASK-004_MapGeneration.md
```

每个任务尽量包括：

```md
# TASK

## Goal
## Owner
## Input
## Requirements
## Acceptance Criteria
## Allowed Changes
## Forbidden Changes
## Dependencies
```

---

# 8. Task Scope Rule

Agent 只处理当前任务范围。

不要因为：

> “顺便可以优化”

就修改大量无关系统。

如果发现新的问题：

创建建议或新 Task。

不要无边界扩张当前 Task。

---

# 9. Coding Rules

## Language

Godot 4 项目默认：

```text
GDScript
```

复杂算法或性能热点可谨慎使用 C#（通过 Godot .NET），但默认优先 GDScript，保持团队一致。

---

## Basic Principles

代码应尽量：

- 清晰
- 模块化
- 单一职责
- 可测试
- 可扩展
- 不过度设计

---

## Existing Code First

修改前必须先阅读相关代码。

不要在不知道已有架构的情况下：

- 重复造系统
- 重复造 Base Class
- 重复造 Signal / Event 总线
- 重复造 Data Model
- 重复造 Resource 定义

---

# 10. Data Driven Rule

游戏内容数值尽量不要硬编码。

> **数值管理规范（强制）**：任何影响玩法/平衡的数值（配置、阈值、奖励、概率、上限、系数）的提出、策划确认、代码写入、策划案回填必须走完整闭环，且脚本不得硬编码数值。详见 `AI_Studio/Design/NUMERIC_CONVENTION.md`，唯一可追溯台账见 `AI_Studio/Design/NUMERIC_LEDGER.md`。未定义数值须提报策划，禁止实现方自填。

例如：

- Card
- Enemy
- Status / Buff
- Relic
- Map Node
- Economy

优先使用项目已经采用的数据体系：

```text
Godot Resource (.tres)
JSON
CSV
其他配置
```

如果项目尚未决定，不要擅自同时引入多套数据方案。

推荐：卡牌 / 敌人 / 遗物 / 状态用 Godot Resource（自定义 Resource 类）或 JSON 描述，由 DataLoader 在运行时加载。

---

# 11. Godot Rules

## Runtime

注意 Godot 节点生命周期：

```text
_init
_enter_tree
_ready
_process
_physics_process
_notification(NOTIFICATION_*)
_exit_tree
```

理解 `_ready` 与 `_enter_tree` 的时机差异；跨场景状态用 Autoload / 单例（如 RunState、SignalBus）。

---

## Performance

避免：

- 每帧无意义 `get_node` / `find_child`
- 每帧大量 Array / Dictionary 分配
- 高频 `instance()` / `queue_free()`（必要时用对象池）
- 不必要 GC Alloc
- 大量重复资源加载

性能优化应符合项目当前规模，不提前做复杂过度优化。

---

# 12. Godot Directory

推荐结构：

```text
res://

scripts/
  core/          # RunState, CombatController, TurnManager, SignalBus
  cards/         # CardBase, CardEffect, CardDatabase
  enemies/       # EnemyBase, EnemyAI
  status/        # StatusEffect
  relics/        # Relic
  map/           # MapGenerator, MapNode
  events/        # GameEvent
  ui/            # CombatUI, MapUI, HandUI, RewardUI
  data/          # DataLoader

scenes/
  combat/
  map/
  main/
  shop/
  rest/
  event/

data/            # .tres / .json
  cards/
  enemies/
  relics/
  status/
  events/

art/
tests/           # Gut 单元测试
```

如果项目已经存在结构：

优先遵循已有结构。

不要为了符合模板大规模搬目录。

---

# 13. Art Rules

所有视觉资源应优先遵循：

```text
ART_STYLE.md
```

如果不存在：

Art Director 负责建立。

Gameplay / UI Agent 不应绕过 Art Director 随意定义全新视觉风格。

---

# 14. Git Rule

默认禁止直接在 `main` 上进行大型功能开发。

推荐：

```text
main
 |
develop
 |
integration
 |
agent/*
```

具体项目可以简化。

---

# 15. Worktree Rule

不同独立开发任务可以使用不同 Worktree。

例如：

```text
worktree/combat
worktree/map
worktree/art
```

一个 Worktree 应尽量对应一个清晰任务域。

不要为了每个小操作创建新的 Worktree。

---

# 16. Branch Rule

推荐：

```text
agent/combat-xxx
agent/map-xxx
agent/art-xxx
fix/xxx
```

Agent 默认：

可以：

- 修改
- Commit
- 报告完成

不应擅自：

- Force Push
- 删除其他 Branch
- 重写别人历史
- 直接合并 main

---

# 17. Integration Rule

Integration 的含义：

> 将多个独立任务成果组合起来验证。

它不是单纯一个 Git 命令。

推荐：

```text
Combat
  Map ----> Integration Branch
  /
Art
	   ↓
Godot Run / Gut Test
```

Integration 通过后再进入最终 Merge。

---

# 18. Testing Rule

任何 Coding Task 完成后，应根据条件执行：

```text
编辑期 / 解析
 ↓
单元测试 (Gut)
 ↓
Godot 运行测试
 ↓
场景 / 节点
 ↓
视觉
```

并不是每个任务都必须运行所有类型测试。

根据任务选择合理测试范围。

---

# 19. Test Honesty Rule

如果没有真正执行：

```text
Godot 运行
Gut 测试
Build
Screenshot
```

必须明确写：

```text
NOT VERIFIED
```

禁止写：

```text
PASS
```

来替代未执行测试。

---

# 20. Error Handling

如果出现错误：

```text
QA
 ↓
Error Analysis
 ↓
Owner
 ↓
Fix
 ↓
Integration
 ↓
QA
```

形成循环。

---

# 21. Bug Ownership

大致规则：

```text
战斗逻辑 / 卡牌效果
→ Programmer

UI 逻辑
→ Programmer / UI

Sprite / 视觉
→ Art

游戏规则 / 数值
→ Designer

Balance
→ Designer / Balance

Build / Integration
→ Programmer / Integration
```

如果无法确定 Owner：

交给 Producer 判断。

---

# 22. Report Rule

重要任务完成后应留下简短报告。

建议位置：

```text
AI_STUDIO/Reports/
```

例如：

```text
DEV_REPORT_TASK-001.md
QA_REPORT_TASK-001.md
```

报告应尽量简洁。

---

# 23. Communication Rule

Agent 输出应优先：

- 事实
- 当前状态
- 修改内容
- 测试结果
- 风险
- 下一步

避免大量无效的角色扮演语言。

---

# 24. Decision Rule

Agent 可以自行决定：

- 小型代码实现方式
- 命名
- 内部结构
- 小范围重构

Agent 不应自行决定：

- 改变核心玩法
- 删除系统
- 改变产品范围
- 改变主要美术方向
- 增加大型新功能
- 改变经济模型

这些交给 Designer / Producer / 用户。

---

# 25. No Guess Rule

以下内容不清楚时，不要猜：

- 核心规则
- 数值
- 美术方向
- 发布平台要求
- 技术限制
- 数据来源

可以先查项目文件。

仍无法确定时：

明确报告 Blocked。

---

# 26. Minimal Engineering Rule

AI Game Studio 当前阶段不追求过度工程化。

优先：

```text
简单
可运行
可验证
```

然后才是：

```text
抽象
通用化
平台化
```

---

# 27. MVP First

新功能优先实现：

```text
最小可玩版本
```

例如 Card System：

先完成：

```text
抽牌
出牌（消耗能量）
弃牌
伤害 / 格挡
```

再考虑：

```text
复杂状态联动
遗物全局修正
卡牌进化树
大型事件网络
```

---

# 28. Human Approval

遇到以下情况建议等待用户确认：

- 明显改变游戏方向
- 大规模重构
- 删除大量内容
- 高成本功能
- 多个合理设计方案且影响重大
- 无法从现有文档确定需求

---

# 29. Recommended Development Loop

```text
User
 ↓
Producer
 ↓
Designer
 ↓
Task
 ↓
Programmer / Art
 ↓
Integration
 ↓
QA
 ↓
PASS?
 ├─ Yes → Merge / Next Task
 └─ No  → Fix → Integration → QA
```

---

# 30. Core Principle

所有 Agent 共同遵守一个原则：

> 不要把“AI 已经输出了一些东西”当作完成。

真正完成意味着：

- 设计清楚
- 实现正确
- 可以运行
- 可以验证
- 与项目其他部分兼容
