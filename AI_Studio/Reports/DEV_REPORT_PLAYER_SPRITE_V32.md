# DEV_REPORT — 主角 v3.2 立绘实装（2026-08-25）

## 改动

| 文件 | 内容 |
|------|------|
| `art/player/SPR_Player_Tannaro_{Idle,Attack,Hit,Death}.png` | v3.2 窑面全套（几何全脸陶瓷面甲 + 长发），rembg 透明底，裁边后统一高 768 |
| `scripts/combat/CombatController.gd` | 玩家 sprite 路径 `SPR_Player_Tannaro_Portrait.png` → `SPR_Player_Tannaro_Idle.png` |
| `scripts/combat/CombatUI.gd` | 新增姿态系统：`PLAYER_POSE_TEX` 四姿态 preload 表 + `_set_player_pose(pose, hold)`；接线：出攻击牌→attack（0.7s 回 idle）、玩家受击→hit（0.7s）、玩家死亡→death 常驻锁定、玩家回合开始→回 idle |
| `scripts/combat/PoseVerify.gd` + `scenes/combat/PoseVerify.tscn` | 新增姿态验证套件（8 断言） |
| `project.godot` | 新增 TestBridge autoload（godot-mcp E2E 桥，由 MCP `manage_game_bridge install` 写入，用于运行中场景检查） |

## 验证

- `CombatPlay.tscn` run_and_verify：零错误，玩家立绘节点 texture = `SPR_Player_Tannaro_Idle.png`、visible、位置 (-60,820) 390×390
- `PoseVerify.tscn`：**POSE_RESULT:PASS（8/8）** — 开局 Idle / 攻击牌→Attack / 到时回 Idle / 受击→Hit / 死亡→Death / 死亡锁定×2
- 截图可视验证：**NOT VERIFIED**（MCP headless_screenshot 工具自身脚本 `_mcp_capture_screenshot.gd` parse error，与本次改动无关；game_bridge 截图超时）

## 风险 / 遗留

- Attack 图宽度 511px 比 Idle 412px 宽（挥斧展开），TextureRect keep-aspect-centered 下视觉重心会略移，实战观感待截图确认
- 旧 `SPR_Player_Tannaro_Portrait.png` / `SPR_Player_Warrior.png`（v2 弃用资产）仍在 `art/player/`，按 ART_STYLE §15 应迁 `_archive`，未动
- TestBridge autoload 常驻 project.godot（调试用途，发布前可移除）
