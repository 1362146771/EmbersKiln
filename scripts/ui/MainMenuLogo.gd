@tool
extends TextureRect
## Eight-second closed fire cycle. Glyph geometry/alpha and menu layout stay fixed.

@export var cycle_seconds := 8.0
@export var flame_padding := Vector2(16.0, 40.0)
var elapsed := 0.0
@onready var flames: TextureRect = $Flames
@onready var _heat: ShaderMaterial = material
@onready var _fire: ShaderMaterial = flames.material


func _ready() -> void:
	var runtime := not Engine.is_editor_hint()
	_heat.set_shader_parameter("use_runtime_clock", runtime)
	_fire.set_shader_parameter("use_runtime_clock", runtime)
	resized.connect(_fit_flames)
	visibility_changed.connect(_sync_visibility)
	_fit_flames()
	_sync_visibility()


func _fit_flames() -> void:
	if texture == null or not is_instance_valid(flames):
		return
	var source_size := texture.get_size()
	var factor := minf(size.x / source_size.x, size.y / source_size.y)
	var drawn := source_size * factor
	flames.position = (size - drawn) * 0.5 - flame_padding
	flames.size = drawn + flame_padding * 2.0
	_fire.set_shader_parameter("logo_size", drawn)
	_fire.set_shader_parameter("padding", flame_padding)


func set_cycle_phase(phase: float) -> void:
	_heat.set_shader_parameter("cycle_phase", phase)
	_fire.set_shader_parameter("cycle_phase", phase)


func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, cycle_seconds)
	set_cycle_phase(elapsed / cycle_seconds)


func _sync_visibility() -> void:
	set_process(not Engine.is_editor_hint() and is_visible_in_tree())
