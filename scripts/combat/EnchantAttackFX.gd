extends CanvasLayer
## Battle-local fullscreen presentation. No rule mutation or gameplay RNG.
var ui: CombatUI
var config: Dictionary
var profile: Dictionary = {}
var rhythm: Dictionary = {}
var shake_enabled := true
var source_entry: Dictionary = {}
var elapsed := 0.0
var charge_duration := 0.0
var prelude_duration := 0.0
var phase := "idle"
var impact_count := 0
var impact_duration_scale := 1.0
var reduced_motion := false
var _pending_origin := Vector2.ZERO
var _ghost: WeakRef
var _atlas_cache: Dictionary = {}
var _target_origins := PackedVector2Array()
@onready var copy: BackBufferCopy = $ScreenCopy
@onready var screen: ColorRect = $Composite
var shader_material: ShaderMaterial

func _ready() -> void:
	shader_material = screen.material.duplicate() as ShaderMaterial
	screen.material = shader_material
	clear()

func attach(combat_ui: CombatUI) -> void:
	ui = combat_ui
	config = GameData.vfx.get("enchant_attack", {})
	reduced_motion = bool(config.get("reduced_motion", false))
	for key in config.get("profiles", {}):
		var path := String(config["profiles"][key]["atlas"])
		_atlas_cache[path] = load(path)
	var cutin: Dictionary = config.get("reaper_cutin", {})
	if not cutin.is_empty():
		shader_material.set_shader_parameter("cutin_portrait", load(String(cutin["portrait"])))
		shader_material.set_shader_parameter("cutin_portrait_height", float(cutin["portrait_height"]))
		shader_material.set_shader_parameter("cutin_portrait_offset", Vector2(float(cutin["portrait_offset"][0]), float(cutin["portrait_offset"][1])))
		shader_material.set_shader_parameter("cutin_mask_top", float(cutin["mask_opacity_top"]))
		shader_material.set_shader_parameter("cutin_mask_bottom", float(cutin["mask_opacity_bottom"]))
		shader_material.set_shader_parameter("cutin_mask_color", Color(cutin["mask_color"]))
		shader_material.set_shader_parameter("cutin_background_retention", float(cutin["background_retention"]))
		shader_material.set_shader_parameter("cutin_eye_uv", Vector2(float(cutin["eye_uv"][0]), float(cutin["eye_uv"][1])))
		shader_material.set_shader_parameter("cutin_blur_pixels", float(cutin["blur_pixels"]))
		shader_material.set_shader_parameter("cutin_red", Color(cutin["red_color"]))

func prelude_for(entry: Dictionary) -> float:
	if not config.get("enabled", false): return 0.0
	var card: CardData = GameData.get_card(StringName(entry.get("id", "")))
	var enchant: EnchantData = CardMutation.town_enchant(entry)
	if card == null or card.id != &"reaper" or enchant == null or not enchant.matches_card(card): return 0.0
	return float(config.get("reaper_cutin", {}).get("seconds", 0.0))

func begin(entry: Dictionary, target_index: int, travel: float, ghost: Control = null) -> bool:
	clear()
	if config.is_empty() or not config.get("enabled", false): return false
	var card: CardData = GameData.get_card(StringName(entry.get("id", "")))
	var enchant: EnchantData = CardMutation.town_enchant(entry)
	if card == null or card.type != &"attack" or enchant == null or not enchant.matches_card(card): return false
	var key := String(config.get("card_profiles", {}).get(String(card.id), ""))
	if key == "" or not config.get("profiles", {}).has(key): return false
	source_entry = entry.duplicate(true)
	_ghost = weakref(ghost) if is_instance_valid(ghost) else null
	profile = config["profiles"][key]
	rhythm = config.get("impact_rhythm", {}).get(key, {})
	shake_enabled = true
	prelude_duration = prelude_for(entry)
	charge_duration = travel + prelude_duration
	if is_instance_valid(ghost):
		ghost.set_meta("cast_prelude_seconds", prelude_duration)
		if prelude_duration > 0.0: ghost.hide()
	_pending_origin = _target_center(target_index)
	_target_origins.clear()
	if card.target == &"all_enemies":
		var centers: Array[Vector2] = []
		for index in ui.controller.enemies.size():
			if ui.controller.enemies[index].is_alive():
				centers.append(_target_center(index))
				_target_origins.append(_target_center(index) / ui.get_viewport_rect().size)
		if not centers.is_empty():
			_pending_origin = Vector2.ZERO
			for center in centers: _pending_origin += center
			_pending_origin /= centers.size()
	if _target_origins.is_empty(): _target_origins.append(_pending_origin / ui.get_viewport_rect().size)
	for parameter in ["effect_kind", "darken", "distortion_pixels", "sprite_rotation", "saturation"]:
		shader_material.set_shader_parameter(parameter, profile[parameter])
	for parameter in ["sprite_size", "sprite_anchor", "sprite_offset"]:
		shader_material.set_shader_parameter(parameter, Vector2(float(profile[parameter][0]), float(profile[parameter][1])))
	shader_material.set_shader_parameter("effect_atlas", _atlas_cache[String(profile["atlas"])])
	shader_material.set_shader_parameter("target_count", mini(_target_origins.size(), 8))
	while _target_origins.size() < 8: _target_origins.append(Vector2.ZERO)
	shader_material.set_shader_parameter("target_origins", _target_origins.slice(0, 8))
	for parameter in ["fire_color", "core_color", "ash_color", "ink_color"]:
		shader_material.set_shader_parameter(parameter, Color(profile[parameter]))
	shader_material.set_shader_parameter("reduced_motion", 1.0 if reduced_motion else 0.0)
	phase = "charge"
	screen.show()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	set_process(true)
	_update_visuals()
	return true

func impact(targets: Array[int], allow_shake := true, duration_scale := 1.0) -> bool:
	if phase != "charge" or targets.is_empty(): return false
	phase = "impact"
	impact_duration_scale = duration_scale
	shake_enabled = allow_shake
	elapsed = 0.0
	impact_count += 1
	if _ghost != null and is_instance_valid(_ghost.get_ref()): _ghost.get_ref().hide()
	_update_visuals()
	return true

func finish_cast(ok: bool) -> void:
	if not ok or phase == "charge": clear()
	# An impact owns its short tail; no additional input lock or await.

func _process(delta: float) -> void:
	elapsed += delta / impact_duration_scale if phase == "impact" else delta
	if phase == "impact" and elapsed >= float(config["impact_seconds"]):
		clear()
		return
	_update_visuals()

func _update_visuals() -> void:
	if not is_instance_valid(ui): return
	var canvas_size := ui.get_viewport_rect().size
	shader_material.set_shader_parameter("canvas_size", canvas_size)
	shader_material.set_shader_parameter("origin_uv", _pending_origin / canvas_size)
	var in_cutin := phase == "charge" and prelude_duration > 0.0 and elapsed < prelude_duration
	shader_material.set_shader_parameter("cutin_progress", clampf(elapsed / prelude_duration, 0.0, 1.0) if in_cutin else -1.0)
	shader_material.set_shader_parameter("charge", clampf((elapsed - prelude_duration) / maxf(charge_duration - prelude_duration, 0.001), 0.0, 1.0) if phase == "charge" else 0.0)
	var visual_progress := _impact_progress(elapsed) if phase == "impact" else 0.0
	var stepped := phase == "impact" and not reduced_motion and not rhythm.is_empty() and elapsed < float(rhythm["stepped_until"])
	var shake := _impact_offset(elapsed) if phase == "impact" and shake_enabled and not reduced_motion else Vector2.ZERO
	shader_material.set_shader_parameter("progress", visual_progress)
	shader_material.set_shader_parameter("frame_cursor", _frame_cursor(visual_progress) if phase == "impact" else 0.0)
	shader_material.set_shader_parameter("stepped_frames", stepped)
	shader_material.set_shader_parameter("impact_offset", shake)
	# Cover the viewport edges while shifting the whole composite, without moving UI hitboxes.
	shader_material.set_shader_parameter("impact_zoom", maxf(absf(shake.x) / canvas_size.x, absf(shake.y) / canvas_size.y) * 2.0)
	shader_material.set_shader_parameter("strength", 1.0 if phase == "impact" else 0.0)

func _motion_time(seconds: float) -> float:
	if rhythm.is_empty() or reduced_motion: return seconds
	var contact := float(rhythm["contact_seconds"])
	var release := contact + float(rhythm["hold_seconds"])
	if seconds >= contact and seconds < release: return contact
	if seconds >= release and seconds < float(rhythm["stepped_until"]):
		var step := float(rhythm["step_seconds"])
		return release + floorf((seconds - release) / step + 0.00001) * step
	return seconds

func _impact_progress(seconds: float) -> float:
	var duration := float(config["impact_seconds"])
	if rhythm.is_empty() or reduced_motion: return clampf(seconds / duration, 0.0, 1.0)
	var contact := float(rhythm["contact_seconds"])
	var release := contact + float(rhythm["hold_seconds"])
	var pose := float(rhythm["contact_progress"])
	var sampled := _motion_time(seconds)
	if sampled <= contact: return pose * clampf(sampled / contact, 0.0, 1.0)
	return lerpf(pose, 1.0, clampf((sampled - release) / (duration - release), 0.0, 1.0))

func _impact_offset(seconds: float) -> Vector2:
	if rhythm.is_empty(): return Vector2.ZERO
	var sampled := _motion_time(seconds)
	var keys: Array = rhythm["shake_keys"]
	for index in range(keys.size() - 1, -1, -1):
		var key: Array = keys[index]
		if sampled + 0.00001 < float(key[0]): continue
		var offset := Vector2(float(key[1]), float(key[2]))
		# Early kicks are held poses. Only the final return interpolates to exact zero.
		if index == keys.size() - 2:
			var next: Array = keys[index + 1]
			return offset.lerp(Vector2.ZERO, smoothstep(float(key[0]), float(next[0]), sampled))
		return offset
	return Vector2.ZERO

func _frame_cursor(progress: float) -> float:
	# Fast contact poses, slower breakup poses. The same clock supports pause and lab scrubbing.
	var marks: Array = config["frame_marks"]
	for index in marks.size() - 1:
		if progress < float(marks[index + 1]):
			return float(index) + clampf(inverse_lerp(float(marks[index]), float(marks[index + 1]), progress), 0.0, 1.0)
	return 5.0

func _target_center(index: int) -> Vector2:
	if index >= 0 and index < ui.controller.enemies.size():
		var panel: Control = ui.unit_panels.get(ui.controller.enemies[index])
		if is_instance_valid(panel):
			var portrait := panel.get_node_or_null("Inner/SpriteRect") as Control
			if portrait != null: return portrait.get_global_transform_with_canvas() * (portrait.size * 0.5)
	return ui.get_viewport_rect().size * Vector2(0.5, 0.32)

func clear() -> void:
	impact_duration_scale = 1.0
	phase = "idle"
	elapsed = 0.0
	prelude_duration = 0.0
	if shader_material != null: shader_material.set_shader_parameter("cutin_progress", -1.0)
	if shader_material != null:
		shader_material.set_shader_parameter("impact_offset", Vector2.ZERO)
		shader_material.set_shader_parameter("impact_zoom", 0.0)
		shader_material.set_shader_parameter("stepped_frames", false)
	source_entry = {}
	_ghost = null
	set_process(false)
	if is_instance_valid(screen): screen.hide()
	if is_instance_valid(copy): copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED

func _exit_tree() -> void:
	clear()
