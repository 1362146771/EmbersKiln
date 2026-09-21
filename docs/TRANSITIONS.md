# 转场系统（第一至三阶段）

`TransitionManager` 是常驻 autoload，接入正式 UI 与独立节点场景。普通场景炭褐色淡入淡出；普通／精英战斗使用陶土颗粒擦除；Boss 入场使用陶壳裂纹；跨幕使用窑门开合。

## 路径与节奏

| 路径 | 名义时长 | 行为 |
| --- | --- | --- |
| 主菜单、城镇、独立节点场景 | 0.12 + 0.18 秒 | 全遮盖后提交数据、切场景、等待布局再揭幕 |
| 普通／精英战斗 | 0.18 + 0.20 秒 | 陶土颗粒从上向下遮盖与揭幕 |
| Boss 入场 | 0.28 + 0.34 秒 | 陶壳裂纹、细窄余烬和一次低沉敲击音 |
| 章节确认 → 下一幕地图 | 0.30 + 0.38 秒 | 窑门开合与短风声，不叠加面板退场 |
| 战后奖励 | 反馈结束 + 死亡演出 + 约 0.30 秒 | 先完成原打击／附魔反馈；移除旧的额外 0.35 秒等待；直接揭幕战利品总览 |
| 总览 → 奖励卡牌 | 总览退场 0.12 秒，卡牌 0.16 秒／间隔 0.03 秒 | 保留原总览确认步骤，选牌时再播放错峰入场 |
| 确认面板 | 每次 0.18 秒 | 淡入淡出与内容轻移 18 像素 |
| 暂停／恢复 | 0.12／0.10 秒 | 无位移，暂停状态下仍可播放 |

实际耗时包含资源实例化、帧同步与布局。`NodePanel.gd` 只管理交互与转场，保留独立节点场景、正式 UI 主题、卡牌容量事务、宝箱开启、附魔确认和升级等原有逻辑。

主菜单保留“新玩家首战／检查点续战／老玩家回镇”的入口规则；城镇出发保留局前准备；战败保留复活与火种结算。Boss 奖励结束时仍只推进一次章节、回血并自动存档，章节确认只重建当前幕地图，最终 Boss 进入正式胜利结算。

## 接口

`change_scene_to_file(path, prepare, hold_seconds, effect, ready_gate)` 与 `change_scene_to_packed(scene, prepare, hold_seconds, effect, ready_gate)` 同步返回 `Error`。`OK` 表示已锁输入并接管异步流程；并发请求返回 `ERR_BUSY`，不排队。`effect` 支持 `fade`（默认）、`clay`、`boss`、`chapter`。

- `prepare`：全遮盖后、目标场景加入树前调用，必须同步返回 `Error`。用于提交节点、写返回标记；失败时调用者负责保持自身业务数据一致。
- `hold_seconds`：等待既有演出，期间阻断鼠标／键盘／触摸。
- `ready_gate`：可选同步布尔检查。下一帧起由单例轮询，原打击与附魔动画都结束后才计死亡演出时间；原场景被外部替换时取消，不持有旧场景上的悬空协程。
- `change_scene_resolved(resolve)`：全遮盖后同步调用返回场景路径的回调，用于原菜单读档和城镇出发的动态路由。

地图 `_ready()` 可能准备奖励、局前准备或检查点续战。其 `take_transition_destination() -> PackedScene` 将下一目标交给管理器，最多跟随四次跳转，全程保持遮盖，只对最终场景发出 `scene_revealing`，避免裸地图闪现。

目标场景可实现 `play_transition_entrance() -> Tween`；揭幕与内容入场并行，全部完成后解锁。`focus_transition_target()` 将焦点交给当前总览、结果页或可选地图节点。`reveal_content(panel)` 用于已存在内容层的受保护入场。

`open_panel(parent, panel, duration, distance)` 与 `close_panel(panel, on_closed, duration, distance)` 共用输入锁，暂停时也能运行。默认 0.18 秒／18 像素；关闭成功后只调用一次回调。面板意外销毁仍能清理遮罩并解锁。

信号：`transition_started(kind)`、`scene_revealing(scene)`、`transition_finished(kind, error)`。立即拒绝请求只返回错误码，不发完成信号。

## 材质与音效

`art/shaders/clay_wipe.gdshader` 与 `kiln_transition.gdshader` 使用固定程序纹理，不抓屏、不使用随时间闪烁的噪声。按画面比例校正，端点显式保证全透明／全不透明；没有白闪或镜头震动。

两段 `art/audio/transition_*.wav` 为原创程序合成、24 kHz 单声道音效，可通过 `python tools/generate_transition_audio.py` 重建。默认 -12 dB，使用 `SFX` 总线（无则使用 `Master`），只在关键转场开始遮盖时播放一次，完成或失败即停止。

## 验证

```text
python tools/run_transition_verify.py --godot <Godot路径> --render
```

工具将最新工程复制到 `Temp/transition-verify-*`，隔离 `user://`、日志、导入缓存并移除编辑器插件与测试桥，不接触玩家档案。`--output-root` 可指定其他名为 `Temp` 的输出父目录，以缩短 Windows 路径。

覆盖正式菜单首战／续玩、暂停返回、全部独立节点、奖励总览与选牌、三幕 Boss、两次跨幕、城镇出发、死亡结算、重复点击、准备失败、面板销毁，以及横竖屏 Shader GPU 端点与中间帧。截图和日志保留在副本中，成功标志 `TRANSITION_RESULT:PASS`。音效使用 Dummy 驱动检查播放生命周期，扬声器听感需另行试听。

快速模式、减少动态设置与多设备性能收尾属于第四阶段。
