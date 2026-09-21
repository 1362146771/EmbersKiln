extends Node
const IDS := [&"everlit_core", &"sealed_hammer", &"cracked_seal", &"firebound_collar"]
var checks := 0
var failures := 0
var c: CombatController
var finishes := 0

class ScriptErrors extends Logger:
	var messages: PackedStringArray = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _notify: bool, error_type: int, _backtraces: Array) -> void:
		if error_type == ERROR_TYPE_SCRIPT: messages.append("%s:%d %s %s" % [file, line, code, rationale])

class RewardMapProbe extends "res://scripts/map/MapUI.gd":
	var routed := ""
	func _route_scene(scene: PackedScene) -> void:
		routed = scene.resource_path

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func fresh(ids: Array = []) -> void:
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.relic_ids.assign(ids)
	RunState.clear_combat_checkpoint()

func entry(id: StringName) -> Dictionary:
	return {"id": id, "upgraded": false, "temporary_cost": 0}

func wound_count() -> int:
	var count := 0
	for pile in [c.draw_pile, c.hand, c.discard_pile, c.exhaust_pile]:
		for card in pile:
			if String(card.id) == "wound": count += 1
	return count

func _ready() -> void:
	if OS.get_environment("BOSS_RELIC_TEST_ROOT").is_empty():
		get_tree().quit(2)
		return
	var errors := ScriptErrors.new()
	OS.add_logger(errors)
	get_tree().create_timer(90).timeout.connect(func(): get_tree().quit(2))
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/boss_relic_save.json"
	c = CombatController.new()
	add_child(c)
	check(GameData.load_errors.is_empty(), "production data validates")
	test_pools()
	test_reward_generation()
	test_energy_and_wounds()
	test_card_limit()
	await test_rest()
	await test_reward_resume()
	if "--visual" in OS.get_cmdline_user_args():
		await test_visuals()
		await test_combat_visual()
	c.queue_free()
	await get_tree().process_frame
	check(errors.messages.is_empty(), "no runtime script errors: " + str(errors.messages))
	print("BOSS_RELIC_RESULT:%s %d/%d" % ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)

func test_pools() -> void:
	fresh()
	for id in IDS:
		check(GameData.is_relic_unlocked(id), "initial unlock " + String(id))
		check(GameData.icon_texture(GameData.get_relic(id).icon) != null, "icon " + String(id))
	var valid := true
	for trial in 60:
		var offers := RewardBuilder.roll_boss_relic_choices()
		valid = valid and offers.size() == 3 and offers[0] != offers[1] and offers[1] != offers[2] and offers[0] != offers[2]
		for id in offers: valid = valid and IDS.has(StringName(id))
		for id in [RewardBuilder.roll_relic(&"elite"), RewardBuilder.roll_shop_relic(), RewardBuilder.roll_shop_relic_excluding([]), RewardBuilder.roll_treasure_relic()]:
			valid = valid and not IDS.has(id)
	check(valid, "unique boss choices and ordinary pools exclude boss relics")
	check(RewardBuilder.roll_relic(&"boss") == &"", "act-one boss ordinary relic replaced")
	RunState.add_relic(IDS[0])
	var offers := RewardBuilder.roll_boss_relic_choices()
	check(offers.size() == 3 and not offers.has(String(IDS[0])), "owned relic excluded")
	RunState.add_relic(IDS[1])
	check(RewardBuilder.roll_boss_relic_choices().size() == 2, "short pool returns all remaining")
	RunState.add_relic(IDS[2]); RunState.add_relic(IDS[3])
	check(RewardBuilder.roll_boss_relic_choices().is_empty(), "exhausted pool")
	RunState.current_act = 2
	check(RewardBuilder.roll_boss_relic_choices().is_empty(), "final act offers no new boss choice")

func test_energy_and_wounds() -> void:
	var base := int(GameData.player_config().energy_per_turn)
	for id in IDS:
		fresh([id])
		c.start_combat([&"claylump"])
		check(c.energy == base + 1 and c.max_energy == base + 1, "opening energy " + String(id))
		c._start_player_turn()
		check(c.energy == base + 1, "later-turn energy " + String(id))
	fresh([IDS[0], IDS[1], &"draft_flue"])
	c.start_combat([&"claylump"])
	check(c.energy == base + 3 and c.max_energy == base + 2, "different boss relics stack with first-turn flue")
	c._start_player_turn()
	check(c.energy == base + 2, "flue is still first-turn only")
	check(not RunState.add_relic(IDS[0]), "duplicate relic rejected")
	fresh([&"cracked_seal"])
	var deck := RunState.deck.duplicate(true)
	c.start_combat([&"claylump"])
	check(wound_count() == 2 and RunState.deck == deck, "two temporary wounds at combat start")
	c._start_player_turn()
	check(wound_count() == 2, "wounds not added every turn")
	RunState.create_combat_checkpoint([&"claylump"])
	check(SaveManager.save_game() and SaveManager.load_game() and RunState.restore_combat_checkpoint(), "relic checkpoint survives disk roundtrip")
	c.start_combat([&"claylump"])
	check(wound_count() == 2 and RunState.deck == deck and c.max_energy == base + 1, "restart rebuilds exactly two wounds and energy bonus")
	fresh()
	c.start_combat([&"claylump"])
	check(c.max_energy == base and wound_count() == 0, "new run clears boss effects")

func test_card_limit() -> void:
	fresh([&"firebound_collar"])
	c.start_combat([&"kilnstatue"])
	c.hand.clear()
	for i in 7: c.hand.append(entry(&"defend"))
	for i in 6: check(c.play_card(0), "allowed card " + str(i + 1))
	var energy := c.energy
	var block := c.player.block
	check(not c.can_play_card(0) and not c.play_card(0) and c.hand.size() == 1 and c.energy == energy and c.player.block == block, "seventh card rejected without consuming resources")
	RunState.potions.assign([&"tinder_oil"])
	check(c.use_potion(0) and c.cards_played_this_turn == 6, "potions still usable at cap without consuming a play")
	c._start_player_turn()
	check(c.cards_played_this_turn == 0 and c.can_play_more_cards(), "counter resets next turn")
	c.hand = [entry(&"havoc")]
	c.draw_pile = [entry(&"defend")]
	c.cards_played_this_turn = 4
	check(c.play_card(0) and c.cards_played_this_turn == 6 and not c.exhaust_pile.is_empty(), "automatic play counts within cap")
	c.hand = [entry(&"havoc")]
	c.draw_pile = [entry(&"defend")]
	c.cards_played_this_turn = 5
	check(c.play_card(0) and c.cards_played_this_turn == 6 and c.hand.is_empty(), "automatic play cannot exceed cap or duplicate a card")
	c.hand = [entry(&"strike")]
	c._double_tap_charges = 1
	c.cards_played_this_turn = 5
	check(c.play_card(0, 0) and c.cards_played_this_turn == 6, "double-tap effect repeats count as one played card")
	var dummy := CombatUI.new()
	dummy.controller = c
	var queue := preload("res://scripts/combat/CardPlayQueue.gd").new()
	queue.ui = dummy
	var a := entry(&"defend"); var b := entry(&"defend")
	c.hand = [a, b]
	c.cards_played_this_turn = 5
	queue.pending = [{"entry": a}]
	check(not queue.can_submit(b), "pending queue reserves final allowed play")
	queue.pending.clear(); queue.active = {"entry": a}
	check(not queue.can_submit(b), "active cast reserves final allowed play")
	c.hand.remove_at(0); c.cards_played_this_turn = 5
	check(queue.can_submit(b), "already-consumed active card not double-counted")
	queue.free(); dummy.free()

func test_rest() -> void:
	fresh([&"everlit_core", &"sealed_hammer"])
	RunState.hp = 20
	var rest := preload("res://scenes/map/RestUI.tscn").instantiate()
	add_child(rest)
	await get_tree().process_frame
	check(rest.get_node("Dim/Center/MainPanel/Content/RestButton").disabled and rest.get_node("Dim/Center/MainPanel/Content/ForgeButton").disabled, "both restricted rest buttons disabled")
	check(not rest.get_node("Dim/Center/MainPanel/Content/LeaveButton").disabled, "can leave when both actions blocked")
	var deck := RunState.deck.duplicate(true)
	rest._on_rest(50); rest._on_upgrade_card(0)
	check(RunState.hp == 20 and RunState.deck == deck, "direct handlers cannot bypass rest restrictions")
	RunState.heal(5)
	check(RunState.hp == 25 and RunState.upgrade_card_at(0), "other healing and upgrade channels remain available")
	rest.queue_free()
	await get_tree().process_frame

func test_reward_resume() -> void:
	fresh()
	RunState.current_node_type = &"boss"
	RunState.current_floor = 14
	var choices := RewardBuilder.roll_boss_relic_choices()
	var data := {"tier": "boss", "stage": "cards", "cards": [], "boss_relic_choices": choices}
	RunState.pending_reward_data = data
	var reward := preload("res://scenes/rewards/RewardUI.tscn").instantiate()
	reward.setup(data, func(): finishes += 1)
	add_child(reward)
	await get_tree().process_frame
	reward._on_skip()
	check(data.stage == "boss_relic" and finishes == 0 and RunState.relic_ids.is_empty(), "finishing normal reward opens choice without granting")
	check(SaveManager.save_game() and SaveManager.load_game(), "pending choice saved and loaded")
	check(RunState.pending_reward_data.boss_relic_choices == choices and RunState.pending_reward_data.stage == "boss_relic", "disk resume preserves offers and stage")
	reward.queue_free()
	await get_tree().process_frame
	var menu := preload("res://scenes/main/MainMenu.tscn").instantiate()
	check(menu._continue_destination() == "res://scenes/rewards/RewardUI.tscn", "main menu resumes pending reward directly")
	menu.free()
	reward = preload("res://scenes/rewards/RewardUI.tscn").instantiate()
	reward.setup(RunState.pending_reward_data, func(): finishes += 1)
	add_child(reward)
	await get_tree().process_frame
	check(reward.has_node("BossRelicChoice"), "resumed page is boss choice")
	reward._on_boss_relic_chosen(&"not_an_offer")
	check(RunState.relic_ids.is_empty(), "invalid offer cannot be granted")
	var selected := StringName(choices[0])
	reward.get_node("BossRelicChoice")._choose(selected)
	reward._on_boss_relic_chosen(StringName(choices[1]))
	while TransitionManager.is_transitioning: await get_tree().process_frame
	await get_tree().process_frame
	check(finishes == 1 and RunState.relic_ids == [selected], "one choice and one completion only")
	check(SaveManager.load_game() and RunState.pending_post_reward and RunState.relic_ids == [selected], "accepted choice saved atomically with completion")
	var interrupted := RunState.to_save_dict()
	interrupted["pending_post_reward"] = false
	check(RunState.from_save_dict(interrupted) and RunState.pending_post_reward, "completed stage recovers interrupted map-return marker")
	var map := preload("res://scenes/map/MapPlay.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	while TransitionManager.is_transitioning: await get_tree().process_frame
	check(RunState.current_act == 1 and RunState.pending_reward_data.is_empty(), "map consumes completion and advances exactly one act")
	check(not RewardBuilder.roll_boss_relic_choices().has(String(selected)), "second-act pool excludes first selection")
	map.queue_free()
	await get_tree().process_frame
	fresh()
	var skip_data := {"tier": "boss", "stage": "boss_relic", "boss_relic_choices": RewardBuilder.roll_boss_relic_choices()}
	reward = preload("res://scenes/rewards/RewardUI.tscn").instantiate()
	reward.setup(skip_data, func(): finishes += 1)
	add_child(reward)
	await get_tree().process_frame
	reward.get_node("BossRelicChoice")._choose(&"")
	while TransitionManager.is_transitioning: await get_tree().process_frame
	check(RunState.relic_ids.is_empty() and skip_data.stage == "complete", "skip completes without relic")
	await get_tree().process_frame

func test_visuals() -> void:
	fresh()
	var panel := preload("res://scenes/rewards/BossRelicChoice.tscn").instantiate()
	panel.setup(["everlit_core", "sealed_hammer", "cracked_seal"])
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://Temp/boss-relic-choice.png") == OK, "capture boss choice screen")
	for row in panel.get_node("Center/Panel/Body/Offers").get_children():
		check(row.get_global_rect().end.x <= 720 and row.get_global_rect().end.y <= 1280, "offer stays within mobile viewport")
		var copy := row.get_node("Content/Copy")
		check(copy.get_node("Cost").get_line_count() == copy.get_node("Cost").get_visible_line_count(), "drawback fully visible")
	panel.queue_free()
	await get_tree().process_frame
	panel = preload("res://scenes/rewards/BossRelicChoice.tscn").instantiate()
	panel.setup(["firebound_collar", "sealed_hammer", "cracked_seal"])
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://Temp/boss-relic-collar.png") == OK, "capture collar option")
	panel.queue_free()
	await get_tree().process_frame


func test_reward_generation() -> void:
	for act in [0, 1, 2]:
		fresh()
		RunState.current_act = act
		RunState.current_node_type = &"boss"
		var map := RewardMapProbe.new()
		map._grant_reward()
		var reward := RunState.pending_reward_data.duplicate(true)
		check(map.routed == "res://scenes/rewards/RewardUI.tscn", "production boss routes to rewards act " + str(act))
		if act < 2:
			check(reward.get("boss_relic_choices", []).size() == 3 and RunState.relic_ids.is_empty() and String(reward.relic_id).is_empty(), "production boss replaces ordinary relic act " + str(act))
		else:
			check(not reward.has("boss_relic_choices") and RunState.relic_ids.size() == 1, "final boss retains original reward without new choice")
		var gold := RunState.gold
		check(SaveManager.load_game() and RunState.gold == gold and RunState.pending_reward_data == JSON.parse_string(JSON.stringify(reward)), "production reward transaction persists without reroll")
		map.free()


func test_combat_visual() -> void:
	fresh([&"firebound_collar", &"everlit_core", &"cracked_seal"])
	RunState.pending_combat_enemy_ids = [&"claylump"]
	var ui := preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	var counters := ui.find_children("PlayLimit", "Label", true, false)
	check(counters.size() == 1 and counters[0].text == "0/6", "collar counter shows turn-start budget")
	ui.controller.hand.clear()
	for i in 7: ui.controller.hand.append(entry(&"defend"))
	ui._refresh_all()
	for i in 6:
		ui.controller.play_card(0)
		await get_tree().process_frame
	ui._refresh_all()
	await get_tree().process_frame
	check(counters[0].text == "6/6" and not ui._play_queue.can_submit(ui.controller.hand[0]), "visible collar cap matches actual input gate")
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://Temp/boss-relic-combat.png") == OK, "capture in-game collar counter")
	ui.queue_free()
	await get_tree().process_frame
