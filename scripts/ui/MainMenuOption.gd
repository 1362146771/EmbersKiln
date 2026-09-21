extends Button
## Main-menu-only presentation. Navigation remains owned by MainMenu.

@export var press_scale := 0.94
@export var rebound_scale := 1.045
@export var press_seconds := 0.07
@export var rebound_seconds := 0.10
@export var settle_seconds := 0.13

var feedback_locked := false
var _feedback_tween: Tween
@onready var _surface_material: ShaderMaterial = $Surface.material


func _ready() -> void:
	resized.connect(_update_pivot)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(_refresh_idle)
	mouse_exited.connect(_refresh_idle)
	focus_entered.connect(_refresh_idle)
	focus_exited.connect(_refresh_idle)
	_update_pivot()


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _new_tween() -> Tween:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return _feedback_tween


func _on_button_down() -> void:
	if feedback_locked or disabled:
		return
	_surface_material.set_shader_parameter("highlight", 1.0)
	_new_tween().tween_property(self, "scale", Vector2.ONE * press_scale, press_seconds)


func _on_button_up() -> void:
	# A cancelled drag also restores the button. A valid press replaces this tween.
	if not feedback_locked:
		_refresh_idle()


func _refresh_idle() -> void:
	if feedback_locked or is_pressed():
		return
	var tween := _new_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, settle_seconds)
	var rim := 0.45 if has_focus() else (0.18 if is_hovered() else 0.0)
	tween.tween_property(_surface_material, "shader_parameter/highlight", rim, settle_seconds)


func confirm_feedback() -> Tween:
	_update_pivot()
	_surface_material.set_shader_parameter("highlight", 1.0)
	var tween := _new_tween()
	tween.tween_property(self, "scale", Vector2.ONE * press_scale, press_seconds)
	tween.tween_property(self, "scale", Vector2.ONE * rebound_scale, rebound_seconds)
	tween.tween_property(self, "scale", Vector2.ONE, settle_seconds)
	return tween


func reset_feedback() -> void:
	feedback_locked = false
	_refresh_idle()
