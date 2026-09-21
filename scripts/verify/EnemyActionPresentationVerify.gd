extends Node

var failures := 0
var checks := 0
var retired_visuals := 0
var player_hits := 0
var status_events: Array = []
var hit_times: Array[int] = []
var ui: CombatUI
var captured := false
var visual := false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func on_node_added(node: Node) -> void:
	if node is TextureRect and node.texture != null and node.texture.resource_path in ["res://art/vfx/ART_CAST_BURST.png", "res://art/vfx/ART_STRIKE_CARD.png"]:
		retired_visuals += 1

func on_damage(to_enemy: bool, _index: int, _amount: int) -> void:
	if to_enemy: return
	player_hits += 1
	hit_times.append(Time.get_ticks_msec())
	if visual and not captured:
		captured = true
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/enemy_action_without_card.png")

func run_case(intent: Dictionary) -> void:
	var enemy: CombatUnit = ui.controller.enemies[0]
	enemy.statuses.clear()
	enemy.intent = intent.duplicate(true)
	enemy.charge_next = &""
	enemy.block = 0
	enemy.hp = enemy.max_hp
	ui.controller.player.statuses.clear()
	ui.controller.player.block = 0
	ui.controller.player.hp = ui.controller.player.max_hp
	RunState.hp = ui.controller.player.hp
	ui.controller.phase = CombatController.Phase.ENEMY
	player_hits = 0
	status_events.clear()
	hit_times.clear()
	var start_hp := ui.controller.player.hp
	var turn := ui.controller.turn
	await BattleDirector.run_enemy_turn(ui.controller, ui.player_panel, func(e): return ui.unit_panels.get(e))
	check(not BattleDirector.input_locked and ui.controller.phase == CombatController.Phase.PLAYER and ui.controller.turn == turn + 1, "turn completes once: " + String(intent.intent))
	check(retired_visuals == 0, "no burst rectangle or flying enemy card: " + String(intent.intent))
	match String(intent.intent):
		"attack":
			check(player_hits == int(intent.times) and start_hp - ui.controller.player.hp == int(intent.value) * int(intent.times), "multihit applies exactly once per strike")
			check(hit_times.size() == 3 and hit_times[1] > hit_times[0] and hit_times[2] > hit_times[1], "multihit feedback remains separated in time")
		"aoe_debuff":
			check(player_hits == 1 and start_hp - ui.controller.player.hp == int(intent.value), "area attack damage is retained")
			check(status_events.has([true, &"crazed", 2]), "area attack also applies its debuff")
		"defend", "charge":
			check(enemy.block == int(intent.value) and player_hits == 0, "defense or charge grants original block without damage")
		"buff":
			check(enemy.get_status(&"heat") == int(intent.value) and player_hits == 0, "enemy buff retained")
		"debuff":
			check(status_events.has([true, &"crazed", 2]) and player_hits == 0, "non-damaging debuff retained")

func _ready() -> void:
	if OS.get_environment("UPGRADE_VERIFY_ROOT").is_empty():
		get_tree().quit(2)
		return
	get_tree().create_timer(45).timeout.connect(func(): get_tree().quit(2))
	visual = OS.get_cmdline_user_args().has("--visual")
	get_tree().node_added.connect(on_node_added)
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/enemy_presentation_save.json"
	RunState.start_new_run()
	RunState.relic_ids.clear()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_combat_enemy_ids = [&"claylump"]
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	SignalBus.damage_dealt.connect(on_damage)
	SignalBus.status_applied.connect(func(is_player, _index, id, stacks): status_events.append([is_player, id, stacks]))
	for intent in [
		{"intent":"attack", "value":3, "times":3},
		{"intent":"aoe_debuff", "value":4, "status":"crazed", "status_value":2},
		{"intent":"defend", "value":7},
		{"intent":"buff", "value":2, "status":"heat"},
		{"intent":"debuff", "value":2, "status":"crazed"},
		{"intent":"charge", "value":8},
	]:
		await run_case(intent)
	check(not VFXSystem.has_method("spawn_cast_burst") and not VFXSystem.has_method("spawn_strike_card"), "retired visuals cannot be spawned by another action")
	print("ENEMY_PRESENTATION_RESULT:", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
