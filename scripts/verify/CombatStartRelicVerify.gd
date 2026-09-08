extends Node
## Regression for combat_start hooks. Uses real summon/enemy phase drivers,
## data-defined relic/minion values and isolated saves. No UI is required.

var passed := 0
var failed := 0
var controller: CombatController
var hound_data: MinionData
var summon_count := 0


func _ready() -> void:
	var isolated := OS.get_environment("RELIC_ONCE_TEST_APPDATA").replace("\\", "/")
	if isolated.is_empty() or not OS.get_user_data_dir().begins_with(isolated + "/"):
		push_error("CombatStartRelicVerify requires isolated APPDATA")
		get_tree().quit(2)
		return
	await get_tree().process_frame
	RunState.start_new_run()
	RunState.add_relic(&"kilnmark")
	hound_data = GameData.get_minion(&"emberhound")
	summon_count = GameData.get_relic(&"kilnmark").value
	controller = CombatController.new()
	add_child(controller)
	controller.start_combat([&"kilnstatue"])
	check("first turn summons configured hound count", controller.allies.size() == summon_count)
	var original_hounds := controller.allies.duplicate()
	for round_index in range(hound_data.lifetime + 1):
		await advance_round()
		var remaining := maxi(0, hound_data.lifetime - round_index - 1)
		check("round %d: no replacement hounds" % controller.turn,
			controller.allies.size() == (summon_count if remaining > 0 else 0))
		for ally in controller.allies:
			check("survivor is original hound with decreasing lifetime",
				original_hounds.has(ally) and ally.lifetime == remaining)
	check("expiry does not refresh combat-start summon", controller.allies.is_empty())

	# Reuse the same controller in a new battle; the existing turn reset must
	# naturally make combat-start effects eligible again (no run-global latch).
	controller.start_combat([&"kilnstatue"])
	check("next combat summons again", controller.turn == 1 and controller.allies.size() == summon_count)
	for ally in controller.allies.duplicate():
		check("next combat gets a fresh hound", not original_hounds.has(ally) and ally.lifetime == hound_data.lifetime)
		controller._intent.deal_to_ally(ally, ally.hp + ally.block)
	check("dead hounds removed", controller.allies.is_empty())
	await advance_round()
	check("death does not cause next-turn replacement", controller.allies.is_empty())

	# Load a save retaining the owned relic, then start a new battle.
	var owned_save := RunState.to_save_dict()
	RunState.start_new_run()
	check("saved relic still loads", RunState.from_save_dict(owned_save) and RunState.has_relic(&"kilnmark"))
	controller.start_combat([&"kilnstatue"])
	check("loaded run gets combat-start summon", controller.allies.size() == summon_count)
	await advance_round()
	check("loaded run does not summon every turn", controller.allies.size() == summon_count)

	RunState.start_new_run()
	controller.start_combat([&"kilnstatue"])
	check("no relic means no free hound", controller.allies.is_empty())
	await advance_round()
	check("no relic stays empty next turn", controller.allies.is_empty())
	await test_other_start_relics()
	controller.queue_free()
	await get_tree().process_frame
	print("COMBAT_START_RELIC_RESULT:%s %d PASS / %d FAIL" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


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
	await BattleDirector.run_summon_turn(controller, null, get_panel, get_panel)
	await BattleDirector.run_enemy_turn(controller, null, get_panel)
	check("real phase driver returns to live player turn",
		controller.combat_active() and controller.phase == CombatController.Phase.PLAYER and not BattleDirector.input_locked)


func check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])
