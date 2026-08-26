# AI_STUDIO 目录说明

```text
AI_STUDIO/
├── Agents/      # Agent 角色定义，不放正式工作成果
├── Memory/      # 项目长期稳定记忆
├── Design/      # 正式设计文档
├── Tasks/       # Producer 创建的任务
└── Reports/      # 开发、QA、美术、项目状态报告
```

核心原则：

> `Agents/` 是“员工说明书”，不是每个 Agent 的私人工作区。

所有 Agent 围绕同一个项目共享 `Design/`、`Tasks/`、`Reports/` 和 Godot 的 `res://`（脚本、场景、数据、美术资源）。
