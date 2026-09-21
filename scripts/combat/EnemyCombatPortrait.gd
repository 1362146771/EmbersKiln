extends TextureRect
## Data-driven hit poses on the approved portrait. Layout and targeting stay intact.
var profile: Dictionary = {}
var hit_playing := false
var hit_count := 0
var _elapsed := 0.0
var _duration := 0.0
var _origin := Vector2.ZERO
var _reduced_motion := false
var _flash: TextureRect
var _flash_material: ShaderMaterial


func _ready() -> void:
	_flash = TextureRect.new()
	_flash.name = "HitFlash"
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flash.stretch_mode = stretch_mode
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = preload("res://art/vfx/EnemyHitFlash.gdshader")
	_flash.material = _flash_material
	add_child(_flash)
	_flash.hide()
	set_process(false)


func configure(enemy_id: StringName) -> void:
	var config: Dictionary = GameData.vfx["enemy_hit"]
	var key: String = config["enemy_profiles"].get(String(enemy_id), config["default_profile"])
	profile = config["profiles"][key]
	_flash.texture = texture


func sync_hit_texture() -> void:
	_flash.texture = texture


func play_hit(max_seconds := 0.0, reduced_motion := false) -> void:
	if profile.is_empty(): return
	# Repeated hits restart from the same resting transform, never accumulate drift.
	if not hit_playing: _origin = position
	_elapsed = 0.0
	_duration = float(profile["duration"])
	if max_seconds > 0.0: _duration = minf(_duration, max_seconds)
	_reduced_motion = reduced_motion
	hit_playing = true
	hit_count += 1
	_flash.texture = texture
	_flash.show()
	set_process(true)
	_apply_pose(0.0)


func begin_layout() -> void:
	if hit_playing: position = _origin


func end_layout() -> void:
	_origin = position
	if hit_playing: _apply_pose(_elapsed / _duration)


func stop_hit() -> void:
	if hit_playing: position = _origin
	rotation = 0.0
	scale = Vector2.ONE
	pivot_offset = Vector2.ZERO
	hit_playing = false
	_flash.hide()
	set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		stop_hit()
	else:
		_apply_pose(_elapsed / _duration)


func _apply_pose(progress: float) -> void:
	var keys: Array = GameData.vfx["enemy_hit"]["keys"]
	var pose := Vector3.ZERO
	for index in range(1, keys.size()):
		var previous: Array = keys[index - 1]
		var next: Array = keys[index]
		if progress > float(next[0]): continue
		var weight := smoothstep(float(previous[0]), float(next[0]), progress)
		pose = Vector3(float(previous[1]), float(previous[2]), float(previous[3])).lerp(
			Vector3(float(next[1]), float(next[2]), float(next[3])), weight)
		break
	# Anchor in the aspect-fitted image, not at the bottom of a wide UI slot.
	var fitted := texture.get_size() * minf(size.x / texture.get_width(), size.y / texture.get_height())
	var anchor: Array = profile["pivot"]
	pivot_offset = (size - fitted) * 0.5 + fitted * Vector2(float(anchor[0]), float(anchor[1]))
	var motion := 0.0 if _reduced_motion else 1.0
	var offset: Array = profile["offset"]
	position = _origin + Vector2(float(offset[0]), float(offset[1])) * pose.x * motion
	rotation = deg_to_rad(float(profile["tilt_degrees"])) * pose.x * motion
	var squash: Array = profile["squash"]
	scale = Vector2.ONE + Vector2(float(squash[0]), float(squash[1])) * pose.y * motion
	_flash_material.set_shader_parameter("strength", pose.z * float(GameData.vfx["enemy_hit"]["flash_opacity"]))
