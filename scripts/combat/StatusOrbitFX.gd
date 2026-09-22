extends Control
## Short, portrait-local status ribbons. Two depth planes wrap around the body.
var status_id: StringName
var profile: Dictionary
var config: Dictionary
var progress := 0.0
var reduced_motion := false
var _back: Control
var _front: Control
var _age := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for rear in [true, false]:
		var plane := Control.new()
		plane.name = "RearRibbon" if rear else "FrontRibbon"
		plane.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plane.z_index = -1 if rear else 2
		add_child(plane)
		plane.draw.connect(_draw_plane.bind(plane, rear))
		if rear: _back = plane
		else: _front = plane
	refresh()


func refresh() -> void:
	_age = 0.0
	progress = 0.0
	_back.queue_redraw()
	_front.queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	progress = minf(_age / float(config["duration"]), 1.0)
	if progress >= 1.0:
		queue_free()
		return
	_back.queue_redraw()
	_front.queue_redraw()


func _body_rect() -> Rect2:
	var portrait := get_parent() as TextureRect
	if portrait == null or portrait.texture == null: return Rect2(Vector2.ZERO, size)
	var tex_size := portrait.texture.get_size()
	var fit := minf(size.x / tex_size.x, size.y / tex_size.y)
	var inset := (size - tex_size * fit) * 0.5
	# The player's idle texture has transparent padding; use its registered body.
	if portrait.get("idle_body_rect") != null:
		var body: Rect2 = portrait.get("idle_body_rect")
		return Rect2(inset + body.position * fit, body.size * fit)
	return Rect2(inset, tex_size * fit)


func _point(angle: float, lane: int, body: Rect2) -> Vector2:
	var center := body.position + body.size * Vector2(0.5, float(config["center_y"]))
	var movement := 0.0 if reduced_motion else progress
	center.y += body.size.y * (float(lane) - 0.5) * float(config["lane_spacing"])
	center.y -= movement * body.size.y * float(profile["rise"])
	var radius := body.size.x * float(config["radius_x"]) * float(profile["width"])
	var depth := body.size.y * float(config["radius_y"]) * float(profile["depth"])
	var point := center + Vector2(cos(angle) * radius, sin(angle) * depth + cos(angle) * depth * float(profile["tilt"]))
	match String(profile["glyph"]):
		"strength": point.y -= absf(cos(angle)) * body.size.y * 0.12 * movement
		"weak": point.y += absf(cos(angle * 3.0)) * depth * 0.5
		"vulnerable": point.x = center.x + (point.x - center.x) * (0.7 + movement * 0.5)
		"burn": point.y -= absf(sin(angle * 4.0 + movement * TAU)) * depth * 0.55
		"regen": point.y += sin(angle * 2.0) * depth * 0.4
		"vigor": point.y += sin(angle * 9.0) * depth * 0.32
		"shield": point.x = center.x + (point.x - center.x) * (0.85 + sin(movement * PI) * 0.15)
		"wither": point.x = center.x + (point.x - center.x) * (1.0 - movement * 0.35)
	return point


func _draw_plane(canvas: Control, rear: bool) -> void:
	var body := _body_rect()
	if body.size.x <= 0.0 or body.size.y <= 0.0: return
	var envelope := smoothstep(0.0, float(config["fade_in"]), progress) * (1.0 - smoothstep(float(config["fade_out"]), 1.0, progress))
	var color := Color(profile["color"])
	color.a = float(config["opacity"]) * envelope * (float(config["rear_opacity"]) if rear else 1.0)
	var motion := 0.0 if reduced_motion else progress * TAU * float(profile["turns"])
	var width := clampf(body.size.x * float(config["line_ratio"]), float(config["line_min"]), float(config["line_max"]))
	var segments := int(config["segments"])
	for lane in int(profile["lanes"]):
		# Distinct silhouettes: wind streaks, drooping wisps, electric zigzags,
		# dotted healing orbits and shield rims. Fracture/flame motifs carry no ring.
		for step in segments:
			if float(profile["ribbon_alpha"]) <= 0.0: break
			if String(profile["glyph"]) == "regen" and step % 3 != 0: continue
			if String(profile["glyph"]) == "wither" and step % 5 < 2: continue
			var t := float(step) / segments
			var angle := motion + lane * PI + t * TAU * float(profile["arc_fraction"])
			var next := motion + lane * PI + float(step + 1) / segments * TAU * float(profile["arc_fraction"])
			if (sin((angle + next) * 0.5) < 0.0) != rear: continue
			var ink := color
			ink.a *= sin(t * PI) * float(profile["ribbon_alpha"])
			var from := _point(angle, lane, body)
			var to := _point(next, lane, body)
			canvas.draw_line(from, to, Color(ink, ink.a * 0.22), width * 3.0, true)
			canvas.draw_line(from, to, ink, width, true)
	var glyph_size := clampf(body.size.x * float(config["glyph_ratio"]), float(config["glyph_min"]), float(config["glyph_max"]))
	for index in int(profile["glyph_count"]):
		var angle := motion + TAU * float(index) / float(profile["glyph_count"])
		if (sin(angle) < 0.0) != rear: continue
		var center := _point(angle, index % 2, body)
		var ink := color
		ink.a *= 0.8 + 0.2 * sin(angle)
		var s := glyph_size * (0.9 + 0.1 * sin(angle))
		_draw_accent(canvas, center, s, ink, width, index)
		_draw_glyph(canvas, center, s, ink, width)


func _fill(canvas: Control, center: Vector2, s: float, coords: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for point in coords: points.append(center + Vector2(point[0], point[1]) * s)
	canvas.draw_colored_polygon(points, Color(color, color.a * 0.28))


func _draw_accent(canvas: Control, center: Vector2, s: float, color: Color, width: float, index: int) -> void:
	var movement := 0.0 if reduced_motion else progress
	match String(profile["glyph"]):
		"strength":
			_fill(canvas, center, s, [[0, -1], [-0.75, -0.1], [-0.3, -0.1], [-0.3, 1.0], [0.3, 1.0], [0.3, -0.1], [0.75, -0.1]], color)
			canvas.draw_line(center + Vector2(0, s * 0.6), center + Vector2(0, s * (1.4 + movement)), Color(color, color.a * 0.4), width, true)
		"agility":
			canvas.draw_arc(center + Vector2(-s, s * 0.2), s * 1.3, -0.6, 0.7, 12, Color(color, color.a * 0.55), width, true)
		"weak":
			# Round, sagging cloud masses contrast with all angular buffs.
			for puff in 3:
				var offset := Vector2((puff - 1) * s * 0.55, sin(float(puff) + movement * PI) * s * 0.2)
				canvas.draw_circle(center + offset, s * 0.62, Color(color, color.a * 0.18), true, -1.0, true)
			canvas.draw_line(center + Vector2(s * 0.35, s * 0.8), center + Vector2(s * 0.35, s * 1.25), Color(color, color.a * 0.6), width, true)
		"vulnerable":
			_fill(canvas, center, s, [[0, -0.95], [-0.7, -0.3], [-0.25, 0.0], [-0.4, 0.7], [0.55, 0.25], [0.25, -0.1], [0.5, -0.6]], color)
			var spread := s * (0.85 + movement * 0.9)
			canvas.draw_line(center + Vector2(-spread, -s * 0.3), center + Vector2(-spread * 1.25, -s * 0.55), color, width, true)
			canvas.draw_line(center + Vector2(spread, s * 0.2), center + Vector2(spread * 1.2, s * 0.45), color, width, true)
		"burn":
			_fill(canvas, center, s, [[0.05, -1.3], [-0.65, 0.1], [-0.35, 0.7], [0.3, 0.65], [0.6, 0.0], [0.3, -0.5], [0, -0.1]], color)
			canvas.draw_circle(center + Vector2(s * 0.5, -s * (1.2 + movement)), width * 0.7, Color(color, color.a * 0.7), true, -1.0, true)
		"regen":
			canvas.draw_circle(center, s * 0.85, Color(color, color.a * 0.12), true, -1.0, true)
			canvas.draw_circle(center + Vector2(-s * 0.85, -s), width, Color(color, color.a * 0.6), true, -1.0, true)
		"vigor":
			var pulse := 0.5 if reduced_motion else 0.5 + 0.5 * sin(progress * TAU * 2.0 + index)
			_stroke(canvas, center, s, [[-0.9, -0.65], [-1.2, -0.1], [-0.85, 0.1]], Color(color, color.a * pulse), width)
		"shield":
			_fill(canvas, center, s, [[0, -0.9], [-0.75, -0.55], [-0.6, 0.35], [0, 0.95], [0.65, 0.3], [0.75, -0.55]], color)
			_stroke(canvas, center, s, [[-0.75, -0.55], [-0.6, 0.35], [0, 0.95], [0.65, 0.3], [0.75, -0.55]], Color(color, color.a * 0.5), width)
		"wither":
			_stroke(canvas, center, s, [[-0.8, -0.8], [-0.55, -0.5], [-0.8, -0.15]], Color(color, color.a * 0.45), width)
			canvas.draw_circle(center + Vector2(s * 0.6, s * (0.8 + movement)), width * 0.65, Color(color, color.a * 0.6), true, -1.0, true)


func _stroke(canvas: Control, center: Vector2, scale_value: float, coords: Array, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for point in coords: points.append(center + Vector2(point[0], point[1]) * scale_value)
	canvas.draw_polyline(points, Color("1B1612") * Color(1.0, 1.0, 1.0, color.a * 0.6), width + 1.5, true)
	canvas.draw_polyline(points, color, width, true)


func _draw_glyph(canvas: Control, center: Vector2, s: float, color: Color, width: float) -> void:
	match String(profile["glyph"]):
		"strength":
			_stroke(canvas, center, s, [[-0.6, 0.15], [0, -0.55], [0.55, 0.05]], color, width)
			_stroke(canvas, center, s, [[-0.5, 0.65], [0, 0.05], [0.45, 0.55]], color, width)
		"agility":
			_stroke(canvas, center, s, [[-0.65, 0.5], [0.15, -0.6], [0.6, -0.55], [0.1, 0.05], [-0.65, 0.5]], color, width)
		"weak":
			_stroke(canvas, center, s, [[-0.55, -0.4], [-0.15, 0.05], [-0.3, 0.3]], color, width)
			_stroke(canvas, center, s, [[0.45, -0.25], [0.1, 0.4], [-0.3, 0.3], [-0.15, 0.65]], color, width)
		"vulnerable":
			_stroke(canvas, center, s, [[0.1, -0.7], [-0.25, -0.05], [0.25, 0.1], [-0.15, 0.7]], color, width)
			_stroke(canvas, center, s, [[-0.2, -0.05], [-0.65, -0.3]], color, width)
			_stroke(canvas, center, s, [[0.2, 0.1], [0.65, 0.4]], color, width)
		"burn":
			_stroke(canvas, center, s, [[0.05, -0.8], [-0.5, 0.05], [-0.3, 0.55], [0.15, 0.65], [0.5, 0.1], [0.3, -0.3], [0.05, 0.1], [0.05, -0.8]], color, width)
		"regen":
			_stroke(canvas, center, s, [[0, -0.55], [0, 0.55]], color, width)
			_stroke(canvas, center, s, [[-0.5, 0], [0.5, 0]], color, width)
		"vigor":
			_stroke(canvas, center, s, [[0.3, -0.65], [-0.45, 0.05], [0.15, 0.05], [-0.2, 0.65]], color, width)
		"shield":
			_stroke(canvas, center, s, [[0, -0.6], [-0.5, -0.35], [-0.4, 0.3], [0, 0.65], [0.45, 0.2], [0.5, -0.35], [0, -0.6]], color, width)
		"wither":
			_stroke(canvas, center, s, [[-0.4, -0.6], [-0.15, -0.1], [0.4, 0.1], [0.2, 0.65]], color, width)
			_stroke(canvas, center, s, [[-0.15, -0.1], [0.35, -0.45]], color, width)
