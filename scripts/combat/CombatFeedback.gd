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
var enchant_fx: Node
signal playback_finished
signal hit_presented(targets: Array[int])
var playing_hits := false
var pending_deaths: Array[int] = []
var _playback_token := 0
var _cast_attack_prepared := false


func _ready() -> void:
	ui = get_parent() as CombatUI
	enchant_fx = ui.get_node("EnchantAttackFX")
	enchant_fx.attach(ui)
	BattleDirector.card_cast_started.connect(_on_cast_started)
	BattleDirector.card_cast_finished.connect(_on_cast_finished)
	BattleDirector.card_flight_started.connect(_on_flight_started)
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
	ui.controller._status.status_gained.connect(_on_status_gained)
	SignalBus.player_hp_changed.connect(update_health)
	SignalBus.combat_ended.connect(_on_combat_end)
	SignalBus.combat_death_pending.connect(clear)
	update_health(RunState.hp, RunState.max_hp)


func _on_status_gained(unit: CombatUnit, status_id: StringName) -> void:
	if ui.combat_over or ui._player_dead or not unit.is_alive(): return
	var anchor: Control = ui.player_sprite if unit.is_player else null
	if not unit.is_player:
		var panel: Control = ui.unit_panels.get(unit)
		if not is_instance_valid(panel):
			# Opening phase buffs can arrive before the first panel is built.
			_show_opening_status.call_deferred(unit, status_id)
			return
		anchor = panel.get_node("Inner/SpriteRect")
	var data := GameData.get_status(status_id)
	VFXSystem.spawn_status(anchor, data != null and not data.is_debuff(), status_id)


func _show_opening_status(unit: CombatUnit, status_id: StringName) -> void:
	if ui.unit_panels.has(unit) and unit.get_status(status_id) > 0:
		_on_status_gained(unit, status_id)


func _clear_status_orbits() -> void:
	var portraits: Array[Control] = [ui.player_sprite]
	for panel in ui.unit_panels.values():
		if is_instance_valid(panel): portraits.append(panel.get_node("Inner/SpriteRect"))
	for portrait in portraits:
		if not is_instance_valid(portrait): continue
		for child in portrait.get_children():
			if child.has_meta("status_orbit"):
				child.hide()
				child.queue_free()


func on_attack(paid_energy: int, _targets: Array[int]) -> void:
	# Victory can precede this receipt; let the finishing card play its actual hits.
	if ui._player_dead or not ui.controller.player_alive():
		return
	var groups: Array = []
	var occurrences: Dictionary = {}
	for hit in ui.controller.attack_hits:
		var target: int = hit["target"]
		var group_index: int = int(occurrences.get(target, 0)) if ui.controller.attack_targets_all else groups.size()
		occurrences[target] = group_index + 1
		while groups.size() <= group_index: groups.append([])
		groups[group_index].append(hit.duplicate())
	if groups.is_empty():
		_flush_deaths()
		return
	_playback_token += 1
	var token := _playback_token
	var entry: Dictionary = enchant_fx.source_entry.duplicate(true)
	playing_hits = true
	var windup := _attack_windup()
	var interval := _hit_interval(not entry.is_empty(), groups.size())
	var impact_seconds := interval if groups.size() > 1 else 0.0
	# One swing (and its PlayerSlash) per card; only enemy impacts repeat.
	if _cast_attack_prepared:
		_cast_attack_prepared = false
		ui.player_sprite.strike_cast_attack()
	else:
		# Automatically played attacks have no flying card to synchronize with.
		SignalBus.sound_requested.emit(&"axe_swing")
		ui._set_player_pose(&"attack")
		await get_tree().create_timer(windup, false).timeout
	if token != _playback_token or ui._player_dead: return
	for group_index in groups.size():
		if group_index > 0:
			await get_tree().create_timer(interval, false).timeout
			if token != _playback_token or ui._player_dead: return
			if not entry.is_empty(): enchant_fx.begin(entry, int(groups[group_index][0]["target"]), 0.0)
		var hit_targets: Array[int] = []
		for hit in groups[group_index]:
			hit_targets.append(int(hit["target"]))
			ui._on_damage(true, int(hit["target"]), int(hit["amount"]), true)
		_present_hit(paid_energy, hit_targets, impact_seconds)
		_present_haptic(paid_energy, groups[group_index])
		var sound := AudioManager.enchant_cue(entry)
		var receipt: Dictionary = groups[group_index][0].get("audio", {})
		if sound == &"" or bool(receipt.get("broken", false)) or bool(receipt.get("blocked", false)):
			sound = AudioManager.impact_cue(receipt)
		SignalBus.sound_requested.emit(sound)
		hit_presented.emit(hit_targets)
		# Keep a killed portrait until its actual final hit is shown.
		for target in hit_targets:
			var has_later_hit := false
			for later in groups.slice(group_index + 1):
				for hit in later:
					if int(hit["target"]) == target: has_later_hit = true
			if not has_later_hit and pending_deaths.has(target):
				pending_deaths.erase(target)
				ui._on_unit_died(false, target)
	# Wait once for player recovery, not once per hit; let the final impact finish.
	var recovery := maxf(0.0, _player_attack_duration() - windup - interval * (groups.size() - 1))
	var tail := impact_seconds if groups.size() > 1 else float(enchant_fx.config["impact_seconds"]) if not entry.is_empty() else float(GameData.vfx["attack"]["portrait_shake_duration"])
	await get_tree().create_timer(maxf(recovery, tail), false).timeout
	if token != _playback_token or ui._player_dead: return
	playing_hits = false
	_flush_deaths()
	playback_finished.emit()


func _present_haptic(paid_energy: int, hits: Array) -> void:
	var has_impact := false
	var all_blocked := true
	var broken := false
	for hit in hits:
		if int(hit["amount"]) <= 0: continue
		has_impact = true
		var receipt: Dictionary = hit.get("audio", {})
		all_blocked = all_blocked and bool(receipt.get("blocked", false))
		broken = broken or bool(receipt.get("broken", false))
	if not has_impact: return
	var cue: StringName = &"attack_heavy" if paid_energy >= int(GameData.vfx["attack"]["heavy_cost_minimum"]) else &"attack"
	if all_blocked: cue = &"block"
	if broken: cue = &"block_break"
	SignalBus.haptic_requested.emit(cue)


func _attack_windup() -> float:
	var sprite: AnimatedSprite2D = ui.player_sprite.get_node("BodyAnimation")
	var frames := sprite.sprite_frames
	return (frames.get_frame_duration(&"attack", 0) + frames.get_frame_duration(&"attack", 1)) / frames.get_animation_speed(&"attack") * float(GameData.vfx["attack"]["player_duration_scale"])


func _hit_interval(enchanted: bool, hit_count := 1) -> float:
	var attack: Dictionary = GameData.vfx["attack"]
	if hit_count > 1:
		return maxf(float(attack["combo_min_hit_seconds"]), float(attack["combo_window_seconds"]) / hit_count)
	var duration := maxf(float(attack["slash_duration"]), _player_attack_duration())
	if enchanted: duration = maxf(duration, float(enchant_fx.config["impact_seconds"]))
	return duration


func _player_attack_duration() -> float:
	var sprite: AnimatedSprite2D = ui.player_sprite.get_node("BodyAnimation")
	var frames := sprite.sprite_frames
	var animation_duration := 0.0
	for index in frames.get_frame_count(&"attack"):
		animation_duration += frames.get_frame_duration(&"attack", index) / frames.get_animation_speed(&"attack")
	return animation_duration * float(GameData.vfx["attack"]["player_duration_scale"])


func _flush_deaths() -> void:
	var deaths := pending_deaths.duplicate()
	pending_deaths.clear()
	for index in deaths: ui._on_unit_died(false, index)


func _present_hit(paid_energy: int, targets: Array[int], impact_seconds := 0.0) -> void:
	var any_target := false
	var heavy := paid_energy >= int(GameData.vfx["attack"]["heavy_cost_minimum"])
	var enchant_scale := minf(1.0, impact_seconds / float(enchant_fx.config["impact_seconds"])) if impact_seconds > 0.0 else 1.0
	var enchanted: bool = enchant_fx.impact(targets, heavy, enchant_scale)
	var attack: Dictionary = GameData.vfx["attack"]
	var local_scale := minf(1.0, impact_seconds / maxf(float(attack["slash_duration"]), float(attack["portrait_shake_duration"]))) if impact_seconds > 0.0 else 1.0
	for index in targets:
		if index < 0 or index >= ui.controller.enemies.size():
			continue
		var panel: Control = ui.unit_panels.get(ui.controller.enemies[index])
		if not is_instance_valid(panel):
			continue
		var portrait := panel.get_node_or_null("Inner/SpriteRect") as Control
		if is_instance_valid(portrait):
			portrait.play_hit(impact_seconds, enchant_fx.reduced_motion)
			if not enchanted: VFXSystem.spawn_attack_impact(portrait, true, local_scale)
			any_target = true
	if any_target and not enchanted and heavy:
		VFXSystem.screen_shake(float(GameData.vfx["attack"]["screen_shake_pixels"]))


func _on_cast_started(entry: Dictionary, target_index: int, travel: float, ghost: Control) -> void:
	_cast_attack_prepared = false
	if not ui.combat_over and not ui._player_dead:
		if is_instance_valid(ghost): ghost.set_meta("attack_feedback", weakref(self))
		enchant_fx.begin(entry, target_index, travel, ghost)


func _on_flight_started(entry: Dictionary, travel: float) -> void:
	var card: CardData = GameData.get_card(StringName(entry.get("id", "")))
	if card != null and card.type == &"attack" and not ui._player_dead and not ui.combat_over:
		SignalBus.sound_requested.emit(&"card_attack")
		SignalBus.sound_requested.emit(&"axe_heavy" if card.cost >= int(GameData.vfx.attack.heavy_cost_minimum) else &"axe_swing")
		_cast_attack_prepared = true
		ui.player_sprite.begin_cast_attack(travel)


func _on_cast_finished(ok: bool) -> void:
	if _cast_attack_prepared:
		_cast_attack_prepared = false
		ui.player_sprite.cancel_cast_attack()
	# Attack feedback owns the remaining hits and recovery after impact.
	if ok and playing_hits: return
	enchant_fx.finish_cast(ok)


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
	_clear_status_orbits()
	_cast_attack_prepared = false
	if is_instance_valid(ui.player_sprite): ui.player_sprite.cancel_cast_attack()
	_playback_token += 1
	playing_hits = false
	pending_deaths.clear()
	playback_finished.emit()
	if is_instance_valid(enchant_fx): enchant_fx.clear()
	low_health_active = false
	blood_strength = 0.0
	if fade != null and fade.is_valid():
		fade.kill()
	_hide_blood()


func _on_combat_end(victory: bool) -> void:
	_clear_status_orbits()
	# The existing victory delay lets the final impact finish before scene change.
	if not victory:
		clear()
		return
	low_health_active = false
	blood_strength = 0.0
	if fade != null and fade.is_valid(): fade.kill()
	_hide_blood()


func _exit_tree() -> void:
	HapticFeedback.clear()
	BattleDirector.input_locked = false
	VFXSystem.cancel_screen_shake()
