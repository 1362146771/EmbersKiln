extends Node
## A3N: actual combat, turn windows, map isolation, and production UI.
var passed := 0
var failed := 0
var cc: CombatController

func check(label: String, ok: bool) -> void:
	if ok: passed += 1
	else: failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func fresh(id: StringName) -> CombatUnit:
	if cc != null: cc.free()
	RunState.start_new_run()
	RunState.current_act = 2
	RunState.relic_ids.clear()
	cc = CombatController.new()
	add_child(cc)
	cc.start_combat([id])
	cc.player.max_hp = 10000
	cc.player.hp = 10000
	return cc.enemies[0]

func step(e: CombatUnit) -> void:
	if cc.enemy_pre(e):
		cc._execute_enemy_intent(e)
		cc.enemy_post(e)

func wounds() -> int:
	return cc.discard_pile.filter(func(c): return String(c.id) == "wound").size()

func _ready() -> void:
	if OS.get_environment("ESCORT_TEST_APPDATA").is_empty():
		get_tree().quit(2)
		return
	await get_tree().process_frame
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/act3normal-save.json"
	check("data validation", GameData.load_errors.is_empty())
	_test_cycles()
	_test_maps()
	await _test_director_and_ui()
	if cc != null: cc.free()
	print("ACT3_NORMAL_RESULT:%s %d PASS / %d FAIL" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _test_cycles() -> void:
	var e := fresh(&"coalseer_act3")
	check("seer effective HP 120 and opening 18", e.hp == 120 and e.intent.value == 18)
	var deck := RunState.deck.duplicate(true)
	step(e)
	var hp := cc.player.hp
	var before := wounds()
	check("seer telegraphs non-attack debuff", e.intent.intent == "debuff")
	step(e)
	check("seer debuff spends action without attack", cc.player.hp == hp and cc.player.get_status(&"damp") == 2)
	check("exactly one temporary wound", wounds() == before + 1 and RunState.deck == deck)
	check("seer telegraphs 30 without another empty charge turn", e.intent.id == "doom" and e.intent.value == 30)
	step(e)
	check("seer heavy attack and cycle", cc.player.hp == hp - 30 and e.intent.id == "strike")
	e = fresh(&"kilnstatue_act3")
	check("statue effective HP 150 opening 18", e.hp == 150 and e.intent.value == 18)
	step(e)
	hp = cc.player.hp
	step(e)
	check("fortify no attack, 16 block and 3 strength", cc.player.hp == hp and e.block == 16 and e.get_status(&"heat") == 3)
	check("slam preview includes earned strength", e.intent.value == 26 and cc.enemy_preview_outgoing(e, 26) == 29)
	step(e)
	check("slam deals 29 and old block expires", cc.player.hp == hp - 29 and e.block == 0)
	step(e)
	step(e)
	check("strength only grows on fortify", e.get_status(&"heat") == 6)
	for id in [&"cinderfiend_act3", &"magmawhelp_act3", &"glazetick_act3"]:
		e = fresh(id)
		check("group HP " + String(id), e.max_hp == (47 if id == &"glazetick_act3" else 65))
		check("group cannot spawn solo " + String(id), e.data.encounter_weight(1) == 0)
		var attacks: Array = []
		for move in e.data.moves:
			if move.intent == "attack":
				var scaled := cc._intent.scale_intent_damage(move, e.data.tier, e.data.effective_stats)
				attacks.append(int(scaled.value))
		var expected: Array = [15,18] if id == &"cinderfiend_act3" else ([13,16] if id == &"magmawhelp_act3" else [10,14])
		check("group attacks use effective values " + String(id), attacks == expected)
	check("original shared monsters unchanged", GameData.get_enemy(&"kilnstatue").base_hp == 52 and GameData.get_enemy(&"glazetick").base_hp == 36)
	e = fresh(&"coalseer")
	check("legacy map ID remains loadable at original HP", e.max_hp == 65 and e.data.ai == &"weighted_random")

func _test_maps() -> void:
	var config: Dictionary = GameData.act_configs[2]
	var pool := MapGenerator._pool_enemies(config, &"normal")
	var rules: Dictionary = GameData.encounter_generation
	for key in ["1", "2", "3"]:
		check("unchanged count weight " + key, int(rules.before_triple_unlock[key]) == {"1":70,"2":30,"3":0}[key] and int(rules.after_triple_unlock[key]) == {"1":65,"2":25,"3":10}[key])
	check("unchanged capacity scaling", rules.third_act_deck_capacity_scaling.max_multi_weight_bonus == 0.20)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/testing/act3_normal_balance.json"))
	for count in [1,2,3]:
		for trial in int(fixture.sim.attempts_per_match):
			seed(int(fixture.sim.seed_base) + trial)
			var ids := MapGenerator._pick_weighted_enemies(pool, count)
			check("exact encounter size %d seed %d" % [count,trial], ids.size() == count)
			if count == 1:
				check("solo is a dedicated strong monster", ids[0] in [&"coalseer_act3", &"kilnstatue_act3"])
			else:
				check("group excludes upgraded solo monsters", not &"coalseer_act3" in ids and not &"kilnstatue_act3" in ids)
				check("group has a main damage dealer", &"cinderfiend_act3" in ids or &"magmawhelp_act3" in ids)
				check("only one support tick", ids.count(&"glazetick_act3") <= 1)
	for act in [0,1]:
		check("earlier act pool unchanged " + str(act), not GameData.act_configs[act].enemy_pool.normal.any(func(id): return String(id).ends_with("_act3")))
	check("boss and elite pools unchanged", config.boss_id == "chi_the_first" and config.enemy_pool.elite == ["ember_eater","glazemaw","escort_deployer","escort_overseer"])

func _test_director_and_ui() -> void:
	for id in [&"coalseer_act3", &"kilnstatue_act3"]:
		var e := fresh(id)
		step(e)
		var hp := cc.player.hp
		cc.end_player_turn()
		await BattleDirector.run_enemy_turn(cc, null, func(_e): return null)
		check("director preparation never attacks " + String(id), cc.player.hp == hp)
		check("director applied preparation effects " + String(id), e.get_status(&"heat") == 3 if id == &"kilnstatue_act3" else cc.player.get_status(&"damp") == 2)
	if cc != null:
		cc.free()
		cc = null
	for ids in [[&"coalseer_act3"], [&"kilnstatue_act3"], [&"cinderfiend_act3",&"magmawhelp_act3",&"glazetick_act3"]]:
		RunState.start_new_run()
		RunState.current_act = 2
		var ui := load("res://scenes/combat/CombatPlay.tscn").instantiate() as CombatUI
		ui.pending_enemy_ids.assign(ids)
		add_child(ui)
		await get_tree().process_frame
		await get_tree().process_frame
		if ids.size() == 1:
			ui.controller._roll_enemy_intent(ui.controller.enemies[0])
		else:
			for enemy in ui.controller.enemies:
				for move in enemy.data.moves:
					if move.intent == "charge":
						enemy.intent = move.duplicate(true)
		ui._refresh_all()
		await get_tree().process_frame
		for enemy in ui.controller.enemies:
			var panel: EnemyPanel = ui.unit_panels[enemy]
			check("shared portrait loads " + String(enemy.id), panel.get_node("Inner/SpriteRect").texture != null)
			var bar := panel.get_node("Inner/IntentBar")
			if enemy.intent.intent == "charge":
				var future: Dictionary = enemy.data.find_move(StringName(enemy.intent.next))
				var shown: Array = bar.get_children().filter(func(b): return b.get_meta("intent_kind") == "attack")
				check("charge preview does not scale effective damage twice " + String(enemy.id), shown.size() == 1 and shown[0].get_node("Value").text == str(int(future.value)))
			if ids[0] == &"kilnstatue_act3":
				check("fortify strength uses buff icon", bar.get_children().any(func(b): return b.get_meta("intent_kind") == "buff") and not bar.get_children().any(func(b): return b.get_meta("intent_kind") == "debuff"))
		if OS.get_cmdline_user_args().has("--visual"):
			await RenderingServer.frame_post_draw
			check("screenshot " + String(ids[0]), get_viewport().get_texture().get_image().save_png("res://Temp/act3-normal-%s.png" % ids[0]) == OK)
		ui.queue_free()
		await get_tree().process_frame
