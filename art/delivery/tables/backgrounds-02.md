# backgrounds 交付表 · 2

[总目录](../README.md)

自动生成；人工修订填 ../overrides.json。尺寸为实际测量，专项要求与现状分别记录。

- [town_level_3_base_preview.png](#asset-7c6da5c38d8fa97f) — `art/backgrounds/town_progression/town_level_3_base_preview.png`
- [town_level_3_preview.png](#asset-aa34952a36479fc1) — `art/backgrounds/town_progression/town_level_3_preview.png`

<a id="asset-7c6da5c38d8fa97f"></a>
## town_level_3_base_preview.png

[打开资产](../../backgrounds/town_progression/town_level_3_base_preview.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/backgrounds/town_progression/town_level_3_base_preview.png；文件标识：town_level_3_base_preview；业务ID待确认／不适用 |
| 资产类别 | backgrounds |
| 用途与出现位置 | 主菜单、各幕战斗、城镇／院落背景及生产参考 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md；art/backgrounds/town_progression/README.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用各场景批准镜头；镇景固定斜俯视，主菜单仰视巨窑 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=941 × 1671 px |
| 正式交付尺寸 | 当前文件实测=941 × 1671 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGB; Alpha=无透明通道 |
| 构图与留白 | 背景按目标长宽比适配，记录长屏裁切及UI遮挡区域；不适用透明图标留白规则 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 背景与标题、按钮、角色、HUD独立；城镇去建筑底图与功能建筑独立 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | town_level_3_base_preview.png |
| 生产路径 | art/backgrounds/town_progression/town_level_3_base_preview.png |
| 引擎接入 | 静态证据：data/town_visuals.json:6；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 本资产字段元数据：art/backgrounds/candidates/handdrawn_cleanup/manifest.json#/images/14/production: tool=built-in image_gen edit; source=art/backgrounds/town_progression/town_level_3_base_preview.png |
| 当前版本与修改摘要 | 当前文件SHA-256=9961f71e0ccc624e90e376dd32e473fcdbad9fb12d7751a14b90ff94b87c8909；历史条目记录（不等于本次审核）：art/backgrounds/candidates/handdrawn_cleanup/manifest.json#/images/14/production: status=runtime_integrated |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；名称／格式含预览特征，身份需结合引用与manifest，不能仅按文件名判为非生产；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
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
  "bytes": 2802918,
  "sha256": "9961f71e0ccc624e90e376dd32e473fcdbad9fb12d7751a14b90ff94b87c8909",
  "width": 941,
  "height": 1671,
  "mode": "RGB",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": false
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/town_visuals.json](../../../data/town_visuals.json)，行 6
- 生产资料：[art/backgrounds/town_progression/README.md](../../backgrounds/town_progression/README.md)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/backgrounds/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/14/source",
      "relation": "source",
      "record": {
        "status": "runtime_integrated",
        "tool": "built-in image_gen edit",
        "source": "art/backgrounds/town_progression/town_level_3_base_preview.png",
        "production": "art/backgrounds/town_progression/town_level_3_base_preview.png",
        "size": [
          941,
          1672
        ]
      }
    },
    {
      "file": "art/backgrounds/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/14/production",
      "relation": "production",
      "record": {
        "status": "runtime_integrated",
        "tool": "built-in image_gen edit",
        "source": "art/backgrounds/town_progression/town_level_3_base_preview.png",
        "production": "art/backgrounds/town_progression/town_level_3_base_preview.png",
        "size": [
          941,
          1672
        ]
      }
    }
  ],
  "business": [],
  "manual_evidence": []
}
```

<a id="asset-aa34952a36479fc1"></a>
## town_level_3_preview.png

[打开资产](../../backgrounds/town_progression/town_level_3_preview.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/backgrounds/town_progression/town_level_3_preview.png；文件标识：town_level_3_preview；业务ID待确认／不适用 |
| 资产类别 | backgrounds |
| 用途与出现位置 | 主菜单、各幕战斗、城镇／院落背景及生产参考 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md；art/backgrounds/town_progression/README.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用各场景批准镜头；镇景固定斜俯视，主菜单仰视巨窑 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=941 × 1672 px |
| 正式交付尺寸 | 当前文件实测=941 × 1672 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGB; Alpha=无透明通道 |
| 构图与留白 | 背景按目标长宽比适配，记录长屏裁切及UI遮挡区域；不适用透明图标留白规则 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 背景与标题、按钮、角色、HUD独立；城镇去建筑底图与功能建筑独立 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | town_level_3_preview.png |
| 生产路径 | art/backgrounds/town_progression/town_level_3_preview.png |
| 引擎接入 | 未发现完整路径或已知加载器映射；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 本资产字段元数据：art/backgrounds/candidates/handdrawn_cleanup/manifest.json#/images/15/production: tool=built-in image_gen edit; source=art/backgrounds/town_progression/town_level_3_preview.png |
| 当前版本与修改摘要 | 当前文件SHA-256=5284f5263fb217b9bff152eb118d1f82ae4ee910d2f93cbdff68fb41da6d6e46；历史条目记录（不等于本次审核）：art/backgrounds/candidates/handdrawn_cleanup/manifest.json#/images/15/production: status=reference_updated |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 名称／格式含预览特征，身份需结合引用与manifest，不能仅按文件名判为非生产；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
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
  "bytes": 3039344,
  "sha256": "5284f5263fb217b9bff152eb118d1f82ae4ee910d2f93cbdff68fb41da6d6e46",
  "width": 941,
  "height": 1672,
  "mode": "RGB",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": false
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 生产资料：[art/backgrounds/town_progression/README.md](../../backgrounds/town_progression/README.md)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/backgrounds/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/15/source",
      "relation": "source",
      "record": {
        "status": "reference_updated",
        "tool": "built-in image_gen edit",
        "source": "art/backgrounds/town_progression/town_level_3_preview.png",
        "production": "art/backgrounds/town_progression/town_level_3_preview.png",
        "size": [
          941,
          1672
        ]
      }
    },
    {
      "file": "art/backgrounds/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/15/production",
      "relation": "production",
      "record": {
        "status": "reference_updated",
        "tool": "built-in image_gen edit",
        "source": "art/backgrounds/town_progression/town_level_3_preview.png",
        "production": "art/backgrounds/town_progression/town_level_3_preview.png",
        "size": [
          941,
          1672
        ]
      }
    }
  ],
  "business": [],
  "manual_evidence": []
}
```
