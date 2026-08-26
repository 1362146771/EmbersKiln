# Game Identity

> 这是 AI Game Studio 的长期项目记忆。
>
> Producer、Designer、Programmer、QA 在开始重要任务前都应优先读取。
>
> 这里记录长期稳定的项目方向，不记录临时任务细节。

# 1. Project Name

当前正式名称：中文《炽窑》 / 英文 *Ember's Kiln*（原工程名「杀戮尖塔1」已弃用）。

立项为原创 IP《炽窑》，2026-08-26 由用户正式定名。

# 2. Game Type

- Godot 4.x 2D
- Roguelike / Roguelite
- 卡组构筑（Deckbuilding）
- 回合制战斗（Turn-based）
- 地牢爬塔（Map / Node 选择）
- 单局循环（Run）

参考体验可接近：

- 杀戮尖塔 / Slay the Spire
- Monster Train
- Roguebook
- 月圆之夜

参考作品只用于理解方向，不要求复制具体内容。

# 3. Core Experience

1. 战斗为回合制，节奏清晰、可读。
2. 每回合受能量（Energy）限制，需要决策出牌顺序。
3. 敌人显示意图（Intent），玩家可预判并应对。
4. 玩家通过卡牌、遗物（Relic）、状态（Status）形成不同 Build。
5. 每场战斗后构筑持续进化（获得卡牌 / 强化 / 移除）。
6. 单局有清晰终点（Boss / 层数）。
7. 强调重复游玩价值（不同卡牌 / 遗物 / 路线组合）。

# 4. Combat Direction

当前方向：

- 回合制（Turn-based），非实时
- 玩家每回合获得固定能量，出牌消耗能量
- 敌人按意图（Intent）行动，玩家可见
- 卡牌驱动战斗：攻击 / 技能 / 能力（Power）
- 状态系统：增益 / 减益（如易伤、虚弱、力量、敏捷、中毒等）
- 格挡（Block）作为核心防御资源，回合结束清空
- 战斗结束后进入爬塔地图，选择下一节点

如果后续正式设计改变这些内容，应更新本文件。

# 5. Design Philosophy

## 简单规则 + 可组合内容

基础规则尽量简单。

复杂度主要来自：

- 卡牌组合
- 遗物（Relic）修正
- 状态（Status）联动
- 敌人组合
- 地图路线压力

而不是大量复杂操作。

## Data Driven

卡牌、敌人、遗物、状态、地图节点和数值尽量数据驱动。

目标：

后续增加内容时尽量少修改底层代码。

优先使用 Godot Resource（.tres）或 JSON 描述，由 DataLoader 加载。

## Clear Feedback

以下行为需要明确反馈：

- 出牌
- 受伤 / 格挡
- 状态变化
- 抽牌 / 弃牌
- 击杀
- 获得卡牌 / 遗物 / 金币
- 升级

# 6. Visual Direction

已确认 v1 美术方向（详见 `AI_STUDIO/Design/ART_STYLE.md`）：

- 风格：**明亮扁平卡通风（Flat Bright Cartoon）**，暖色系，干净、几何化、粗圆角。
- 与《杀戮尖塔》暗黑哥特手绘形成明显差异（调性、线条、配色、质感、情绪均不同）。
- 配色：奶油白 / 暖橙 / 青绿 / 珊瑚红为主；敌人偏冷紫灰以区分敌我。

默认原则：

- 适合 Godot 4.x 2D
- 战斗与卡牌信息清晰可读
- 玩家、敌人、卡牌区分明显
- 状态图标 / 数值在战斗中可读
- UI 不遮挡主要战斗区域

卡牌本身需要明确可读：名称、费用、类型、效果文本、稀有度框。

# 7. Technical Direction

主要引擎：Godot 4.x

语言：GDScript（默认）

原则：

- 模块化
- 数据驱动
- 可测试（Gut 单元测试）
- 不过度设计
- 优先保证可运行

跨场景状态（如当前 Run 的卡组、遗物、金币、地图进度）使用 Autoload 单例或 Resource 持久化。

# 8. Scope Principles

当前 AI Studio 优先制作：

“可完整游玩的中小型 Godot 2D 卡组构筑 Roguelike”。

第一阶段不追求：

- 超大型开放世界
- MMO
- 大规模联机
- 高复杂度剧情系统
- AAA 级美术管线
- 无限制自动生成所有内容

# 9. Current Confirmed Rules

当前示例：

- Godot 4.x 2D
- 回合制卡组构筑 Roguelike 方向
- 能量限制出牌
- 敌人意图（Intent）系统
- 格挡（Block）+ 状态（Status）系统
- 数据驱动优先
- **仅保留「战士」一个职业**（无多职业切换）
- **难度已归位 `normal`**（敌人伤害 ×1.0、HP ×1.0、单场最多 3 敌、精英频率 0.18+，见 `BALANCE_TABLE.json`；原 v1「×0.65/×0.8 低难度」折扣已于 2026-08-17 撤销）
- **3 幕串联**（Act1 陶原初探 10 层 / Act2 炽窑升焰 9 层 / Act3 窑主终焰 8 层，每幕 1 个 Boss）
- **美术：明亮扁平卡通风、暖色系**（见 `ART_STYLE.md`）

正式立项后请按实际策划替换。

# 10. Pending Decisions

尚未确认：

- 正式名称 ✅ 已确认：中文《炽窑》/ 英文 *Ember's Kiln*（原工程名「杀戮尖塔1」已弃用）
- 世界观 / 叙事文案详稿（v2「陶土世界·炽窑」已落地，WORLD_SETTING.md）
- 音效与音乐方向
- 是否存在 Meta Progression（当前明确不做，留作后续）
- 发布平台
- 角色 / 敌人原创立绘细化（当前 sprite 为占位名）

已确认（详见 `AI_STUDIO/Design/`）：

- 美术风格 ✅ 明亮扁平卡通风（ART_STYLE.md）
- 职业 ✅ 仅战士
- 难度 ✅ 已归位 normal（BALANCE_TABLE.json，系数 1.0 / 单场最多 3 敌）
- 规模 ✅ 3 幕串联 / 43 卡 / 20 敌 / 10 遗物 / 9 状态（多幕扩展已完成）
- 多幕扩展 ✅ 3 幕串联 + 幕间回血 + 存档 v2（MULTIACT_EXPANSION_DESIGN.md）

这些内容不要由 Agent 自行假设。

# 11. Change Log

长期方向发生变化时记录：

```md
## YYYY-MM-DD
Changed:
...

Reason:
...
```

# 使用原则

这个文件负责回答：

“这个项目到底是什么游戏，我们长期坚持什么方向？”

详细系统规则写进 Design。

具体任务写进 Tasks。

测试结果写进 Reports。
