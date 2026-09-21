# 窑变攻击手绘序列

九张正式透明图集由内置 ImageGen 生成，经 generate2dsprite 色键清理和 QC；不使用参考游戏的素材。

| 文件 | 主形 |
|---|---|
| bludgeon.png | 斜劈接触点、陶片爆裂、烟尘冷却 |
| immolate.png | 火团聚集、卷曲火舌、撕裂碎焰与焦烟 |
| reaper.png | 镰形锋刃、暗靛残影、分裂弧光 |
| carnage.png | 锯齿重斩、断裂陶片 |
| uppercut.png | 上升钩弧、冲击碎屑 |
| searing_blow.png | 炽热刀口、碎焰 |
| fiend_fire.png | 旋焰收拢、喷发与灰烬 |
| sever_soul.png | 细亮斜刃、暗靛残影 |
| blood_for_blood.png | 深红交叉斩痕、碎陶 |

每张 1536×1024，3 列 × 2 行，512×512/帧，从左到右、从上到下，共 6 帧。恶魔之焰使用修正光晕后的图集，经统一比例缩放与居中留出格内安全边距；其余图集使用清理后的原始格子位置，保留火焰基线和自然扩张，不按每帧包围盒重新居中或缩放。禁止生成 mipmap，线性采样在格子内保留半像素边距。

运行参数、图集映射和非匀速帧时间位于 `data/vfx.json.enchant_attack`；独立 Shader 合成层负责短帧混合、火焰错时、收割位移、局部折射和全屏遮罩。时间由 EnchantAttackFX 控制，不依赖 Shader TIME，可暂停与逐帧查看。

基础攻击演出 1.20 秒（蓄势 0.18 + 命中/收尾 1.02）。死亡收割另有 0.65 秒红眼半脸前置特写，总长 1.85 秒，素材见 `../reaper_half_face.md`。测试入口 `scenes/combat/EnchantAttackLab.tscn`。

生成提示词见 `prompts.json`，背景修正提示用于去除第一轮生成的光晕；纯色底不进入运行资源。

新增六牌完整生成提示词与源图见 `remaining_prompts.json`，恶魔之焰修正提示词与后处理方式见 `fiend_fire_correction.json`。已有 alpha 的素材保留 alpha；恶魔之焰修正稿用洋红色键清理。
