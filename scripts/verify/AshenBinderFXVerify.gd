extends Node
var ui: CombatUI
var fx: CanvasLayer
var checks := 0
var failures := 0
var started: Array[String] = []
var impacts: Array[String] = []
var visual := false
var recording := false
var record_age := 0.0
var frame := 0
var captured: Dictionary = {}

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("[FAIL] ", description)

func _process(delta: float) -> void:
	if not recording or not visual: return
	record_age += delta
	if record_age < 0.09: return
	record_age = 0.0
	get_viewport().get_texture().get_image().save_png("res://Temp/ashen_frames/%04d.png" % frame)
	frame += 1

func capture_started(kind: String) -> void:
	started.append(kind)
	if not visual or captured.has(kind): return
	captured[kind] = true
	_capture_after(kind, 0.23 if kind != "backlash" else 0.06)
	if kind in ["ash_burst", "press", "vent"]:
		_capture_after(kind + "_early", 0.13)
		_capture_after(kind + "_late", 0.29)

func _capture_after(name: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/ashen_%s.png" % name)

func action() -> void:
	ui.controller.phase = CombatController.Phase.ENEMY
	await BattleDirector.run_enemy_turn(ui.controller, ui.player_panel, func(e): return ui.unit_panels.get(e))
	check(not BattleDirector.input_locked and ui.controller.phase == CombatController.Phase.PLAYER, "action returns control")

func capture_impact(kind: String) -> void:
	impacts.append(kind)
	if not visual or captured.has(kind + "_impact"): return
	captured[kind + "_impact"] = true
	_capture_after(kind + "_settle", 0.08)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/ashen_%s_impact.png" % kind)

func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func(): get_tree().quit(2))
	visual = "--visual" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://Temp/ashen_frames")
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/ashen_fx_run.json"
	RunState.start_new_run()
	RunState.current_act = GameData.act_configs.size() - 1
	RunState.relic_ids.clear()
	RunState.pending_combat_enemy_ids = [&"ashen_binder"]
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	fx = ui.get_node("AshenBinderFX")
	fx.effect_started.connect(capture_started)
	fx.effect_impacted.connect(capture_impact)
	var enemy := ui.controller.enemies[0]
	var hp := ui.controller.player.hp
	check(fx.canvas.mouse_filter == Control.MOUSE_FILTER_IGNORE, "visual cannot intercept touch")
	recording = true
	await action()
	check(enemy.block == 18 and enemy.ash_sealed and ui.controller.player.hp == hp, "seal has only existing rule effects")
	await action()
	check(started.count("ash_burst") == 3 and impacts.count("ash_burst") == 3, "one plume and impact per real hit")
	check(ui.controller.player.hp == hp - 24, "burst damage unchanged")
	await action()
	check(impacts.count("press") == 1 and ui.controller.player.hp == hp - 56, "heavy wave hits once for original damage")
	await action()
	check(not enemy.ash_sealed and enemy.get_status(&"heat") == 2 and ui.controller.player.hp == hp - 56, "vent remains non attacking")
	await get_tree().create_timer(0.6).timeout
	check(fx.effects.is_empty(), "effects clean up their tails")
	await action()
	ui.controller.hand = [{"id":&"defend"}]
	ui.controller.energy = 10
	hp = ui.controller.player.hp
	ui.controller.play_card(0, -1)
	check(impacts.count("backlash") == 1 and ui.controller.player.hp == hp and ui.controller.player.block == 4, "shield absorbs backlash before visual receipt")
	for i in 8:
		ui.controller.hand.append({"id":&"defend"})
		ui.controller.play_card(ui.controller.hand.size() - 1, -1)
	check(impacts.count("backlash") == 6, "no false lash after raw cap")
	check(fx.effects.filter(func(item): return item.kind == "backlash").size() == 1, "dense cards merge visual only")
	await get_tree().create_timer(0.5).timeout
	# A real unblocked receipt must use the damage presentation, not a shield mark.
	await action()
	ui.controller.player.hp = hp
	ui.controller.player.block = 0
	ui.controller.energy = 10
	ui.controller.hand = [{"id":&"strike"}]
	var previous_lashes := impacts.count("backlash")
	ui.controller.play_card(0, 0)
	check(impacts.count("backlash") == previous_lashes + 1 and ui.controller.player.hp == hp - 1, "unblocked backlash follows real damage")
	check(not fx.effects.back().absorbed, "unblocked backlash has no shield visual")
	if visual:
		await get_tree().create_timer(0.06).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/ashen_backlash_unblocked.png")
	await get_tree().create_timer(0.3).timeout
	recording = false
	# Reduced motion uses local marks, no travelling stroke, same impact callbacks.
	fx.reduced_motion = true
	ui.controller.player.hp = 80
	ui.controller.player.block = 0
	enemy.statuses.clear()
	enemy.intent = enemy.data.find_move(&"press").duplicate(true)
	var previous := impacts.count("press")
	await action()
	check(impacts.count("press") == previous + 1 and ui.controller.player.hp == 48, "reduced motion preserves real damage")
	fx._on_start(enemy, 1.0)
	await get_tree().process_frame
	get_tree().paused = true
	var age: float = fx.effects.back().age
	await get_tree().create_timer(0.15, true).timeout
	check(fx.effects.back().age == age, "pause freezes effect age")
	get_tree().paused = false
	fx.clear()
	# A non-boss never receives this boss's effect.
	var other := CombatUnit.new()
	other.setup(false, &"claylump", "测试", 20)
	var count := started.size()
	fx._on_start(other, 0.34)
	check(started.size() == count and fx.effects.is_empty(), "ordinary enemies keep existing visuals")
	other = null
	fx._on_start(enemy, 0.34)
	SignalBus.combat_ended.emit(true)
	check(fx.effects.is_empty() and not fx.is_processing(), "combat end clears all effects")
	ui.queue_free()
	await get_tree().process_frame
	check(BattleDirector.enemy_visual_started.get_connections().is_empty(), "scene exit disconnects global visual listeners")
	print("ASHEN_FX_RESULT:%s checks=%d failed=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
