# 封窑兽·匣母 — 立绘审批稿

2026-08-28最新：两次内置imagegen去底返回无alpha的RGB棋盘格，均拒绝入库。用户随后明确授权本地抠图，已从批准原图导出`21_SaggerMatron_alpha.png`，真实RGBA，安装生产资源并通过游戏内透明验收。工具：`tools/cutout_sagger.py`，不重新绘制。历史提示词见ART_PROMPT_SAGGER_MATRON_20260828.md。

状态：2026-08-28用户批准立绘及数值，并要求正式替换。审批图原件永久保留；当前SPR_Enemy_SaggerMatron.png为批准原图的本地去底版，主体不透明区域RGB完全保留，尺寸/构图不变。

- 文件：`21_SaggerMatron_candidate.png`，1254×1254，RGB，浅灰背景，非透明生产图。
- 画面：低伏负重巨兽、背部匣钵、前胸封匣门；鼠尾草灰绿/烟紫/旧白，局部赭橙炉光。动漫描边与low-poly式概括块面。
- 工具：内置 imagegen；已批准v3烬噬/窑心仅用于画法参考，无原版怪物造型输入。
- 提示词：`AI_Studio/Design/ART_PROMPT_SAGGER_MATRON_20260828.md`。
- SHA256：`BBFEFA0E6F13BD9BCD4DC92F00251B3054FB4D840C2754D137324DB0EDA3138A`。

已批准并接入首版数值：生命160、拦路12、封匣格挡14、喷火20；新局第一幕已使用匣母，旧存档和第二/三幕保持不变。

透明生产文件：`21_SaggerMatron_alpha.png`，1254×1254 RGBA；SHA256 `DC1FC0DE1F640285EA7D3F3D79F79EEA46C4649143B3F20E1C9DD55D289479D5`。804290透明、5822半透明边缘、762404不透明像素。生产import UID保持不变。

验证：此前机制43/0、headless正式接入36/0、多幕49/0；去底后新增4项技术检查，Godot图形接入46/0（含6张实际截图）。深浅底、3倍边缘、真实开窑/泄压竖屏画面已目视通过。完整路线平衡与三幕逐战仍未验证。详见AI_Studio/Reports/ART_REPORT_SAGGER_ALPHA_20260828.md。审批目录由 `.gdignore` 隔离。
