# 窑口镇建筑等级透明图

当前运行资源：五栋功能建筑，每栋 0、1、2、3 级，共 20 张独立 1024×1024 RGBA PNG。用于叠加在去除功能建筑的镇貌底图上；已接入 `scenes/town/Town.tscn`，映射由 `data/town_visuals.json` 管理。

| 目录 | 建筑 |
|---|---|
| hearth | 炉心 |
| card_mold_workshop | 牌模工坊 |
| relic_shelf | 遗珍架 |
| glaze_apothecary | 药釉坊 |
| bellows_station | 风箱台 |

文件命名为 `{建筑ID}_level_{0到3}.png`。

## 当前美术要求

- 固定俯视斜角、手绘色块、细深色轮廓。
- 0 级为破损待修复状态，1 级为基础木质设施。
- 2、3 级采用江南水乡的黑色弧瓦、灰白砖墙与灰石基础，保留暖木色。
- 2 级露出原木与木榫连接，不包铁皮，不使用铆钉加固板或装饰性铁带；钟、斧等功能器物保留原本材质。
- 3 级木构接头以铆钉铁皮包角加固，与 2 级拉开材料升级差异。
- 3 级通过完整屋脊与瓦当、石构加固、更多功能设备和器物表达升级。
- 建筑前部开放，露出功能器具，便于镇貌缩略图辨认。

## 使用与复核

最终 PNG 已清除洋红底色及边缘色溢出，检查 Alpha 透明、画布裁切与残余洋红。每栋各级保留统一画布；`manifest.json` 记录原点、可见范围与预览摆放参数。运行时使用每栋四级共用的 AtlasTexture 裁切框与固定锚点；点击区域按 Alpha 生成，不使用透明矩形抢占相邻建筑点击。

`preview/all_building_levels.jpg` 为全套对照；`preview/town_composite_level_0.jpg` 至 `3.jpg` 为固定摆位的合成预览，仅用于美术审阅，不是新的镇貌底图。

本套 0–3 级为用户要求的美术状态，不修改现有玩法等级或数值。运行验证入口为 `scenes/verify/TownVisualCapture.tscn`，覆盖二十组贴图、实际点击、工程领取、混合等级读档与截图。

## 来源与重建

全部主体由内置 image_gen 生成。`source_manifest.json` 保存当前来源与提示词；`processed/` 保存原始洋红图、去底输出及处理元数据。原始生成文件保留在生成目录。

运行 `process_assets.py` 可处理变更的来源，再运行 `finish_assets.py` 清理色边、校验透明图并重建预览。仅使用 generate2dsprite 处理器与确定性图像后处理，不以程序绘制建筑。
