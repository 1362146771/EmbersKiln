extends Control
## Presentation only; all materials and emitters remain authored in the scene.

@export_range(1.0, 120.0) var cycle_seconds := 24.0
@export var background_path: NodePath = ^"../Background"

var elapsed := 0.0
@onready var _background: TextureRect = get_node(background_path)
@onready var _material: ShaderMaterial = _background.material
@onready var _embers: GPUParticles2D = $Embers
@onready var _ash: GPUParticles2D = $Ash


func _ready() -> void:
	_material.set_shader_parameter("use_runtime_clock", true)
	resized.connect(_fit_emitters)
	visibility_changed.connect(_sync_visibility)
	_fit_emitters()
	_sync_visibility()


func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, cycle_seconds)
	_material.set_shader_parameter("cycle_phase", elapsed / cycle_seconds)


func _fit_emitters() -> void:
	# Existing portrait canvas is maintained by Godot's stretch mode. Only resize
	# emission bounds here; no per-frame particle/material allocations.
	for emitter in [_embers, _ash]:
		emitter.position = size * 0.5
		var particle_material := emitter.process_material as ParticleProcessMaterial
		particle_material.emission_box_extents = Vector3(size.x * 0.55, size.y * 0.55, 0.0)
		emitter.visibility_rect = Rect2(-size * 0.75, size * 1.5)


func _sync_visibility() -> void:
	var active := is_visible_in_tree()
	set_process(active)
	_embers.emitting = active
	_ash.emitting = active
