extends Node
## 玩家回合末弃牌、虚无消耗、弃牌洗回与牌堆 UI 的专项回归。
## 只改测试进程内存态；所有玩法数值均读取正式配置。

const CombatScene := preload("res://scenes/combat/CombatPlay.tscn")

var passed := 0
var failed := 0
var discarded_ids: Array[StringName] = []
var exhausted_ids: Array[StringName] = []
var drawn_ids: Array[StringName] = []
var visual := false


func _ready() -> void:
	visual = OS.get_cmdline_user_args().has("--visual")
	_disconnect_auto_save()
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	check("GameData loaded", GameData.is_loaded)
	if GameData.is_loaded:
		_connect_card_signals()
		await verify_controller_flow()
		await verify_hand_limit()
		await verify_combat_ui_sync()
		_disconnect_card_signals()
	print("TURN_END_CARD_FLOW_RESULT:%s PASS=%d FAIL=%d" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func verify_controller_flow() -> void:
	RunState.start_new_run()
	var controller := CombatController.new()
	add_child(controller)
	controller.start_combat(["claylump"])
	discarded_ids.clear()
	exhausted_ids.clear()
	drawn_ids.clear()
	var strike := card(&"strike", "left_strike", true)
	strike["temporary_cost"] = 0
	strike["_x_spent"] = 2
	strike["_active_card_id"] = &"strike"
	var defend := card(&"defend", "left_defend")
	var bash := card(&"bash", "left_bash")
	var dazed := card(&"dazed", "left_dazed")
	controller.hand = [strike, defend, bash, dazed]
	controller.draw_pile = [card(&"strike", "draw_1"), card(&"defend", "draw_2")]
	controller.discard_pile.clear()
	controller.exhaust_pile.clear()
	var permanent_deck := RunState.deck.duplicate(true)
	controller.end_player_turn()
	check("end turn immediately locks player phase", controller.phase == CombatController.Phase.ENEMY)
	check("all unplayed cards leave hand", controller.hand.is_empty())
	check("non-ethereal cards enter discard pile", markers(controller.discard_pile) == ["left_strike", "left_defend", "left_bash"])
	check("ethereal card enters exhaust pile instead", markers(controller.exhaust_pile) == ["left_dazed"])
	check("end-turn discard emits once per discarded card", discarded_ids.size() == 3)
	check("ethereal exhaust emits once", exhausted_ids == [&"dazed"])
	check("turn-only fields reset while upgrade and enchant survive", not strike.has("temporary_cost")
		and not strike.has("_x_spent") and not strike.has("_active_card_id")
		and bool(strike.get("upgraded", false)) and strike.get("enchants", []).size() == 1)
	check("combat pile movement never changes permanent deck", RunState.deck == permanent_deck)
	controller.enemy_phase_done()
	check("next turn draws configured amount across reshuffle boundary",
		controller.phase == CombatController.Phase.PLAYER
		and controller.hand.size() == int(GameData.player_config().get("draw_per_turn", 0))
		and drawn_ids.size() == int(GameData.player_config().get("draw_per_turn", 0)))
	check("discard pile shuffles only after original draw pile is exhausted",
		controller.draw_pile.is_empty() and controller.discard_pile.is_empty()
		and marker_set(controller.hand) == {"draw_1":true, "draw_2":true, "left_strike":true, "left_defend":true, "left_bash":true})

	# 回合末状态牌先结算，再与普通未打出牌一起进入弃牌堆。
	controller.hand = [card(&"burn", "burn")]
	controller.draw_pile.clear()
	controller.discard_pile.clear()
	var hp_before := controller.player.hp
	var burn_loss := int(GameData.get_card(&"burn").end_turn_effects[0].get("value", 0))
	controller.end_player_turn()
	check("burn resolves before being discarded", controller.player.hp == hp_before - burn_loss
		and controller.hand.is_empty() and markers(controller.discard_pile) == ["burn"])

	# 虚无触发的抽牌发生在普通手牌统一弃置之前，不能抽回同批未打出的牌。
	controller.enemy_phase_done()
	controller.hand = [card(&"strike", "same_turn_normal"), card(&"dazed", "same_turn_ethereal")]
	controller.draw_pile.clear()
	controller.discard_pile.clear()
	controller.exhaust_pile.clear()
	controller.powers[&"power_on_exhaust_draw"] = 1
	drawn_ids.clear()
	controller.end_player_turn()
	check("ethereal draw cannot recycle cards from the same ending hand",
		drawn_ids.is_empty() and markers(controller.discard_pile) == ["same_turn_normal"]
		and markers(controller.exhaust_pile) == ["same_turn_ethereal"])
	controller.queue_free()
	await frames()


func verify_hand_limit() -> void:
	RunState.start_new_run()
	var controller := CombatController.new()
	add_child(controller)
	controller.start_combat(["claylump"])
	var hand_max := int(GameData.player_config().get("hand_max", 0))
	controller.hand.clear()
	for index in hand_max:
		controller.hand.append(card(&"strike", "hand_%d" % index))
	controller.draw_pile = [card(&"defend", "waiting_1"), card(&"bash", "waiting_2")]
	controller._draw_cards(2)
	check("draw attempts at hand limit leave cards in draw pile", controller.hand.size() == hand_max
		and markers(controller.draw_pile) == ["waiting_1", "waiting_2"])
	controller.hand.pop_back()
	controller._draw_cards(2)
	check("draw fills only the available hand slot", controller.hand.size() == hand_max
		and markers(controller.draw_pile) == ["waiting_2"])
	controller.queue_free()
	await frames()


func verify_combat_ui_sync() -> void:
	RunState.start_new_run()
	var ui: CombatUI = CombatScene.instantiate()
	add_child(ui)
	await frames(6)
	ui.controller.hand = [card(&"strike", "ui_strike"), card(&"defend", "ui_defend"), card(&"bash", "ui_bash")]
	ui.controller.draw_pile = []
	for index in int(GameData.player_config().get("draw_per_turn", 0)):
		ui.controller.draw_pile.append(card(&"strike", "next_%d" % index))
	ui.controller.discard_pile.clear()
	ui._refresh_all()
	await frames()
	check("UI fixture renders current hand", ui.hand_container.get_child_count() == 3)
	ui.controller.end_player_turn()
	check("turn-ended signal clears hand visuals immediately", ui.controller.hand.is_empty()
		and ui.hand_container.get_child_count() == 0)
	check("turn-ended signal refreshes discard counter",
		ui.discard_pile_view.get_node("Content/Labels/Count").text == "3")
	if visual:
		await capture("enemy_phase_empty_hand")
	ui.controller.enemy_phase_done()
	await frames()
	var discarded_before := ui.controller.discard_pile.duplicate(true)
	await click(ui.discard_pile_view)
	check("discard pile can be browsed read-only", ui.card_browser_open()
		and ui._card_browser.entries.size() == 3 and not ui._card_browser.selectable)
	check("browsing discard pile preserves physical pile", ui.controller.discard_pile == discarded_before)
	if visual:
		await capture("discard_browser")
	ui._close_card_browser()
	ui.queue_free()
	await frames()


func card(id: StringName, marker: String, upgraded := false) -> Dictionary:
	return {"id":id, "upgraded":upgraded, "upgrade_level":1 if upgraded else 0,
		"enchants":[GameData.enchants.keys()[0]] if upgraded and not GameData.enchants.is_empty() else [],
		"marker":marker}


func markers(pile: Array) -> Array:
	return pile.map(func(entry): return String(entry.get("marker", "")))


func marker_set(pile: Array) -> Dictionary:
	var result := {}
	for entry in pile:
		result[String(entry.get("marker", ""))] = true
	return result


func frames(count := 3) -> void:
	for index in count:
		await get_tree().process_frame


func capture(label: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	check("screenshot " + label,
		get_viewport().get_texture().get_image().save_png("res://Temp/turn_end_card_flow_" + label + ".png") == OK)


func click(control: Control) -> void:
	var position := control.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.pressed = true
	get_viewport().push_input(press, true)
	await frames(2)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.pressed = false
	get_viewport().push_input(release, true)
	await frames(2)


func check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])


func _connect_card_signals() -> void:
	SignalBus.card_discarded.connect(_on_card_discarded)
	SignalBus.card_exhausted.connect(_on_card_exhausted)
	SignalBus.card_drawn.connect(_on_card_drawn)


func _disconnect_card_signals() -> void:
	if SignalBus.card_discarded.is_connected(_on_card_discarded):
		SignalBus.card_discarded.disconnect(_on_card_discarded)
	if SignalBus.card_exhausted.is_connected(_on_card_exhausted):
		SignalBus.card_exhausted.disconnect(_on_card_exhausted)
	if SignalBus.card_drawn.is_connected(_on_card_drawn):
		SignalBus.card_drawn.disconnect(_on_card_drawn)


func _on_card_discarded(card_id: StringName) -> void:
	discarded_ids.append(card_id)


func _on_card_exhausted(card_id: StringName) -> void:
	exhausted_ids.append(card_id)


func _on_card_drawn(card_id: StringName) -> void:
	drawn_ids.append(card_id)


func _disconnect_auto_save() -> void:
	for sig in [SignalBus.combat_ended, SignalBus.floor_entered, SignalBus.act_changed, SignalBus.run_ended]:
		for connection in sig.get_connections():
			if connection.callable.get_object() == SaveManager:
				sig.disconnect(connection.callable)
