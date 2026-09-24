# enemies 交付表 · 3

[总目录](../README.md)

自动生成；人工修订填 ../overrides.json。尺寸为实际测量，专项要求与现状分别记录。

- [raw-sheet-clean.png](#asset-f526b92a08980c08) — `art/enemies/candidates/robber/processed_1254_v2/raw-sheet-clean.png`
- [raw-sheet.png](#asset-a227bca584d39d99) — `art/enemies/candidates/robber/processed_1254_v2/raw-sheet.png`
- [sheet-transparent.png](#asset-7eafe4170a9ab616) — `art/enemies/candidates/robber/processed_1254_v2/sheet-transparent.png`
- [single_asset-1.png](#asset-45b32c158f3314e6) — `art/enemies/candidates/robber/processed_1254_v2/single_asset-1.png`
- [raw-sheet.png](#asset-5d118e74005c7139) — `art/enemies/candidates/robber/raw-sheet.png`
- [CONCEPT_Boss_AshenBinder.png](#asset-062e9e915c363c08) — `art/enemies/concepts/ashen_binder/CONCEPT_Boss_AshenBinder.png`
- [SPR_SaggerMatron_Bar.png](#asset-d48687a8ce52bf0f) — `art/enemies/sagger_matron/SPR_SaggerMatron_Bar.png`
- [SPR_SaggerMatron_Cool.png](#asset-33896a17ef69f456) — `art/enemies/sagger_matron/SPR_SaggerMatron_Cool.png`
- [SPR_SaggerMatron_Fire.png](#asset-a3b24d1b00de655d) — `art/enemies/sagger_matron/SPR_SaggerMatron_Fire.png`
- [SPR_SaggerMatron_Seal.png](#asset-ed7882f968ca56be) — `art/enemies/sagger_matron/SPR_SaggerMatron_Seal.png`
- [SPR_SaggerMatron_Vent.png](#asset-a9634c0ef463f969) — `art/enemies/sagger_matron/SPR_SaggerMatron_Vent.png`

<a id="asset-f526b92a08980c08"></a>
## raw-sheet-clean.png

[打开资产](../../enemies/candidates/robber/processed_1254_v2/raw-sheet-clean.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/enemies/candidates/robber/processed_1254_v2/raw-sheet-clean.png；文件标识：raw-sheet-clean；业务ID待确认／不适用 |
| 资产类别 | enemies |
| 用途与出现位置 | 敌人立绘／状态图／概念或生产资料；具体敌人由数据与manifest核对 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE_ENEMIES.md；art/enemies/manifest.json；data/enemies.json |
| 美术要求 | 怪物独立v2：动漫感、low-poly式块面、低饱和多色、陶瓷与炉火；不套玩家色板／头身比 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1254 × 1254 px |
| 正式交付尺寸 | 当前文件实测=1254 × 1254 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 动态适配 EnemyPanel 可用区域；单体／多敌分别记录，不将1254画布当显示尺寸 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(130, 72, 1077, 1213)（右／下边界不含） |
| 构图与留白 | 正式静态怪物按透明主体边界适配；匣母状态图保留共同画布配准 |
| 对齐与视觉大小 | 精英主怪与随从主体包围盒面积约3:2，共同底线；多敌按布局安全边界限幅 |
| 内容拆分 | 立绘不烘焙名称、血条、状态、意图及选择反馈 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | raw-sheet-clean.png |
| 生产路径 | art/enemies/candidates/robber/processed_1254_v2/raw-sheet-clean.png |
| 引擎接入 | 未发现完整路径或已知加载器映射；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=d27abb16d08880d9608a622a2241d767d147a38bc90386996f5c3d57213376b7；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 候选目录（可能含已批准生产源，以逐条元数据为准）；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 匣母状态集见 SAGGER_STATES.md；其他敌人受击由 EnemyCombatPortrait 驱动 |

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
  "bytes": 934177,
  "sha256": "d27abb16d08880d9608a622a2241d767d147a38bc90386996f5c3d57213376b7",
  "width": 1254,
  "height": 1254,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    130,
    72,
    1077,
    1213
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 生产资料：[art/enemies/manifest.json](../../enemies/manifest.json)
- 生产资料：[art/README.md](../../README.md)

<a id="asset-a227bca584d39d99"></a>
## raw-sheet.png

[打开资产](../../enemies/candidates/robber/processed_1254_v2/raw-sheet.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/enemies/candidates/robber/processed_1254_v2/raw-sheet.png；文件标识：raw-sheet；业务ID待确认／不适用 |
| 资产类别 | enemies |
| 用途与出现位置 | 敌人立绘／状态图／概念或生产资料；具体敌人由数据与manifest核对 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE_ENEMIES.md；art/enemies/manifest.json；data/enemies.json |
| 美术要求 | 怪物独立v2：动漫感、low-poly式块面、低饱和多色、陶瓷与炉火；不套玩家色板／头身比 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1254 × 1254 px |
| 正式交付尺寸 | 当前文件实测=1254 × 1254 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 动态适配 EnemyPanel 可用区域；单体／多敌分别记录，不将1254画布当显示尺寸 |
| 文件格式 | PNG / RGBA; Alpha=[255, 255]；非零Alpha包围盒=(0, 0, 1254, 1254)（右／下边界不含） |
| 构图与留白 | 正式静态怪物按透明主体边界适配；匣母状态图保留共同画布配准 |
| 对齐与视觉大小 | 精英主怪与随从主体包围盒面积约3:2，共同底线；多敌按布局安全边界限幅 |
| 内容拆分 | 立绘不烘焙名称、血条、状态、意图及选择反馈 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | raw-sheet.png |
| 生产路径 | art/enemies/candidates/robber/processed_1254_v2/raw-sheet.png |
| 引擎接入 | 未发现完整路径或已知加载器映射；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=655963f3f85ca6dd2a6564d054b2c90b79859f37a2c02a09096c844d09ace871；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 候选目录（可能含已批准生产源，以逐条元数据为准）；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 匣母状态集见 SAGGER_STATES.md；其他敌人受击由 EnemyCombatPortrait 驱动 |

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
  "bytes": 1752462,
  "sha256": "655963f3f85ca6dd2a6564d054b2c90b79859f37a2c02a09096c844d09ace871",
  "width": 1254,
  "height": 1254,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    255,
    255
  ],
  "alpha_bbox": [
    0,
    0,
    1254,
    1254
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 生产资料：[art/enemies/manifest.json](../../enemies/manifest.json)
- 生产资料：[art/README.md](../../README.md)

<a id="asset-7eafe4170a9ab616"></a>
## sheet-transparent.png

[打开资产](../../enemies/candidates/robber/processed_1254_v2/sheet-transparent.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/enemies/candidates/robber/processed_1254_v2/sheet-transparent.png；文件标识：sheet-transparent；业务ID待确认／不适用 |
| 资产类别 | enemies |
| 用途与出现位置 | 敌人立绘／状态图／概念或生产资料；具体敌人由数据与manifest核对 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE_ENEMIES.md；art/enemies/manifest.json；data/enemies.json |
| 美术要求 | 怪物独立v2：动漫感、low-poly式块面、低饱和多色、陶瓷与炉火；不套玩家色板／头身比 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1254 × 1254 px |
| 正式交付尺寸 | 当前文件实测=1254 × 1254 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 动态适配 EnemyPanel 可用区域；单体／多敌分别记录，不将1254画布当显示尺寸 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(185, 95, 1069, 1160)（右／下边界不含） |
| 构图与留白 | 正式静态怪物按透明主体边界适配；匣母状态图保留共同画布配准 |
| 对齐与视觉大小 | 精英主怪与随从主体包围盒面积约3:2，共同底线；多敌按布局安全边界限幅 |
| 内容拆分 | 立绘不烘焙名称、血条、状态、意图及选择反馈 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | sheet-transparent.png |
| 生产路径 | art/enemies/candidates/robber/processed_1254_v2/sheet-transparent.png |
| 引擎接入 | 未发现完整路径或已知加载器映射；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=6b5fdc310e7d4b29a473a701d8d55bbdec68b0d69ba4c81e73cfd75ca1301477；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 候选目录（可能含已批准生产源，以逐条元数据为准）；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 匣母状态集见 SAGGER_STATES.md；其他敌人受击由 EnemyCombatPortrait 驱动 |

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
  "bytes": 874352,
  "sha256": "6b5fdc310e7d4b29a473a701d8d55bbdec68b0d69ba4c81e73cfd75ca1301477",
  "width": 1254,
  "height": 1254,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    185,
    95,
    1069,
    1160
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 生产资料：[art/enemies/manifest.json](../../enemies/manifest.json)
- 生产资料：[art/README.md](../../README.md)

<a id="asset-45b32c158f3314e6"></a>
## single_asset-1.png

[打开资产](../../enemies/candidates/robber/processed_1254_v2/single_asset-1.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/enemies/candidates/robber/processed_1254_v2/single_asset-1.png；文件标识：single_asset-1；业务ID待确认／不适用 |
| 资产类别 | enemies |
| 用途与出现位置 | 敌人立绘／状态图／概念或生产资料；具体敌人由数据与manifest核对 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE_ENEMIES.md；art/enemies/manifest.json；data/enemies.json |
| 美术要求 | 怪物独立v2：动漫感、low-poly式块面、低饱和多色、陶瓷与炉火；不套玩家色板／头身比 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1254 × 1254 px |
| 正式交付尺寸 | 当前文件实测=1254 × 1254 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 动态适配 EnemyPanel 可用区域；单体／多敌分别记录，不将1254画布当显示尺寸 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(185, 95, 1069, 1160)（右／下边界不含） |
| 构图与留白 | 正式静态怪物按透明主体边界适配；匣母状态图保留共同画布配准 |
| 对齐与视觉大小 | 精英主怪与随从主体包围盒面积约3:2，共同底线；多敌按布局安全边界限幅 |
| 内容拆分 | 立绘不烘焙名称、血条、状态、意图及选择反馈 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | single_asset-1.png |
| 生产路径 | art/enemies/candidates/robber/processed_1254_v2/single_asset-1.png |
| 引擎接入 | 未发现完整路径或已知加载器映射；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=b9aec0d9a8ebb6cfdc32c5ad7cfd60546acd00ebd467b34836d7152e097ab3ad；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 候选目录（可能含已批准生产源，以逐条元数据为准）；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 匣母状态集见 SAGGER_STATES.md；其他敌人受击由 EnemyCombatPortrait 驱动 |

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
  "bytes": 893656,
  "sha256": "b9aec0d9a8ebb6cfdc32c5ad7cfd60546acd00ebd467b34836d7152e097ab3ad",
  "width": 1254,
  "height": 1254,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    185,
    95,
    1069,
    1160
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 生产资料：[art/enemies/manifest.json](../../enemies/manifest.json)
- 生产资料：[art/README.md](../../README.md)

<a id="asset-5d118e74005c7139"></a>
## raw-sheet.png

[打开资产](../../enemies/candidates/robber/raw-sheet.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/enemies/candidates/robber/raw-sheet.png；文件标识：raw-sheet；业务ID待确认／不适用 |
| 资产类别 | enemies |
| 用途与出现位置 | 敌人立绘／状态图／概念或生产资料；具体敌人由数据与manifest核对 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE_ENEMIES.md；art/enemies/manifest.json；data/enemies.json |
| 美术要求 | 怪物独立v2：动漫感、low-poly式块面、低饱和多色、陶瓷与炉火；不套玩家色板／头身比 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1254 × 1254 px |
| 正式交付尺寸 | 当前文件实测=1254 × 1254 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 动态适配 EnemyPanel 可用区域；单体／多敌分别记录，不将1254画布当显示尺寸 |
| 文件格式 | PNG / RGB; Alpha=无透明通道 |
| 构图与留白 | 正式静态怪物按透明主体边界适配；匣母状态图保留共同画布配准 |
| 对齐与视觉大小 | 精英主怪与随从主体包围盒面积约3:2，共同底线；多敌按布局安全边界限幅 |
| 内容拆分 | 立绘不烘焙名称、血条、状态、意图及选择反馈 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | raw-sheet.png |
| 生产路径 | art/enemies/candidates/robber/raw-sheet.png |
| 引擎接入 | 未发现完整路径或已知加载器映射；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=7c399762f7fb323505453780770c8f050025f3b592a267c3f73163a17c955a70；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 候选目录（可能含已批准生产源，以逐条元数据为准）；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 匣母状态集见 SAGGER_STATES.md；其他敌人受击由 EnemyCombatPortrait 驱动 |

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
  "bytes": 1564456,
  "sha256": "7c399762f7fb323505453780770c8f050025f3b592a267c3f73163a17c955a70",
  "width": 1254,
  "height": 1254,
  "mode": "RGB",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": false
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 生产资料：[art/enemies/manifest.json](../../enemies/manifest.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/enemies/candidates/robber/processed/pipeline-meta.json",
      "pointer": "/input",
      "relation": "input",
      "record": {}
    },
    {
      "file": "art/enemies/candidates/robber/processed_1254/pipeline-meta.json",
      "pointer": "/input",
      "relation": "input",
      "record": {}
    },
    {
      "file": "art/enemies/candidates/robber/processed_1254_v2/pipeline-meta.json",
      "pointer": "/input",
      "relation": "input",
      "record": {}
    }
  ],
  "business": [],
  "manual_evidence": []
}
```

<a id="asset-062e9e915c363c08"></a>
## CONCEPT_Boss_AshenBinder.png

[打开资产](../../enemies/concepts/ashen_binder/CONCEPT_Boss_AshenBinder.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/enemies/concepts/ashen_binder/CONCEPT_Boss_AshenBinder.png；文件标识：CONCEPT_Boss_AshenBinder；业务ID待确认／不适用 |
| 资产类别 | enemies |
| 用途与出现位置 | 敌人立绘／状态图／概念或生产资料；具体敌人由数据与manifest核对 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE_ENEMIES.md；art/enemies/manifest.json；data/enemies.json |
| 美术要求 | 怪物独立v2：动漫感、low-poly式块面、低饱和多色、陶瓷与炉火；不套玩家色板／头身比 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1215 × 1295 px |
| 正式交付尺寸 | 当前文件实测=1215 × 1295 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 动态适配 EnemyPanel 可用区域；单体／多敌分别记录，不将1254画布当显示尺寸 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(0, 18, 1204, 1273)（右／下边界不含） |
| 构图与留白 | 正式静态怪物按透明主体边界适配；匣母状态图保留共同画布配准 |
| 对齐与视觉大小 | 精英主怪与随从主体包围盒面积约3:2，共同底线；多敌按布局安全边界限幅 |
| 内容拆分 | 立绘不烘焙名称、血条、状态、意图及选择反馈 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | CONCEPT_Boss_AshenBinder.png |
| 生产路径 | art/enemies/concepts/ashen_binder/CONCEPT_Boss_AshenBinder.png |
| 引擎接入 | 未发现完整路径或已知加载器映射；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=a570ebe8234fbe95c5898d302bfacf88d13da5429e5f1b66de848284c55b1539；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 参考／概念资料；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 匣母状态集见 SAGGER_STATES.md；其他敌人受击由 EnemyCombatPortrait 驱动 |

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
  "bytes": 1460411,
  "sha256": "a570ebe8234fbe95c5898d302bfacf88d13da5429e5f1b66de848284c55b1539",
  "width": 1215,
  "height": 1295,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    0,
    18,
    1204,
    1273
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 生产资料：[art/enemies/concepts/ashen_binder/prompts.json](../../enemies/concepts/ashen_binder/prompts.json)
- 生产资料：[art/enemies/manifest.json](../../enemies/manifest.json)
- 生产资料：[art/README.md](../../README.md)

<a id="asset-d48687a8ce52bf0f"></a>
## SPR_SaggerMatron_Bar.png

[打开资产](../../enemies/sagger_matron/SPR_SaggerMatron_Bar.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/enemies/sagger_matron/SPR_SaggerMatron_Bar.png；文件标识：SPR_SaggerMatron_Bar；业务ID：sagger_matron |
| 资产类别 | enemies |
| 用途与出现位置 | 敌人立绘／状态图／概念或生产资料；具体敌人由数据与manifest核对；数据名称：封窑兽·匣母 |
| 依据与参考 | AI_Studio/Design/Art/SAGGER_STATES.md；art/enemies/manifest.json |
| 美术要求 | 匣母保留已批准原型，不随其他怪物v2重设；三座匣钵，按招式切换封匣／喷火／泄压／冷却姿态 |
| 视角与光向 | 三分之四朝左；光向沿用批准原型 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1254 × 1254 px |
| 正式交付尺寸 | 当前文件实测=1254 × 1254 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 动态适配 EnemyPanel 可用区域；单体／多敌分别记录，不将1254画布当显示尺寸 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(75, 212, 1181, 1254)（右／下边界不含） |
| 构图与留白 | 共同1254×1254透明画布与原始配准；不得按各状态轮廓重新撑满画布 |
| 对齐与视觉大小 | 专项约定统一scale0.9、脚底y1120；这是文档锚点要求，现文件包围盒与实际显示另核对 |
| 内容拆分 | 立绘不烘焙名称、血条、状态、意图及选择反馈 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | SPR_SaggerMatron_Bar.png |
| 生产路径 | art/enemies/sagger_matron/SPR_SaggerMatron_Bar.png |
| 引擎接入 | 静态证据：data/enemies.json:903；data/enemies.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 本资产字段元数据：art/enemies/candidates/handdrawn_cleanup/manifest.json#/images/22/production: tool=built-in image_gen edit; source=art/enemies/sagger_matron/SPR_SaggerMatron_Bar.png；art/enemies/manifest.json#/state_sets/sagger_matron/states/bar/production: source=art/enemies/candidates/handdrawn_cleanup/SPR_SaggerMatron_Bar.png |
| 当前版本与修改摘要 | 当前文件SHA-256=1f9c000427eae9a04b48bd7bff79fbd3aab1f50e2142c5e692592f6127b99c1c；历史条目记录（不等于本次审核）：art/enemies/candidates/handdrawn_cleanup/manifest.json#/images/22/production: status=runtime_integrated；art/enemies/manifest.json#/state_sets/sagger_matron/states/bar/production: status=current |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 匣母状态集见 SAGGER_STATES.md；其他敌人受击由 EnemyCombatPortrait 驱动 |

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
  "bytes": 1220698,
  "sha256": "1f9c000427eae9a04b48bd7bff79fbd3aab1f50e2142c5e692592f6127b99c1c",
  "width": 1254,
  "height": 1254,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    75,
    212,
    1181,
    1254
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/enemies.json](../../../data/enemies.json)，行 903
- 数据字段映射：[data/enemies.json](../../../data/enemies.json)
- 生产资料：[art/enemies/manifest.json](../../enemies/manifest.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/enemies/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/22/source",
      "relation": "source",
      "record": {
        "status": "runtime_integrated",
        "tool": "built-in image_gen edit",
        "source": "art/enemies/sagger_matron/SPR_SaggerMatron_Bar.png",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Bar.png",
        "size": [
          1254,
          1254
        ]
      }
    },
    {
      "file": "art/enemies/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/22/production",
      "relation": "production",
      "record": {
        "status": "runtime_integrated",
        "tool": "built-in image_gen edit",
        "source": "art/enemies/sagger_matron/SPR_SaggerMatron_Bar.png",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Bar.png",
        "size": [
          1254,
          1254
        ]
      }
    },
    {
      "file": "art/enemies/manifest.json",
      "pointer": "/state_sets/sagger_matron/states/bar/production",
      "relation": "production",
      "record": {
        "status": "current",
        "name": "拦路",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Bar.png",
        "source": "art/enemies/candidates/handdrawn_cleanup/SPR_SaggerMatron_Bar.png",
        "size": [
          1254,
          1254
        ]
      }
    }
  ],
  "business": [
    {
      "file": "data/enemies.json",
      "pointer": "/enemies/20/state_sprites/bar",
      "id": "sagger_matron",
      "name": "封窑兽·匣母"
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-33896a17ef69f456"></a>
## SPR_SaggerMatron_Cool.png

[打开资产](../../enemies/sagger_matron/SPR_SaggerMatron_Cool.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/enemies/sagger_matron/SPR_SaggerMatron_Cool.png；文件标识：SPR_SaggerMatron_Cool；业务ID：sagger_matron |
| 资产类别 | enemies |
| 用途与出现位置 | 敌人立绘／状态图／概念或生产资料；具体敌人由数据与manifest核对；数据名称：封窑兽·匣母 |
| 依据与参考 | AI_Studio/Design/Art/SAGGER_STATES.md；art/enemies/manifest.json |
| 美术要求 | 匣母保留已批准原型，不随其他怪物v2重设；三座匣钵，按招式切换封匣／喷火／泄压／冷却姿态 |
| 视角与光向 | 三分之四朝左；光向沿用批准原型 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1254 × 1254 px |
| 正式交付尺寸 | 当前文件实测=1254 × 1254 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 动态适配 EnemyPanel 可用区域；单体／多敌分别记录，不将1254画布当显示尺寸 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(76, 49, 1198, 1228)（右／下边界不含） |
| 构图与留白 | 共同1254×1254透明画布与原始配准；不得按各状态轮廓重新撑满画布 |
| 对齐与视觉大小 | 专项约定统一scale0.9、脚底y1120；这是文档锚点要求，现文件包围盒与实际显示另核对 |
| 内容拆分 | 立绘不烘焙名称、血条、状态、意图及选择反馈 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | SPR_SaggerMatron_Cool.png |
| 生产路径 | art/enemies/sagger_matron/SPR_SaggerMatron_Cool.png |
| 引擎接入 | 静态证据：data/enemies.json:907；data/enemies.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 本资产字段元数据：art/enemies/candidates/handdrawn_cleanup/manifest.json#/images/23/production: tool=built-in image_gen edit; source=art/enemies/sagger_matron/SPR_SaggerMatron_Cool.png；art/enemies/manifest.json#/state_sets/sagger_matron/states/cool/production: source=art/enemies/candidates/handdrawn_cleanup/SPR_SaggerMatron_Cool.png |
| 当前版本与修改摘要 | 当前文件SHA-256=597978025aa699a472ce59ccfa54ce8bdd653a24ecb12cdf520434f1c5d693d3；历史条目记录（不等于本次审核）：art/enemies/candidates/handdrawn_cleanup/manifest.json#/images/23/production: status=runtime_integrated；art/enemies/manifest.json#/state_sets/sagger_matron/states/cool/production: status=current |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 匣母状态集见 SAGGER_STATES.md；其他敌人受击由 EnemyCombatPortrait 驱动 |

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
  "bytes": 936106,
  "sha256": "597978025aa699a472ce59ccfa54ce8bdd653a24ecb12cdf520434f1c5d693d3",
  "width": 1254,
  "height": 1254,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    76,
    49,
    1198,
    1228
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/enemies.json](../../../data/enemies.json)，行 907
- 数据字段映射：[data/enemies.json](../../../data/enemies.json)
- 生产资料：[art/enemies/manifest.json](../../enemies/manifest.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/enemies/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/23/source",
      "relation": "source",
      "record": {
        "status": "runtime_integrated",
        "tool": "built-in image_gen edit",
        "source": "art/enemies/sagger_matron/SPR_SaggerMatron_Cool.png",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Cool.png",
        "size": [
          1254,
          1254
        ]
      }
    },
    {
      "file": "art/enemies/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/23/production",
      "relation": "production",
      "record": {
        "status": "runtime_integrated",
        "tool": "built-in image_gen edit",
        "source": "art/enemies/sagger_matron/SPR_SaggerMatron_Cool.png",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Cool.png",
        "size": [
          1254,
          1254
        ]
      }
    },
    {
      "file": "art/enemies/manifest.json",
      "pointer": "/state_sets/sagger_matron/states/cool/production",
      "relation": "production",
      "record": {
        "status": "current",
        "name": "散热",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Cool.png",
        "source": "art/enemies/candidates/handdrawn_cleanup/SPR_SaggerMatron_Cool.png",
        "size": [
          1254,
          1254
        ]
      }
    }
  ],
  "business": [
    {
      "file": "data/enemies.json",
      "pointer": "/enemies/20/state_sprites/cool",
      "id": "sagger_matron",
      "name": "封窑兽·匣母"
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-a3b24d1b00de655d"></a>
## SPR_SaggerMatron_Fire.png

[打开资产](../../enemies/sagger_matron/SPR_SaggerMatron_Fire.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/enemies/sagger_matron/SPR_SaggerMatron_Fire.png；文件标识：SPR_SaggerMatron_Fire；业务ID：sagger_matron |
| 资产类别 | enemies |
| 用途与出现位置 | 敌人立绘／状态图／概念或生产资料；具体敌人由数据与manifest核对；数据名称：封窑兽·匣母 |
| 依据与参考 | AI_Studio/Design/Art/SAGGER_STATES.md；art/enemies/manifest.json |
| 美术要求 | 匣母保留已批准原型，不随其他怪物v2重设；三座匣钵，按招式切换封匣／喷火／泄压／冷却姿态 |
| 视角与光向 | 三分之四朝左；光向沿用批准原型 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1254 × 1254 px |
| 正式交付尺寸 | 当前文件实测=1254 × 1254 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 动态适配 EnemyPanel 可用区域；单体／多敌分别记录，不将1254画布当显示尺寸 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(73, 114, 1220, 1127)（右／下边界不含） |
| 构图与留白 | 共同1254×1254透明画布与原始配准；不得按各状态轮廓重新撑满画布 |
| 对齐与视觉大小 | 专项约定统一scale0.9、脚底y1120；这是文档锚点要求，现文件包围盒与实际显示另核对 |
| 内容拆分 | 立绘不烘焙名称、血条、状态、意图及选择反馈 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | SPR_SaggerMatron_Fire.png |
| 生产路径 | art/enemies/sagger_matron/SPR_SaggerMatron_Fire.png |
| 引擎接入 | 静态证据：data/enemies.json:905；data/enemies.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 本资产字段元数据：art/enemies/candidates/handdrawn_cleanup/manifest.json#/images/24/production: tool=built-in image_gen edit; source=art/enemies/sagger_matron/SPR_SaggerMatron_Fire.png；art/enemies/manifest.json#/state_sets/sagger_matron/states/fire/production: source=art/enemies/candidates/handdrawn_cleanup/SPR_SaggerMatron_Fire.png |
| 当前版本与修改摘要 | 当前文件SHA-256=fef15d8f0229c4f54e705b0128868b36875ee087d4d7740fc5a010ffae489baf；历史条目记录（不等于本次审核）：art/enemies/candidates/handdrawn_cleanup/manifest.json#/images/24/production: status=runtime_integrated；art/enemies/manifest.json#/state_sets/sagger_matron/states/fire/production: status=current |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 匣母状态集见 SAGGER_STATES.md；其他敌人受击由 EnemyCombatPortrait 驱动 |

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
  "bytes": 1485305,
  "sha256": "fef15d8f0229c4f54e705b0128868b36875ee087d4d7740fc5a010ffae489baf",
  "width": 1254,
  "height": 1254,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    73,
    114,
    1220,
    1127
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/enemies.json](../../../data/enemies.json)，行 905
- 数据字段映射：[data/enemies.json](../../../data/enemies.json)
- 生产资料：[art/enemies/manifest.json](../../enemies/manifest.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/enemies/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/24/source",
      "relation": "source",
      "record": {
        "status": "runtime_integrated",
        "tool": "built-in image_gen edit",
        "source": "art/enemies/sagger_matron/SPR_SaggerMatron_Fire.png",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Fire.png",
        "size": [
          1254,
          1254
        ]
      }
    },
    {
      "file": "art/enemies/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/24/production",
      "relation": "production",
      "record": {
        "status": "runtime_integrated",
        "tool": "built-in image_gen edit",
        "source": "art/enemies/sagger_matron/SPR_SaggerMatron_Fire.png",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Fire.png",
        "size": [
          1254,
          1254
        ]
      }
    },
    {
      "file": "art/enemies/manifest.json",
      "pointer": "/state_sets/sagger_matron/states/fire/production",
      "relation": "production",
      "record": {
        "status": "current",
        "name": "开窑",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Fire.png",
        "source": "art/enemies/candidates/handdrawn_cleanup/SPR_SaggerMatron_Fire.png",
        "size": [
          1254,
          1254
        ]
      }
    }
  ],
  "business": [
    {
      "file": "data/enemies.json",
      "pointer": "/enemies/20/state_sprites/fire",
      "id": "sagger_matron",
      "name": "封窑兽·匣母"
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-ed7882f968ca56be"></a>
## SPR_SaggerMatron_Seal.png

[打开资产](../../enemies/sagger_matron/SPR_SaggerMatron_Seal.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/enemies/sagger_matron/SPR_SaggerMatron_Seal.png；文件标识：SPR_SaggerMatron_Seal；业务ID：sagger_matron |
| 资产类别 | enemies |
| 用途与出现位置 | 敌人立绘／状态图／概念或生产资料；具体敌人由数据与manifest核对；数据名称：封窑兽·匣母 |
| 依据与参考 | AI_Studio/Design/Art/SAGGER_STATES.md；art/enemies/manifest.json |
| 美术要求 | 匣母保留已批准原型，不随其他怪物v2重设；三座匣钵，按招式切换封匣／喷火／泄压／冷却姿态 |
| 视角与光向 | 三分之四朝左；光向沿用批准原型 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1254 × 1254 px |
| 正式交付尺寸 | 当前文件实测=1254 × 1254 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 动态适配 EnemyPanel 可用区域；单体／多敌分别记录，不将1254画布当显示尺寸 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(78, 53, 1179, 1254)（右／下边界不含） |
| 构图与留白 | 共同1254×1254透明画布与原始配准；不得按各状态轮廓重新撑满画布 |
| 对齐与视觉大小 | 专项约定统一scale0.9、脚底y1120；这是文档锚点要求，现文件包围盒与实际显示另核对 |
| 内容拆分 | 立绘不烘焙名称、血条、状态、意图及选择反馈 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | SPR_SaggerMatron_Seal.png |
| 生产路径 | art/enemies/sagger_matron/SPR_SaggerMatron_Seal.png |
| 引擎接入 | 静态证据：data/enemies.json:904；data/enemies.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 本资产字段元数据：art/enemies/candidates/handdrawn_cleanup/manifest.json#/images/25/production: tool=built-in image_gen edit; source=art/enemies/sagger_matron/SPR_SaggerMatron_Seal.png；art/enemies/manifest.json#/state_sets/sagger_matron/states/seal/production: source=art/enemies/candidates/handdrawn_cleanup/SPR_SaggerMatron_Seal.png |
| 当前版本与修改摘要 | 当前文件SHA-256=efd75f0c1db29a9cec7765c84e1bdaa96e98e745376ffc303d4ea61aa03e6f5e；历史条目记录（不等于本次审核）：art/enemies/candidates/handdrawn_cleanup/manifest.json#/images/25/production: status=runtime_integrated；art/enemies/manifest.json#/state_sets/sagger_matron/states/seal/production: status=current |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 匣母状态集见 SAGGER_STATES.md；其他敌人受击由 EnemyCombatPortrait 驱动 |

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
  "bytes": 1244812,
  "sha256": "efd75f0c1db29a9cec7765c84e1bdaa96e98e745376ffc303d4ea61aa03e6f5e",
  "width": 1254,
  "height": 1254,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    78,
    53,
    1179,
    1254
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/enemies.json](../../../data/enemies.json)，行 904
- 数据字段映射：[data/enemies.json](../../../data/enemies.json)
- 生产资料：[art/enemies/manifest.json](../../enemies/manifest.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/enemies/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/25/source",
      "relation": "source",
      "record": {
        "status": "runtime_integrated",
        "tool": "built-in image_gen edit",
        "source": "art/enemies/sagger_matron/SPR_SaggerMatron_Seal.png",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Seal.png",
        "size": [
          1254,
          1254
        ]
      }
    },
    {
      "file": "art/enemies/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/25/production",
      "relation": "production",
      "record": {
        "status": "runtime_integrated",
        "tool": "built-in image_gen edit",
        "source": "art/enemies/sagger_matron/SPR_SaggerMatron_Seal.png",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Seal.png",
        "size": [
          1254,
          1254
        ]
      }
    },
    {
      "file": "art/enemies/manifest.json",
      "pointer": "/state_sets/sagger_matron/states/seal/production",
      "relation": "production",
      "record": {
        "status": "current",
        "name": "封匣",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Seal.png",
        "source": "art/enemies/candidates/handdrawn_cleanup/SPR_SaggerMatron_Seal.png",
        "size": [
          1254,
          1254
        ]
      }
    }
  ],
  "business": [
    {
      "file": "data/enemies.json",
      "pointer": "/enemies/20/state_sprites/seal",
      "id": "sagger_matron",
      "name": "封窑兽·匣母"
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-a9634c0ef463f969"></a>
## SPR_SaggerMatron_Vent.png

[打开资产](../../enemies/sagger_matron/SPR_SaggerMatron_Vent.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/enemies/sagger_matron/SPR_SaggerMatron_Vent.png；文件标识：SPR_SaggerMatron_Vent；业务ID：sagger_matron |
| 资产类别 | enemies |
| 用途与出现位置 | 敌人立绘／状态图／概念或生产资料；具体敌人由数据与manifest核对；数据名称：封窑兽·匣母 |
| 依据与参考 | AI_Studio/Design/Art/SAGGER_STATES.md；art/enemies/manifest.json |
| 美术要求 | 匣母保留已批准原型，不随其他怪物v2重设；三座匣钵，按招式切换封匣／喷火／泄压／冷却姿态 |
| 视角与光向 | 三分之四朝左；光向沿用批准原型 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1254 × 1254 px |
| 正式交付尺寸 | 当前文件实测=1254 × 1254 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 动态适配 EnemyPanel 可用区域；单体／多敌分别记录，不将1254画布当显示尺寸 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(41, 33, 1228, 1198)（右／下边界不含） |
| 构图与留白 | 共同1254×1254透明画布与原始配准；不得按各状态轮廓重新撑满画布 |
| 对齐与视觉大小 | 专项约定统一scale0.9、脚底y1120；这是文档锚点要求，现文件包围盒与实际显示另核对 |
| 内容拆分 | 立绘不烘焙名称、血条、状态、意图及选择反馈 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | SPR_SaggerMatron_Vent.png |
| 生产路径 | art/enemies/sagger_matron/SPR_SaggerMatron_Vent.png |
| 引擎接入 | 静态证据：data/enemies.json:906；data/enemies.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 本资产字段元数据：art/enemies/candidates/handdrawn_cleanup/manifest.json#/images/26/production: tool=built-in image_gen edit; source=art/enemies/sagger_matron/SPR_SaggerMatron_Vent.png；art/enemies/manifest.json#/state_sets/sagger_matron/states/vent/production: source=art/enemies/candidates/handdrawn_cleanup/SPR_SaggerMatron_Vent.png |
| 当前版本与修改摘要 | 当前文件SHA-256=66ffb72310cc37babb73152687ebc361eca32301588302e203b38a94a8b15bb0；历史条目记录（不等于本次审核）：art/enemies/candidates/handdrawn_cleanup/manifest.json#/images/26/production: status=runtime_integrated；art/enemies/manifest.json#/state_sets/sagger_matron/states/vent/production: status=current |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 匣母状态集见 SAGGER_STATES.md；其他敌人受击由 EnemyCombatPortrait 驱动 |

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
  "bytes": 1274484,
  "sha256": "66ffb72310cc37babb73152687ebc361eca32301588302e203b38a94a8b15bb0",
  "width": 1254,
  "height": 1254,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    41,
    33,
    1228,
    1198
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/enemies.json](../../../data/enemies.json)，行 906
- 数据字段映射：[data/enemies.json](../../../data/enemies.json)
- 生产资料：[art/enemies/manifest.json](../../enemies/manifest.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/enemies/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/26/source",
      "relation": "source",
      "record": {
        "status": "runtime_integrated",
        "tool": "built-in image_gen edit",
        "source": "art/enemies/sagger_matron/SPR_SaggerMatron_Vent.png",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Vent.png",
        "size": [
          1254,
          1254
        ]
      }
    },
    {
      "file": "art/enemies/candidates/handdrawn_cleanup/manifest.json",
      "pointer": "/images/26/production",
      "relation": "production",
      "record": {
        "status": "runtime_integrated",
        "tool": "built-in image_gen edit",
        "source": "art/enemies/sagger_matron/SPR_SaggerMatron_Vent.png",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Vent.png",
        "size": [
          1254,
          1254
        ]
      }
    },
    {
      "file": "art/enemies/manifest.json",
      "pointer": "/state_sets/sagger_matron/states/vent/production",
      "relation": "production",
      "record": {
        "status": "current",
        "name": "泄压",
        "production": "art/enemies/sagger_matron/SPR_SaggerMatron_Vent.png",
        "source": "art/enemies/candidates/handdrawn_cleanup/SPR_SaggerMatron_Vent.png",
        "size": [
          1254,
          1254
        ]
      }
    }
  ],
  "business": [
    {
      "file": "data/enemies.json",
      "pointer": "/enemies/20/state_sprites/vent",
      "id": "sagger_matron",
      "name": "封窑兽·匣母"
    }
  ],
  "manual_evidence": []
}
```
