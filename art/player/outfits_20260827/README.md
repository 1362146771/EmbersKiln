# 炭之郎换装候选 — 2026-08-27

## 范围

用户要求：根据上传的当前人物换 5 套符合世界观的衣服，其他不修改。以本次上传图片为唯一人物底图；不套用历史文档中的胡茬、面具或比例修改。只生成候选，不替换游戏现役资源。

设定依据：AI_Studio/Design/WORLD_SETTING.md（守窑学徒、手作生活、工具即武器），ART_STYLE.md（新衣服冷中性色系）。原图人物、装备、背景优先保留，不做全图调色或去背。

工具：内置 image_gen；每套独立编辑原图。

输入：C:/Users/Administrator/AppData/Local/Temp/codex-clipboard-1ff8477b-d702-4b9e-984c-be67a6d56f77.png

## 完整提示词

每次调用使用以下公共提示词，加对应服装段。

```text
Use case: identity-preserve.
Input image 1 is the EDIT TARGET, not merely a style reference.
Primary request: make ONE outfit variation of this exact existing illustrated character. Change CLOTHING ONLY. Deliver a single full-body character, not a collage.
World: Ember's Kiln, a sunless handmade clay world warmed by one great kiln. This young man is a kiln-keeper apprentice and practical craftsperson, NOT a knight, wizard, assassin or soldier. Clothes are hand-sewn canvas, linen, wool and work leather, functional for pottery, firewood and kiln tending.
STRICT LOCKED REGIONS: preserve the source image's exact face and exposed clean-shaven jaw, skin tone, ceramic mask shape/eye openings/chips/crack lines, hair shape and strands, head size, body anatomy and proportions, entire pose, stance and feet placement. Preserve both arms, hands and fingers, including the exact pale ceramic hand on viewer-right. Preserve the axe and wooden shaft in viewer-left hand and all its details/angle/scale. Preserve the bellows at viewer-right hip, its wooden boards/leather folds/nozzle/handle and hanging ring exactly. Preserve both metal forearm bracers, arm straps, all existing brown leather shoulder harness and chest straps/buckles, belt/hanging straps, and both brown boots exactly in place. Keep the small brick-red chest kiln badge as the same badge in the same location over the new clothing. No added props, weaponry, armor plates, bags, jewelry or symbols.
EDIT AREA: only the textile torso garment/apron and the trousers; their cut, seams, layering and subdued colors can change. Existing gear must stay above the replacement clothes, never hidden or displaced. Keep shoulders and arms bare as in the original, with sleeveless cuts. No hood, hat, cape, fur, high collar, gloves or additional shoulder equipment. Keep the head, neck and hair completely unobstructed.
Style: match the source's exact hand-drawn ink outlines and illustrated shading, same detail level, same lighting. Do not restyle or globally recolor the image. Clothing palette grounded in slate blue-gray #3A4554, iron gray #68665E, brown-gray #94826F and dark olive #35392C; small existing brick-red badge only. Matte practical fabrics, neat visible stitching, light believable wear, no dirt overlays.
Composition: same 1024x1536 portrait canvas and same character scale and position as source. Preserve the exact pale checkered background and margins. Do not crop, zoom, mirror or rotate. No text, labels, watermark, scenery, effects or glow.
CRITICAL: this is a surgical garment edit, NOT a redraw of the character. All non-clothing elements must remain visually unchanged.
```

### 陶坊工装 — 01_pottery_workwear.png

```text
Outfit variation: 陶坊工装. Replace the blue bib apron with a brown-gray sleeveless wrap-front linen work tunic, low simple neckline below the original chest harness, plus a separate slate blue-gray waist apron reaching above the knees. The apron has two broad overlapping rectangular panels with sturdy stitched hems, practical for pottery. Trousers are dark olive straight work trousers tucked into the unchanged boots. Distinct two-piece tunic and waist-apron construction, not another bib apron.
```

### 薪道行装 — 02_fuelway_travelwear.png

```text
Outfit variation: 薪道行装. Replace the blue apron with a dark olive sleeveless fitted canvas work jerkin, simple low collarless neckline and clearly visible short split side seams, hip-length rather than a long apron. Below the unchanged belt is a short double-layer work overskirt of olive cloth with brown-gray bound edges, ending at upper thigh, exposing more of iron-gray work trousers with sewn cloth reinforcement panels at the knees. No new leather armor and no extra accessories. Practical mobile clothing for carrying firewood through kiln passages.
```

### 釉廊罩衣 — 03_glaze_hall_smock.png

```text
Outfit variation: 釉廊罩衣. Replace the blue apron with a brown-gray sleeveless cross-over potter's smock with a diagonal closure, a modest shallow V neckline below the harness, and an asymmetrical calfward work hem reaching just above the knees. A broad slate-blue-gray protective textile panel is sewn into the lower front, with one diagonal overlapping fold and simple neat seams, no motifs. Iron-gray narrow work trousers tucked into the unchanged boots. Functional handmade glaze-work clothing, not a robe or noble costume.
```

### 守窑隔热服 — 04_kiln_heat_workwear.png

```text
Outfit variation: 守窑隔热服. Replace the blue apron with a sleeveless iron-gray quilted heat-protective work tunic, low squared neckline below the unchanged harness, visible widely spaced diamond quilting on the textile torso, and a knee-length split-front protective apron constructed of three broad overlapping vertical heavy cloth panels edged in muted brown-gray canvas. Dark slate-blue-gray trousers tucked into the unchanged boots. This is padded craftsman's work clothing, NOT plate armor or a knight's gambeson costume; keep its bulk modest so anatomy and proportions remain the same.
```

### 高塔保暖服 — 05_cold_tower_workwear.png

```text
Outfit variation: 高塔保暖服. Replace the blue apron with a sleeveless dark slate-blue-gray wool work waistcoat, low collarless neckline below the unchanged chest harness, fitted chest and long divided front tails to just above the knees; the tails part slightly below the unchanged belt to reveal a brown-gray linen inner tunic hem. Add subtle narrow olive textile binding on the waistcoat edges and understated large hand stitches. Dark iron-gray work trousers tucked into unchanged boots. Layered practical warmth for colder upper kiln floors, NO fur, cloak, hood, raised collar or sleeves, keep all original bare shoulder and arm regions visible.
```

## 验证

5 套独立 PNG 已生成并逐张视觉查看，均为 1024×1536。主角身份、面具/头发、姿势、薪斧、风箱、陶瓷手和背景保持视觉一致；这不是非服装区域逐像素一致的保证。第三套首轮装备漂移已重做，最终版本恢复原图横带与宽靴口造型。保存后核对尺寸、文件存在及源/目标 SHA256 一致。未做去背、全图调色或接入现役资源。Godot / GUT / Build：NOT VERIFIED（本任务不修改代码或现役素材）。


## 第三套迭代记录

首轮改变了胸前横带和靴口，双图恢复版仍有靴子形状偏差，均未选入最终交付。最终重新直接编辑原图，缩小服装编辑范围，使用以下提示词：

```text
Edit this original image. Output the same image with ONLY its blue apron and olive trousers changed. Leave EVERYTHING else exactly as it is, particularly the entire head/hair/face/mask, all bare skin, both arms/hands, ceramic hand, both original boots INCLUDING their broad folded cuffs at their exact original height, all leather straps including the horizontal chest cross-strap, axe and bellows. No change to character size, proportions, position, pose, outline, framing or background. Do not redraw the character.
Make the blue apron into a brown-gray cross-wrap sleeveless pottery smock, with a diagonal seam across the torso below the original leather chest strap. Keep the original apron silhouette and length so it ends at the SAME HEIGHT as the original blue hem. Add a single asymmetrical slate-blue-gray canvas protection panel sewn over the lower front. Trousers change from olive to muted iron-gray but keep the same exact shape. Keep the original badge and all belts on top of the fabric. Preserve original bare shoulders, visible chest above the garment, and the original low neckline. Matte linen and canvas with simple hand stitching, same illustration style. This is practical work clothing for a kiln-keeper in a handmade clay world. No additional garments, no armor, no new accessories. Exactly ONE full-body character, same 1024x1536 image with same pale checkered background.
```

## 最终交付文件

- [陶坊工装](01_pottery_workwear.png)
- [薪道行装](02_fuelway_travelwear.png)
- [釉廊罩衣](03_glaze_hall_smock.png)
- [守窑隔热服](04_kiln_heat_workwear.png)
- [高塔保暖服](05_cold_tower_workwear.png)
