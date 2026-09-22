extends CanvasLayer
## 灰络专属、纯表现层。监听真实行动/反冲回执，不调用伤害或游戏随机数。
signal effect_started(kind: String)
signal effect_impacted(kind: String)
var ui: CombatUI
var canvas: Control
var config: Dictionary
var effects: Array[Dictionary] = []
var reduced_motion := false

func _ready() -> void:
	ui = get_parent() as CombatUI
	if not ui.is_node_ready(): await ui.ready
	config = GameData.vfx.get("ashen_binder", {})
	reduced_motion = bool(config.get("reduced_motion", false))
	canvas = Control.new()
	canvas.name = "AshCanvas"
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://art/vfx/AshenBinderHUDMask.gdshader")
	canvas.material = material
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(canvas)
	canvas.draw.connect(_draw_effects)
	BattleDirector.enemy_visual_started.connect(_on_start)
	BattleDirector.enemy_visual_impact.connect(_on_impact)
	ui.controller._binder.backlash_resolved.connect(_on_backlash)
	SignalBus.combat_ended.connect(func(_won): clear())
	SignalBus.combat_death_pending.connect(clear)
	set_process(false)

func clear() -> void:
	effects.clear()
	canvas.queue_redraw()
	set_process(false)

func _eligible(enemy: CombatUnit) -> bool:
	return bool(config.get("enabled", false)) and is_instance_valid(enemy) and enemy.id == &"ashen_binder" and ui.unit_panels.has(enemy) and ui.controller.combat_active()

func _on_start(enemy: CombatUnit, windup: float) -> void:
	if not _eligible(enemy): return
	var kind := String(enemy.intent.get("id", ""))
	if kind not in ["seal", "ash_burst", "press", "vent"]: return
	_append(enemy, kind, windup, false)
	effect_started.emit(kind)

func _on_impact(enemy: CombatUnit) -> void:
	for fx in effects:
		if fx.enemy == enemy and not fx.impact:
			fx.impact = true
			fx.age = 0.0
			effect_impacted.emit(fx.kind)
	canvas.queue_redraw()

func _on_backlash(enemy: CombatUnit, absorbed: bool) -> void:
	if not _eligible(enemy): return
	_append(enemy, "backlash", 0.0, absorbed)
	effect_started.emit("backlash")
	effect_impacted.emit("backlash")

func _append(enemy: CombatUnit, kind: String, windup: float, absorbed: bool) -> void:
	# Dense automatic plays share one visual lash; rule callbacks still run per card.
	if kind == "backlash":
		for i in range(effects.size() - 1, -1, -1):
			if effects[i].kind == kind: effects.remove_at(i)
	var panel: Control = ui.unit_panels[enemy]
	var hud_top := minf(panel.get_node("Inner/HpBar").get_global_rect().position.y, panel.get_node("Inner/BlockShield").get_global_rect().position.y)
	var hud_bottom: float = ui.player_panel.get_parent().get_global_rect().end.y
	canvas.material.set_shader_parameter("hud_band", Vector2(hud_top, hud_bottom))
	canvas.material.set_shader_parameter("hand_top", ui.hand_container.get_global_rect().position.y)
	var body := _body_rect(panel.get_node("Inner/SpriteRect"))
	var target := _body_rect(ui.player_sprite)
	effects.append({"enemy":enemy,"kind":kind,"age":0.0,"windup":windup,"impact":kind == "backlash", "absorbed":absorbed,
		"origin":body.get_center(),"body":body.size,"target":target.position + target.size * Vector2(0.5, 0.38)})
	set_process(true)
	canvas.queue_redraw()

func _body_rect(portrait: TextureRect) -> Rect2:
	var tex_size := portrait.texture.get_size()
	var fit := minf(portrait.size.x / tex_size.x, portrait.size.y / tex_size.y)
	var local := Rect2((portrait.size - tex_size * fit) * 0.5, tex_size * fit)
	if portrait == ui.player_sprite:
		var body: Rect2 = portrait.get("idle_body_rect")
		local.position += body.position * fit
		local.size = body.size * fit
	return portrait.get_global_transform_with_canvas() * local

func _process(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var fx := effects[i]
		fx.age += delta
		if fx.impact and fx.age >= float(config["tails"][fx.kind]): effects.remove_at(i)
	canvas.queue_redraw()
	if effects.is_empty(): set_process(false)

func _color(key: String, alpha := 1.0) -> Color:
	return Color(Color(config[key]), alpha * float(config["opacity"]))

func _ceramic_piece(start: Vector2, finish: Vector2, width: float, seed: int, alpha: float, pigment := "seal_clay") -> void:
	var along := finish - start
	var edge := along.normalized().orthogonal()
	var chip := 0.38 + float(seed % 3) * 0.08
	var points := PackedVector2Array([
		start - edge * width * 0.4, start + along * 0.25 - edge * width,
		start + along * chip - edge * width * 0.54,
		start + along * 0.68 - edge * width * 0.88, finish - edge * width * 0.35,
		finish + edge * width * 0.5, start + along * 0.60 + edge * width * 0.83,
		start + along * 0.18 + edge * width * 0.61])
	canvas.draw_colored_polygon(points, _color(pigment, alpha))
	canvas.draw_colored_polygon(PackedVector2Array([
		start, start + along * 0.6 + edge * width * 0.2,
		finish + edge * width * 0.5, start + along * 0.60 + edge * width * 0.83,
		start + along * 0.18 + edge * width * 0.61]), _color("seal_soot", alpha * 0.85))
	points.append(points[0])
	canvas.draw_polyline(points, _color("ink", alpha * 0.9), 1.4, true)
	var crack := start + along * chip
	canvas.draw_polyline(PackedVector2Array([crack - edge * width * 0.6,
		crack + along * 0.12, crack + edge * width * 0.5]), _color("ink", alpha * 0.7), 1.0, true)
	for mark in 5:
		var p := start + along * (0.16 + float(mark) * 0.13) + edge * sin(float(mark * 9 + seed)) * width * 0.43
		canvas.draw_line(p, p + along.normalized() * 2.0, _color("seal_dust", alpha * 0.45), 1.0, true)

func _broken_arc(center: Vector2, radius: Vector2, offset: float, sweep: float, tilt: float, width: float, alpha: float, pigment := "seal_clay") -> void:
	for i in 7:
		var a := offset + sweep * float(i) / 7.0
		var b := a + sweep * (0.76 + float(i % 3) * 0.06) / 7.0
		var start := center + (Vector2(cos(a), sin(a)) * radius).rotated(tilt)
		var finish := center + (Vector2(cos(b), sin(b)) * radius).rotated(tilt)
		_ceramic_piece(start, finish, width * (0.75 + float(i % 3) * 0.14), i, alpha, pigment)

func _shards(center: Vector2, radius: float, progress: float, alpha: float, count := -1, size_scale := 1.0) -> void:
	for i in (int(config["shards"]) if count < 0 else count):
		var a := float(i) * 2.39996
		var direction := Vector2.from_angle(a)
		var spread := 0.42 if reduced_motion else progress
		var point := center + direction * radius * (0.2 + spread) * (0.65 + 0.35 * sin(i * 4.0))
		if not reduced_motion: point.y += progress * progress * radius * 0.22
		var length := (5.0 + float(i % 3) * 3.0) * size_scale
		_ceramic_piece(point - direction * length, point + direction * length * 0.6, length * 0.5, i, alpha,
			"seal_dust" if i % 4 == 0 else "seal_clay")

func _frayed_cord(start: Vector2, finish: Vector2, bend: float, width: float, alpha: float) -> void:
	var side := (finish - start).normalized().orthogonal()
	for strand in 2:
		var points := PackedVector2Array()
		for i in 20:
			var t := float(i) / 19.0
			var fray := sin(float(i * 7 + strand)) * width * 0.55
			points.append(start.lerp(finish, t) + side * (sin(t * PI) * bend + fray + strand * width))
		canvas.draw_polyline(points, _color("ink", alpha * 0.75), width + 1.5, true)
		canvas.draw_polyline(points, _color("seal_clay", alpha * (0.85 - strand * 0.2)), width, true)
		# Dry, interrupted fibres follow the rough cord, without a bright central spine.
		for i in range(1, 18, 3):
			canvas.draw_line(points[i], points[i + 1], _color("seal_dust", alpha * 0.48), 1.0, true)
			canvas.draw_line(points[i], points[i] + side * width * 2.3, _color("seal_soot", alpha * 0.65), 1.0, true)

func _ash_plume(head: Vector2, direction: Vector2, length: float, width: float, alpha: float, seed := 0) -> void:
	var side := direction.orthogonal()
	var points := PackedVector2Array()
	# Torn soot silhouette with broad matte planes, not a solid arrow or neon flame.
	for p in [Vector2(0.10,0), Vector2(-0.02,-0.31), Vector2(-0.23,-0.42), Vector2(-0.19,-0.65),
		Vector2(-0.49,-0.51), Vector2(-0.70,-0.74), Vector2(-0.64,-0.32), Vector2(-1.0,-0.38),
		Vector2(-0.85,-0.06), Vector2(-1.18,0.23), Vector2(-0.64,0.19), Vector2(-0.78,0.51),
		Vector2(-0.47,0.43), Vector2(-0.37,0.68), Vector2(-0.20,0.45), Vector2(-0.24,0.20), Vector2(-0.03,0.26)]:
		points.append(head + direction * p.x * length + side * p.y * width)
	canvas.draw_colored_polygon(points, _color("seal_soot", alpha * 0.80))
	points.append(points[0])
	canvas.draw_polyline(points, _color("ink", alpha * 0.55), 1.4, true)
	var plane := PackedVector2Array()
	for p in [Vector2(0.02,0), Vector2(-0.29,-0.21), Vector2(-0.23,-0.38), Vector2(-0.65,-0.33),
		Vector2(-0.50,-0.07), Vector2(-0.83,0.14), Vector2(-0.39,0.13), Vector2(-0.35,0.37), Vector2(-0.13,0.20)]:
		plane.append(head + direction * p.x * length + side * p.y * width)
	canvas.draw_colored_polygon(plane, _color("seal_clay", alpha * 0.66))
	for i in 24:
		var u := 0.08 + float(i % 8) * 0.125
		var v := sin(float(i * 11 + seed)) * (0.20 + u * 0.30)
		var p := head - direction * length * u + side * width * v
		var size := 1.0 + float(i % 3) * 0.65
		canvas.draw_colored_polygon(PackedVector2Array([p - direction * size * 1.6,
			p + side * size, p + direction * size, p - side * size * 0.6]),
			_color("seal_dust" if i % 3 else "ink", alpha * 0.48))
	for i in 6:
		var p := head - direction * length * (0.45 + float(i) * 0.14) + side * width * sin(float(i * 7 + seed)) * 0.76
		canvas.draw_line(p, p - direction * (2.0 + float(i % 3)), _color("seal_dust", alpha * 0.5), 1.8, true)

func _seal_clamp(center: Vector2, radius: Vector2, tilt: float, seed: int, alpha: float) -> void:
	# Broken, flat ceramic links: irregular silhouettes and dark fracture faces,
	# never a continuous smooth tube. Deterministic marks stay fixed during motion.
	for link in 9:
		var a := -0.18 + float(link) * 0.39
		var b := a + 0.35
		var start := center + (Vector2(cos(a), sin(a)) * radius).rotated(tilt)
		var finish := center + (Vector2(cos(b), sin(b)) * radius).rotated(tilt)
		var along := finish - start
		var edge := along.normalized().orthogonal()
		var width := 5.0 + float((link * 3 + seed) % 5)
		var points := PackedVector2Array([
			start - edge * width * 0.65,
			start + along * 0.30 - edge * width,
			start + along * 0.44 - edge * width * 0.52,
			start + along * 0.57 - edge * width * 0.92,
			finish - edge * width * 0.60,
			finish + edge * width * 0.76,
			start + along * 0.68 + edge * width,
			start + along * 0.27 + edge * width * 0.66,
			start + edge * width * 0.42])
		canvas.draw_colored_polygon(points, _color("seal_clay" if (link + seed) % 3 else "seal_soot", alpha))
		canvas.draw_colored_polygon(PackedVector2Array([
			start + edge * width * 0.06, start + along * 0.48 + edge * width * 0.25,
			finish + edge * width * 0.12, finish + edge * width * 0.76,
			start + along * 0.68 + edge * width, start + edge * width * 0.42]), _color("seal_soot", alpha * 0.8))
		points.append(points[0])
		canvas.draw_polyline(points, _color("ink", alpha * 0.9), 1.4, true)
		# Short branching cracks and uneven dry ash flecks, with no specular stripe.
		var crack := start + along * 0.63
		canvas.draw_polyline(PackedVector2Array([crack - edge * width * 0.8,
			crack - along * 0.12, crack + edge * width * 0.6]), _color("ink", alpha * 0.8), 1.1, true)
		for mark in 7:
			var u := 0.12 + float(mark) * 0.11
			var v := sin(float(mark * 13 + link * 7 + seed)) * width * 0.52
			var p := start + along * u + edge * v
			canvas.draw_line(p, p + along.normalized() * (1.0 + float(mark % 3)), _color("seal_dust", alpha * 0.45), 1.0, true)

func _seal(origin: Vector2, body: Vector2, motion: float, alpha: float, impact: bool) -> void:
	var close := 1.0 if impact or reduced_motion else 1.0 - pow(1.0 - motion, 3.0)
	for band in 3:
		var radius := Vector2(body.x * lerpf(0.52, 0.34, close), body.y * 0.055)
		var center := origin + Vector2(0, (band - 1) * body.y * 0.17 - body.y * 0.06)
		_seal_clamp(center, radius, -0.10 if band % 2 == 0 else 0.13, band * 5, alpha)
	# Loose ash folds inward; after closure only a few brittle crumbs fall away.
	for i in int(config["shards"]):
		var a := float(i) * 2.39996
		var travel := lerpf(0.60, 0.39, close)
		var point := origin + Vector2(cos(a) * body.x, sin(a) * body.y * 0.76) * travel
		if impact and not reduced_motion: point += Vector2(sin(a) * 12.0, 26.0) * motion
		var size := 2.0 + float(i % 3)
		canvas.draw_colored_polygon(PackedVector2Array([point + Vector2(-size, -size * 0.3),
			point + Vector2(size * 0.35, -size), point + Vector2(size, size * 0.5),
			point + Vector2(-size * 0.6, size)]), _color("seal_dust", alpha * 0.6))

func _vent(origin: Vector2, body: Vector2, motion: float, alpha: float, impact: bool) -> void:
	# Continue opening across the action receipt; resetting age must not close it again.
	var opening := 0.55 if reduced_motion else lerpf(0.55, 1.0, motion) if impact else motion * 0.55
	for band in 3:
		var center := origin + Vector2(0, (band - 1) * body.y * 0.17 - body.y * 0.06)
		var radius := Vector2(body.x * lerpf(0.34, 0.51, opening), body.y * 0.055)
		_seal_clamp(center, radius, -0.10 if band % 2 == 0 else 0.13, band * 5, alpha * (1.0 - opening * 0.45))
	var mouth := origin - Vector2(0, body.y * 0.10)
	for i in 2:
		var head := mouth + Vector2((float(i) - 0.5) * body.x * 0.10, -body.y * (0.06 + opening * 0.15))
		_ash_plume(head, Vector2(0.16 if i == 0 else -0.22, -1).normalized(), body.y * 0.16, body.x * 0.055, alpha * 0.50, i * 5)
	for i in 9:
		var spread := (float(i % 3) - 1.0) * body.x * 0.07
		var p := mouth + Vector2(spread * (0.6 + opening), -body.y * (0.03 + float(i) * 0.02 + opening * 0.13))
		var size := 1.4 + float(i % 3) * 0.6
		canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(-size, 0), p + Vector2(0, -size * 1.7),
			p + Vector2(size, 0), p + Vector2(0, size)]), _color("ember" if i % 4 == 0 else "seal_dust", alpha * 0.65))

func _draw_effects() -> void:
	for fx in effects:
		var origin: Vector2 = fx.origin
		var target: Vector2 = fx.target
		var body: Vector2 = fx.body
		var t := clampf(float(fx.age) / (float(config["tails"][fx.kind]) if fx.impact else maxf(0.001, float(fx.windup))), 0.0, 1.0)
		var motion := 0.5 if reduced_motion else t
		var alpha := 1.0 - t if fx.impact else minf(1.0, t * 5.0)
		var direction := (target - origin).normalized()
		var heavy: bool = fx.kind == "press"
		match String(fx.kind):
			"ash_burst", "press":
				if not fx.impact:
					var travel := pow(motion, 4.0 if heavy else 3.0)
					var head := origin.lerp(target, travel)
					if reduced_motion: head = origin
					if heavy:
						for band in 3:
							_broken_arc(head - direction * band * 30.0, Vector2(110, 34) * (0.65 + motion * 0.35),
								0.08, 2.98, direction.angle() - PI * 0.5, 13.0 - band * 2.5, alpha * (1.0 - band * 0.22))
						_shards(head, 62.0, motion * 0.4, alpha * 0.65, 6)
					else:
						_ash_plume(head - direction * 68.0 + direction.orthogonal() * 17.0, direction, 76.0, 28.0, alpha * 0.48, 5)
						_ash_plume(head, direction, 138.0, 54.0, alpha)
				else:
					var radius := (120.0 if heavy else 54.0) * (0.75 + motion)
					if heavy:
						_broken_arc(target + Vector2(0, 12), Vector2(radius, radius * 0.38), 0.08, 2.98, -0.10, 14.0, alpha)
					else:
						_ash_plume(target + direction * motion * 18.0, direction, 62.0, 48.0, alpha * 0.6)
					_shards(target, radius, motion, alpha, -1, 1.45 if heavy else 0.85)
			"seal":
				_seal(origin, body, motion, alpha, fx.impact)
			"vent":
				_vent(origin, body, motion, alpha, fx.impact)
			"backlash":
				if not reduced_motion: _frayed_cord(origin, target, -70.0 * (1.0 - t), 1.8, alpha * 0.75)
				if fx.absorbed:
					_broken_arc(target, Vector2(36, 46) * (0.85 + motion * 0.2), -1.25, 1.9, 0.0, 3.4, alpha, "shield")
				_shards(target, 36.0, motion, alpha * 0.8, 7)
