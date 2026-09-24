# shaders 交付表 · 1

[总目录](../README.md)

自动生成；人工修订填 ../overrides.json。尺寸为实际测量，专项要求与现状分别记录。

- [clay_wipe.gdshader](#asset-4715c199fa5f03de) — `art/shaders/clay_wipe.gdshader`
- [kiln_transition.gdshader](#asset-feedec80b2a2baf6) — `art/shaders/kiln_transition.gdshader`

<a id="asset-4715c199fa5f03de"></a>
## clay_wipe.gdshader

[打开资产](../../shaders/clay_wipe.gdshader) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/shaders/clay_wipe.gdshader；文件标识：clay_wipe；业务ID待确认／不适用 |
| 资产类别 | shaders |
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
| 文件命名 | clay_wipe.gdshader |
| 生产路径 | art/shaders/clay_wipe.gdshader |
| 引擎接入 | 静态证据：scripts/core/TransitionManager.gd:14；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=9bb02cc302d895d277acf336a77e32f3edb68a3f88d706561db099c454f88c4a；历史版本／变更摘要待补充 |
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
  "bytes": 1828,
  "sha256": "9bb02cc302d895d277acf336a77e32f3edb68a3f88d706561db099c454f88c4a",
  "format": "gdshader",
  "shader_type": [
    "canvas_item"
  ],
  "uniforms": [
    "uniform float progress : hint_range(0.0, 1.0) = 0.0;",
    "uniform bool revealing = false;",
    "uniform vec4 clay_color : source_color = vec4(0.12, 0.10, 0.09, 1.0);",
    "uniform vec4 ember_color : source_color = vec4(0.56, 0.23, 0.09, 1.0);"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scripts/core/TransitionManager.gd](../../../scripts/core/TransitionManager.gd)，行 14
- 生产资料：[art/README.md](../../README.md)

<a id="asset-feedec80b2a2baf6"></a>
## kiln_transition.gdshader

[打开资产](../../shaders/kiln_transition.gdshader) · [总目录](../README.md)

| 字段 | 当前交付记录 |
| --- | --- |
| 资产 ID | 目录唯一键：art/shaders/kiln_transition.gdshader；文件标识：kiln_transition；业务ID待确认／不适用 |
| 资产类别 | shaders |
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
| 文件命名 | kiln_transition.gdshader |
| 生产路径 | art/shaders/kiln_transition.gdshader |
| 引擎接入 | 静态证据：scripts/core/TransitionManager.gd:15；可达性与实际显示仍需运行确认 |
| 导入设置 | 无独立.import；见资源文件自身参数与消费组件 |
| 验收环境 | 真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查 |
| 来源与制作资料 | 待补充逐资产来源；以下元数据与相邻生产资料只作证据入口 |
| 当前版本与修改摘要 | 当前文件SHA-256=e1fac319020c021a3e8303699d028dcedf401d0c35f741fa82488c285053a06b；历史版本／变更摘要待补充 |
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
  "bytes": 2447,
  "sha256": "e1fac319020c021a3e8303699d028dcedf401d0c35f741fa82488c285053a06b",
  "format": "gdshader",
  "shader_type": [
    "canvas_item"
  ],
  "uniforms": [
    "uniform float progress : hint_range(0.0, 1.0) = 0.0;",
    "uniform bool revealing = false;",
    "uniform bool chapter = false;"
  ]
}
```

证据入口（静态引用与历史元数据均不等于本次验收通过）：

- 静态资源引用：[scripts/core/TransitionManager.gd](../../../scripts/core/TransitionManager.gd)，行 15
- 生产资料：[art/README.md](../../README.md)
