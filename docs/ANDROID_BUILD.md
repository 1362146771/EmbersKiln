# Android 内测 APK

项目使用 Godot 4.7.1、Mobile 渲染器、720×1280 设计画布和固定竖屏。Android 限制最高 60 FPS；桌面预览保持原配置。

## 构建

从项目根目录运行（Windows / Python 3）：

```powershell
python tools/build_android.py --godot F:/app/Godot_v4.7.1-stable_win64_console.exe --sdk Temp/android-toolchain/sdk --java "C:/Program Files/Android/openjdk/jdk-21.0.8" --templates Temp/android-toolchain/templates
```

参数可替换成本机安装位置。SDK 至少包含 `platform-tools/adb.exe` 和 `build-tools/<版本>/apksigner.bat`、`zipalign.exe`；模板目录包含与引擎版本匹配的 `android_debug.apk` 与 `android_release.apk`。目前使用普通 APK 模板，无需 Gradle / NDK。

脚本在 `Temp/android-build-*` 创建独立副本和独立用户数据目录，串行完成导入、手机交互回归、Debug APK 导出。该副本移除 TestBridge、MCP Autoload 和编辑器插件。不要仅排除插件文件而保留指向它们的 Autoload。正式开发工程及玩家存档不受影响。

输出：`outputs/android/embers-kiln-internal.apk`。首次构建创建本地调试签名 `outputs/android/debug.keystore`；保留它可用同一签名覆盖安装后续内测版本。APK、签名文件、工具链与构建副本均不提交 Git。

`--verify-only` 仅运行回归；`--render` 增加桌面真实渲染并在构建副本的隔离 `user://` 下保存 `android-combat.png`。这些都不能代替 Android 真机测试。构建日志在各独立副本中。

## 内测配置

- 预设：`export_presets.cfg` 中的 Android；ARM64。
- 应用图标：`art/icons/app/ICO_EmbersKiln.png`（用户确认的火种陶瓷面具图），项目图标、Android 主图标及自适应前景统一引用该文件。
- 包名、版本及应用名称沿用 `export_presets.cfg` 当前设置；体积优化不覆盖这些字段。正式发行前确定最终包名、版本号、应用图标与发布签名。
- Debug 构建保持现有模拟激励广告。Release 尚未接入真实广告 SDK。
- 包含 `data/*.json`；排除测试场景、工具、临时目录、参考图及已核对无运行时引用的生产中间图。JSON 动态引用的正式卡图、城镇与特效资源必须保留。
- 仅在 Android 构建副本中对卡牌插画、敌人立绘、背景和城镇大图使用质量 0.85 的 WebP 有损导入；尺寸、透明度和图集裁切坐标不变。UI 卡框、图标、文字及动画/特效图集保持原导入设置。源 PNG 与源 `.import` 不变，渲染器不变。
- 包体策略集中在 `tools/android_assets.json`，实现为 `tools/android_assets.py`。构建脚本会合并必需的 JSON 包含规则与制作中间图/测试文件排除规则，即使编辑器将预设过滤器清空也不会失效；额外自定义过滤器保留。导出后检查实际 APK 中不存在被排除的资源，运行时 JSON 和纹理导入缓存完整，ZIP CRC 有效。仅对明确列出的目录按运行时引用裁剪旧图，并保留 `EnemyData` 按 sprite ID 拼出的全部敌人图。动态拼接 UI/图标路径的目录不参与裁剪。
- 改过压缩参数的纹理必须重新导入，不得复制旧 `.ctex` 缓存；回归检查全部敌人图、JSON 动态资源和压缩图片的原始尺寸。
- WebP 有损压缩主要减少下载体积，不降低相同分辨率纹理的显存占用。

## 手机行为

Android 返回键打开 / 关闭已有暂停菜单；暂停菜单内图鉴优先关闭。主菜单仍通过现有退出按钮退出。切后台保存单局及永久档案，并在可暂停的游戏界面打开暂停菜单。转场中不插入新的暂停转场。

拖拽过程中失焦、切后台或暂停，取消拖拽，不出牌、不弃牌、不消耗能量。单局存档先写入同目录临时文件，确认写入完成后替换正式文件；战斗恢复仍沿用既有开战检查点规则。

## 真机验收

检查 ARM64 设备安装、冷启动、长屏/刘海与手势区域、卡牌和药水拖拽、系统返回键、切后台再回来、后台进程被系统回收后继续游戏、战斗与城镇切换、特效帧耗时及内存。真实广告、商店发行与性能验收不由 Debug APK 构建结果替代。
