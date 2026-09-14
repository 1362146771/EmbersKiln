# 窑口镇镇貌等级图

`town_level_0_base_preview.png` 至 `town_level_3_base_preview.png` 已接入 `scenes/town/Town.tscn`，文件沿用原命名。去除五栋功能建筑的底图与独立透明建筑层组合，固定斜俯视视角，不将功能建筑烘焙回底图。

- 0 级：镇门、民居屋顶与围栏破损，居民较少。
- 1 级：基础镇貌修复。
- 2 级：铺装窑道、恢复陶灯、修复部分民居。
- 3 级：完整民居、摊位、陶灯陶铃与花草。

运行时按 `ProfileState.town_visual_stage` 选择底图，功能建筑按独立 `facility_levels` 选择外观；两者不互相代替。图片映射在 `data/town_visuals.json`，固定锚点在 Town 场景，所有层共享同一个等比画布。工程领取后更新，建造完成但未领取时保留旧外观；档案重载恢复各自进度。现有玩法工程与数值不变。

美术基准为暖棕金手绘块面、细深色描边。五栋功能建筑的 2 级白墙黑瓦、木构不包铁皮，3 级增加铁皮加固；镇中普通民居遵循本批既有镇景图。

`town_level_1.png`、`town_level_2_preview.png`、`town_level_3_preview.png` 是早期完整镇貌参考，不作为运行底图。原图由内置 image_gen 生成，透明建筑和院落分别见 `art/ui/town/building_levels/`、`art/ui/town/interior_levels/`。验证入口：`scenes/verify/TownVisualCapture.tscn`。
