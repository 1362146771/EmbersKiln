extends Node
## Real scene regression for the Android v0.1 feedback; run in an isolated copy.
var failures := 0
var checks := 0
var visual := false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func settle() -> void:
	for i in 4: await get_tree().process_frame

func capture(label: String) -> void:
	await settle()
	if visual:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/device_" + label + ".png")

func remove_screen(screen: Node) -> void:
	screen.queue_free()
	await settle()

func _ready() -> void:
	visual = OS.get_cmdline_user_args().has("--visual")
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/device_feedback_save.json"
	get_tree().create_timer(120).timeout.connect(func(): get_tree().quit(2))
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.granny_opening = {"resolved": true}
	var map_ui = preload("res://scenes/map/MapPlay.tscn").instantiate()
	add_child(map_ui)
	await capture("map")
	var legend: Control = map_ui.get_node("MapLegend")
	check(legend.get_global_rect().position.x >= map_ui.map_scroller.get_global_rect().end.x, "map legend does not cover route column")
	check(map_ui.get_global_rect().encloses(legend.get_global_rect()), "map legend fits screen")
	check(legend.position.y >= map_ui.get_node("FormalHeader").size.y, "map legend clears header")
	await remove_screen(map_ui)

	var altar = preload("res://scenes/map/AltarUI.tscn").instantiate()
	RunState.deck[0]["upgraded"] = true
	add_child(altar)
	await capture("altar")
	var list: VBoxContainer = altar.get_node("Dim/Center/MainPanel/Content/CardScroll/Choices")
	check(list.get_child_count() == altar.choices.size(), "one altar row per eligible card instance")
	var titles: Array[String] = []
	for row in list.get_children():
		var title: Label = row.find_child("InstanceTitle", true, false)
		check(not titles.has(title.text), "altar instance title is unique: " + title.text)
		titles.append(title.text)
	check(titles[0].contains("+"), "altar upgrade marker is visible")
	var chosen: Dictionary = altar.choices[0]
	altar._on_pick(chosen)
	altar._on_pick(altar.choices[1])
	await settle()
	check(RunState.deck[0].enchants.has(String(chosen.eid)), "altar enchants selected instance")
	check(RunState.deck[1].get("enchants", []).is_empty(), "repeat click cannot enchant another instance")
	await remove_screen(altar)

	var reward = preload("res://scenes/rewards/RewardUI.tscn").instantiate()
	var cards: Array = []
	for id in [&"shrug_it_off", &"perfected_strike", &"heavy_blade"]:
		var cd := GameData.get_card(id)
		cards.append({"id": id, "name": cd.name, "cost": cd.cost, "desc": cd.description, "rarity": cd.rarity})
	reward.setup({"gold": 12, "cards": cards}, Callable())
	add_child(reward)
	await capture("reward_cards")
	var row: HBoxContainer = reward.get_node("Dim/Center/MainPanel/Content/CardScroll/Cards")
	for offer in row.get_children():
		var detail: ScrollContainer = offer.find_child("CardDescription", true, false)
		var desc: Label = detail.get_child(0)
		check(desc.get_line_count() <= 6, "Chinese effect avoids premature wrapping: %d lines" % desc.get_line_count())
		check(detail.size.y >= desc.get_minimum_size().y, "full reward description is visible")
	await remove_screen(reward)

	var overview = preload("res://scenes/ui/BattleRewardOverview.tscn").instantiate()
	add_child(overview)
	var relic_id: StringName = GameData.relics.keys()[0]
	overview.setup({"gold": 29, "relic_id": relic_id, "potion_id": &"tinder_oil", "cards": cards}, load(FormalUI.act_background()))
	await settle()
	var tile: Control = overview.get_node("Panel/Items/Scroll/Grid").get_child(1)
	var inspect: Button = tile.get_node("InspectRelic")
	inspect.grab_focus()
	await capture("reward_focus")
	check(inspect.get_theme_stylebox("focus") is StyleBoxEmpty, "relic keyboard/touch focus cannot paint over reward")
	inspect.pressed.emit()
	await settle()
	check(tile.get_node("RelicDetailsPopup/Details").visible, "reward relic detail opens")
	tile.get_node("RelicDetailsPopup").close()
	await capture("reward_return")
	check(inspect.has_focus(), "return from relic details restores transparent focus")
	await remove_screen(overview)
	await verify_turns()
	await verify_victory_transition()
	print("DEVICE_FEEDBACK_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	await preload("res://scripts/verify/CombatRegressionSupport.gd").finish(get_tree(), 0 if failures == 0 else 1)

func verify_turns() -> void:
	RunState.potions.clear()
	RunState.pending_combat_enemy_ids = [&"claylump"]
	var ui: CombatUI = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	ui.set_process(false)
	await capture("hand")
	for card in ui.hand_container.get_children():
		var title: Label = card.get_node("Body")
		var badge: TextureRect = card.get_node("RarityBadge")
		check(title.position.y >= 10 and title.get_rect().end.y <= 42, "hand name lies in title strip: " + str(title.get_rect()))
		check(card.get_rect().size.y >= badge.get_rect().end.y and badge.position.y > title.get_rect().end.y, "hand rarity stays at card bottom")
	var c := ui.controller
	c.energy = 0
	c.hand = [{"id": &"anger"}]
	check(ui._can_auto_end_turn(), "zero energy and no potion ends even with a zero-cost card per user rule")
	RunState.potions.append(&"tinder_oil")
	check(not ui._can_auto_end_turn(), "remaining potion keeps manual end")
	RunState.potions.clear()
	c.energy = 1
	check(not ui._can_auto_end_turn(), "remaining energy keeps manual end")
	c.energy = 0
	c.phase = CombatController.Phase.ENEMY
	check(not ui._can_auto_end_turn(), "enemy phase never triggers auto end")
	c.phase = CombatController.Phase.PLAYER
	BattleDirector.input_locked = true
	check(not ui._can_auto_end_turn(), "enemy/card presentation lock blocks auto end")
	BattleDirector.input_locked = false
	c.pending_card_choice = {"kind": "test"}
	check(not ui._can_auto_end_turn(), "required card selection blocks auto end")
	c.pending_card_choice.clear()
	ui._play_queue.returning = 1
	check(not ui._can_auto_end_turn(), "returning card flight blocks auto end")
	ui._play_queue.returning = 0
	ui._drag_active = true
	check(not ui._can_auto_end_turn(), "unfinished drag blocks auto end")
	ui._drag_active = false
	get_tree().paused = true
	check(not ui._can_auto_end_turn(), "pause blocks auto end")
	get_tree().paused = false
	ui.combat_over = true
	check(not ui._can_auto_end_turn(), "combat over blocks auto end")
	ui.combat_over = false
	var ends := [0]
	var count_end := func(player: bool):
		if player: ends[0] += 1
	SignalBus.turn_ended.connect(count_end)
	ui.set_process(true)
	await get_tree().create_timer(3).timeout
	check(ends[0] == 1, "resource exhaustion automatically ends exactly one player turn")
	check(c.phase == CombatController.Phase.PLAYER and c.energy == c.max_energy, "enemy turn completes and next turn replenishes energy")
	# Real queued casts consume the final energy only at impact; no early/duplicate end.
	c.enemies[0].hp = 500
	c.enemies[0].max_hp = 500
	c.hand = [{"id": &"strike"}, {"id": &"strike"}]
	c.energy = 2
	c.kiln_heat = 0
	ui._refresh_all()
	await settle()
	var before_ends: int = ends[0]
	for i in 2:
		var view: CardView = ui.hand_container.get_child(0)
		ui._targeting.on_card_drag_started(view)
		ui._targeting.cast_card(view, 0)
	var ended_during_cast := false
	while ui._play_queue.busy():
		ended_during_cast = ended_during_cast or ends[0] != before_ends
		await get_tree().create_timer(0.1).timeout
	check(not ended_during_cast, "queued card presentation finishes before automatic end")
	await get_tree().create_timer(3).timeout
	check(ends[0] == before_ends + 1 and c.phase == CombatController.Phase.PLAYER, "last-energy queued attacks cause one complete automatic turn")
	RunState.potions.assign([&"ash_salve"])
	c.energy = 0
	before_ends = ends[0]
	await settle()
	check(ends[0] == before_ends, "zero energy with a held potion remains player-controlled")
	check(c.use_potion(0), "last potion can still be used at zero energy")
	await get_tree().create_timer(3).timeout
	check(ends[0] == before_ends + 1 and c.phase == CombatController.Phase.PLAYER, "consuming final potion triggers one automatic turn")
	RunState.potions.assign([&"tinder_oil"])
	c.energy = 0
	before_ends = ends[0]
	check(c.use_potion(0), "energy potion resolves before automatic end decision")
	await settle()
	check(c.energy > 0 and ends[0] == before_ends, "last potion granting energy keeps manual end")
	SignalBus.turn_ended.disconnect(count_end)
	ui.set_process(false)
	if visual:
		ui._play_queue.returning = 1
		check(not ui._victory_backdrop_ready() and not ui._reward_snapshot_requested, "victory backdrop waits for card flight")
		ui._play_queue.returning = 0
		ui._victory_backdrop_ready()
		await capture("settled_victory")
		check(ui._reward_snapshot_ready and FormalUI.combat_reward_backdrop != null, "victory backdrop captured after settled frame")
		check(ui.log_label.text.contains("战斗胜利"), "victory backdrop replaces stale enemy turn message")
	await remove_screen(ui)

func verify_victory_transition() -> void:
	# Keep the suite outside current_scene while the real battle routes to rewards.
	get_tree().current_scene = null
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.granny_opening = {"resolved": true}
	RunState.pending_combat_enemy_ids = [&"claylump"]
	RunState.current_node_type = &"combat"
	var ui: CombatUI = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	get_tree().root.add_child(ui)
	get_tree().current_scene = ui
	ui.controller.enemies[0].hp = 1
	ui.controller.enemies[0].block = 0
	ui.controller.hand = [{"id": &"strike"}]
	ui.controller.energy = 1
	ui._refresh_all()
	await settle()
	var view: CardView = ui.hand_container.get_child(0)
	ui._targeting.on_card_drag_started(view)
	ui._targeting.cast_card(view, 0)
	while get_tree().current_scene == ui or TransitionManager.is_transitioning:
		await get_tree().process_frame
	var reward: Control = get_tree().current_scene
	check(reward.scene_file_path == "res://scenes/rewards/RewardUI.tscn", "lethal final-energy card routes to actual rewards without enemy turn")
	var overview: Control = reward.get_node_or_null("BattleRewardOverview")
	check(overview != null, "actual victory displays reward overview")
	if overview != null and visual:
		var backdrop: Texture2D = overview.get_node("Background").texture
		check(backdrop != null, "actual reward receives settled battle backdrop")
		if backdrop != null: backdrop.get_image().save_png("res://Temp/device_actual_victory_backdrop.png")
	await capture("actual_victory")
	get_tree().current_scene = null
	await remove_screen(reward)
