extends Node
## Autoload: VFXSystem —— 战斗轻量视觉反馈工具库（v2，依据 VFX_DESIGN.md）。
## 设计原则（SYSTEM_DESIGN §15 / ART_STYLE §9）：信息优先于华丽，不做全屏大特效。
## 全部方法瞬态：在 anchor 上创建节点，tween 后自动 queue_free；对 null target 安全。
## 刻意不写 class_name（避免与 autoload 单例名 VFXSystem 冲突，参考 SignalBus.gd）。

# ---- 参数（MVP 常量；验收后迁 data/vfx.json）----
const BIG_HIT := 15           # 单次伤害 ≥ 此值触发大伤害震屏
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
const DMG_BIG_THRESHOLD := 12            # 单次伤害 ≥ 此值视为大伤害：放大字号 + 更强冲击


var _screen_tween: Tween
var _screen_origin := Vector2.ZERO
var _shake_rng := RandomNumberGenerator.new()


## White slash and real portrait movement; bars and intent remain in place.
func spawn_attack_impact(portrait: Control, show_slash := true, duration_scale := 1.0) -> void:
	if not is_instance_valid(portrait):
		return
	var config: Dictionary = GameData.vfx["attack"]
	var cut := ColorRect.new()
	cut.name = "WhiteSlash"
	cut.visible = show_slash
	cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cut.z_index = 5
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://art/vfx/WhiteSlash.gdshader")
	cut.material = shader
	portrait.add_child(cut)
	var slash_tween := cut.create_tween()
	slash_tween.tween_method(func(value: float): shader.set_shader_parameter("progress", value), 0.0, 1.0, float(config["slash_duration"]) * duration_scale)
	slash_tween.tween_callback(cut.queue_free)
	# Enemy portraits own recoil, squash and recovery; do not layer the old shake.
	if portrait.has_method("play_hit"):
		return
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
		0.0, 1.0, float(config["portrait_shake_duration"]) * duration_scale)
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


## 深红伤害数字：双层描边、短促弹出、停留后淡出。overlay 可放在全屏合成层上方。
func spawn_damage(anchor: Control, amount: int, to_player: bool, overlay: Control = null, combine_hits := false) -> void:
	if not is_instance_valid(anchor) or amount <= 0: return
	# A synchronous Fiend Fire burst shares one readable total instead of overlapping numbers.
	var parent: Control = overlay if is_instance_valid(overlay) else anchor
	if combine_hits:
		for existing in parent.get_children():
			if existing.get_meta("damage_anchor", 0) != anchor.get_instance_id() or existing.get_meta("damage_frame", -1) != Engine.get_process_frames(): continue
			var total := int(existing.get_meta("damage_total")) + amount
			var hits := int(existing.get_meta("damage_hits")) + 1
			existing.set_meta("damage_total", total)
			existing.set_meta("damage_hits", hits)
			for label_name in ["Shadow", "Value"]: existing.get_node(label_name).text = "-%d · %d击" % [total, hits]
			return
	var big := amount >= DMG_BIG_THRESHOLD
	var config: Dictionary = GameData.vfx["damage_number"]
	var font_size := int(config["font_size"])
	if big:
		font_size = clampi(int(config["big_font_base"]) + int(amount * float(config["big_font_per_damage"])), int(config["big_font_base"]), int(config["big_font_max"]))
	var popup := Control.new()
	popup.name = "DamageNumber"
	if combine_hits:
		popup.set_meta("damage_anchor", anchor.get_instance_id())
		popup.set_meta("damage_frame", Engine.get_process_frames())
		popup.set_meta("damage_total", amount)
		popup.set_meta("damage_hits", 1)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.size = Vector2(maxf(anchor.size.x, 1.0), font_size + 20.0)
	var local_origin := Vector2(0.0, maxf(anchor.size.y * 0.18, 2.0))
	if not to_player: local_origin.y += float(config["enemy_offset_y"])
	if is_instance_valid(overlay):
		overlay.add_child(popup)
		popup.position = overlay.get_global_transform_with_canvas().affine_inverse() * (anchor.get_global_transform_with_canvas() * local_origin)
	else:
		anchor.add_child(popup)
		popup.position = local_origin
	popup.pivot_offset = popup.size * 0.5
	for is_shadow in [true, false]:
		var label := Label.new()
		label.name = "Shadow" if is_shadow else "Value"
		label.text = "-%d" % amount
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color(config["shadow_color"] if is_shadow else config["player_color"] if to_player else config["enemy_color"]))
		label.add_theme_color_override("font_outline_color", Color(config["shadow_color"] if is_shadow else config["outline_color"]))
		label.add_theme_constant_override("outline_size", int(config["shadow_outline_size"] if is_shadow else config["outline_size"]))
		popup.add_child(label)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if is_shadow: label.position += Vector2(float(config["shadow_offset"][0]), float(config["shadow_offset"][1]))
	popup.scale = Vector2.ONE * float(config["start_scale"])
	popup.rotation = deg_to_rad(float(config["tilt_degrees"]))
	var pop := popup.create_tween()
	pop.tween_property(popup, "scale", Vector2.ONE * float(config["peak_scale"]), float(config["pop_seconds"])).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(popup, "rotation", 0.0, float(config["pop_seconds"]))
	pop.tween_property(popup, "scale", Vector2.ONE, float(config["settle_seconds"])).set_ease(Tween.EASE_OUT)
	var duration := float(config["duration"])
	var rise := popup.create_tween()
	rise.tween_property(popup, "position:y", popup.position.y - float(config["rise_pixels"]), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var fade := popup.create_tween()
	fade.tween_interval(duration * float(config["fade_start_ratio"]))
	fade.tween_property(popup, "modulate:a", 0.0, duration * (1.0 - float(config["fade_start_ratio"])))
	fade.tween_callback(popup.queue_free)
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


## 死亡：缩放至 0 + 淡出，结束回调释放面板（解决旧方案野指针）。
func spawn_death(anchor: Control, on_done: Callable) -> void:
	if anchor == null:
		on_done.call()
		return
	# 群攻可同时击败多个敌人；切场景时取消已离场面板的回调。
	var t := create_tween().bind_node(anchor)
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
