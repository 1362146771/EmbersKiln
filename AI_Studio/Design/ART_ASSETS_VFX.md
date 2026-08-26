# 战斗演出升级 · 美术资源清单（ART_ASSETS_VFX）

> 关联方案：`BATTLE_INTERACTION_VFX_PLAN.md`（v1）
> 流程：**先规范（本清单 spec）→ 再生成**（依次落地到 `art/vfx/`）。
> 原则：沿用现有暖色调色板；信息优先，不做全屏大特效；尽量复用、少新增。

## 资源总览

| 编号 | 资产 | 用途（分期） | 落地方式 | 优先级 | 状态 |
|---|---|---|---|---|---|
| A1 | 落点高亮环 | P1 拖拽合法落点指示 | **代码绘制**（`DropLayer._draw` 弧形+描边，无资产） | — | ✅ 已实现（代码） |
| A2 | 出牌爆发光环 `ART_CAST_BURST.png` | P1/P2 卡牌命中目标瞬间元素光环 | **白底径向柔光精灵，运行时按元素染色** | 高 | 🟡 生成中 |
| A3 | 碰撞攻击卡卡框 `ART_STRIKE_CARD.png` | P3 敌人"攻击卡"飞向玩家并碰撞 | **红/橙侵略性卡框，中心透明可贴意图图标** | 中（P3） | 🟡 生成中 |
| A4 | 卡牌拖拽投影 | P1 幽灵卡浮起深度感 | 代码（PanelStyleBox 阴影/偏移），无需资产 | 低 | ⚪ 代码可替代 |
| A5 | 大伤害数字 | P1 飘字夸张化 | **代码**（`Label` 描边+缩放冲击，字号随伤害放大），无需字体资产 | — | ✅ 已实现（代码） |
| A6 | 玩家受击碎裂/红屏 | P3 撞击反馈增强 | 代码闪光+（可选）碎裂粒子精灵 | 低（P3） | ⚪ 待定 |
| A7 | 出牌元素拖尾 | P2 卡牌飞行拖影 | 可选；代码 `Tween` 残影或粒子 | 低 | ⚪ 待定 |

> 说明：**A1/A4/A5 纯代码实现，不消耗美术产能**；真正需要美术出图的只有 **A2（出牌爆发）** 与 **A3（碰撞卡框）**。A6/A7 为后续可选增强。

---

## A2 · 出牌爆发光环 `ART_CAST_BURST.png`

- **路径**：`art/vfx/ART_CAST_BURST.png`（建议 256×256，正方形，PNG 带透明通道）
- **视觉 spec**：
  - 纯白径向柔光：中心最亮、向外快速衰减至透明；无硬边、无颗粒噪声。
  - **透明背景**，无任何文字/图标/形状轮廓。
  - 整体接近正圆，允许极轻微的不规则以显"能量感"，但不要星形/花瓣。
  - 色调必须中性白，运行时由代码 `modulate` 染成元素色（攻击=暖橙 `#F0997B`、其余=青绿 `#5DCAA5`）。
- **生成 prompt（给美术/生图）**：
  > "Soft white radial glow burst, centered bright core fading smoothly to fully transparent edges, perfectly clean transparent background, no shapes, no text, no outlines, subtle energy feel, game VFX sprite, square 256x256, PNG with alpha"

- **接入点**：`VFXSystem.spawn_cast_burst(anchor, is_attack)` 已预留 `CAST_BURST_TEX` 常量，资产缺失时自动回退代码闪光，不影响功能。

---

## A3 · 碰撞攻击卡卡框 `ART_STRIKE_CARD.png`

- **路径**：`art/vfx/ART_STRIKE_CARD.png`（建议 256×360，竖卡比例，PNG 带透明）
- **视觉 spec**：
  - 侵略性卡牌外框：粗红/橙描边，边缘可有火焰/裂纹质感但保持可辨识的卡形（圆角矩形）。
  - **中心区域透明**，运行时在中心贴敌人攻击意图图标 + 数值（复用 `_card_style` / 意图图标）。
  - 四角可加锐利尖角/火星点缀，强化"敌人打你"的攻击性。
  - 不写文字。
- **生成 prompt（给美术/生图）**：
  > "Aggressive playing-card frame, thick red-orange border with fiery cracked edges and small ember sparks at corners, transparent center interior (no fill), rounded rectangle card shape, game UI asset, vertical 256x360, PNG with alpha, no text"

- **接入点**：P3 `BattleDirector._play_strike_card` 实现时由 `VFXSystem.spawn_strike_card` 复用（当前 P1 尚未实现，资产先生成备货）。

---

## 验收与回退

- 所有精灵缺失/未就绪时，代码均有 **null 兜底**（A2 回退闪光、A3 P3 未接），不阻塞 P1 功能。
- 资产落地后需在编辑器 `run_and_verify` 冒烟，确认染色/尺寸/透明通道正确。
- 美术资产统一放 `art/vfx/`，由 Godot 自动 import（`.import` 由编辑器生成）。

---

## 生成顺序（依次）

1. **A2 出牌爆发光环** —— P1 已引用，优先生成。
2. **A3 碰撞攻击卡框** —— P3 备货，紧随生成。
3. A6/A7 视 P2/P3 实装需要再议，不阻塞当前进度。
