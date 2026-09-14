extends Node
## Autoload: VFXSystem —— 战斗轻量视觉反馈工具库（v2，依据 VFX_DESIGN.md）。
## 设计原则（SYSTEM_DESIGN §15 / ART_STYLE §9）：信息优先于华丽，不做全屏大特效。
## 全部方法瞬态：在 anchor 上创建节点，tween 后自动 queue_free；对 null target 安全。
## 刻意不写 class_name（避免与 autoload 单例名 VFXSystem 冲突，参考 SignalBus.gd）。

# ---- 参数（MVP 常量；验收后迁 data/vfx.json）----
const BIG_HIT := 15           # 单次伤害 ≥ 此值触发大伤害震屏
const DMG_DUR := 0.6
const DMG_RISE := 44
const HEAL_DUR := 0.6
const HEAL_RISE := 44
const BLOCK_DUR := 0.32
const STATUS_DUR := 0.36
const CARD_DUR := 0.22
const DEATH_DUR := 0.5
const SHAKE_DUR := 0.3
const SHAKE_MAX := 9.0         # 震屏强度上限（px）

# ---- 颜色（ART_STYLE 暖色调色板）----
const C_ENEMY_DMG := Color("#F0997B")   # 暖橙：敌人受击
const C_PLAYER_DMG := Color("#D85A30")   # 珊瑚红：玩家受击
const C_HEAL := Color("#5DCAA5")         # 青绿：治疗
const C_BLOCK := Color("#378ADD")        # 蓝：格挡
const C_BUFF := Color("#5DCAA5")         # 青绿：增益
const C_DEBUFF := Color("#D85A30")       # 珊瑚红系：减益（与玩家受击区分用紫灰更佳，见下）
const C_DEBUFF2 := Color("#7F77DD")      # 紫灰：减益
const C_CARD := Color("#EF9F27")         # 琥珀：出牌
const C_ALLY := Color(0.40, 0.80, 0.95)  # 友方（召唤物）青蓝：与敌人红/橙区分
const CAST_BURST_TEX := "res://art/vfx/ART_CAST_BURST.png"   # 出牌爆发精灵（白底可染色，缺失则代码闪光兜底）
const CAST_BURST_SIZE := 180             # 爆发精灵基准尺寸（px）
const STRIKE_CARD_TEX := "res://art/vfx/ART_STRIKE_CARD.png"  # 敌人攻击碰撞卡卡面（红橙侵略性框，中心透明；P2 新增）
const STRIKE_CARD_W := 132               # 碰撞卡宽（px，竖卡比例 ~3:4）
const STRIKE_CARD_H := 176
const STRIKE_TRAVEL := 0.34              # 碰撞卡飞行时长（s）
const STRIKE_ARC := 90.0                 # 抛物线弧高（px）
const DMG_BIG_THRESHOLD := 12            # 单次伤害 ≥ 此值视为大伤害：放大字号 + 更强冲击


var _screen_tween: Tween
var _screen_origin := Vector2.ZERO
var _shake_rng := RandomNumberGenerator.new()


## White slash and real portrait movement; bars and intent remain in place.
func spawn_attack_impact(portrait: Control) -> void:
	if not is_instance_valid(portrait):
		return
	var config: Dictionary = GameData.vfx["attack"]
	var cut := ColorRect.new()
	cut.name = "WhiteSlash"
	cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cut.z_index = 5
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://art/vfx/WhiteSlash.gdshader")
	cut.material = shader
	portrait.add_child(cut)
	var slash_tween := cut.create_tween()
	slash_tween.tween_method(func(value: float): shader.set_shader_parameter("progress", value), 0.0, 1.0, float(config["slash_duration"]))
	slash_tween.tween_callback(cut.queue_free)
	var previous: Tween = portrait.get_meta("hit_tween") if portrait.has_meta("hit_tween") else null
	var origin: Vector2 = portrait.get_meta("hit_origin", portrait.position)
	if previous != null and previous.is_valid():
		previous.kill()
	else:
		origin = portrait.position
	portrait.position = origin
	portrait.set_meta("hit_origin", origin)
	var tween := portrait.create_tween()
	portrait.set_meta("hit_tween", tween)
	tween.tween_method(func(progress: float):
		portrait.position = origin + Vector2(sin(progress * TAU * 3.0), sin(progress * TAU * 2.0) * 0.25) * float(config["portrait_shake_pixels"]) * (1.0 - progress),
		0.0, 1.0, float(config["portrait_shake_duration"]))
	tween.tween_property(portrait, "position", origin, 0.0)


## 通用飘字（伤害/治疗）。amount 为正数；big=true 时字号随伤害放大并叠加「缩小→弹大→回落」冲击。
func _float(anchor: Control, amount: int, color: Color, dur: float, rise: float, big := false) -> void:
	if anchor == null or amount <= 0:
		return
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	var size := 36
	if big:
		# 夸张：字号随伤害放大（12→~72 上限），视觉冲击更强
		size = clampi(40 + int(amount * 0.7), 40, 72)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	# 描边让大数字在混乱战场依旧清晰
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var w := maxf(anchor.size.x, 1.0)
	lbl.custom_minimum_size = Vector2(w, size + 12)
	lbl.position = Vector2(0.0, maxf(anchor.size.y * 0.18, 2.0))
	anchor.add_child(lbl)
	lbl.pivot_offset = lbl.custom_minimum_size * 0.5
	lbl.scale = Vector2(0.4, 0.4)

	# 冲击：先快速放大到 1.3，再回落到 1.0；与上升/淡出并行
	var t1 := create_tween()
	t1.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.10).set_ease(Tween.EASE_OUT)
	t1.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.09).set_ease(Tween.EASE_OUT)
	var t2 := create_tween()
	t2.tween_property(lbl, "position:y", lbl.position.y - rise, dur).set_ease(Tween.EASE_OUT)
	t2.parallel().tween_property(lbl, "modulate:a", 0.0, dur)
	t2.tween_callback(lbl.queue_free)


## 伤害飘字。to_player=true 用珊瑚红并达阈值时触发震屏。≥ DMG_BIG_THRESHOLD 视为大伤害（放大+冲击）。
func spawn_damage(anchor: Control, amount: int, to_player: bool) -> void:
	var big := amount >= DMG_BIG_THRESHOLD
	_float(anchor, amount, C_PLAYER_DMG if to_player else C_ENEMY_DMG, DMG_DUR, DMG_RISE, big)
	if to_player and amount >= BIG_HIT:
		screen_shake(clamp(float(amount) / BIG_HIT, 1.0, 3.0) * 3.0)


## 治疗飘字（青绿）。
func spawn_heal(anchor: Control, amount: int) -> void:
	_float(anchor, amount, C_HEAL, HEAL_DUR, HEAL_RISE)


## 颜色脉冲（格挡/状态/出牌通用）。闪烁后回到白色（面板 self_modulate 不受影响）。
func _flash(anchor: Control, color: Color, dur: float) -> void:
	if anchor == null:
		return
	var t := create_tween()
	t.tween_property(anchor, "modulate", color, dur * 0.4)
	t.tween_property(anchor, "modulate", Color.WHITE, dur * 0.6)


## 格挡闪光（蓝）。
func spawn_block(anchor: Control) -> void:
	_flash(anchor, C_BLOCK, BLOCK_DUR)


## 状态获得脉冲（增益青绿 / 减益紫灰）。
func spawn_status(anchor: Control, is_buff: bool) -> void:
	_flash(anchor, C_BUFF if is_buff else C_DEBUFF2, STATUS_DUR)


## 出牌闪光（琥珀）。
func spawn_card_played(anchor: Control) -> void:
	_flash(anchor, C_CARD, CARD_DUR)


## 玩家受击反馈：红色脉冲（位置抖动会受容器布局干扰，故用闪光）。
func spawn_hit_shake(anchor: Control) -> void:
	_flash(anchor, C_PLAYER_DMG, 0.25)


## 出牌爆发：卡牌命中目标瞬间的元素光环。attack=暖橙、其余（格挡/治疗/增益）=青绿。
## 优先用 ART_CAST_BURST.png（白底可染色），缺失则回退代码闪光。纯瞬态，自动释放。
func spawn_cast_burst(anchor: Control, is_attack: bool) -> void:
	if anchor == null:
		return
	var col := C_ENEMY_DMG if is_attack else C_BUFF
	if ResourceLoader.exists(CAST_BURST_TEX):
		var tex: Texture2D = load(CAST_BURST_TEX)
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(CAST_BURST_SIZE, CAST_BURST_SIZE)
			tr.size = Vector2(CAST_BURST_SIZE, CAST_BURST_SIZE)
			tr.modulate = col
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tr.position = anchor.size * 0.5 - tr.size * 0.5
			anchor.add_child(tr)
			tr.scale = Vector2(0.3, 0.3)
			tr.modulate.a = 0.95
			var t := create_tween()
			t.tween_property(tr, "scale", Vector2(1.5, 1.5), 0.24).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(tr, "modulate:a", 0.0, 0.24)
			t.tween_callback(tr.queue_free)
			return
	# 兜底：代码闪光
	_flash(anchor, col, CARD_DUR)


## 死亡：缩放至 0 + 淡出，结束回调释放面板（解决旧方案野指针）。
func spawn_death(anchor: Control, on_done: Callable) -> void:
	if anchor == null:
		on_done.call()
		return
	var t := create_tween()
	t.tween_property(anchor, "scale", Vector2.ZERO, DEATH_DUR).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(anchor, "modulate:a", 0.0, DEATH_DUR)
	t.tween_callback(on_done)


## 大伤害震屏：抖动视口 canvas_transform（全屏轻微，布局无关，非大爆炸）。
func screen_shake(intensity: float) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var amt: float = clamp(intensity, 0.0, SHAKE_MAX)
	if _screen_tween != null and _screen_tween.is_valid():
		_screen_tween.kill()
	else:
		_screen_origin = vp.canvas_transform.origin
	var base := _screen_origin
	var steps := 6
	var t := create_tween()
	_screen_tween = t
	for i in steps:
		var off: Vector2 = Vector2(_shake_rng.randf_range(-1.0, 1.0), _shake_rng.randf_range(-1.0, 1.0)) * amt
		t.tween_property(vp, "canvas_transform:origin", base + off, SHAKE_DUR / float(steps))
	t.tween_property(vp, "canvas_transform:origin", base, SHAKE_DUR / float(steps))


func cancel_screen_shake() -> void:
	if _screen_tween != null and _screen_tween.is_valid():
		_screen_tween.kill()
		get_viewport().canvas_transform.origin = _screen_origin
	_screen_tween = null


## 敌人攻击"碰撞卡"：从敌方面板浮现攻击卡，沿抛物线弧飞向玩家面板；
## 撞击瞬间：轻微震屏 + 玩家红闪 + 卡面碎裂（scale→0 + 淡出）。
## on_impact 在撞击点回调，供 BattleDirector 在此时结算伤害（演出本身不碰数值）。
## 非攻击意图不应调用本方法（由 Director 决定走"自身出牌"演出）。纹理缺失则回退红色卡底。
## 敌人攻击"碰撞卡"：从敌方面板浮现攻击卡，沿抛物线弧飞向玩家面板；
## 撞击瞬间：轻微震屏 + 玩家红闪 + 卡面碎裂（scale→0 + 淡出）。
## on_impact 在撞击点回调，供 BattleDirector 在此时结算伤害（演出本身不碰数值）。
## 本方法为协程（await 飞行 + 碎裂），调用方 await 它即可等到"撞击播完"。
## 非攻击意图不应调用本方法（由 Director 决定走"自身出牌"演出）。纹理缺失则回退红色卡底。
func spawn_strike_card(from: Control, to: Control, intent: Dictionary, on_impact: Callable = Callable()) -> void:
	if from == null or to == null:
		if on_impact.is_valid():
			on_impact.call()
		return
	var value: int = int(intent.get("value", 0))
	var start := from.get_global_rect().get_center()
	var end := to.get_global_rect().get_center()

	var card := Control.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.top_level = true
	card.z_as_relative = false
	card.z_index = 500
	card.custom_minimum_size = Vector2(STRIKE_CARD_W, STRIKE_CARD_H)
	card.size = Vector2(STRIKE_CARD_W, STRIKE_CARD_H)
	card.global_position = start - card.size * 0.5
	from.add_child(card)

	var tex := _strike_tex()
	if tex != null:
		var face := TextureRect.new()
		face.texture = tex
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(face)
	else:
		var bg := Panel.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.modulate = C_PLAYER_DMG
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bg)

	var lbl := Label.new()
	lbl.text = str(value) if value > 0 else ""
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.03))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)

	# 飞行
	var tw := create_tween()
	tw.tween_method(_strike_arc.bind(card, start, end, STRIKE_ARC), 0.0, 1.0, STRIKE_TRAVEL).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(card, "scale", Vector2(1.12, 1.12), STRIKE_TRAVEL * 0.5)
	tw.parallel().tween_property(card, "scale", Vector2(1.0, 1.0), STRIKE_TRAVEL * 0.5)
	await tw.finished

	# 撞击点：结算伤害 + 震屏/红闪
	if on_impact.is_valid():
		on_impact.call()
	if is_instance_valid(to):
		screen_shake(6.0)
		spawn_hit_shake(to)

	# 碎裂
	var sh := create_tween()
	sh.tween_property(card, "scale", Vector2(0.1, 0.1), 0.16).set_ease(Tween.EASE_IN)
	sh.parallel().tween_property(card, "modulate:a", 0.0, 0.16)
	await sh.finished
	if is_instance_valid(card):
		card.queue_free()


## 碰撞卡弧线更新：progress 0→1，x 线性、y 叠加抛物线（sin 弧）。
func _strike_arc(p: float, card: Control, start: Vector2, end: Vector2, arc: float) -> void:
	if not is_instance_valid(card):
		return
	var x := lerpf(start.x, end.x, p)
	var y := lerpf(start.y, end.y, p) - arc * sin(p * PI)
	card.global_position = Vector2(x, y) - card.size * 0.5


func _strike_tex() -> Texture2D:
	if ResourceLoader.exists(STRIKE_CARD_TEX):
		return load(STRIKE_CARD_TEX) as Texture2D
	return null


## 友方随从攻击：友色光球（复用出牌爆发精灵，染青蓝）从 from 飞向 to，沿抛物线弧；
## 撞击点：结算伤害（on_impact）+ 轻微震屏 + 目标红闪 + 命中处元素爆发。
## on_impact 由 BattleDirector.run_summon_turn 在撞击点回调，演出本身不碰数值。
## from / to 为 null 时（无对应面板）直接回调 on_impact，保证逻辑照常结算（优雅降级）。
## 本方法为协程，调用方 await 它即可等到演出播完。
func spawn_summon_strike(from: Control, to: Control, on_impact: Callable = Callable()) -> void:
	if from == null or to == null:
		if on_impact.is_valid():
			on_impact.call()
		return
	var start := from.get_global_rect().get_center()
	var end := to.get_global_rect().get_center()

	var proj := Control.new()
	proj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proj.top_level = true
	proj.z_as_relative = false
	proj.z_index = 500
	proj.custom_minimum_size = Vector2(64, 64)
	proj.size = Vector2(64, 64)
	proj.global_position = start - proj.size * 0.5
	from.add_child(proj)

	if ResourceLoader.exists(CAST_BURST_TEX):
		var tex := load(CAST_BURST_TEX) as Texture2D
		if tex != null:
			var face := TextureRect.new()
			face.texture = tex
			face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			face.modulate = C_ALLY
			proj.add_child(face)
	else:
		var bg := Panel.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.modulate = C_ALLY
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		proj.add_child(bg)

	# 飞行（弧线与敌人碰撞卡一致）
	var tw := create_tween()
	tw.tween_method(_strike_arc.bind(proj, start, end, STRIKE_ARC), 0.0, 1.0, STRIKE_TRAVEL).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(proj, "scale", Vector2(1.2, 1.2), STRIKE_TRAVEL * 0.5)
	tw.parallel().tween_property(proj, "scale", Vector2(1.0, 1.0), STRIKE_TRAVEL * 0.5)
	await tw.finished

	# 撞击点：结算伤害 + 反馈
	if on_impact.is_valid():
		on_impact.call()
	if is_instance_valid(to):
		screen_shake(4.0)
		spawn_hit_shake(to)
		spawn_cast_burst(to, true)

	# 碎裂
	var sh := create_tween()
	sh.tween_property(proj, "scale", Vector2(0.1, 0.1), 0.14).set_ease(Tween.EASE_IN)
	sh.parallel().tween_property(proj, "modulate:a", 0.0, 0.14)
	await sh.finished
	if is_instance_valid(proj):
		proj.queue_free()
