extends TextureRect
## Static portrait keeps its layout and input contract; the child plays body frames.
@export var idle_body_rect := Rect2(14, 47, 493, 1263)
@export var animation_body_height := 545.0
## Anatomical right boot is the screen-left support foot in this facing.
@export var idle_right_foot := Vector2(221.5, 1310)
@export var frame_right_foot := Vector2(240, 700)
@onready var animation_sprite: AnimatedSprite2D = $BodyAnimation
var _windup_tween: Tween


func _ready() -> void:
	# Both frame sets are color-calibrated to the idle portrait during export.
	animation_sprite.material = null
	animation_sprite.animation_finished.connect(_restore_idle)
	animation_sprite.frame_changed.connect(_on_attack_frame)
	resized.connect(_align_animation)
	_align_animation()


func play_pose(pose: StringName) -> void:
	_stop_windup()
	var action: StringName = &"hurt" if pose == &"hit" else pose
	if action == &"death":
		_restore_idle()
	elif animation_sprite.sprite_frames.has_animation(action):
		_clear_slash()
		_align_animation()
		self_modulate.a = 0.0
		animation_sprite.show()
		# stop() resets the frame even when replaying the same action.
		animation_sprite.stop()
		var duration_scale := float(GameData.vfx["attack"]["player_duration_scale"]) if action == &"attack" else 1.0
		animation_sprite.play(action, 1.0 / duration_scale)
	elif not animation_sprite.is_playing():
		_restore_idle()


func _restore_idle() -> void:
	_stop_windup()
	_clear_slash()
	animation_sprite.stop()
	animation_sprite.hide()
	self_modulate.a = 1.0


## Hold the two preparation frames across card flight; frame 2 belongs to impact.
func begin_cast_attack(duration: float) -> void:
	play_pose(&"attack")
	animation_sprite.pause()
	var frames := animation_sprite.sprite_frames
	var first := frames.get_frame_duration(&"attack", 0)
	var split := first / (first + frames.get_frame_duration(&"attack", 1))
	_windup_tween = create_tween()
	_windup_tween.tween_method(func(progress: float):
		if progress < split:
			animation_sprite.set_frame_and_progress(0, progress / split)
		else:
			animation_sprite.set_frame_and_progress(1, (progress - split) / (1.0 - split))
	, 0.0, 1.0, duration)


func strike_cast_attack() -> void:
	_stop_windup()
	animation_sprite.play(&"attack", 1.0 / float(GameData.vfx["attack"]["player_duration_scale"]))
	animation_sprite.set_frame_and_progress(2, 0.0)


func cancel_cast_attack() -> void:
	if _windup_tween != null:
		_restore_idle()


func _stop_windup() -> void:
	if _windup_tween != null and _windup_tween.is_valid():
		_windup_tween.kill()
	_windup_tween = null


func _clear_slash() -> void:
	for child in animation_sprite.get_children():
		if child.name == &"PlayerSlash":
			child.hide()
			child.queue_free()


func _on_attack_frame() -> void:
	if animation_sprite.animation != &"attack":
		_clear_slash()
		return
	if animation_sprite.frame != 2:
		return
	_clear_slash()
	var slash := ColorRect.new()
	slash.name = "PlayerSlash"
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slash.position = Vector2(290, 170)
	slash.size = Vector2(390, 430)
	slash.z_index = 5
	var effect := ShaderMaterial.new()
	effect.shader = preload("res://art/vfx/PlayerSlash.gdshader")
	slash.material = effect
	animation_sprite.add_child(slash)
	var tween := slash.create_tween()
	tween.tween_method(func(p: float): effect.set_shader_parameter("progress", p), 0.0, 1.0, float(GameData.vfx["attack"]["player_slash_duration"]) * float(GameData.vfx["attack"]["player_duration_scale"]))
	tween.tween_callback(slash.queue_free)


func _align_animation() -> void:
	if texture == null:
		return
	var texture_size := texture.get_size()
	var portrait_scale := minf(size.x / texture_size.x, size.y / texture_size.y)
	var inset := (size - texture_size * portrait_scale) * 0.5
	var body_scale := idle_body_rect.size.y * portrait_scale / animation_body_height
	animation_sprite.scale = Vector2.ONE * body_scale
	animation_sprite.position = inset + idle_right_foot * portrait_scale - frame_right_foot * body_scale
