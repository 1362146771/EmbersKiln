extends TextureRect
## Static portrait keeps its layout and input contract; the child plays body frames.
@export var idle_body_rect := Rect2(14, 47, 493, 1263)
@export var animation_body_height := 545.0
## Anatomical right boot is the screen-left support foot in this facing.
@export var idle_right_foot := Vector2(221.5, 1310)
@export var frame_right_foot := Vector2(240, 700)
@onready var animation_sprite: AnimatedSprite2D = $BodyAnimation


func _ready() -> void:
	var portrait_tone := ShaderMaterial.new()
	portrait_tone.shader = preload("res://art/player/animations/PortraitTone.gdshader")
	animation_sprite.material = portrait_tone
	animation_sprite.animation_finished.connect(_restore_idle)
	resized.connect(_align_animation)
	_align_animation()


func play_pose(pose: StringName) -> void:
	var action: StringName = &"hurt" if pose == &"hit" else pose
	if action == &"death":
		_restore_idle()
	elif animation_sprite.sprite_frames.has_animation(action):
		_align_animation()
		self_modulate.a = 0.0
		animation_sprite.show()
		# stop() resets the frame even when replaying the same action.
		animation_sprite.stop()
		animation_sprite.play(action)
	elif not animation_sprite.is_playing():
		_restore_idle()


func _restore_idle() -> void:
	animation_sprite.stop()
	animation_sprite.hide()
	self_modulate.a = 1.0


func _align_animation() -> void:
	if texture == null:
		return
	var texture_size := texture.get_size()
	var portrait_scale := minf(size.x / texture_size.x, size.y / texture_size.y)
	var inset := (size - texture_size * portrait_scale) * 0.5
	var body_scale := idle_body_rect.size.y * portrait_scale / animation_body_height
	animation_sprite.scale = Vector2.ONE * body_scale
	animation_sprite.position = inset + idle_right_foot * portrait_scale - frame_right_foot * body_scale
