extends Node
var failed := 0
var checks := 0
var cc: CombatController

func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failed += 1
		print("[FAIL] ", title)

func settle() -> void:
	for i in 15: await get_tree().process_frame
	while TransitionManager.is_transitioning: await get_tree().process_frame

func capture(name: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/hidden_" + name + ".png")

func open_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await settle()

func completed_act3(id: String = "extreme") -> void:
	RunState.start_new_run(id)
	RunState.granny_opening = {"resolved":true}
	RunState.pre_run_preparation_resolved = true
	RunState.current_act = GameData.act_configs.size() - 1
	RunState.current_floor = RunState.total_floors() - 1
	RunState.current_node_type = &"boss"
	RunState.current_map().back()[0].visited = true
	RunState.hp = 40
	RunState.revive_used_count = 1
	SaveManager.save_game()

func fresh_boss() -> CombatUnit:
	if is_instance_valid(cc): cc.free()
	RunState.start_new_run("normal")
	cc = CombatController.new()
	add_child(cc)
	cc.start_combat([&"ashen_binder"])
	cc.player.hp = 10000
	cc.player.max_hp = 10000
	cc.hand.clear()
	cc.draw_pile.clear()
	cc.discard_pile.clear()
	cc.energy = 100
	return cc.enemies[0]

func step(enemy: CombatUnit) -> void:
	if cc.enemy_pre(enemy):
		cc._execute_enemy_intent(enemy)
		cc.enemy_post(enemy)

func card(id: String, upgraded: bool = false) -> Dictionary:
	return {"id":StringName(id),"upgraded":upgraded,"upgrade_level":1 if upgraded else 0,"enchants":[],"enchant_active":false}

func play(id: String, upgraded: bool = false) -> bool:
	cc.hand.append(card(id, upgraded))
	return cc.play_card(cc.hand.size() - 1, 0)

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func(): get_tree().quit(2))
	if not GameData.is_loaded:
		print("HIDDEN_ACT_RESULT:FAIL data invalid")
		get_tree().quit(1)
		return
	get_tree().current_scene = null
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/hidden_run.json"
	ProfileState.reset_to_defaults(false)
	ProfileState.difficulty_data = {"cleared":["normal","warm","blazing","molten"]}
	completed_act3()
	var run_id := RunState.run_id
	var expected_reward := RunEndRewardSystem.preview_base_reward(true)
	await open_scene("res://scenes/map/MapPlay.tscn")
	get_tree().current_scene._on_reward_done()
	await settle()
	check(HiddenActFlow.choice_pending() and RunState.is_active, "first highest clear offers hidden act in same run")
	check(ProfileState.difficulty_data.hidden_unlocked and ProfileState.difficulty_data.cleared.has("extreme"), "permanent highest clear and entrance")
	check(not RunState.run_end_base_settled, "no premature payout")
	check(SaveManager.load_game() and HiddenActFlow.choice_pending(), "pending entrance survives reload")
	await open_scene("res://scenes/map/MapPlay.tscn")
	check(get_tree().current_scene.has_node("HiddenActEntrance"), "entrance restored in real map")
	await capture("entrance")
	var previous := RunState.to_save_dict()
	SaveManager.runtime_save_path = "res://missing_hidden_directory/run.json"
	check(not HiddenActFlow.enter() and RunState.to_save_dict() == previous, "failed entry save rolls back without consuming run")
	SaveManager.runtime_save_path = "res://Temp/hidden_run.json"
	get_tree().current_scene.get_node("HiddenActEntrance/%Enter").pressed.emit()
	await settle()
	check(HiddenActFlow.is_hidden() and RunState.current_map().size() == 3, "real enter button opens short fourth map")
	check(RunState.run_id == run_id and RunState.hp == 40 and RunState.revive_used_count == 1, "no new run healing or revive reset")
	check(RunState.current_map()[0][0].type == &"rest" and RunState.current_map()[1][0].enemy_ids == ["kiln_captain"], "camp and captain route")
	check(SaveManager.load_game() and HiddenActFlow.is_hidden() and RunState.total_floors() == 3, "hidden map reload")
	check(FormalUI.boss_map_texture(["ashen_binder"]) != null, "hidden boss has a visible map emblem")
	await capture("map")
	# True rest scene keeps the existing boss relic restriction.
	get_tree().current_scene._on_node_pressed(0, 0)
	await settle()
	check(get_tree().current_scene.scene_file_path == "res://scenes/map/RestUI.tscn", "fourth camp opens rest scene")
	for relic in GameData.relics.values():
		if relic.drawback in [&"no_rest_heal", &"no_rest_upgrade"]: RunState.add_relic(relic.id)
	get_tree().current_scene._build_main()
	check(get_tree().current_scene.get_node("Dim/Center/MainPanel/Content/RestButton").disabled and get_tree().current_scene.get_node("Dim/Center/MainPanel/Content/ForgeButton").disabled, "fourth camp retains both relic restrictions")
	get_tree().current_scene._on_rest(20)
	check(RunState.hp == 40, "restricted rest cannot heal through callback")
	RunState.relic_ids.clear()
	get_tree().current_scene._build_main()
	get_tree().current_scene._on_rest(int(RunState.max_hp * DifficultyRules.rest_percent()))
	await settle()
	check(RunState.hp == 60, "extreme camp uses existing 25 percent")
	var entered := RunState.to_save_dict()
	RunState.end_run(false)
	check(RunState.run_end_base_fireseed == expected_reward and RunState.ordinary_cleared, "hidden defeat preserves ordinary victory reward")
	var balance := ProfileState.fireseed_balance
	check(not RunEndRewardSystem.settle_base_reward(false) and ProfileState.fireseed_balance == balance, "no duplicate payout")
	completed_act3("normal")
	check(HiddenActFlow.record_ordinary_clear() and HiddenActFlow.choice_pending(), "lower difficulty access after permanent unlock")
	await open_scene("res://scenes/map/MapPlay.tscn")
	get_tree().current_scene.get_node("HiddenActEntrance/%Return").pressed.emit()
	await settle()
	check(not RunState.is_active and RunState.victory and RunState.run_end_base_settled, "declining produces normal victory")
	# Previous runs are never extended, even when the profile has unlocked the door.
	completed_act3("normal")
	var old := RunState.to_save_dict()
	old.version = 9
	old.erase("hidden_act_state")
	check(RunState.from_save_dict(old) and HiddenActFlow.record_ordinary_clear() and not HiddenActFlow.choice_pending(), "legacy run remains three acts")
	# Actual fourth boss completion uses final payout, not another reward/energy relic.
	completed_act3()
	HiddenActFlow.record_ordinary_clear()
	HiddenActFlow.enter()
	RunState.current_floor = RunState.total_floors() - 1
	RunState.current_node_type = &"boss"
	RunState.current_map().back()[0].visited = true
	await open_scene("res://scenes/map/MapPlay.tscn")
	get_tree().current_scene._grant_reward()
	await settle()
	check(not RunState.is_active and RunState.hidden_act_state.cleared and ProfileState.difficulty_data.hidden_cleared.has("extreme"), "hidden victory recorded by difficulty")
	check(RunState.pending_reward_data.is_empty() and RunState.run_end_base_settled, "hidden boss does not grant extra boss relic")
	await capture("ending")
	# Remove the live UI before isolated controller checks.
	var scene := get_tree().current_scene
	get_tree().current_scene = null
	scene.queue_free()
	await settle()
	var boss := fresh_boss()
	check(boss.max_hp == 600 and boss.intent.id == "seal" and not boss.ash_sealed, "boss starts with safe preparation")
	var hp := cc.player.hp
	step(boss)
	check(cc.player.hp == hp and boss.block == 18 and boss.ash_sealed and cc._binder.live_ash(boss) == 2, "seal block and finite dazed without attack")
	check(boss.intent.value == 8 and boss.intent.times == 3, "burst preview")
	step(boss)
	check(cc.player.hp == hp - 24 and boss.block == 0 and boss.intent.value == 32, "burst hits three times and shield expires")
	step(boss)
	check(cc.player.hp == hp - 56 and boss.intent.id == "vent", "press follows burst")
	step(boss)
	check(not boss.ash_sealed and boss.get_status(&"heat") == 2 and cc.player.hp == hp - 56, "vent grows without extra attack")
	step(boss)
	check(cc._binder.live_ash(boss) == 4, "second seal reaches ash cap")
	for cycle in 3:
		for action in 4: step(boss)
	check(cc._binder.live_ash(boss) == 4, "ash never exceeds live cap")
	var player_dazed := card("dazed")
	cc.discard_pile.append(player_dazed)
	cc._exhaust_card(cc.discard_pile.pop_front())
	for action in 4: step(boss)
	check(cc._binder.live_ash(boss) == 4 and cc.discard_pile.has(player_dazed), "player-generated dazed is separate and never removed")
	boss = fresh_boss()
	step(boss)
	hp = cc.player.hp
	check(play("defend") and cc.player.hp == hp and cc.player.block == 4, "defend resolves before its backlash")
	cc.player.block = 100
	for i in 10: play("strike")
	check(boss.ash_backlash_used == 6 and cc.player.hp == hp and cc.player.block == 95, "raw backlash caps even when blocked")
	cc._binder.start_turn()
	check(boss.ash_backlash_used == 0, "budget resets each player turn")
	boss.ash_sealed = false
	play("strike")
	check(boss.ash_backlash_used == 0, "vent window permits free plays")
	boss = fresh_boss()
	step(boss)
	cc._apply_status(boss, &"heat", 100)
	cc._apply_status(boss, &"damp", 2)
	cc._apply_status(cc.player, &"crazed", 2)
	cc._temporary_thorns = 50
	var boss_hp := boss.hp
	hp = cc.player.hp
	play("double_tap")
	check(cc.player.hp == hp - 1 and boss.hp == boss_hp, "backlash ignores strength weak vulnerable and does not trigger attack thorns")
	cc._apply_status(cc.player, &"glaze", 2)
	hp = cc.player.hp
	play("double_tap")
	check(cc.player.hp == hp and cc.player.get_status(&"glaze") == 1 and boss.ash_backlash_used == 2, "buffer absorbs backlash and still spends raw budget")
	RunState.difficulty_snapshot = DifficultyRules.tier("extreme").duplicate(true)
	check(cc._intent.scale_intent_damage(boss.data.find_move(&"press"), &"boss", true).value == 34 and cc._intent.scale_intent_damage(boss.data.find_move(&"ash_burst"), &"boss", true).value == 8, "extreme only increases single hit press")
	boss = fresh_boss()
	step(boss)
	cc.powers[CombatController.POWER_ON_EXHAUST_BLOCK] = 5
	cc.hand = [card("defend")]
	hp = cc.player.hp
	check(play("burning_pact") and not cc.pending_card_choice.is_empty() and cc.player.hp == hp, "choice waits before backlash")
	cc.resolve_card_choice(0)
	check(cc.player.hp == hp and cc.player.block == 4 and boss.ash_backlash_used == 1, "choice exhaust block before backlash")
	boss = fresh_boss()
	step(boss)
	cc.powers[CombatController.POWER_ON_EXHAUST_BLOCK] = 5
	cc.draw_pile = [card("strike")]
	hp = cc.player.hp
	check(play("havoc") and boss.ash_backlash_used == 2 and cc.player.hp == hp and cc.player.block == 3, "automatic card finishes forced exhaust before backlash; parent counts once")
	boss = fresh_boss()
	step(boss)
	cc._double_tap_charges = 1
	play("strike")
	check(boss.ash_backlash_used == 1, "repeat effects only one backlash")
	boss = fresh_boss()
	step(boss)
	boss.block = 0
	boss.hp = 1
	cc.player.hp = 1
	play("strike")
	check(cc.player.hp == 1 and not boss.is_alive(), "killing card cancels backlash")
	boss = fresh_boss()
	step(boss)
	cc.player.hp = 1
	cc.draw_pile = [card("strike")]
	RunState.revive_used_count = 1
	play("havoc")
	check(not cc.player.is_alive() and cc.phase == CombatController.Phase.ENDED, "nested backlash stops combat on death")
	var energy := cc.energy
	check(not play("defend") and cc.energy == energy, "queued card cannot spend after death")
	cc.free()
	cc = null
	# Real battle rendering, checkpoint reload and explicit status budget.
	RunState.from_save_dict(entered)
	RunState.current_floor = RunState.total_floors() - 1
	RunState.current_node_type = &"boss"
	RunState.create_combat_checkpoint(["ashen_binder"])
	await open_scene("res://scenes/combat/CombatPlay.tscn")
	var ui: CombatUI = get_tree().current_scene
	ui.controller.player.hp = 80
	ui.controller._execute_enemy_intent(ui.controller.enemies[0])
	ui.controller.enemy_post(ui.controller.enemies[0])
	await settle()
	await capture("boss")
	check(ui.controller.enemies[0].ash_sealed, "real battle uses seal mechanism")
	check(SaveManager.save_game() and SaveManager.load_game() and RunState.restore_combat_checkpoint(), "fourth battle checkpoint restores")
	await open_scene("res://scenes/combat/CombatPlay.tscn")
	ui = get_tree().current_scene
	check(not ui.controller.enemies[0].ash_sealed and ui.controller.enemies[0].ash_backlash_used == 0 and ui.controller.enemies[0].intent.id == "seal", "checkpoint restarts full battle with no leaked backlash debt")
	ui.controller.enemies[0].hp = 1
	ui.controller.enemies[0].block = 0
	ui.controller.hand = [card("strike")]
	ui.controller.play_card(0, 0)
	await settle()
	# Combat victory presentation runs on its existing timer before returning to MapUI.
	for i in 600:
		if not RunState.is_active: break
		await get_tree().process_frame
	check(not RunState.is_active and RunState.hidden_act_state.get("cleared", false), "real combat kill returns through map to hidden ending")
	print("HIDDEN_ACT_RESULT:%s checks=%d failed=%d" % ["PASS" if failed == 0 else "FAIL", checks, failed])
	get_tree().quit(0 if failed == 0 else 1)
