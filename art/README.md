# 图像资源目录

`art/` 只存放当前有效的生产资源和仍在使用的视觉参考图。

逐资产交付表与校对入口：[可搜索校对页](delivery/index.html)／[Markdown分册目录](delivery/README.md)。新增或修改资产后运行 `python tools/build_art_delivery.py`，人工补录写 `art/delivery/overrides.json`；生成表记录尺寸、来源、接入与验收，不改变素材。规范见 `AI_Studio/Design/Art/ASSET_DELIVERY.md`，尚未统一的文档问题见 `ASSET_DELIVERY_REVIEW.md`。

- `backgrounds/`：战斗场景背景与窑口镇正式背景
- `cards/`：卡牌插画
- `enemies/`：敌人立绘与当前生产映射 `manifest.json`
- `icons/`：附魔、药水、遗物、状态图标
- `player/SPR_Player_Tannaro.png`：主角当前正式透明立绘；Idle 与 Death 使用
- `player/animations/`：攻击与受击帧动画、运行图集和重建说明
- `player/outfits/`：其余 4 张待用服装透明立绘
- `references/`：仍有效的风格和造型锚点
- `ui/`：界面面板与界面图标
- `vfx/`：特效贴图

仍在选择中的候选只允许放在对应类别的 `candidates/`，确定正式版本后删除被淘汰文件。旧版本、重复 ZIP 交付包、备份和测试截图不进入 `art/`；测试截图统一写入忽略版本控制的 `Temp/`，完成核对后删除。资产旁的 README 只记录当前映射、重建方式和不可丢失的生产约束，不保存生成日志或已完成批次提示词。
