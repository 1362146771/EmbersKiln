extends Node
## Battle-local presentation; never changes damage, costs, or turn timing.
var ui: CombatUI
var blood: ColorRect
var blood_material: ShaderMaterial
var blood_strength := 0.0
var low_health_active := false
var elapsed := 0.0
var fade: Tween
var config: Dictionary


func _ready() -> void:
	ui = get_parent() as CombatUI
	config = GameData.vfx["low_health"]
	var layer := CanvasLayer.new()
	layer.name = "BloodEdgeLayer"
	layer.layer = 90
	add_child(layer)
	blood = ColorRect.new()
	blood.name = "BloodEdge"
	blood.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood_material = ShaderMaterial.new()
	blood_material.shader = preload("res://art/vfx/LowHealth.gdshader")
	blood_material.set_shader_parameter("blood_color", Color(config["color"]))
	blood_material.set_shader_parameter("edge_width", float(config["edge_width"]))
	blood_material.set_shader_parameter("opacity", 0.0)
	blood.material = blood_material
	layer.add_child(blood)
	blood.hide()
	set_process(false)
	ui.controller.attack_feedback.connect(on_attack)
	SignalBus.player_hp_changed.connect(update_health)
	SignalBus.combat_ended.connect(_on_combat_end)
	SignalBus.combat_death_pending.connect(clear)
	update_health(RunState.hp, RunState.max_hp)


func on_attack(paid_energy: int, targets: Array[int]) -> void:
	if ui._player_dead or ui.combat_over:
		return
	var any_target := false
	for index in targets:
		if index < 0 or index >= ui.controller.enemies.size():
			continue
		var panel: Control = ui.unit_panels.get(ui.controller.enemies[index])
		if not is_instance_valid(panel):
			continue
		var portrait := panel.get_node_or_null("Inner/SpriteRect") as Control
		if is_instance_valid(portrait):
			VFXSystem.spawn_attack_impact(portrait)
			any_target = true
	if any_target and paid_energy >= int(GameData.vfx["attack"]["heavy_cost_minimum"]):
		VFXSystem.screen_shake(float(GameData.vfx["attack"]["screen_shake_pixels"]))


func update_health(current: int, maximum: int) -> void:
	var active := not ui.combat_over and current > 0 and maximum > 0 and float(current) / maximum < float(config["threshold_ratio"])
	if active == low_health_active:
		return
	low_health_active = active
	if fade != null and fade.is_valid():
		fade.kill()
	if active:
		elapsed = 0.0
		blood.show()
		set_process(true)
	fade = create_tween()
	fade.tween_property(self, "blood_strength", 1.0 if active else 0.0, float(config["fade_seconds"]))
	if not active:
		fade.tween_callback(_hide_blood)


func _process(delta: float) -> void:
	elapsed += delta
	var breath := (1.0 - cos(elapsed * TAU / float(config["breath_seconds"]))) * 0.5
	var opacity := lerpf(float(config["minimum_opacity"]), float(config["maximum_opacity"]), breath) * blood_strength
	blood_material.set_shader_parameter("opacity", opacity)


func _hide_blood() -> void:
	blood.hide()
	set_process(false)


func clear() -> void:
	low_health_active = false
	blood_strength = 0.0
	if fade != null and fade.is_valid():
		fade.kill()
	_hide_blood()


func _on_combat_end(_victory: bool) -> void:
	clear()


func _exit_tree() -> void:
	VFXSystem.cancel_screen_shake()
