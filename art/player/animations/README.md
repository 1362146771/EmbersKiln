# 玩家战斗帧动画

正式角色保持陶工服、陶面具与手斧。运行资源统一使用 768×768 透明帧、30 fps 时间轴，`PlayerCombatFrames.tres` 提供 `attack` 与 `hurt` 两个单次播放动画。

## 当前资源

- `attack`：5 个全身关键姿势（待机、蓄力、下劈、随势、回收），每个姿势持有 6 个时间单位，总长 1 秒。运行图集为 `attack/atlas-5.png`（1536×2304）。
- `hurt`：4 个关键姿势通过 30 帧持帧组成后仰、停顿和回正，总长 1 秒。运行图集为 `hurt/atlas-hd-1.png` 与 `hurt/atlas-hd-2.png`。
- 动态与静态角色按右靴鞋底对齐，导出锚点为 `(240, 700)`，站立主体基准高度为 545 像素。
- `PortraitTone.gdshader` 只调整动画中间调；静态正式立绘不调色。

## 接入

`scenes/combat/CombatPlay.tscn` 的 `PlayerSprite/BodyAnimation` 使用该资源。攻击牌播放 `attack`，玩家实际受到正伤害播放 `hurt`；结束后恢复静态立绘，连续事件从首帧重播，死亡时停止并锁定。播放器为 `scripts/combat/PlayerCombatPortrait.gd`。

## 重建

- 攻击源位于 `attack5_source/`，使用 `export_bundle.py` / `build_attack5.py` 重建。五个姿势采用同一整体缩放比例；斧头共用同一份素材，只允许旋转和平移。
- 受击源位于 `hd_source/`，使用 `process_hd.py` 与 `assemble_hd.py` 重建。
- `manifest.json` 与各目录的 `pipeline-meta.json` 保存帧顺序、几何和处理参数；`index.html` 用于逐帧预览。
- 重建后检查透明背景、洋红残边、画布裁切、脚底锚点和一秒播放时长。
