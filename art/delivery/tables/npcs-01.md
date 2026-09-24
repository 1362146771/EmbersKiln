# npcs 交付表 · 1

[总目录](../README.md)

自动生成；人工修订填 ../overrides.json。尺寸为实际测量，专项要求与现状分别记录。

- [SPR_NPC_GrannyKiln.png](#asset-e24948e60ffb83f8) — `art/npcs/granny_kiln/SPR_NPC_GrannyKiln.png`

<a id="asset-e24948e60ffb83f8"></a>
## SPR_NPC_GrannyKiln.png

[打开资产](../../npcs/granny_kiln/SPR_NPC_GrannyKiln.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/npcs/granny_kiln/SPR_NPC_GrannyKiln.png；文件标识：SPR_NPC_GrannyKiln；业务ID待确认／不适用 |
| 资产类别 | npcs |
| 用途与出现位置 | 陶婆开场馈赠对话场景及生产资料 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md；AI_Studio/Design/World/GRANNY_KILN_DIALOGUE.md；art/npcs/granny_kiln/prompts-v2.json |
| 美术要求 | 简化罩袍兜帽、遮眼鼻头发只露干瘪嘴尖下巴；佝偻枯瘦，粗轮廓大色块 |
| 视角与光向 | 源图三分之四略朝右，PreRunPreparation场景flip_h后在右侧面向玩家；光向沿用原图 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1145 × 1374 px |
| 正式交付尺寸 | 当前文件实测=1145 × 1374 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(49, 16, 1131, 1359)（右／下边界不含） |
| 构图与留白 | 按对应参考检查主体完整性、安全边距；未有明确模板的项目待确认 |
| 对齐与视觉大小 | 开场馈赠场景玩家左、陶婆右，共同地面基线，陶婆坐姿小于主角；GrannyPortrait使用flip_h。具体显示大小随场景区域等比适配。 |
| 内容拆分 | 立绘、气泡、选项与保存退出按钮分离 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | SPR_NPC_GrannyKiln.png |
| 生产路径 | art/npcs/granny_kiln/SPR_NPC_GrannyKiln.png |
| 引擎接入 | 静态证据：scenes/main/PreRunPreparation.tscn:4；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 内置image_gen，2026-09-21；当前版本hooded-simplified-crone，art/npcs/granny_kiln/prompts-v2.json是现行罩袍基线；prompts.json为旧露脸形象资料。 |
| 当前版本与修改摘要 | 当前文件SHA-256=7e26274959d9603f1d84e776df95a312d0365cebd6169ca2eaba0013407971cc；历史条目记录（不等于本次审核）：art/npcs/granny_kiln/prompts-v2.json#/asset: revision=hooded-simplified-crone; date=2026-09-21 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 不适用（非序列帧）；若用于图集／材质，请查实际引用资源 |

| 检查项 | 结果 | 证据／问题 |
| --- | --- | --- |
| 文件、尺寸与命名 | 已盘点／已测量；命名合规待审核 | 实际文件、技术参数与SHA-256；不是设计验收PASS |
| 透明边缘与裁切 | 待检查 | 尚未进行本次人工验收 |
| 目标尺寸与同类一致性 | 待检查 | 尚未进行本次人工验收 |
| 美术风格 | 待检查 | 尚未进行本次人工验收 |
| Godot 编辑器与运行时 | NOT VERIFIED | 本次未启动Godot或截图，不沿用历史PASS |
| 来源与重建资料 | 待检查 | 尚未进行本次人工验收 |

技术测量：

```json
{
  "bytes": 857442,
  "sha256": "7e26274959d9603f1d84e776df95a312d0365cebd6169ca2eaba0013407971cc",
  "width": 1145,
  "height": 1374,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    49,
    16,
    1131,
    1359
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scenes/main/PreRunPreparation.tscn](../../../scenes/main/PreRunPreparation.tscn)，行 4
- 生产资料：[art/npcs/granny_kiln/prompts-v2.json](../../npcs/granny_kiln/prompts-v2.json)
- 生产资料：[art/npcs/granny_kiln/prompts.json](../../npcs/granny_kiln/prompts.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/npcs/granny_kiln/prompts-v2.json",
      "pointer": "/asset",
      "relation": "asset",
      "record": {
        "tool": "image_gen.imagegen",
        "date": "2026-09-21",
        "revision": "hooded-simplified-crone",
        "asset": "SPR_NPC_GrannyKiln.png"
      }
    }
  ],
  "business": [],
  "manual_evidence": [
    "art/npcs/granny_kiln/prompts-v2.json",
    "AI_Studio/Design/World/GRANNY_KILN_DIALOGUE.md",
    "scenes/main/PreRunPreparation.tscn"
  ]
}
```
