extends Node
## 正式开箱交互测试。强制权重仅为测试夹具；禁用自动存档。
const SCENE := preload("res://scenes/map/TreasureUI.tscn")
var failures := 0
var production: Dictionary
func check(label: String, ok: bool) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures += 1

func _ready() -> void:
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/treasure_verify_save.json"
	for sig in [SignalBus.combat_ended, SignalBus.floor_entered, SignalBus.act_changed, SignalBus.run_ended]:
		for connection in sig.get_connections():
			if connection.callable.get_object() == SaveManager:
				sig.disconnect(connection.callable)
	await get_tree().process_frame
	production = GameData.balance.treasure.duplicate(true)
	verify_distribution()
	for mode in ["card", "relic", "potion", "gold", "gold_bonus", "random", "full_potions", "all_relics", "full_deck", "empty_cards"]:
		await verify(mode)
	GameData.balance.treasure = production.duplicate(true)
	await verify_map_return()
	print("TREASURE_EXIT_RESULT:%s FAIL=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(0 if failures == 0 else 1)

func counts() -> Array:
	return [RunState.deck.size(), RunState.relic_ids.size(), RunState.potions.size()]

func verify(mode: String) -> void:
	RunState.start_new_run()
	RunState.is_active = false
	var kind := mode
	var expected := [0, 0, 0]
	var cards: Dictionary = GameData.cards.duplicate()
	var gold_before := 0
	match mode:
		"card": expected[0] = 1
		"relic": expected[1] = 1
		"potion": expected[2] = 1
		"gold_bonus":
			kind = "gold"
			RunState.relic_ids.append(&"charcoal_chit")
		"full_potions":
			kind = "potion"
			expected[0] = 1
			for i in RunState._potion_cap(): RunState.potions.append(GameData.potions.keys()[0])
		"all_relics":
			kind = "relic"
			expected[0] = 1
			for id in GameData.relics: RunState.relic_ids.append(id)
		"full_deck":
			kind = "card"
			RunState.base_run_deck_capacity = RunState.deck.size()
			RunState.run_ad_deck_capacity_bonus = 0
		"empty_cards":
			kind = "card"
			GameData.cards.clear()
	GameData.balance.treasure = production.duplicate(true)
	if mode != "random":
		GameData.balance.treasure.reward_weights = {kind: 1}
	if kind == "gold":
		GameData.balance.treasure.chest_size_weights = {"medium": 1}
		GameData.balance.treasure.chest_tiers.medium.gold = {"min": 50, "max": 50}
	gold_before = RunState.gold
	var ui = SCENE.instantiate()
	var calls := [0]
	ui.setup(func(): calls[0] += 1)
	add_child(ui)
	for i in 3: await get_tree().process_frame
	check(mode + " closed, no reward before click", not ui._claimed and not ui._result_panel.visible)
	var before := counts()
	if mode == "card" and OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/treasure_closed.png")
	var at: Vector2 = ui._chest.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion, true)
	await get_tree().create_timer(0.2).timeout
	var down := InputEventMouseButton.new()
	down.position = at
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	get_viewport().push_input(down, true)
	await get_tree().create_timer(0.06).timeout
	check(mode + " pointer press scales chest", ui._chest.scale != Vector2.ONE)
	var up := down.duplicate()
	up.pressed = false
	get_viewport().push_input(up, true)
	check(mode + " pointer release starts opening", ui._claimed)
	ui._on_open()
	ui._on_open()
	ui._finish()
	check(mode + " locks while opening, cannot skip result", ui._claimed and ui._chest.disabled and calls[0] == 0 and counts() == before)
	await get_tree().create_timer(0.7).timeout
	if mode == "full_deck":
		check("full deck awaits capacity transaction", not RunState.pending_card_acquisition.is_empty() and not ui._reward_ready)
		CardAcquireService.abandon_pending()
		check("abandon keeps chest opened", ui._claimed and ui._result_name.text == "已放弃卡牌")
	ui._on_open()
	if mode == "random":
		var received := 0
		for i in 3: received += counts()[i] - before[i]
		if RunState.gold > gold_before: received += 1
		check("production config grants exactly one category", received == 1)
	else:
		check(mode + " exactly one expected reward", counts() == [before[0]+expected[0], before[1]+expected[1], before[2]+expected[2]])
	if kind == "gold":
		var amount := 63 if mode == "gold_bonus" else 50
		check(mode + " gold and result include bonus exactly once", RunState.gold == gold_before + amount and ui._result_name.text == "%d 金币" % amount and ui._result_icon.texture != null)
	check(mode + " open sprite and scale restored", ui._chest.texture_normal == ui.OPEN_TEXTURE and ui._chest.scale.is_equal_approx(Vector2.ONE))
	check(mode + " reward below visible chest", ui._result_panel.visible and ui._chest.visible and ui._result_panel.global_position.y > ui._chest.global_position.y + ui._chest.size.y)
	for i in 3: await get_tree().process_frame
	check(mode + " result fits viewport", get_viewport().get_visible_rect().encloses(ui.get_node("Layout/Panel").get_global_rect()))
	if expected[0] == 1:
		check(mode + " uses enlarged complete card", is_instance_valid(ui._result_card) and ui._result_card.size.x >= 224 and not ui._result_icon.visible and not ui._result_name.visible)
		var visual: Control = ui._result_card
		check(mode + " framed card above description", visual.has_node("DecorativeFrame") and visual.has_node("CardEnergyCost") and visual.get_global_rect().end.y <= ui._result_description.global_position.y)
	if mode == "relic":
		ui._result_icon.gui_input.emit(down)
		check("relic remains inspectable", ui._result_icon.has_node("RelicDetailsPopup"))
		ui._result_icon.get_node("RelicDetailsPopup").queue_free()
	if mode in ["card", "potion", "gold"] and OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/treasure_%s.png" % mode)
	GameData.cards = cards
	ui._continue_button.pressed.emit()
	ui._finish()
	while TransitionManager.is_transitioning: await get_tree().process_frame
	check(mode + " continue callback exactly once", calls[0] == 1 and (not is_instance_valid(ui) or ui.is_queued_for_deletion()))
	await get_tree().process_frame


func verify_distribution() -> void:
	check("production four categories each 25", production.reward_weights.size() == 4 and ["card", "relic", "potion", "gold"].all(func(kind): return float(production.reward_weights.get(kind, 0)) == 25.0))
	seed(92418)
	var tally := {"card":0, "relic":0, "potion":0, "gold":0}
	for i in 40000:
		var kind := String(RewardBuilder.roll_treasure_kind())
		tally[kind] += 1
	for kind in tally:
		check("category frequency " + kind, abs(tally[kind] - 10000) < 400)
	print("TREASURE_KIND_SAMPLE:", tally)
	var potion_tally := {"common":0,"uncommon":0,"rare":0}
	for i in 20000:
		var rarity := String(RewardBuilder._weighted_key(production.potion_rarity_weights))
		potion_tally[rarity] += 1
	for rarity in potion_tally:
		check("potion rarity " + rarity, abs(potion_tally[rarity] - 20000 * production.potion_rarity_weights[rarity] / 100.0) < 400)
	for tier in production.chest_tiers:
		GameData.balance.treasure.chest_size_weights = {tier:1}
		var band: Dictionary = production.chest_tiers[tier].gold
		var values := {}
		for i in 500:
			values[RewardBuilder.roll_treasure_gold()] = true
		check("gold band " + tier, values.size() == band.max - band.min + 1 and values.has(int(band.min)) and values.has(int(band.max)))
	GameData.balance.treasure = production.duplicate(true)
	check("treasure card base follows normal card rewards", RewardBuilder.rarity_probabilities(&"treasure", 0) == {&"common":60,&"uncommon":37,&"rare":3})
	RunState.start_new_run()
	RunState.is_active = false
	for i in 100:
		var rid := RewardBuilder.roll_treasure_relic()
		if rid == &"" or not GameData.is_relic_unlocked(rid) or RunState.relic_ids.has(rid):
			check("relic pool returns available item", false)
			return
	check("relic pool handles absent rare tier", true)


func verify_map_return() -> void:
	RunState.start_new_run()
	RunState.is_active = false
	var ui = SCENE.instantiate()
	get_tree().root.add_child(ui)
	get_tree().current_scene = ui
	await get_tree().process_frame
	ui._on_open()
	await get_tree().create_timer(0.7).timeout
	check("standalone result waits for continue", ui._reward_ready and not ui._finished)
	RunState.is_active = true
	RunState.pre_run_preparation_resolved = true
	ui._finish()
	await get_tree().scene_changed
	while TransitionManager.is_transitioning: await get_tree().process_frame
	check("standalone returns to map", get_tree().current_scene.scene_file_path == "res://scenes/map/MapPlay.tscn" and not RunState.pending_node_resolved)
