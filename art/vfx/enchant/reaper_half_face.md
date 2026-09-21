# 死亡收割 · 红眼半脸

## 当前版本 v2

- 运行素材：`reaper_half_face_v2.png`，1024×1536 RGBA，内置 image_gen 编辑原素材，补全角尖并生成真实透明背景，直接入库保留 alpha。
- 原始输出：`exec-d7a22c9c-810d-4586-a2f7-cdaeb7e7c862.png`。
- 全屏渐变遮罩先合成，再按自然 alpha 轮廓叠半脸；顶部不透明度 0.50、底部 0.90（对应顶部透明度 50%、底部 10%），底色采用近黑深紫 `#07050C`，遮罩内部仅保留 4% 模糊背景亮色，避免灰白泛亮。人物依然水平镜像成左半脸，按高度等比缩放，保留角尖顶端余量，取消 52% 屏宽裁切。
- 参数：`data/vfx.json.enchant_attack.reaper_cutin` 中的 `portrait_height`、`portrait_offset`、`mask_opacity_top/bottom` 和 `eye_uv`。

## v2 最终编辑提示词

Edit this supplied half-face game portrait into a transparent PNG VFX cutout, 1024x1536 portrait canvas. Preserve EXACT same hero, facial expression, angular ivory ceramic mask shapes and cracks, visible single red glowing eye, brown swept-back hair, tan mouth/jaw, hand-painted dark comic rendering and source orientation (eye on image right half, nose centerline cutoff at right side). Critical changes: OUTPAINT / restore the complete long pointed upper mask horn, with its entire tip visibly inside canvas and 6% clear transparent padding above it; expand the composition upward and slightly outward as needed, do not truncate the horn or hair outline. Remove ALL opaque dark background: genuinely transparent alpha outside the natural outer silhouette of hair, mask horn, ear and neck. This must be an isolated half-head and neck, with one eye, NOT a full face, not a mask floating without skin. The right-side cut through the nose/mouth midline is preserved as in source; left/top outer contour should be naturally irregular hair/horn silhouette. Keep all visible face, eye and mouth from reference, zoom out modestly to fit the complete pointed horn and outer silhouette. Main subject fills about 85% width and 90% height, transparent margin around top and sides, neck may end at bottom. Red glow confined near eye, no baked horizontal beam. NO rectangle backdrop, NO smoky backdrop, NO checkerboard painted into image, NO UI, NO text, NO extra face/eye, no frame, no large shadow patch outside the silhouette. Final production sprite must have REAL transparent background.

## 初版素材（保留，已不用于运行）

- 运行素材：`reaper_half_face.png`，1024×1536，使用内置 image_gen 生成。
- 主角身份参考：`art/player/SPR_Player_Tannaro.png`。保留陶瓷面具、深色后梳发型与露出的下颌。
- Shader 按原图纵横比铺满屏幕左侧约 52%，裁切至鼻梁中线；红眼亮核、横向光痕、退场和右侧背景模糊由代码动态叠加。
- 原始输出：`exec-d59ba02b-12ec-479c-a60f-a2988ebfe3c1.png`。直接复制入库，未进行后处理。
- 动画与裁切配置：`data/vfx.json.enchant_attack.reaper_cutin`。
- 按用户确认，运行时在左侧屏幕区域内水平镜像半脸，红眼光效锚点同步镜像；屏幕位置、尺寸与右侧特效保持原样。原始 PNG 保留不变。

## 最终生成提示词

Create ONE production game VFX portrait texture, portrait 1024x1536 PNG. Reference image supplies exact original hero identity: adult male potter warrior, swept back dark brown hair, angular ivory ceramic mask with hornlike pointed brow corners and narrow black eye slit, tan jaw. Draw an EXTREME CLOSE UP of ONLY ONE VERTICAL HALF OF HIS FACE, intended to fill the LEFT HALF of a vertical phone game screen from TOP TO BOTTOM. Image right edge cuts straight through the centerline of mask nose and mouth, other half of face is off-canvas to right; ONLY ONE EYE is visible. Huge face dominates full canvas: hair and horn at top cropped by top border, eye at normalized x0.58 y0.38, angular mask covering cheek, lower exposed mouth chin and tiny neck at bottom, left temple/hair clipped slightly by left edge. Keep same ivory mask design from reference. Menacing focused RED glowing eye within black slit, small hot crimson core and red light spilling subtly on edges of ceramic cracks. No long light beam baked in, animation will add it. Highly graphic dark hand-painted comic / cel shaded original RPG illustration, broad clean hard shadow shapes, thick expressive near-black outlines, desaturated ivory mask with pale warm edge accents, dark plum shadows, very restrained crimson. Opaque extremely dark charcoal-plum background fills every gap, no transparency needed, no gradient studio backdrop. Strong readable silhouette, handmade ink edge details, no photographic textures. This is JUST the tall half-face portrait asset, NOT a screenshot, NO UI, no text, no lettering, no borders, no frame, no additional people, no full body, no weapons, no eyes elsewhere.
