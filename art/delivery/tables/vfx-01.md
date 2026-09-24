# vfx 交付表 · 1

[总目录](../README.md)

自动生成；人工修订填 ../overrides.json。尺寸为实际测量，专项要求与现状分别记录。

- [ART_CAST_BURST.png](#asset-77e4f6fb906e2e84) — `art/vfx/ART_CAST_BURST.png`
- [ART_STRIKE_CARD.png](#asset-c85c8781ac687254) — `art/vfx/ART_STRIKE_CARD.png`
- [AshenBinderHUDMask.gdshader](#asset-90acc7604c0ac46c) — `art/vfx/AshenBinderHUDMask.gdshader`
- [EnemyHitFlash.gdshader](#asset-3cdd29b84afd2d7e) — `art/vfx/EnemyHitFlash.gdshader`
- [LowHealth.gdshader](#asset-2f2b11bf172c0865) — `art/vfx/LowHealth.gdshader`
- [PlayerSlash.gdshader](#asset-1bd9ff69f803d47d) — `art/vfx/PlayerSlash.gdshader`
- [WhiteSlash.gdshader](#asset-db05198f581531a2) — `art/vfx/WhiteSlash.gdshader`
- [EnchantScreen.gdshader](#asset-4c6316b095ae4a89) — `art/vfx/enchant/EnchantScreen.gdshader`
- [blood_for_blood.png](#asset-0b588923f49daec4) — `art/vfx/enchant/handdrawn/blood_for_blood.png`
- [bludgeon.png](#asset-cc6b30b09998a352) — `art/vfx/enchant/handdrawn/bludgeon.png`
- [carnage.png](#asset-4f34426a83e9f047) — `art/vfx/enchant/handdrawn/carnage.png`
- [fiend_fire.png](#asset-ed24670e97433561) — `art/vfx/enchant/handdrawn/fiend_fire.png`
- [immolate.png](#asset-ff3d04b96fe2d29e) — `art/vfx/enchant/handdrawn/immolate.png`
- [reaper.png](#asset-a14c393d8a4942a7) — `art/vfx/enchant/handdrawn/reaper.png`
- [searing_blow.png](#asset-a9cbb46de0253b58) — `art/vfx/enchant/handdrawn/searing_blow.png`
- [sever_soul.png](#asset-4701d4f66593db5b) — `art/vfx/enchant/handdrawn/sever_soul.png`
- [uppercut.png](#asset-aa08bc13638e9373) — `art/vfx/enchant/handdrawn/uppercut.png`
- [reaper_half_face.png](#asset-c15d238a4cf6a596) — `art/vfx/enchant/reaper_half_face.png`
- [reaper_half_face_v2.png](#asset-613c81eeebd655a2) — `art/vfx/enchant/reaper_half_face_v2.png`

<a id="asset-77e4f6fb906e2e84"></a>
## ART_CAST_BURST.png

[打开资产](../../vfx/ART_CAST_BURST.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/ART_CAST_BURST.png；文件标识：ART_CAST_BURST；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1024 × 1024 px |
| 正式交付尺寸 | 当前文件实测=1024 × 1024 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGB; Alpha=无透明通道 |
| 构图与留白 | 按对应参考检查主体完整性、安全边距；未有明确模板的项目待确认 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | ART_CAST_BURST.png |
| 生产路径 | art/vfx/ART_CAST_BURST.png |
| 引擎接入 | 静态证据：scripts/verify/CardPlayQueueVerify.gd:78；scripts/verify/EnemyActionPresentationVerify.gd:19；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=7961f5fed9674d13978ff0aa194b21146b4028e3e1a164eac8dc0ba336d5f284；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 用途待核对：未发现完整路径静态引用；可能由动态拼接加载；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 按实际shader／动画与 data/vfx.json核对，不能按文件帧数猜测运行时长 |

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
  "bytes": 785466,
  "sha256": "7961f5fed9674d13978ff0aa194b21146b4028e3e1a164eac8dc0ba336d5f284",
  "width": 1024,
  "height": 1024,
  "mode": "RGB",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": false
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 验证代码引用：[scripts/verify/CardPlayQueueVerify.gd](../../../scripts/verify/CardPlayQueueVerify.gd)，行 78
- 验证代码引用：[scripts/verify/EnemyActionPresentationVerify.gd](../../../scripts/verify/EnemyActionPresentationVerify.gd)，行 19
- 生产资料：[art/README.md](../../README.md)

<a id="asset-c85c8781ac687254"></a>
## ART_STRIKE_CARD.png

[打开资产](../../vfx/ART_STRIKE_CARD.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/ART_STRIKE_CARD.png；文件标识：ART_STRIKE_CARD；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1024 × 1536 px |
| 正式交付尺寸 | 当前文件实测=1024 × 1536 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGB; Alpha=无透明通道 |
| 构图与留白 | 按对应参考检查主体完整性、安全边距；未有明确模板的项目待确认 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | ART_STRIKE_CARD.png |
| 生产路径 | art/vfx/ART_STRIKE_CARD.png |
| 引擎接入 | 静态证据：scripts/verify/CardPlayQueueVerify.gd:78；scripts/verify/EnemyActionPresentationVerify.gd:19；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=dfc3df63738d80dedc185520140c9f5ce418f9e8f6056da848b20cfe24290d14；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 用途待核对：未发现完整路径静态引用；可能由动态拼接加载；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 按实际shader／动画与 data/vfx.json核对，不能按文件帧数猜测运行时长 |

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
  "bytes": 1879449,
  "sha256": "dfc3df63738d80dedc185520140c9f5ce418f9e8f6056da848b20cfe24290d14",
  "width": 1024,
  "height": 1536,
  "mode": "RGB",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": false
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 验证代码引用：[scripts/verify/CardPlayQueueVerify.gd](../../../scripts/verify/CardPlayQueueVerify.gd)，行 78
- 验证代码引用：[scripts/verify/EnemyActionPresentationVerify.gd](../../../scripts/verify/EnemyActionPresentationVerify.gd)，行 19
- 生产资料：[art/README.md](../../README.md)

<a id="asset-90acc7604c0ac46c"></a>
## AshenBinderHUDMask.gdshader

[打开资产](../../vfx/AshenBinderHUDMask.gdshader) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/AshenBinderHUDMask.gdshader；文件标识：AshenBinderHUDMask；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | gdshader |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | AshenBinderHUDMask.gdshader |
| 生产路径 | art/vfx/AshenBinderHUDMask.gdshader |
| 引擎接入 | 静态证据：scripts/combat/AshenBinderFX.gd:20；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=5e4355682ce7998cdab9574ba4e9645595f4906a69c961ef617bbd85cfe4d31e；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 按实际shader／动画与 data/vfx.json核对，不能按文件帧数猜测运行时长 |

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
  "bytes": 422,
  "sha256": "5e4355682ce7998cdab9574ba4e9645595f4906a69c961ef617bbd85cfe4d31e",
  "format": "gdshader",
  "shader_type": [
    "canvas_item"
  ],
  "uniforms": [
    "uniform vec2 hud_band = vec2(0.0);",
    "uniform float hand_top = 100000.0;"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scripts/combat/AshenBinderFX.gd](../../../scripts/combat/AshenBinderFX.gd)，行 20
- 生产资料：[art/README.md](../../README.md)

<a id="asset-3cdd29b84afd2d7e"></a>
## EnemyHitFlash.gdshader

[打开资产](../../vfx/EnemyHitFlash.gdshader) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/EnemyHitFlash.gdshader；文件标识：EnemyHitFlash；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | gdshader |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | EnemyHitFlash.gdshader |
| 生产路径 | art/vfx/EnemyHitFlash.gdshader |
| 引擎接入 | 静态证据：scripts/combat/EnemyCombatPortrait.gd:22；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=95cbc44ed435705e5e88d488b99d626e89c95570a090002a249efbea7dd13c68；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 按实际shader／动画与 data/vfx.json核对，不能按文件帧数猜测运行时长 |

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
  "bytes": 149,
  "sha256": "95cbc44ed435705e5e88d488b99d626e89c95570a090002a249efbea7dd13c68",
  "format": "gdshader",
  "shader_type": [
    "canvas_item"
  ],
  "uniforms": [
    "uniform float strength : hint_range(0.0, 1.0) = 0.0;"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scripts/combat/EnemyCombatPortrait.gd](../../../scripts/combat/EnemyCombatPortrait.gd)，行 22
- 生产资料：[art/README.md](../../README.md)

<a id="asset-2f2b11bf172c0865"></a>
## LowHealth.gdshader

[打开资产](../../vfx/LowHealth.gdshader) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/LowHealth.gdshader；文件标识：LowHealth；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | gdshader |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | LowHealth.gdshader |
| 生产路径 | art/vfx/LowHealth.gdshader |
| 引擎接入 | 静态证据：scripts/combat/CombatFeedback.gd:37；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=dd8a6ba4de9eaee14635cc2aed36e7954a687e46ce632b386d0ab8e4650e95d7；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 按实际shader／动画与 data/vfx.json核对，不能按文件帧数猜测运行时长 |

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
  "bytes": 502,
  "sha256": "dd8a6ba4de9eaee14635cc2aed36e7954a687e46ce632b386d0ab8e4650e95d7",
  "format": "gdshader",
  "shader_type": [
    "canvas_item"
  ],
  "uniforms": [
    "uniform vec4 blood_color : source_color;",
    "uniform float edge_width;",
    "uniform float opacity;"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scripts/combat/CombatFeedback.gd](../../../scripts/combat/CombatFeedback.gd)，行 37
- 生产资料：[art/README.md](../../README.md)

<a id="asset-1bd9ff69f803d47d"></a>
## PlayerSlash.gdshader

[打开资产](../../vfx/PlayerSlash.gdshader) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/PlayerSlash.gdshader；文件标识：PlayerSlash；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | gdshader |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | PlayerSlash.gdshader |
| 生产路径 | art/vfx/PlayerSlash.gdshader |
| 引擎接入 | 静态证据：scripts/combat/PlayerCombatPortrait.gd:128；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=0b3ada9ca6b93eb509f5b32602ac6d11b5b94b47cc6deb9186644ef2b18d7d55；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 按实际shader／动画与 data/vfx.json核对，不能按文件帧数猜测运行时长 |

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
  "bytes": 509,
  "sha256": "0b3ada9ca6b93eb509f5b32602ac6d11b5b94b47cc6deb9186644ef2b18d7d55",
  "format": "gdshader",
  "shader_type": [
    "canvas_item"
  ],
  "uniforms": [
    "uniform float progress = 0.0;"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scripts/combat/PlayerCombatPortrait.gd](../../../scripts/combat/PlayerCombatPortrait.gd)，行 128
- 生产资料：[art/README.md](../../README.md)

<a id="asset-db05198f581531a2"></a>
## WhiteSlash.gdshader

[打开资产](../../vfx/WhiteSlash.gdshader) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/WhiteSlash.gdshader；文件标识：WhiteSlash；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | gdshader |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | WhiteSlash.gdshader |
| 生产路径 | art/vfx/WhiteSlash.gdshader |
| 引擎接入 | 静态证据：scripts/core/VFXSystem.gd:47；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=9607920676f9fe07b1a8644703d10be02d42cad0f11d1ef71f103150874641ab；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 按实际shader／动画与 data/vfx.json核对，不能按文件帧数猜测运行时长 |

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
  "bytes": 890,
  "sha256": "9607920676f9fe07b1a8644703d10be02d42cad0f11d1ef71f103150874641ab",
  "format": "gdshader",
  "shader_type": [
    "canvas_item"
  ],
  "uniforms": [
    "uniform float progress : hint_range(0.0, 1.0) = 0.0;"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scripts/core/VFXSystem.gd](../../../scripts/core/VFXSystem.gd)，行 47
- 生产资料：[art/README.md](../../README.md)

<a id="asset-4c6316b095ae4a89"></a>
## EnchantScreen.gdshader

[打开资产](../../vfx/enchant/EnchantScreen.gdshader) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/enchant/EnchantScreen.gdshader；文件标识：EnchantScreen；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 不适用固定图像视角；实际视觉方向随消费场景 |
| 源图尺寸 | 不适用（非图片）；制作源见来源资料 |
| 正式交付尺寸 | 不适用像素尺寸；见文件格式及技术参数 |
| Godot 导入尺寸 | 不适用（非纹理像素导入） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | gdshader |
| 构图与留白 | 不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果 |
| 对齐与视觉大小 | 按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | EnchantScreen.gdshader |
| 生产路径 | art/vfx/enchant/EnchantScreen.gdshader |
| 引擎接入 | 静态证据：scenes/combat/EnchantAttackFX.tscn:4；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=8697132f101bf87a38fcf8af82a5acf9976d1ec21e1de5c0a5102550ac5541ee；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 按实际shader／动画与 data/vfx.json核对，不能按文件帧数猜测运行时长 |

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
  "bytes": 11030,
  "sha256": "8697132f101bf87a38fcf8af82a5acf9976d1ec21e1de5c0a5102550ac5541ee",
  "format": "gdshader",
  "shader_type": [
    "canvas_item"
  ],
  "uniforms": [
    "uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;",
    "uniform sampler2D effect_atlas : source_color, repeat_disable, filter_linear;",
    "uniform sampler2D cutin_portrait : source_color, repeat_disable, filter_linear;",
    "uniform float cutin_progress = -1.0;",
    "uniform float cutin_portrait_height = 0.98;",
    "uniform vec2 cutin_portrait_offset = vec2(-0.19, 0.035);",
    "uniform float cutin_mask_top = 0.50;",
    "uniform float cutin_mask_bottom = 0.90;",
    "uniform vec4 cutin_mask_color : source_color = vec4(0.02745, 0.01961, 0.04706, 1.0);",
    "uniform float cutin_background_retention = 0.04;",
    "uniform vec2 cutin_eye_uv = vec2(0.716, 0.482);",
    "uniform float cutin_blur_pixels = 18.0;",
    "uniform vec4 cutin_red : source_color = vec4(0.835, 0.16, 0.21, 1.0);",
    "uniform float charge = 0.0;",
    "uniform float progress = 0.0;",
    "uniform float strength = 0.0;",
    "uniform float frame_cursor = 0.0;",
    "uniform bool stepped_frames = false;",
    "uniform vec2 impact_offset = vec2(0.0);",
    "uniform float impact_zoom = 0.0;",
    "uniform int effect_kind = 0;",
    "uniform vec2 origin_uv = vec2(0.5, 0.32);",
    "uniform vec2 canvas_size = vec2(720.0, 1280.0);",
    "uniform vec2 sprite_size = vec2(520.0);",
    "uniform vec2 sprite_anchor = vec2(0.5);",
    "uniform vec2 sprite_offset = vec2(0.0);",
    "uniform float sprite_rotation = 0.0;",
    "uniform float saturation = 0.72;",
    "uniform vec4 fire_color : source_color = vec4(0.85, 0.64, 0.25, 1.0);",
    "uniform vec4 core_color : source_color = vec4(0.88, 0.76, 0.67, 1.0);",
    "uniform vec4 ash_color : source_color = vec4(0.49, 0.31, 0.31, 1.0);",
    "uniform vec4 ink_color : source_color = vec4(0.106, 0.086, 0.07, 1.0);",
    "uniform float darken = 0.38;",
    "uniform float distortion_pixels = 9.0;",
    "uniform float reduced_motion = 0.0;",
    "uniform int target_count = 0;",
    "uniform vec2 target_origins[8];"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scenes/combat/EnchantAttackFX.tscn](../../../scenes/combat/EnchantAttackFX.tscn)，行 4
- 生产资料：[art/README.md](../../README.md)

<a id="asset-0b588923f49daec4"></a>
## blood_for_blood.png

[打开资产](../../vfx/enchant/handdrawn/blood_for_blood.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/enchant/handdrawn/blood_for_blood.png；文件标识：blood_for_blood；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；art/vfx/enchant/handdrawn/README.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1536 × 1024 px |
| 正式交付尺寸 | 当前文件实测=1536 × 1024 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGBA; Alpha=[0, 254]；非零Alpha包围盒=(25, 9, 1518, 1024)（右／下边界不含） |
| 构图与留白 | 正式九张图集1536×1024，3列×2行，单帧512×512；保留绘制锚点，不逐帧重缩放 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | blood_for_blood.png |
| 生产路径 | art/vfx/enchant/handdrawn/blood_for_blood.png |
| 引擎接入 | 静态证据：data/vfx.json:1038；data/vfx.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=1f10e06836b980de1b1976b1055e9c87c8f8d7ff4824e01594eff308c7d204bf；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 6帧非匀速；基础演出1.20秒，死亡收割另加0.65秒前置。命中与运行参数由配置驱动 |

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
  "bytes": 1779767,
  "sha256": "1f10e06836b980de1b1976b1055e9c87c8f8d7ff4824e01594eff308c7d204bf",
  "width": 1536,
  "height": 1024,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    254
  ],
  "alpha_bbox": [
    25,
    9,
    1518,
    1024
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/vfx.json](../../../data/vfx.json)，行 1038
- 数据字段映射：[data/vfx.json](../../../data/vfx.json)
- 生产资料：[art/vfx/enchant/handdrawn/README.md](../../vfx/enchant/handdrawn/README.md)
- 生产资料：[art/vfx/enchant/handdrawn/prompts.json](../../vfx/enchant/handdrawn/prompts.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/vfx/enchant/handdrawn/remaining_prompts.json",
      "pointer": "/assets/blood_for_blood/runtime",
      "relation": "runtime",
      "record": {
        "generator": "image_gen (generate2dsprite workflow)"
      }
    }
  ],
  "business": [
    {
      "file": "data/vfx.json",
      "pointer": "/enchant_attack/profiles/blood_for_blood/atlas",
      "id": "",
      "name": ""
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-cc6b30b09998a352"></a>
## bludgeon.png

[打开资产](../../vfx/enchant/handdrawn/bludgeon.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/enchant/handdrawn/bludgeon.png；文件标识：bludgeon；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；art/vfx/enchant/handdrawn/README.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1536 × 1024 px |
| 正式交付尺寸 | 当前文件实测=1536 × 1024 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(39, 26, 1497, 996)（右／下边界不含） |
| 构图与留白 | 正式九张图集1536×1024，3列×2行，单帧512×512；保留绘制锚点，不逐帧重缩放 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | bludgeon.png |
| 生产路径 | art/vfx/enchant/handdrawn/bludgeon.png |
| 引擎接入 | 静态证据：data/vfx.json:846；data/vfx.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=564b3e490daffe66389aeca74c0f090ded0d3901c986dbc5ecc3148000dc3af2；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 6帧非匀速；基础演出1.20秒，死亡收割另加0.65秒前置。命中与运行参数由配置驱动 |

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
  "bytes": 783225,
  "sha256": "564b3e490daffe66389aeca74c0f090ded0d3901c986dbc5ecc3148000dc3af2",
  "width": 1536,
  "height": 1024,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    39,
    26,
    1497,
    996
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/vfx.json](../../../data/vfx.json)，行 846
- 数据字段映射：[data/vfx.json](../../../data/vfx.json)
- 生产资料：[art/vfx/enchant/handdrawn/README.md](../../vfx/enchant/handdrawn/README.md)
- 生产资料：[art/vfx/enchant/handdrawn/prompts.json](../../vfx/enchant/handdrawn/prompts.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [],
  "business": [
    {
      "file": "data/vfx.json",
      "pointer": "/enchant_attack/profiles/kiln_cleave/atlas",
      "id": "",
      "name": ""
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-4f34426a83e9f047"></a>
## carnage.png

[打开资产](../../vfx/enchant/handdrawn/carnage.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/enchant/handdrawn/carnage.png；文件标识：carnage；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；art/vfx/enchant/handdrawn/README.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1536 × 1024 px |
| 正式交付尺寸 | 当前文件实测=1536 × 1024 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGBA; Alpha=[0, 254]；非零Alpha包围盒=(39, 21, 1520, 1024)（右／下边界不含） |
| 构图与留白 | 正式九张图集1536×1024，3列×2行，单帧512×512；保留绘制锚点，不逐帧重缩放 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | carnage.png |
| 生产路径 | art/vfx/enchant/handdrawn/carnage.png |
| 引擎接入 | 静态证据：data/vfx.json:918；data/vfx.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=69be182537571e45e0bb54e70819d1b51c6471c4261195c27c859e0985ffdbcc；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 6帧非匀速；基础演出1.20秒，死亡收割另加0.65秒前置。命中与运行参数由配置驱动 |

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
  "bytes": 1846267,
  "sha256": "69be182537571e45e0bb54e70819d1b51c6471c4261195c27c859e0985ffdbcc",
  "width": 1536,
  "height": 1024,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    254
  ],
  "alpha_bbox": [
    39,
    21,
    1520,
    1024
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/vfx.json](../../../data/vfx.json)，行 918
- 数据字段映射：[data/vfx.json](../../../data/vfx.json)
- 生产资料：[art/vfx/enchant/handdrawn/README.md](../../vfx/enchant/handdrawn/README.md)
- 生产资料：[art/vfx/enchant/handdrawn/prompts.json](../../vfx/enchant/handdrawn/prompts.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/vfx/enchant/handdrawn/remaining_prompts.json",
      "pointer": "/assets/carnage/runtime",
      "relation": "runtime",
      "record": {
        "generator": "image_gen (generate2dsprite workflow)"
      }
    }
  ],
  "business": [
    {
      "file": "data/vfx.json",
      "pointer": "/enchant_attack/profiles/carnage/atlas",
      "id": "",
      "name": ""
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-ed24670e97433561"></a>
## fiend_fire.png

[打开资产](../../vfx/enchant/handdrawn/fiend_fire.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/enchant/handdrawn/fiend_fire.png；文件标识：fiend_fire；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；art/vfx/enchant/handdrawn/README.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1536 × 1024 px |
| 正式交付尺寸 | 当前文件实测=1536 × 1024 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(53, 50, 1482, 982)（右／下边界不含） |
| 构图与留白 | 正式九张图集1536×1024，3列×2行，单帧512×512；保留绘制锚点，不逐帧重缩放 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | fiend_fire.png |
| 生产路径 | art/vfx/enchant/handdrawn/fiend_fire.png |
| 引擎接入 | 静态证据：data/vfx.json:990；data/vfx.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=c628f1485c50c8a0c88775eba79fde15a8744e7ab675d546255f83d77319ff61；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 6帧非匀速；基础演出1.20秒，死亡收割另加0.65秒前置。命中与运行参数由配置驱动 |

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
  "bytes": 998475,
  "sha256": "c628f1485c50c8a0c88775eba79fde15a8744e7ab675d546255f83d77319ff61",
  "width": 1536,
  "height": 1024,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    53,
    50,
    1482,
    982
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/vfx.json](../../../data/vfx.json)，行 990
- 数据字段映射：[data/vfx.json](../../../data/vfx.json)
- 生产资料：[art/vfx/enchant/handdrawn/README.md](../../vfx/enchant/handdrawn/README.md)
- 生产资料：[art/vfx/enchant/handdrawn/prompts.json](../../vfx/enchant/handdrawn/prompts.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/vfx/enchant/handdrawn/remaining_prompts.json",
      "pointer": "/assets/fiend_fire/runtime",
      "relation": "runtime",
      "record": {
        "generator": "image_gen (generate2dsprite workflow)"
      }
    }
  ],
  "business": [
    {
      "file": "data/vfx.json",
      "pointer": "/enchant_attack/profiles/fiend_fire/atlas",
      "id": "",
      "name": ""
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-ff3d04b96fe2d29e"></a>
## immolate.png

[打开资产](../../vfx/enchant/handdrawn/immolate.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/enchant/handdrawn/immolate.png；文件标识：immolate；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；art/vfx/enchant/handdrawn/README.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1536 × 1024 px |
| 正式交付尺寸 | 当前文件实测=1536 × 1024 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(34, 19, 1512, 980)（右／下边界不含） |
| 构图与留白 | 正式九张图集1536×1024，3列×2行，单帧512×512；保留绘制锚点，不逐帧重缩放 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | immolate.png |
| 生产路径 | art/vfx/enchant/handdrawn/immolate.png |
| 引擎接入 | 静态证据：data/vfx.json:870；data/vfx.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=b30b54304b748f38e14bee27087d5bc8daaf5c953f4b88fa5ece326a9f22f0ff；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 6帧非匀速；基础演出1.20秒，死亡收割另加0.65秒前置。命中与运行参数由配置驱动 |

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
  "bytes": 946016,
  "sha256": "b30b54304b748f38e14bee27087d5bc8daaf5c953f4b88fa5ece326a9f22f0ff",
  "width": 1536,
  "height": 1024,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    34,
    19,
    1512,
    980
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/vfx.json](../../../data/vfx.json)，行 870
- 数据字段映射：[data/vfx.json](../../../data/vfx.json)
- 生产资料：[art/vfx/enchant/handdrawn/README.md](../../vfx/enchant/handdrawn/README.md)
- 生产资料：[art/vfx/enchant/handdrawn/prompts.json](../../vfx/enchant/handdrawn/prompts.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [],
  "business": [
    {
      "file": "data/vfx.json",
      "pointer": "/enchant_attack/profiles/furnace_wave/atlas",
      "id": "",
      "name": ""
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-a14c393d8a4942a7"></a>
## reaper.png

[打开资产](../../vfx/enchant/handdrawn/reaper.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/enchant/handdrawn/reaper.png；文件标识：reaper；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；art/vfx/enchant/handdrawn/README.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1536 × 1024 px |
| 正式交付尺寸 | 当前文件实测=1536 × 1024 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGBA; Alpha=[0, 255]；非零Alpha包围盒=(53, 49, 1502, 970)（右／下边界不含） |
| 构图与留白 | 正式九张图集1536×1024，3列×2行，单帧512×512；保留绘制锚点，不逐帧重缩放 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | reaper.png |
| 生产路径 | art/vfx/enchant/handdrawn/reaper.png |
| 引擎接入 | 静态证据：data/vfx.json:894；data/vfx.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=528ce7f8f2655807f92f44de6157cd142dffb921cc50778e31ed55a06d295374；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 6帧非匀速；基础演出1.20秒，死亡收割另加0.65秒前置。命中与运行参数由配置驱动 |

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
  "bytes": 639377,
  "sha256": "528ce7f8f2655807f92f44de6157cd142dffb921cc50778e31ed55a06d295374",
  "width": 1536,
  "height": 1024,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    255
  ],
  "alpha_bbox": [
    53,
    49,
    1502,
    970
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/vfx.json](../../../data/vfx.json)，行 894
- 数据字段映射：[data/vfx.json](../../../data/vfx.json)
- 生产资料：[art/vfx/enchant/handdrawn/README.md](../../vfx/enchant/handdrawn/README.md)
- 生产资料：[art/vfx/enchant/handdrawn/prompts.json](../../vfx/enchant/handdrawn/prompts.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [],
  "business": [
    {
      "file": "data/vfx.json",
      "pointer": "/enchant_attack/profiles/harvest_arc/atlas",
      "id": "",
      "name": ""
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-a9cbb46de0253b58"></a>
## searing_blow.png

[打开资产](../../vfx/enchant/handdrawn/searing_blow.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/enchant/handdrawn/searing_blow.png；文件标识：searing_blow；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；art/vfx/enchant/handdrawn/README.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1536 × 1024 px |
| 正式交付尺寸 | 当前文件实测=1536 × 1024 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGBA; Alpha=[0, 254]；非零Alpha包围盒=(59, 15, 1524, 1004)（右／下边界不含） |
| 构图与留白 | 正式九张图集1536×1024，3列×2行，单帧512×512；保留绘制锚点，不逐帧重缩放 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | searing_blow.png |
| 生产路径 | art/vfx/enchant/handdrawn/searing_blow.png |
| 引擎接入 | 静态证据：data/vfx.json:966；data/vfx.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=78b7f25edbaf43d5171fb0bd48d26311e4dea2992c79f92660c3c08735c75e1b；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 6帧非匀速；基础演出1.20秒，死亡收割另加0.65秒前置。命中与运行参数由配置驱动 |

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
  "bytes": 1771794,
  "sha256": "78b7f25edbaf43d5171fb0bd48d26311e4dea2992c79f92660c3c08735c75e1b",
  "width": 1536,
  "height": 1024,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    254
  ],
  "alpha_bbox": [
    59,
    15,
    1524,
    1004
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/vfx.json](../../../data/vfx.json)，行 966
- 数据字段映射：[data/vfx.json](../../../data/vfx.json)
- 生产资料：[art/vfx/enchant/handdrawn/README.md](../../vfx/enchant/handdrawn/README.md)
- 生产资料：[art/vfx/enchant/handdrawn/prompts.json](../../vfx/enchant/handdrawn/prompts.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/vfx/enchant/handdrawn/remaining_prompts.json",
      "pointer": "/assets/searing_blow/runtime",
      "relation": "runtime",
      "record": {
        "generator": "image_gen (generate2dsprite workflow)"
      }
    }
  ],
  "business": [
    {
      "file": "data/vfx.json",
      "pointer": "/enchant_attack/profiles/searing_blow/atlas",
      "id": "",
      "name": ""
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-4701d4f66593db5b"></a>
## sever_soul.png

[打开资产](../../vfx/enchant/handdrawn/sever_soul.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/enchant/handdrawn/sever_soul.png；文件标识：sever_soul；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；art/vfx/enchant/handdrawn/README.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1536 × 1024 px |
| 正式交付尺寸 | 当前文件实测=1536 × 1024 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGBA; Alpha=[0, 254]；非零Alpha包围盒=(23, 19, 1488, 1000)（右／下边界不含） |
| 构图与留白 | 正式九张图集1536×1024，3列×2行，单帧512×512；保留绘制锚点，不逐帧重缩放 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | sever_soul.png |
| 生产路径 | art/vfx/enchant/handdrawn/sever_soul.png |
| 引擎接入 | 静态证据：data/vfx.json:1014；data/vfx.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=65f17c2b7c4c1e6efd9da3fe8738d0dd3811ca46c4fa4fb768610e4081424117；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 6帧非匀速；基础演出1.20秒，死亡收割另加0.65秒前置。命中与运行参数由配置驱动 |

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
  "bytes": 1504782,
  "sha256": "65f17c2b7c4c1e6efd9da3fe8738d0dd3811ca46c4fa4fb768610e4081424117",
  "width": 1536,
  "height": 1024,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    254
  ],
  "alpha_bbox": [
    23,
    19,
    1488,
    1000
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/vfx.json](../../../data/vfx.json)，行 1014
- 数据字段映射：[data/vfx.json](../../../data/vfx.json)
- 生产资料：[art/vfx/enchant/handdrawn/README.md](../../vfx/enchant/handdrawn/README.md)
- 生产资料：[art/vfx/enchant/handdrawn/prompts.json](../../vfx/enchant/handdrawn/prompts.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/vfx/enchant/handdrawn/remaining_prompts.json",
      "pointer": "/assets/sever_soul/runtime",
      "relation": "runtime",
      "record": {
        "generator": "image_gen (generate2dsprite workflow)"
      }
    }
  ],
  "business": [
    {
      "file": "data/vfx.json",
      "pointer": "/enchant_attack/profiles/sever_soul/atlas",
      "id": "",
      "name": ""
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-aa08bc13638e9373"></a>
## uppercut.png

[打开资产](../../vfx/enchant/handdrawn/uppercut.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/enchant/handdrawn/uppercut.png；文件标识：uppercut；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | AI_Studio/Design/Art/VFX_DESIGN.md；art/vfx/enchant/handdrawn/README.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1536 × 1024 px |
| 正式交付尺寸 | 当前文件实测=1536 × 1024 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGBA; Alpha=[0, 254]；非零Alpha包围盒=(0, 7, 1496, 1000)（右／下边界不含） |
| 构图与留白 | 正式九张图集1536×1024，3列×2行，单帧512×512；保留绘制锚点，不逐帧重缩放 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | uppercut.png |
| 生产路径 | art/vfx/enchant/handdrawn/uppercut.png |
| 引擎接入 | 静态证据：data/vfx.json:942；data/vfx.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=3be64d0a8dd36ae9b7288c075802f84cd41d78cd27e53c962d5c5a4a8168009c；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 6帧非匀速；基础演出1.20秒，死亡收割另加0.65秒前置。命中与运行参数由配置驱动 |

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
  "bytes": 1874268,
  "sha256": "3be64d0a8dd36ae9b7288c075802f84cd41d78cd27e53c962d5c5a4a8168009c",
  "width": 1536,
  "height": 1024,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    254
  ],
  "alpha_bbox": [
    0,
    7,
    1496,
    1000
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/vfx.json](../../../data/vfx.json)，行 942
- 数据字段映射：[data/vfx.json](../../../data/vfx.json)
- 生产资料：[art/vfx/enchant/handdrawn/README.md](../../vfx/enchant/handdrawn/README.md)
- 生产资料：[art/vfx/enchant/handdrawn/prompts.json](../../vfx/enchant/handdrawn/prompts.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [
    {
      "file": "art/vfx/enchant/handdrawn/remaining_prompts.json",
      "pointer": "/assets/uppercut/runtime",
      "relation": "runtime",
      "record": {
        "generator": "image_gen (generate2dsprite workflow)"
      }
    }
  ],
  "business": [
    {
      "file": "data/vfx.json",
      "pointer": "/enchant_attack/profiles/uppercut/atlas",
      "id": "",
      "name": ""
    }
  ],
  "manual_evidence": []
}
```

<a id="asset-c15d238a4cf6a596"></a>
## reaper_half_face.png

[打开资产](../../vfx/enchant/reaper_half_face.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/enchant/reaper_half_face.png；文件标识：reaper_half_face；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 半脸旧版保留图；专用README明确现行使用v2，旧版不用于运行 |
| 依据与参考 | art/vfx/enchant/reaper_half_face.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1024 × 1536 px |
| 正式交付尺寸 | 当前文件实测=1024 × 1536 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGB; Alpha=无透明通道 |
| 构图与留白 | 按对应参考检查主体完整性、安全边距；未有明确模板的项目待确认 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | reaper_half_face.png |
| 生产路径 | art/vfx/enchant/reaper_half_face.png |
| 引擎接入 | 未发现完整路径或已知加载器映射；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=d782b7e371252a708902468926b1a73b5f4c438132c096c39d97311d4915bf28；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 用途待核对：未发现完整路径静态引用；可能由动态拼接加载；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 按实际shader／动画与 data/vfx.json核对，不能按文件帧数猜测运行时长 |

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
  "bytes": 1886360,
  "sha256": "d782b7e371252a708902468926b1a73b5f4c438132c096c39d97311d4915bf28",
  "width": 1024,
  "height": 1536,
  "mode": "RGB",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": false
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 生产资料：[art/README.md](../../README.md)

<a id="asset-613c81eeebd655a2"></a>
## reaper_half_face_v2.png

[打开资产](../../vfx/enchant/reaper_half_face_v2.png) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/vfx/enchant/reaper_half_face_v2.png；文件标识：reaper_half_face_v2；业务ID待确认／不适用 |
| 资产类别 | vfx |
| 用途与出现位置 | 战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用 |
| 依据与参考 | art/vfx/enchant/reaper_half_face.md；AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md |
| 美术要求 | 遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别 |
| 视角与光向 | 沿用已批准参考；统一视角与光向的具体要求待确认 |
| 源图尺寸 | 待核对原始制作源尺寸；当前文件实测=1024 × 1536 px |
| 正式交付尺寸 | 当前文件实测=1024 × 1536 px；这是现状记录，不自动批准为全类规格 |
| Godot 导入尺寸 | 当前.import长边上限=0（0表示未设置上限；不是显示尺寸） |
| 实际显示／验收尺寸 | 待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代 |
| 文件格式 | PNG / RGBA; Alpha=[0, 254]；非零Alpha包围盒=(0, 16, 974, 1518)（右／下边界不含） |
| 构图与留白 | 1024×1536 RGBA；完整角尖、真实透明；运行时镜像等比缩放 |
| 对齐与视觉大小 | 按实际组件与同类参考校对；锚点／视觉大小模板待确认 |
| 内容拆分 | 半脸独立；全屏遮罩和红眼光束由Shader提供 |
| 禁止内容 | 禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则 |
| 文件命名 | reaper_half_face_v2.png |
| 生产路径 | art/vfx/enchant/reaper_half_face_v2.png |
| 引擎接入 | 静态证据：data/vfx.json:201；data/vfx.json；可达性与实际显示仍需运行确认 |
| 导入设置 | importer="texture"; type="CompressedTexture2D"; compress/mode=0; mipmaps/generate=false; process/fix_alpha_border=true; process/premult_alpha=false；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=52a8680778ca2110d246578cfcea38ac7f81bb107206bf193e5880dad00f0596；历史版本／变更摘要待补充 |
| 制作与审核责任人 | 制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充 |
| 当前状态 | 存在静态资源／数据引用；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED |
| 动画／特效专项 | 死亡收割前置0.65秒，结束后才进入飞行命中；基于data/vfx.json |

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
  "bytes": 1972758,
  "sha256": "52a8680778ca2110d246578cfcea38ac7f81bb107206bf193e5880dad00f0596",
  "width": 1024,
  "height": 1536,
  "mode": "RGBA",
  "format": "PNG",
  "frames": 1,
  "alpha_channel": true,
  "alpha_extrema": [
    0,
    254
  ],
  "alpha_bbox": [
    0,
    16,
    974,
    1518
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[data/vfx.json](../../../data/vfx.json)，行 201
- 数据字段映射：[data/vfx.json](../../../data/vfx.json)
- 生产资料：[art/README.md](../../README.md)

```json
{
  "metadata": [],
  "business": [
    {
      "file": "data/vfx.json",
      "pointer": "/enchant_attack/reaper_cutin/portrait",
      "id": "",
      "name": ""
    }
  ],
  "manual_evidence": []
}
```
