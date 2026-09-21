extends Node
## Isolated regression: profile transactions, run snapshots, battle qualification and all 54 directions.
var passed := 0
var failed := 0
var controller: CombatController

func check(label: String, value: bool) -> void:
	if value: passed += 1
	else:
		failed += 1
		printerr("MUTATION_FAIL: " + label)

func _ready() -> void:
	var isolated := OS.get_environment("MUTATION_TEST_APPDATA").replace("\\", "/")
	if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "user://mutation_run.json"
	CardMutation.storage_path = "user://mutation_profile.json"
	controller = CombatController.new()
	add_child(controller)
	check("data validation", GameData.load_errors.is_empty())
	test_transactions()
	test_run_snapshot()
	test_all_directions()
	test_combat_edges()
	await test_ui()
	controller.queue_free()
	await get_tree().process_frame
	print("CARD_MUTATION_RESULT: %d PASS / %d FAIL" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func unlock() -> void:
	ProfileState.reset_to_defaults(false)
	ProfileState.completed_project_ids.append(&"apothecary_research_1")
	for cid in CardMutation.config().card_directions:
		ProfileState.unlocked_card_ids.append(StringName(cid))
		ProfileState.discovered_card_ids.append(StringName(cid))
	ProfileState.fireseed_balance = 10000

func test_transactions() -> void:
	ProfileState.reset_to_defaults(false)
	check("locked research rejects", CardMutation.begin("bludgeon", 0) != "")
	unlock()
	var old := ProfileState.to_save_dict()
	CardMutation.storage_path = "res://logs/no_such_directory/profile.json"
	check("write failure reports error", CardMutation.begin("bludgeon", 0) != "")
	check("write failure leaves wallet and patterns intact", ProfileState.to_save_dict() == old)
	CardMutation.storage_path = "user://mutation_profile.json"
	check("first enchant", CardMutation.begin("bludgeon", 0) == "")
	check("first price", ProfileState.fireseed_balance == 9940)
	var eid := CardMutation.pattern("bludgeon")
	check("first valid direction", CardMutation.directions("bludgeon").has(eid))
	check("duplicate click blocked", CardMutation.begin("bludgeon", 1) != "" and ProfileState.fireseed_balance == 9940)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CardMutation.storage_path))
	check("receipt and RNG serialized", saved.mutation_data.pending.new_id == eid and saved.mutation_data.rng_state is String)
	check("restart restores pending", ProfileState.from_save_dict(saved, false) and CardMutation.pending().new_id == eid)
	check("first acknowledgement", CardMutation.resolve(true, 1) == "")
	for index in 8:
		var balance := ProfileState.fireseed_balance
		var revision := CardMutation.revision()
		var current := CardMutation.pattern("bludgeon")
		check("reroll begins", CardMutation.begin("bludgeon", revision) == "")
		check("reroll excludes current and charges once", CardMutation.pending().new_id != current and ProfileState.fireseed_balance == balance - 30)
		var candidate := String(CardMutation.pending().new_id)
		check("reroll resolves", CardMutation.resolve(index % 2 == 0, revision + 1) == "")
		check("keep/accept exact result", CardMutation.pattern("bludgeon") == (candidate if index % 2 == 0 else current))
	var legacy := ProfileState.to_save_dict()
	legacy.version = 6
	legacy.erase("mutation_data")
	check("legacy profile empty patterns", ProfileState.from_save_dict(legacy, false) and ProfileState.mutation_data.is_empty())

func test_run_snapshot() -> void:
	unlock()
	ProfileState.mutation_data = {"patterns":{"bludgeon":"town_bludgeon_1"}}
	RunState.start_new_run()
	RunState.base_run_deck_capacity = -1
	ProfileState.mutation_data.patterns.bludgeon = "town_bludgeon_2"
	RunState.deck.clear()
	for index in 4: RunState.add_card(&"bludgeon")
	check("run snapshot frozen on acquisition", RunState.deck[0].enchants == ["town_bludgeon_1"])
	check("three active copies, fourth waiting", RunState.selected_enchant_instance_ids.size() == 3 and not CardMutation.is_active(RunState.deck[3]))
	check("distinct instances", RunState.deck[0].instance_id != RunState.deck[1].instance_id)
	check("full rejects fourth", not RunState.set_enchant_selected(RunState.deck[3].instance_id, true))
	RunState.set_enchant_selected(RunState.deck[0].instance_id, false)
	check("swap selected", RunState.set_enchant_selected(RunState.deck[3].instance_id, true))
	var ids := RunState.selected_enchant_instance_ids.duplicate()
	RunState.create_combat_checkpoint([&"kilnstatue"])
	check("checkpoint locks editing", not RunState.set_enchant_selected(ids[0], false))
	var saved := RunState.to_save_dict()
	RunState.from_save_dict(JSON.parse_string(JSON.stringify(saved)))
	check("save roundtrip snapshot and instances", RunState.selected_enchant_instance_ids == ids and RunState.deck[3].enchants == ["town_bludgeon_1"])
	RunState.restore_combat_checkpoint()
	check("revive restores loadout", RunState.selected_enchant_instance_ids == ids)
	var ordinary := RewardBuilder.roll_enchant_for_card(GameData.get_card(&"bludgeon"))
	check("run pools exclude town directions", GameData.get_enchant(ordinary).acquisition_scope == "run")
	check("run service may replace town", RunState.add_enchant_to_card_at(3, ordinary) and RunState.deck[3].enchants == [ordinary])
	check("replacement keeps selected instance", RunState.selected_enchant_instance_ids == ids)
	check("replacement leaves permanent pattern", CardMutation.pattern("bludgeon") == "town_bludgeon_2")
	check("ordinary cannot reroll ordinary", not RunState.add_enchant_to_card_at(3, ordinary))
	saved = RunState.to_save_dict()
	saved.version = 6
	for key in ["mutation_patterns_snapshot", "selected_enchant_instance_ids", "next_card_serial"]: saved.erase(key)
	saved.combat_checkpoint = {}
	RunState.from_save_dict(saved)
	check("old active run never receives profile patterns", RunState.mutation_patterns_snapshot.is_empty())
	check("old run migrates three active existing enchants", RunState.selected_enchant_instance_ids.size() == 3)
	ProfileState.mutation_data = {"patterns":{"bludgeon":"town_bludgeon_2"}}
	RunState.start_new_run()
	RunState.base_run_deck_capacity = -1
	var preview := CardMutation.preview({"id":"bludgeon","enchants":[]})
	check("reward preview inherits run snapshot", preview.enchants == ["town_bludgeon_2"] and preview.enchant_preview)
	check("real acquisition service inherits same preview", CardAcquireService.acquire_free_card(&"bludgeon", true, &"verify") == CardAcquireService.RESULT_ACQUIRED and RunState.deck.back().enchants == preview.enchants)
	for index in 3: RunState.add_card(&"bludgeon")
	check("full acquisition requests review", RunState.pending_enchant_review)
	RunState.create_combat_checkpoint([&"kilnstatue"])
	controller.start_combat([&"kilnstatue"])
	var battle_cards: Array = controller.hand + controller.draw_pile
	check("battle freezes exactly three active instances", battle_cards.filter(func(entry): return CardMutation.is_active(entry)).size() == 3)
	RunState.selected_enchant_instance_ids.clear()
	check("battle snapshot independent from run selection", battle_cards.filter(func(entry): return CardMutation.is_active(entry)).size() == 3)

func setup_battle(cid: String, eid: String, active: bool, upgraded: bool = false) -> Dictionary:
	RunState.clear_combat_checkpoint()
	RunState.deck.clear()
	RunState.relic_ids.clear()
	RunState.is_active = true
	RunState.max_hp = 80
	RunState.hp = 60
	RunState.pre_run_buff_id = &""
	controller.start_combat([&"kilnstatue", &"kilnstatue"])
	for enemy in controller.enemies:
		enemy.hp = 1000
		enemy.max_hp = 1000
		enemy.block = 0
		enemy.statuses.clear()
	controller.energy = 10
	controller.draw_pile.clear()
	controller.hand.clear()
	controller.discard_pile.clear()
	for index in 20: controller.draw_pile.append({"id":&"strike","enchants":[]})
	var entry := {"id":StringName(cid),"enchants":[eid],"enchant_active":active,"instance_id":"test:1","upgraded":upgraded,"upgrade_level":1 if upgraded else 0}
	controller.hand.append(entry)
	if cid in ["fiend_fire", "sever_soul"]:
		controller.hand.append({"id":&"defend","enchants":[]})
		controller.hand.append({"id":&"defend","enchants":[]})
	return entry

func signature() -> Dictionary:
	return {"damage":2000-controller.enemies[0].hp-controller.enemies[1].hp,
		"block":controller.player.block,"strength":controller.player.get_status(&"heat"),"dex":controller.player.get_status(&"temper"),
		"draw":controller.hand.size(),"energy":controller.energy,"kiln":controller.kiln_heat,"hp":controller.player.hp,
		"ashrot":controller.enemies[0].get_status(&"ashrot"),"damp":controller.enemies[0].get_status(&"damp"),"crazed":controller.enemies[0].get_status(&"crazed"),
		"thorns":controller._temporary_thorns,"turn_strength":int(controller.powers.get(&"power_start_turn_strength",0)),
		"turn_block":int(controller.powers.get(&"power_start_turn_block",0)),"exhaust_block":int(controller.powers.get(&"power_on_exhaust_block",0)),
		"on_block":int(controller.powers.get(&"power_on_block_damage",0))}

func test_all_directions() -> void:
	# Independently authored expected deltas for neutral units; same fixtures run on upgraded cards.
	var expected := {
		"bludgeon":[{"damage":8},{"damage":6},{"block":10}],
		"immolate":[{"damage":10},{"ashrot":2},{"kiln":2}],
		"demon_form":[{"strength":2},{"block":12},{"turn_strength":1}],
		"barricade":[{"block":12},{"dex":2},{"turn_block":3}],
		"impervious":[{"block":10},{"draw":2},{"energy":1}],
		"fiend_fire":[{"damage":4},{"draw":2},{"block":8}],
		"corruption":[{"block":12},{"draw":2},{"energy":1}],
		"juggernaut":[{"on_block":2},{"block":10},{"dex":2}],
		"blood_for_blood":[{"damage":6},{"block":8},{"damp":2}],
		"carnage":[{"damage":6},{},{"draw":1}],
		"dark_embrace":[{"draw":2},{"block":10},{"exhaust_block":2}],
		"entrench":[{"block":8},{"dex":1},{"draw":2}],
		"flame_barrier":[{"block":6},{"thorns":2},{"energy":1}],
		"searing_blow":[{"damage":6},{"kiln":2},{"damage":4}],
		"sever_soul":[{"damage":6},{"block":4},{"draw":2}],
		"shockwave":[{"damp":1,"crazed":1},{"damage":18},{"block":10}],
		"uppercut":[{"damage":5},{"damp":1,"crazed":1},{"energy":1}],
		"reaper":[{"damage":2,"hp":2},{"block":10},{"draw":2}]}
	check("all eligible cards covered", expected.size() == CardMutation.config().card_directions.size())
	for cid in expected:
		for variant in 3:
			var eid := "town_%s_%d" % [cid, variant+1]
			for upgraded in [false, true]:
				var original_effects := GameData.get_card(StringName(cid)).get_effects(upgraded).duplicate(true)
				setup_battle(cid, eid, false, upgraded)
				check("base card plays " + cid, controller.play_card(0,0))
				var base := signature()
				var entry := setup_battle(cid, eid, true, upgraded)
				if cid == "carnage" and variant == 1:
					check("active stabilization removes ethereal", not controller.card_is_ethereal(entry, GameData.get_card(&"carnage")))
				check("enchanted card plays " + eid, controller.play_card(0,0))
				var actual := signature()
				for key in expected[cid][variant]:
					check("%s upgrade=%s %s delta %s got %s" % [eid,upgraded,key,expected[cid][variant][key],actual[key]-base[key]], actual[key]-base[key] == expected[cid][variant][key])
				if cid == "juggernaut" and variant == 1:
					check("block triggers newly registered juggernaut", actual.damage == (7 if upgraded else 5))
				check("templates immutable " + eid, GameData.get_card(StringName(cid)).get_effects(upgraded) == original_effects)

func test_combat_edges() -> void:
	var entry := setup_battle("uppercut", "town_uppercut_3", true)
	controller._double_tap_charges = 1
	controller.play_card(0,0)
	check("double tap refunds once", controller.energy == 9)
	var second := entry.duplicate(true)
	second.instance_id = "test:2"
	controller.hand.append(second)
	controller.play_card(controller.hand.size()-1,0)
	check("same name shares refund turn limit", controller.energy == 7)
	controller._start_player_turn()
	controller.hand = [second]
	controller.play_card(0,0)
	check("refund limit resets on new player turn", controller.energy == controller.max_energy - 1)
	entry = setup_battle("uppercut", "town_uppercut_3", true)
	entry.temporary_cost = 0
	controller.play_card(0,0)
	check("free casts cannot refund", controller.energy == 10)
	entry = setup_battle("carnage", "town_carnage_2", true)
	var copy := CardMutation.strip_copy(entry)
	check("copy loses identity enchant and stabilization", copy.enchants.is_empty() and not copy.has("instance_id") and controller.card_is_ethereal(copy, GameData.get_card(&"carnage")))
	RunState.mutation_patterns_snapshot["carnage"] = "town_carnage_2"
	controller._add_generated_card(&"carnage", "hand", 1, false)
	check("generated cards never preview a permanent enchant", CardMutation.preview(controller.hand.back()).enchants.is_empty())
	entry.enchant_active = false
	check("waiting carnage remains ethereal", controller.card_is_ethereal(entry, GameData.get_card(&"carnage")))
	setup_battle("bludgeon", "town_bludgeon_3", true)
	controller.enemies[0].hp = 1
	controller.enemies[1].hp = 0
	controller.play_card(0,0)
	check("lethal skips after-effect block", controller.player.block == 0)
	setup_battle("sever_soul", "town_sever_soul_2", true)
	controller.hand.resize(1)
	controller.player.statuses[&"temper"] = 3
	controller.play_card(0,0)
	check("zero exhaust cannot grant dex-only block", controller.player.block == 0)
	setup_battle("sever_soul", "town_sever_soul_2", true)
	for index in 5: controller.hand.append({"id":&"defend","enchants":[]})
	controller.player.statuses[&"temper"] = 3
	controller.play_card(0,0)
	check("consumed block caps before one dex grant", controller.player.block == 11)
	setup_battle("fiend_fire", "town_fiend_fire_1", true)
	controller.powers[&"power_on_exhaust_draw"] = 1
	controller.play_card(0,0)
	check("exhaust snapshots hand, newly drawn cards survive", controller.hand.size() == 3 and controller.exhaust_pile.size() == 3)

func test_ui() -> void:
	unlock()
	var panel := preload("res://scenes/town/CardMutationPanel.tscn").instantiate()
	add_child(panel)
	check("all 18 cards in town gallery", panel.get_node("Gallery/Cards").get_child_count() == 18)
	panel.select_card(String(panel.card_ids[0]))
	panel.get_node("Actions/Fire").pressed.emit()
	check("town first enchant shows receipt", panel.get_node("Actions/Accept").visible and not panel.get_node("Actions/Fire").visible)
	panel.get_node("Actions/Accept").pressed.emit()
	check("town accepts result", CardMutation.pending().is_empty())
	panel.queue_free()
	ProfileState.mutation_data = {"patterns":{"bludgeon":"town_bludgeon_1"}}
	RunState.start_new_run()
	RunState.base_run_deck_capacity = -1
	for index in 4: RunState.add_card(&"bludgeon")
	var loadout := preload("res://scenes/ui/EnchantLoadout.tscn").instantiate()
	add_child(loadout)
	check("loadout scene opens", loadout.get_node("Cover/Panel/Body/Close") != null)
	var rows := loadout.get_node("Cover/Panel/Body/Scroll/Cards")
	check("four instances displayed with last disabled", rows.get_child_count() == 4 and rows.get_child(3).get_child(0).disabled)
	rows.get_child(0).get_child(0).button_pressed = false
	check("deselect immediately releases next-battle slot", RunState.selected_enchant_instance_ids.size() == 2 and not rows.get_child(3).get_child(0).disabled)
	rows.get_child(3).get_child(0).button_pressed = true
	check("choose waiting instance", RunState.selected_enchant_instance_ids.has(String(RunState.deck.back().instance_id)))
	check("review acknowledgement saved", not RunState.pending_enchant_review)
	loadout.queue_free()
	await get_tree().process_frame
