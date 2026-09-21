extends Node
## Combat-start relic timing and retired-content save migration regression.

var passed := 0
var failed := 0
var controller: CombatController


func _ready() -> void:
	var isolated := OS.get_environment("RELIC_ONCE_TEST_APPDATA").replace("\\", "/")
	if isolated.is_empty() or not OS.get_user_data_dir().begins_with(isolated + "/"):
		push_error("CombatStartRelicVerify requires isolated APPDATA")
		get_tree().quit(2)
		return
	await get_tree().process_frame
	ProfileManager.autosave_enabled = false
	controller = CombatController.new()
	add_child(controller)
	test_retired_content_saves()
	await test_other_start_relics()
	controller.queue_free()
	await get_tree().process_frame
	print("COMBAT_START_RELIC_RESULT:%s %d PASS / %d FAIL" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func test_retired_content_saves() -> void:
	RunState.start_new_run()
	check("retired relic cannot be awarded", not RunState.add_relic(&"kilnmark"))
	check("retired status and effect kinds absent", GameData.get_status(&"command") == null
		and not GameData.effect_kinds.has("summon") and not GameData.effect_kinds.has("power_on_summon_command"))
	check("data validates without retired content", GameData.load_errors.is_empty())
	RunState.add_relic(&"hearth_totem")
	RunState.create_combat_checkpoint([&"kilnstatue"])
	var old_save := RunState.to_save_dict()
	old_save["relic_ids"].append("kilnmark")
	old_save["combat_checkpoint"]["relic_ids"].append("kilnmark")
	var valid_stock := {"id": "hearth_totem", "price": 100, "bought": true}
	old_save["shop_states"] = {"verify": {"relic_stock": [valid_stock, {"id": "kilnmark", "price": 100, "bought": false}], "refresh_count": 1}}
	check("old run still loads", RunState.from_save_dict(old_save))
	check("owned retired relic removed, valid relic retained", not RunState.has_relic(&"kilnmark") and RunState.has_relic(&"hearth_totem"))
	check("checkpoint no longer persists retired relic", not RunState.combat_checkpoint["relic_ids"].has("kilnmark"))
	check("old shop keeps valid stock and refresh count", RunState.shop_states["verify"]["relic_stock"] == [valid_stock] and RunState.shop_states["verify"]["refresh_count"] == 1)
	check("checkpoint restores successfully", RunState.restore_combat_checkpoint())
	check("restore cannot reintroduce retired relic", not RunState.has_relic(&"kilnmark") and RunState.has_relic(&"hearth_totem"))
	var profile := ProfileState.to_save_dict()
	profile["unlocked_relic_ids"] = ["kilnmark", "hearth_totem"]
	check("old permanent profile loads", ProfileState.from_save_dict(profile))
	check("permanent unlocks keep only valid relics", ProfileState.unlocked_relic_ids == [&"hearth_totem"])


func test_other_start_relics() -> void:
	RunState.start_new_run()
	for id in [&"bellows_glove", &"keeper_apron", &"hearth_totem", &"draft_flue"]:
		RunState.add_relic(id)
	controller.start_combat([&"kilnstatue"])
	var base_draw := int(GameData.player_config().draw_per_turn)
	var initial_heat := GameData.get_relic(&"bellows_glove").value
	check("first-turn strength relic", controller.player.get_status(&"heat") == initial_heat)
	check("first-turn block relic survives block reset", controller.player.block == GameData.get_relic(&"hearth_totem").value)
	check("first-turn extra draw", controller.hand.size() == base_draw + GameData.get_relic(&"keeper_apron").value)
	check("first-turn energy relic", controller.energy == controller.max_energy + GameData.get_relic(&"draft_flue").value)
	# Empty the hand into discard so hand limits cannot hide a repeated draw.
	controller.discard_pile.append_array(controller.hand)
	controller.hand.clear()
	await advance_round()
	check("strength relic does not stack next turn", controller.player.get_status(&"heat") == initial_heat)
	check("block relic does not refill next turn", controller.player.block == 0)
	check("draw relic does not add a card next turn", controller.hand.size() == base_draw)
	check("first-turn extra energy does not repeat", controller.energy == controller.max_energy)


func advance_round() -> void:
	# Use an existing passive move so this regression does not depend on
	# uncommitted enemy content, random attacks or unrelated combat balance.
	for move in GameData.get_enemy(&"kilnstatue").moves:
		if move.get("intent", "") == "defend":
			controller.enemies[0].intent = move.duplicate(true)
			break
	controller.end_player_turn()
	var get_panel := func(_unit): return null
	await BattleDirector.run_enemy_turn(controller, null, get_panel)
	check("real phase driver returns to live player turn",
		controller.combat_active() and controller.phase == CombatController.Phase.PLAYER and not BattleDirector.input_locked)


func check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])
