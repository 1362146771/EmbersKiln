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
	var radius := body.size.x * float(config["radius_x"])
	var depth := body.size.y * float(config["radius_y"])
	return center + Vector2(cos(angle) * radius, sin(angle) * depth + cos(angle) * depth * float(profile["tilt"]))


func _draw_plane(canvas: Control, rear: bool) -> void:
	var body := _body_rect()
	if body.size.x <= 0.0 or body.size.y <= 0.0: return
	var envelope := smoothstep(0.0, float(config["fade_in"]), progress) * (1.0 - smoothstep(float(config["fade_out"]), 1.0, progress))
	var color := Color(profile["color"])
	color.a = float(config["opacity"]) * envelope * (float(config["rear_opacity"]) if rear else 1.0)
	var motion := 0.0 if reduced_motion else progress * TAU * float(profile["turns"])
	var width := clampf(body.size.x * float(config["line_ratio"]), float(config["line_min"]), float(config["line_max"]))
	var segments := int(config["segments"])
	for lane in 2:
		# A pair of broken ribbons, with a tapered leading edge; never a solid halo.
		for step in segments:
			var t := float(step) / segments
			var angle := motion + lane * PI + t * TAU * float(config["arc_fraction"])
			var next := motion + lane * PI + float(step + 1) / segments * TAU * float(config["arc_fraction"])
			if (sin((angle + next) * 0.5) < 0.0) != rear: continue
			var ink := color
			ink.a *= sin(t * PI) * 0.75
			var from := _point(angle, lane, body)
			var to := _point(next, lane, body)
			canvas.draw_line(from, to, Color(ink, ink.a * 0.22), width * 3.0, true)
			canvas.draw_line(from, to, ink, width, true)
	var glyph_size := clampf(body.size.x * float(config["glyph_ratio"]), float(config["glyph_min"]), float(config["glyph_max"]))
	for index in int(config["glyph_count"]):
		var angle := motion + TAU * float(index) / float(config["glyph_count"])
		if (sin(angle) < 0.0) != rear: continue
		var center := _point(angle, index % 2, body)
		var ink := color
		ink.a *= 0.8 + 0.2 * sin(angle)
		_draw_glyph(canvas, center, glyph_size * (0.9 + 0.1 * sin(angle)), ink, width)


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
