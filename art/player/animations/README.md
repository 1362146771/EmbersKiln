# 玩家战斗帧动画

正式角色保持陶工服、陶面具与手斧。运行资源统一使用 768×768 透明帧、30 fps 时间轴，`PlayerCombatFrames.tres` 提供 `attack` 与 `hurt` 两个单次播放动画。

## 当前资源

- `attack`：8 个全身姿势，30 fps 时间轴持帧为 3 / 8 / 2 / 5 / 6 / 6 / 6 / 6，总长 1.4 秒。运行图集为 `attack/atlas-8.png`（1536×3072）。
- `hurt`：4 个关键姿势通过 30 帧持帧组成后仰、停顿和回正，总长 1 秒。运行图集为 `hurt/atlas-hd-1.png` 与 `hurt/atlas-hd-2.png`。
- 动态与静态角色按右靴鞋底对齐，导出锚点为 `(240, 700)`，站立主体基准高度为 545 像素。
- `portrait_palette.py` 在导出时将攻击与受击材质配色匹配正式立绘；`PlayerCombatPortrait` 不再叠加 `PortraitTone.gdshader`，避免二次偏色。静态正式立绘不调色。

## 接入

`scenes/combat/CombatPlay.tscn` 的 `PlayerSprite/BodyAnimation` 使用该资源。攻击牌播放 `attack`，玩家实际受到正伤害播放 `hurt`；结束后恢复静态立绘，连续事件从首帧重播，死亡时停止并锁定。播放器为 `scripts/combat/PlayerCombatPortrait.gd`。

## 重建

- 使用 `export_bundle.py` / `build_attack5.py` 重建攻击与受击的最终配色。攻击姿势源位于 `attack5_source/`，斧头共用同一份素材，只允许旋转和平移。
- 受击已验收的四张透明姿势保存在 `palette_source/`，按原持帧序列导出三十帧；`hd_source/` 保留生成来源。校色每次从未校色姿势开始，不累计叠加。
- `manifest.json` 与各目录的 `pipeline-meta.json` 保存帧顺序、几何和处理参数；`index.html` 用于逐帧预览。
- 重建后检查透明背景、洋红残边、画布裁切、脚底锚点、攻击 1.4 秒 / 受击 1 秒时长，并核对正式立绘配色。
