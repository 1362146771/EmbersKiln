# themes 交付表 · 1

[总目录](../README.md)

自动生成；人工修订填 ../overrides.json。尺寸为实际测量，专项要求与现状分别记录。

- [MenuBackground.tres](#asset-470f20afab38022a) — `themes/formal/MenuBackground.tres`
- [PlayerPortrait.tres](#asset-5839708991c716bb) — `themes/formal/PlayerPortrait.tres`
- [StoneLegend.tres](#asset-ffc4cbb5926b8c26) — `themes/formal/StoneLegend.tres`
- [Town_detail.tres](#asset-9f0fdd69ec65033a) — `themes/formal/Town_detail.tres`
- [Town_field.tres](#asset-4796a659969c73e9) — `themes/formal/Town_field.tres`
- [btn_event_normal.tres](#asset-67541f312d4c3efc) — `themes/formal/btn_event_normal.tres`
- [btn_hall_normal_small.tres](#asset-d6ae92bc38aecd29) — `themes/formal/btn_hall_normal_small.tres`
- [btn_return_normal_small.tres](#asset-cf53e1e781891bfe) — `themes/formal/btn_return_normal_small.tres`
- [btn_shop_normal_long.tres](#asset-2956d844883ee711) — `themes/formal/btn_shop_normal_long.tres`
- [btn_zhanLiPin_normal.tres](#asset-6bcf0302bbca243f) — `themes/formal/btn_zhanLiPin_normal.tres`

<a id="asset-470f20afab38022a"></a>
## MenuBackground.tres

[打开资产](../../../themes/formal/MenuBackground.tres) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：themes/formal/MenuBackground.tres；文件标识：MenuBackground；业务ID待确认／不适用 |
| 资产类别 | themes |
| 用途与出现位置 | Godot主题／StyleBox／AtlasTexture配置；被场景引用不等于贴图已批准 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 随消费组件变化，见具体场景 |
| 文件格式 | tres |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 动态文字、数值与交互反馈按对应 UI 组件独立提供；例外须由专项明确 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | MenuBackground.tres |
| 生产路径 | themes/formal/MenuBackground.tres |
| 引擎接入 | 静态证据：scenes/ui/RunResult.tscn:4；scripts/ui/FormalUI.gd:96；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=8ef372365897895e7ab2af84f57a7fb39a3853fbea60a1276f81928503ef0246；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 不适用（非序列帧）；若用于图集／材质，请查实际引用资源 |

| 检查项 | 结果 | 证据／问题 |
| --- | --- | --- |
| 文件、尺寸与命名 | 已盘点／已测量；命名合规待审核 | 实际文件、技术参数与SHA-256；不是设计验收PASS |
| 透明边缘与裁切 | 不适用图片Alpha检查 | 非图片；音频／材质／shader须在实际效果中另验 |
| 目标尺寸与同类一致性 | 待检查 | 尚未进行本次人工验收 |
| 美术风格 | 待检查 | 尚未进行本次人工验收 |
| Godot 编辑器与运行时 | NOT VERIFIED | 本次未启动Godot或截图，不沿用历史PASS |
| 来源与重建资料 | 待检查 | 尚未进行本次人工验收 |

技术测量：

```json
{
  "bytes": 527,
  "sha256": "8ef372365897895e7ab2af84f57a7fb39a3853fbea60a1276f81928503ef0246",
  "format": "tres",
  "resource_type": [
    "[gd_resource type=\"ShaderMaterial\" format=3 uid=\"uid://db062oq67b4vg\"]"
  ],
  "regions_and_margins": []
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scenes/ui/RunResult.tscn](../../../scenes/ui/RunResult.tscn)，行 4
- 静态资源引用：[scripts/ui/FormalUI.gd](../../../scripts/ui/FormalUI.gd)，行 96

<a id="asset-5839708991c716bb"></a>
## PlayerPortrait.tres

[打开资产](../../../themes/formal/PlayerPortrait.tres) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：themes/formal/PlayerPortrait.tres；文件标识：PlayerPortrait；业务ID待确认／不适用 |
| 资产类别 | themes |
| 用途与出现位置 | Godot主题／StyleBox／AtlasTexture配置；被场景引用不等于贴图已批准 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 随消费组件变化，见具体场景 |
| 文件格式 | tres |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 动态文字、数值与交互反馈按对应 UI 组件独立提供；例外须由专项明确 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | PlayerPortrait.tres |
| 生产路径 | themes/formal/PlayerPortrait.tres |
| 引擎接入 | 静态证据：scenes/combat/CombatPlay.tscn:5；scenes/main/PreRunPreparation.tscn:5；scripts/verify/EnemyPortraitVerify.gd:126；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=a537a3fb6bd08116c111bea56f7f1fdf294b6e4a630ef70463a32a2cc93b3363；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 不适用（非序列帧）；若用于图集／材质，请查实际引用资源 |

| 检查项 | 结果 | 证据／问题 |
| --- | --- | --- |
| 文件、尺寸与命名 | 已盘点／已测量；命名合规待审核 | 实际文件、技术参数与SHA-256；不是设计验收PASS |
| 透明边缘与裁切 | 不适用图片Alpha检查 | 非图片；音频／材质／shader须在实际效果中另验 |
| 目标尺寸与同类一致性 | 待检查 | 尚未进行本次人工验收 |
| 美术风格 | 待检查 | 尚未进行本次人工验收 |
| Godot 编辑器与运行时 | NOT VERIFIED | 本次未启动Godot或截图，不沿用历史PASS |
| 来源与重建资料 | 待检查 | 尚未进行本次人工验收 |

技术测量：

```json
{
  "bytes": 254,
  "sha256": "a537a3fb6bd08116c111bea56f7f1fdf294b6e4a630ef70463a32a2cc93b3363",
  "format": "tres",
  "resource_type": [
    "[gd_resource type=\"AtlasTexture\" format=3 uid=\"uid://dh5emmx0vsiow\"]"
  ],
  "regions_and_margins": [
    "atlas = ExtResource(\"1\")",
    "region = Rect2(230, 120, 520, 1330)"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scenes/combat/CombatPlay.tscn](../../../scenes/combat/CombatPlay.tscn)，行 5
- 静态资源引用：[scenes/main/PreRunPreparation.tscn](../../../scenes/main/PreRunPreparation.tscn)，行 5
- 验证代码引用：[scripts/verify/EnemyPortraitVerify.gd](../../../scripts/verify/EnemyPortraitVerify.gd)，行 126

<a id="asset-ffc4cbb5926b8c26"></a>
## StoneLegend.tres

[打开资产](../../../themes/formal/StoneLegend.tres) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：themes/formal/StoneLegend.tres；文件标识：StoneLegend；业务ID待确认／不适用 |
| 资产类别 | themes |
| 用途与出现位置 | Godot主题／StyleBox／AtlasTexture配置；被场景引用不等于贴图已批准 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 随消费组件变化，见具体场景 |
| 文件格式 | tres |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 动态文字、数值与交互反馈按对应 UI 组件独立提供；例外须由专项明确 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | StoneLegend.tres |
| 生产路径 | themes/formal/StoneLegend.tres |
| 引擎接入 | 静态证据：scenes/ui/EnchantLoadout.tscn:3；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=64669f7a6376f7369ccbfc5aa5607bf17024d903198c0f4804144b3ab247eebc；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 不适用（非序列帧）；若用于图集／材质，请查实际引用资源 |

| 检查项 | 结果 | 证据／问题 |
| --- | --- | --- |
| 文件、尺寸与命名 | 已盘点／已测量；命名合规待审核 | 实际文件、技术参数与SHA-256；不是设计验收PASS |
| 透明边缘与裁切 | 不适用图片Alpha检查 | 非图片；音频／材质／shader须在实际效果中另验 |
| 目标尺寸与同类一致性 | 待检查 | 尚未进行本次人工验收 |
| 美术风格 | 待检查 | 尚未进行本次人工验收 |
| Godot 编辑器与运行时 | NOT VERIFIED | 本次未启动Godot或截图，不沿用历史PASS |
| 来源与重建资料 | 待检查 | 尚未进行本次人工验收 |

技术测量：

```json
{
  "bytes": 402,
  "sha256": "64669f7a6376f7369ccbfc5aa5607bf17024d903198c0f4804144b3ab247eebc",
  "format": "tres",
  "resource_type": [
    "[gd_resource type=\"StyleBoxTexture\" format=3]"
  ],
  "regions_and_margins": [
    "texture = ExtResource(\"1\")",
    "texture_margin_left = 24.0",
    "content_margin_left = 12.0",
    "texture_margin_top = 24.0",
    "content_margin_top = 12.0",
    "texture_margin_right = 24.0",
    "content_margin_right = 12.0",
    "texture_margin_bottom = 24.0",
    "content_margin_bottom = 12.0"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scenes/ui/EnchantLoadout.tscn](../../../scenes/ui/EnchantLoadout.tscn)，行 3

<a id="asset-9f0fdd69ec65033a"></a>
## Town_detail.tres

[打开资产](../../../themes/formal/Town_detail.tres) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：themes/formal/Town_detail.tres；文件标识：Town_detail；业务ID待确认／不适用 |
| 资产类别 | themes |
| 用途与出现位置 | Godot主题／StyleBox／AtlasTexture配置；被场景引用不等于贴图已批准 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 随消费组件变化，见具体场景 |
| 文件格式 | tres |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 动态文字、数值与交互反馈按对应 UI 组件独立提供；例外须由专项明确 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | Town_detail.tres |
| 生产路径 | themes/formal/Town_detail.tres |
| 引擎接入 | 静态证据：scenes/main/PreRunAdPreparation.tscn:8；scenes/map/HiddenActEntrance.tscn:3；scenes/town/Town.tscn:24；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=1f000a4361d5db3a688a8be5de20fc4ffbaea90e3d15e3c182db6e9ba8ae25b0；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 不适用（非序列帧）；若用于图集／材质，请查实际引用资源 |

| 检查项 | 结果 | 证据／问题 |
| --- | --- | --- |
| 文件、尺寸与命名 | 已盘点／已测量；命名合规待审核 | 实际文件、技术参数与SHA-256；不是设计验收PASS |
| 透明边缘与裁切 | 不适用图片Alpha检查 | 非图片；音频／材质／shader须在实际效果中另验 |
| 目标尺寸与同类一致性 | 待检查 | 尚未进行本次人工验收 |
| 美术风格 | 待检查 | 尚未进行本次人工验收 |
| Godot 编辑器与运行时 | NOT VERIFIED | 本次未启动Godot或截图，不沿用历史PASS |
| 来源与重建资料 | 待检查 | 尚未进行本次人工验收 |

技术测量：

```json
{
  "bytes": 290,
  "sha256": "1f000a4361d5db3a688a8be5de20fc4ffbaea90e3d15e3c182db6e9ba8ae25b0",
  "format": "tres",
  "resource_type": [
    "[gd_resource type=\"StyleBoxTexture\" format=3]"
  ],
  "regions_and_margins": [
    "texture = ExtResource(\"1\")",
    "texture_margin_left = 24.0",
    "texture_margin_top = 24.0",
    "texture_margin_right = 24.0",
    "texture_margin_bottom = 24.0"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scenes/main/PreRunAdPreparation.tscn](../../../scenes/main/PreRunAdPreparation.tscn)，行 8
- 静态资源引用：[scenes/map/HiddenActEntrance.tscn](../../../scenes/map/HiddenActEntrance.tscn)，行 3
- 静态资源引用：[scenes/town/Town.tscn](../../../scenes/town/Town.tscn)，行 24

<a id="asset-4796a659969c73e9"></a>
## Town_field.tres

[打开资产](../../../themes/formal/Town_field.tres) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：themes/formal/Town_field.tres；文件标识：Town_field；业务ID待确认／不适用 |
| 资产类别 | themes |
| 用途与出现位置 | Godot主题／StyleBox／AtlasTexture配置；被场景引用不等于贴图已批准 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 随消费组件变化，见具体场景 |
| 文件格式 | tres |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 动态文字、数值与交互反馈按对应 UI 组件独立提供；例外须由专项明确 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | Town_field.tres |
| 生产路径 | themes/formal/Town_field.tres |
| 引擎接入 | 静态证据：scenes/main/PreRunPreparation.tscn:8；scenes/town/Town.tscn:22；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=8ce6d59e068fecf400267a809bd8c694fc8ad6d32e99a4d130b5014599019f7e；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 不适用（非序列帧）；若用于图集／材质，请查实际引用资源 |

| 检查项 | 结果 | 证据／问题 |
| --- | --- | --- |
| 文件、尺寸与命名 | 已盘点／已测量；命名合规待审核 | 实际文件、技术参数与SHA-256；不是设计验收PASS |
| 透明边缘与裁切 | 不适用图片Alpha检查 | 非图片；音频／材质／shader须在实际效果中另验 |
| 目标尺寸与同类一致性 | 待检查 | 尚未进行本次人工验收 |
| 美术风格 | 待检查 | 尚未进行本次人工验收 |
| Godot 编辑器与运行时 | NOT VERIFIED | 本次未启动Godot或截图，不沿用历史PASS |
| 来源与重建资料 | 待检查 | 尚未进行本次人工验收 |

技术测量：

```json
{
  "bytes": 292,
  "sha256": "8ce6d59e068fecf400267a809bd8c694fc8ad6d32e99a4d130b5014599019f7e",
  "format": "tres",
  "resource_type": [
    "[gd_resource type=\"StyleBoxTexture\" format=3]"
  ],
  "regions_and_margins": [
    "texture = ExtResource(\"1\")",
    "texture_margin_left = 24.0",
    "texture_margin_top = 24.0",
    "texture_margin_right = 24.0",
    "texture_margin_bottom = 24.0"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scenes/main/PreRunPreparation.tscn](../../../scenes/main/PreRunPreparation.tscn)，行 8
- 静态资源引用：[scenes/town/Town.tscn](../../../scenes/town/Town.tscn)，行 22

<a id="asset-67541f312d4c3efc"></a>
## btn_event_normal.tres

[打开资产](../../../themes/formal/btn_event_normal.tres) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：themes/formal/btn_event_normal.tres；文件标识：btn_event_normal；业务ID待确认／不适用 |
| 资产类别 | themes |
| 用途与出现位置 | Godot主题／StyleBox／AtlasTexture配置；被场景引用不等于贴图已批准 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 随消费组件变化，见具体场景 |
| 文件格式 | tres |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 动态文字、数值与交互反馈按对应 UI 组件独立提供；例外须由专项明确 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | btn_event_normal.tres |
| 生产路径 | themes/formal/btn_event_normal.tres |
| 引擎接入 | 静态证据：scenes/main/BuffOffer.tscn:5；scenes/main/PreRunAdPreparation.tscn:6；scenes/main/PreRunPreparation.tscn:7；scenes/map/EventUI.tscn:4；scenes/map/HiddenActEntrance.tscn:2；scenes/map/MapPlay.tscn:6；scenes/map/TreasureUI.tscn:6；scenes/town/Town.tscn:14；scenes/ui/FireseedInfo.tscn:5；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=cefd028493310c45777bd9f88e9c3641f30f33cc6c756b343cd1e6fb8a07e40a；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 不适用（非序列帧）；若用于图集／材质，请查实际引用资源 |

| 检查项 | 结果 | 证据／问题 |
| --- | --- | --- |
| 文件、尺寸与命名 | 已盘点／已测量；命名合规待审核 | 实际文件、技术参数与SHA-256；不是设计验收PASS |
| 透明边缘与裁切 | 不适用图片Alpha检查 | 非图片；音频／材质／shader须在实际效果中另验 |
| 目标尺寸与同类一致性 | 待检查 | 尚未进行本次人工验收 |
| 美术风格 | 待检查 | 尚未进行本次人工验收 |
| Godot 编辑器与运行时 | NOT VERIFIED | 本次未启动Godot或截图，不沿用历史PASS |
| 来源与重建资料 | 待检查 | 尚未进行本次人工验收 |

技术测量：

```json
{
  "bytes": 2832,
  "sha256": "cefd028493310c45777bd9f88e9c3641f30f33cc6c756b343cd1e6fb8a07e40a",
  "format": "tres",
  "resource_type": [
    "[gd_resource type=\"Theme\" format=3 uid=\"uid://cxfpxjrywhns\"]"
  ],
  "regions_and_margins": [
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_asmou\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_asmou\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_asmou\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_asmou\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_asmou\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scenes/main/BuffOffer.tscn](../../../scenes/main/BuffOffer.tscn)，行 5
- 静态资源引用：[scenes/main/PreRunAdPreparation.tscn](../../../scenes/main/PreRunAdPreparation.tscn)，行 6
- 静态资源引用：[scenes/main/PreRunPreparation.tscn](../../../scenes/main/PreRunPreparation.tscn)，行 7
- 静态资源引用：[scenes/map/EventUI.tscn](../../../scenes/map/EventUI.tscn)，行 4
- 静态资源引用：[scenes/map/HiddenActEntrance.tscn](../../../scenes/map/HiddenActEntrance.tscn)，行 2
- 静态资源引用：[scenes/map/MapPlay.tscn](../../../scenes/map/MapPlay.tscn)，行 6
- 静态资源引用：[scenes/map/TreasureUI.tscn](../../../scenes/map/TreasureUI.tscn)，行 6
- 静态资源引用：[scenes/town/Town.tscn](../../../scenes/town/Town.tscn)，行 14
- 静态资源引用：[scenes/ui/FireseedInfo.tscn](../../../scenes/ui/FireseedInfo.tscn)，行 5

<a id="asset-d6ae92bc38aecd29"></a>
## btn_hall_normal_small.tres

[打开资产](../../../themes/formal/btn_hall_normal_small.tres) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：themes/formal/btn_hall_normal_small.tres；文件标识：btn_hall_normal_small；业务ID待确认／不适用 |
| 资产类别 | themes |
| 用途与出现位置 | Godot主题／StyleBox／AtlasTexture配置；被场景引用不等于贴图已批准 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 随消费组件变化，见具体场景 |
| 文件格式 | tres |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 动态文字、数值与交互反馈按对应 UI 组件独立提供；例外须由专项明确 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | btn_hall_normal_small.tres |
| 生产路径 | themes/formal/btn_hall_normal_small.tres |
| 引擎接入 | 静态证据：scenes/main/MainMenu.tscn:3；scenes/main/PreRunAdPreparation.tscn:9；scenes/ui/AudioSettingsPopup.tscn:5；scenes/ui/RunResult.tscn:3；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=fa4649dc5b553ffcc50a0c7c995195246c3c605995318f63d83d3f7d98fbc1be；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 不适用（非序列帧）；若用于图集／材质，请查实际引用资源 |

| 检查项 | 结果 | 证据／问题 |
| --- | --- | --- |
| 文件、尺寸与命名 | 已盘点／已测量；命名合规待审核 | 实际文件、技术参数与SHA-256；不是设计验收PASS |
| 透明边缘与裁切 | 不适用图片Alpha检查 | 非图片；音频／材质／shader须在实际效果中另验 |
| 目标尺寸与同类一致性 | 待检查 | 尚未进行本次人工验收 |
| 美术风格 | 待检查 | 尚未进行本次人工验收 |
| Godot 编辑器与运行时 | NOT VERIFIED | 本次未启动Godot或截图，不沿用历史PASS |
| 来源与重建资料 | 待检查 | 尚未进行本次人工验收 |

技术测量：

```json
{
  "bytes": 2483,
  "sha256": "fa4649dc5b553ffcc50a0c7c995195246c3c605995318f63d83d3f7d98fbc1be",
  "format": "tres",
  "resource_type": [
    "[gd_resource type=\"Theme\" format=3 uid=\"uid://mmwy4iawijb3\"]"
  ],
  "regions_and_margins": [
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_r3xkk\")",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_r3xkk\")",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_r3xkk\")",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_r3xkk\")"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scenes/main/MainMenu.tscn](../../../scenes/main/MainMenu.tscn)，行 3
- 静态资源引用：[scenes/main/PreRunAdPreparation.tscn](../../../scenes/main/PreRunAdPreparation.tscn)，行 9
- 静态资源引用：[scenes/ui/AudioSettingsPopup.tscn](../../../scenes/ui/AudioSettingsPopup.tscn)，行 5
- 静态资源引用：[scenes/ui/RunResult.tscn](../../../scenes/ui/RunResult.tscn)，行 3

<a id="asset-cf53e1e781891bfe"></a>
## btn_return_normal_small.tres

[打开资产](../../../themes/formal/btn_return_normal_small.tres) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：themes/formal/btn_return_normal_small.tres；文件标识：btn_return_normal_small；业务ID待确认／不适用 |
| 资产类别 | themes |
| 用途与出现位置 | Godot主题／StyleBox／AtlasTexture配置；被场景引用不等于贴图已批准 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 随消费组件变化，见具体场景 |
| 文件格式 | tres |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 动态文字、数值与交互反馈按对应 UI 组件独立提供；例外须由专项明确 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | btn_return_normal_small.tres |
| 生产路径 | themes/formal/btn_return_normal_small.tres |
| 引擎接入 | 静态证据：scenes/town/Town.tscn:13；scenes/ui/BattleRewardOverview.tscn:6；scenes/ui/PotionDetails.tscn:4；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=37e122c9f0f35e299095a1fc2dbf2ea346e4e2dc09f64ca2f24052c5b6b3a209；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 不适用（非序列帧）；若用于图集／材质，请查实际引用资源 |

| 检查项 | 结果 | 证据／问题 |
| --- | --- | --- |
| 文件、尺寸与命名 | 已盘点／已测量；命名合规待审核 | 实际文件、技术参数与SHA-256；不是设计验收PASS |
| 透明边缘与裁切 | 不适用图片Alpha检查 | 非图片；音频／材质／shader须在实际效果中另验 |
| 目标尺寸与同类一致性 | 待检查 | 尚未进行本次人工验收 |
| 美术风格 | 待检查 | 尚未进行本次人工验收 |
| Godot 编辑器与运行时 | NOT VERIFIED | 本次未启动Godot或截图，不沿用历史PASS |
| 来源与重建资料 | 待检查 | 尚未进行本次人工验收 |

技术测量：

```json
{
  "bytes": 2839,
  "sha256": "37e122c9f0f35e299095a1fc2dbf2ea346e4e2dc09f64ca2f24052c5b6b3a209",
  "format": "tres",
  "resource_type": [
    "[gd_resource type=\"Theme\" format=3 uid=\"uid://jygg6eyq13il\"]"
  ],
  "regions_and_margins": [
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_fqme3\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_fqme3\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_fqme3\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_fqme3\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_fqme3\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scenes/town/Town.tscn](../../../scenes/town/Town.tscn)，行 13
- 静态资源引用：[scenes/ui/BattleRewardOverview.tscn](../../../scenes/ui/BattleRewardOverview.tscn)，行 6
- 静态资源引用：[scenes/ui/PotionDetails.tscn](../../../scenes/ui/PotionDetails.tscn)，行 4

<a id="asset-2956d844883ee711"></a>
## btn_shop_normal_long.tres

[打开资产](../../../themes/formal/btn_shop_normal_long.tres) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：themes/formal/btn_shop_normal_long.tres；文件标识：btn_shop_normal_long；业务ID待确认／不适用 |
| 资产类别 | themes |
| 用途与出现位置 | Godot主题／StyleBox／AtlasTexture配置；被场景引用不等于贴图已批准 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 随消费组件变化，见具体场景 |
| 文件格式 | tres |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 动态文字、数值与交互反馈按对应 UI 组件独立提供；例外须由专项明确 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | btn_shop_normal_long.tres |
| 生产路径 | themes/formal/btn_shop_normal_long.tres |
| 引擎接入 | 静态证据：scenes/map/ShopUI.tscn:4；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=7e6ba5760aa1e8172275b1ca59405a9cf475e67fce83ffdc2617f72bf4260ab2；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 不适用（非序列帧）；若用于图集／材质，请查实际引用资源 |

| 检查项 | 结果 | 证据／问题 |
| --- | --- | --- |
| 文件、尺寸与命名 | 已盘点／已测量；命名合规待审核 | 实际文件、技术参数与SHA-256；不是设计验收PASS |
| 透明边缘与裁切 | 不适用图片Alpha检查 | 非图片；音频／材质／shader须在实际效果中另验 |
| 目标尺寸与同类一致性 | 待检查 | 尚未进行本次人工验收 |
| 美术风格 | 待检查 | 尚未进行本次人工验收 |
| Godot 编辑器与运行时 | NOT VERIFIED | 本次未启动Godot或截图，不沿用历史PASS |
| 来源与重建资料 | 待检查 | 尚未进行本次人工验收 |

技术测量：

```json
{
  "bytes": 2837,
  "sha256": "7e6ba5760aa1e8172275b1ca59405a9cf475e67fce83ffdc2617f72bf4260ab2",
  "format": "tres",
  "resource_type": [
    "[gd_resource type=\"Theme\" format=3 uid=\"uid://buytv31it4syg\"]"
  ],
  "regions_and_margins": [
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_x1tw0\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_x1tw0\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_x1tw0\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_x1tw0\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_x1tw0\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scenes/map/ShopUI.tscn](../../../scenes/map/ShopUI.tscn)，行 4

<a id="asset-6bcf0302bbca243f"></a>
## btn_zhanLiPin_normal.tres

[打开资产](../../../themes/formal/btn_zhanLiPin_normal.tres) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：themes/formal/btn_zhanLiPin_normal.tres；文件标识：btn_zhanLiPin_normal；业务ID待确认／不适用 |
| 资产类别 | themes |
| 用途与出现位置 | Godot主题／StyleBox／AtlasTexture配置；被场景引用不等于贴图已批准 |
| 依据与参考 | AI_Studio/Design/Art/ART_STYLE.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 随消费组件变化，见具体场景 |
| 文件格式 | tres |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 动态文字、数值与交互反馈按对应 UI 组件独立提供；例外须由专项明确 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | btn_zhanLiPin_normal.tres |
| 生产路径 | themes/formal/btn_zhanLiPin_normal.tres |
| 引擎接入 | 静态证据：scenes/rewards/BossRelicChoice.tscn:4；scenes/rewards/RewardUI.tscn:6；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=4697374750acca28cc2171a4e5ceff423f5798c3d432afb2ae332f5aa77d035b；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 不适用（非序列帧）；若用于图集／材质，请查实际引用资源 |

| 检查项 | 结果 | 证据／问题 |
| --- | --- | --- |
| 文件、尺寸与命名 | 已盘点／已测量；命名合规待审核 | 实际文件、技术参数与SHA-256；不是设计验收PASS |
| 透明边缘与裁切 | 不适用图片Alpha检查 | 非图片；音频／材质／shader须在实际效果中另验 |
| 目标尺寸与同类一致性 | 待检查 | 尚未进行本次人工验收 |
| 美术风格 | 待检查 | 尚未进行本次人工验收 |
| Godot 编辑器与运行时 | NOT VERIFIED | 本次未启动Godot或截图，不沿用历史PASS |
| 来源与重建资料 | 待检查 | 尚未进行本次人工验收 |

技术测量：

```json
{
  "bytes": 2837,
  "sha256": "4697374750acca28cc2171a4e5ceff423f5798c3d432afb2ae332f5aa77d035b",
  "format": "tres",
  "resource_type": [
    "[gd_resource type=\"Theme\" format=3 uid=\"uid://c7ayq5d4blbto\"]"
  ],
  "regions_and_margins": [
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_bwncy\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_bwncy\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_bwncy\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_bwncy\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0",
    "content_margin_left = 12.0",
    "content_margin_top = 12.0",
    "content_margin_right = 12.0",
    "content_margin_bottom = 12.0",
    "texture = ExtResource(\"1_bwncy\")",
    "texture_margin_left = 12.0",
    "texture_margin_top = 12.0",
    "texture_margin_right = 12.0",
    "texture_margin_bottom = 12.0"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scenes/rewards/BossRelicChoice.tscn](../../../scenes/rewards/BossRelicChoice.tscn)，行 4
- 静态资源引用：[scenes/rewards/RewardUI.tscn](../../../scenes/rewards/RewardUI.tscn)，行 6
