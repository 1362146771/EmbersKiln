extends Node
## 隔离自动存档；fixture 数字只用于测试，不是玩法数值。
const Shop := preload("res://scenes/map/ShopUI.tscn")
const Event := preload("res://scenes/map/EventUI.tscn")
const Combat := preload("res://scenes/combat/CombatPlay.tscn")
var passed := 0
var failed := 0
var visual := false
var pointer_completed := false


func _ready() -> void:
	for sig in [SignalBus.combat_ended, SignalBus.floor_entered, SignalBus.act_changed, SignalBus.run_ended]:
		for connection in sig.get_connections():
			if connection.callable.get_object() == SaveManager:
				sig.disconnect(connection.callable)
	visual = OS.get_cmdline_user_args().has("--visual")
	await frames()
	await verify_shop()
	await verify_stale_shop()
	await verify_event()
	await verify_scene_exit()
	for formal in [true, false]:
		await verify_draw(formal)
	if visual:
		await verify_pointer()
		check("pointer suite reached final checkpoint", pointer_completed)
	print("CARD_REMOVAL_DRAW_RESULT:%s PASS=%d FAIL=%d" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func check(title: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", title])


func frames(count: int = 4) -> void:
	for i in count:
		await get_tree().process_frame


func card(id: StringName, upgraded: bool = false, enchants: Array = []) -> Dictionary:
	return {"id": id, "upgraded": upgraded, "enchants": enchants}


func start_fixture() -> void:
	RunState.start_new_run()
	RunState.gold = int(GameData.balance.shop.remove_card_cost) * 2
	RunState.deck = [card(&"strike"), card(&"strike", true, [GameData.enchants.keys()[0]]), card(&"strike"), card(&"defend")]


func verify_shop() -> void:
	start_fixture()
	var ui = Shop.instantiate()
	add_child(ui)
	await frames()
	var before := RunState.deck.duplicate(true)
	var gold := RunState.gold
	check("shop uses configured fee", ui.remove_cost == int(GameData.balance.shop.remove_card_cost))
	ui._on_remove_pressed()
	var browser = ui._remove_browser
	ui._on_remove_pressed()
	check("opening removal twice creates one browser", browser == ui._remove_browser)
	browser.select_card(1)
	check("selection alone does not spend or remove", RunState.deck == before and RunState.gold == gold)
	check("upgraded enchanted card is visible in confirmation", browser._hint.text.contains("+") and browser.entries[1].enchants == before[1].enchants)
	browser._go_back()
	browser._go_back()
	check("cancel is lossless", RunState.deck == before and RunState.gold == gold and not ui.removing)
	await frames()
	ui._on_remove_pressed()
	browser = ui._remove_browser
	browser.select_card(1)
	var first: Dictionary = RunState.deck[0]
	var duplicate: Dictionary = RunState.deck[2]
	var event_counts := [0, 0]
	var states: Array = []
	var on_deck := func():
		event_counts[0] += 1
		states.append([RunState.deck.size(), RunState.gold])
		browser._confirm_selection()
		ui._confirm_remove(1, before[1])
		check("state transaction rejects nested removal", not RunState.try_remove_card(0, first, 0))
	var on_gold := func(_value):
		event_counts[1] += 1
		states.append([RunState.deck.size(), RunState.gold])
	SignalBus.deck_changed.connect(on_deck)
	SignalBus.gold_changed.connect(on_gold)
	browser._confirm_selection()
	browser._confirm_selection()
	SignalBus.deck_changed.disconnect(on_deck)
	SignalBus.gold_changed.disconnect(on_gold)
	check("shop confirmation removes exactly selected instance", RunState.deck.size() == before.size() - 1 and is_same(RunState.deck[0], first) and is_same(RunState.deck[1], duplicate))
	check("shop charges once", RunState.gold == gold - ui.remove_cost and event_counts == [1, 1])
	check("inventory listeners see committed deck and gold", states.all(func(s): return s == [RunState.deck.size(), RunState.gold]))
	check("shop displays success feedback", ui._remove_status.contains("已永久移除"))
	check("isolated save succeeds", SaveManager.save_to_file("res://Temp/card_removal_test_save.json"))
	var saved := SaveManager.load_from_file("res://Temp/card_removal_test_save.json")
	var expected := RunState.deck.duplicate(true)
	RunState.deck.clear()
	check("removed card stays removed after reload", RunState.from_save_dict(saved) and RunState.deck == expected)
	ui.queue_free()
	await frames()
	var controller := CombatController.new()
	add_child(controller)
	controller.start_combat(["claylump"])
	check("subsequent combat uses reduced deck", controller.hand.size() + controller.draw_pile.size() == expected.size() and controller.hand.all(func(c): return not c.upgraded))
	controller.queue_free()
	await frames()


func verify_stale_shop() -> void:
	for mode in ["gold", "shifted_duplicate", "upgraded", "last_card"]:
		start_fixture()
		var ui = Shop.instantiate()
		add_child(ui)
		ui._on_remove_pressed()
		var browser = ui._remove_browser
		browser.select_card(0)
		match mode:
			"gold": RunState.gold = 0
			"shifted_duplicate":
				# 内容相同但实例不同，不能误删后一个同名牌。
				RunState.deck.remove_at(0)
				RunState.deck.remove_at(0)
			"upgraded": RunState.deck[0].upgraded = true
			"last_card": RunState.deck = [RunState.deck[0]]
		var before := RunState.deck.duplicate(true)
		var gold := RunState.gold
		browser._confirm_selection()
		check("stale shop " + mode + " is lossless", before == RunState.deck and gold == RunState.gold)
		check("stale shop " + mode + " explains rejection", ui._remove_status.contains("未扣费"))
		ui.queue_free()
		await frames()
	start_fixture()
	RunState.gold = 0
	var ui = Shop.instantiate()
	add_child(ui)
	ui._on_remove_pressed()
	check("insufficient funds disables entry", not ui.removing and ui.find_child("RemoveCardButton", true, false).disabled)
	ui.queue_free()
	await frames()


func removal_event() -> Dictionary:
	for event in GameData.events:
		if event.id == "ember_remnant":
			return event
	return {}


func verify_event() -> void:
	start_fixture()
	var ui = Event.instantiate()
	ui._event = removal_event()
	add_child(ui)
	await frames()
	var event_before: Dictionary = ui._event.duplicate(true)
	check("live event data exposes removal option", ui._event.options.any(func(o): return o.effects.get("remove_card", false)))
	var before := RunState.deck.duplicate(true)
	var gold := RunState.gold
	ui._on_choose({"remove_card": true})
	var browser = ui._remove_browser
	ui._on_choose({"gold": 30})
	check("event modal locks other rewards", RunState.gold == gold)
	browser.close()
	check("event cancel keeps same event and deck", ui._event == event_before and before == RunState.deck and not ui._choosing)
	await frames()
	ui._on_choose({"remove_card": true})
	browser = ui._remove_browser
	browser.select_card(1)
	var reentry := func(): ui._on_choose({"gold": 30})
	SignalBus.deck_changed.connect(reentry)
	browser._confirm_selection()
	browser._confirm_selection()
	ui._on_choose({"remove_card": true})
	ui._on_choose({"gold": 30})
	SignalBus.deck_changed.disconnect(reentry)
	check("event consumes only chosen card once", RunState.deck.size() == before.size() - 1 and ui._resolved)
	check("event has no extra charge or other reward", RunState.gold == gold)
	var callbacks := [0]
	ui.on_done = func(): callbacks[0] += 1
	ui._finish()
	ui._finish()
	check("event exits once", callbacks[0] == 1)
	await frames()
	start_fixture()
	RunState.deck = [card(&"strike")]
	ui = Event.instantiate()
	ui._event = removal_event()
	add_child(ui)
	ui._on_choose({"remove_card": true})
	check("last card blocks event removal but allows other options", not ui._choosing and ui._choice_buttons.any(func(b): return not b.disabled))
	check("negative fee and invalid index rejected", not RunState.try_remove_card(-1, {}, 0) and not RunState.try_remove_card(0, RunState.deck[0], -1))
	ui.queue_free()
	await frames()
	start_fixture()
	ui = Event.instantiate()
	ui._event = removal_event()
	add_child(ui)
	ui._on_choose({"remove_card": true})
	browser = ui._remove_browser
	browser.select_card(0)
	RunState.deck[0].upgraded = true
	before = RunState.deck.duplicate(true)
	browser._confirm_selection()
	check("stale event selection can retry without consuming event", RunState.deck == before and not ui._resolved and not ui._choosing and ui._status.text.contains("未移除"))
	ui._on_choose({"remove_card": true})
	browser = ui._remove_browser
	browser.select_card(0)
	browser._confirm_selection()
	check("event retry successfully removes updated card", ui._resolved and RunState.deck.size() == before.size() - 1)
	ui.queue_free()
	await frames()


func verify_scene_exit() -> void:
	for event_mode in [false, true]:
		start_fixture()
		var tree := get_tree()
		var ui = Event.instantiate() if event_mode else Shop.instantiate()
		if event_mode:
			ui._event = removal_event()
		tree.root.add_child(ui)
		tree.current_scene = ui
		if event_mode:
			ui._on_choose({"remove_card": true})
		else:
			ui._on_remove_pressed()
		var browser = ui._remove_browser
		browser.select_card(1)
		browser._confirm_selection()
		var expected := RunState.deck.duplicate(true)
		var gold := RunState.gold
		ui._finish()
		ui._finish()
		await tree.scene_changed
		check("formal scene returns to map " + str(event_mode), tree.current_scene.scene_file_path == "res://scenes/map/MapPlay.tscn" and not RunState.pending_node_resolved)
		check("map preserves removal and payment " + str(event_mode), RunState.deck == expected and RunState.gold == gold)
		var map := tree.current_scene
		tree.current_scene = self
		tree.root.remove_child(map)
		map.queue_free()
		await frames()


func verify_draw(formal: bool) -> void:
	RunState.start_new_run()
	var ui: CombatUI = Combat.instantiate() if formal else CombatUI.new()
	add_child(ui)
	await frames()
	check("draw count matches opening hand " + str(formal), ui.draw_pile_button.get_node("Count").text == str(ui.controller.draw_pile.size()))
	var piles := [ui.controller.draw_pile.duplicate(true), ui.controller.hand.duplicate(true), ui.controller.discard_pile.duplicate(true), RunState.deck.duplicate(true)]
	seed(218)
	var expected_rng := randi()
	seed(218)
	ui._open_draw_pile()
	var browser = ui._card_browser
	check("browse does not advance RNG " + str(formal), randi() == expected_rng)
	ui._open_draw_pile()
	check("draw browser is singleton and read-only", ui._card_browser == browser and not browser.selectable and not browser._confirm.visible)
	check("draw browse preserves physical pile order", piles[0] == ui.controller.draw_pile)
	browser.select_card(0)
	browser._confirm_selection()
	var view: CardView = ui.hand_container.get_child(0)
	ui._targeting.on_card_tapped(view)
	ui._targeting.on_card_drag_started(view)
	ui._targeting.on_end_turn()
	RunState.potions.append(GameData.potions.keys()[0])
	ui._targeting.on_potion_pressed(0)
	check("modal blocks play drag end-turn and potion", ui.controller.phase == CombatController.Phase.PLAYER and not ui._drag_active and RunState.potions.size() == 1)
	check("viewing never changes any deck", piles == [ui.controller.draw_pile, ui.controller.hand, ui.controller.discard_pile, RunState.deck])
	PauseManager._open_pause()
	check("pause menu can coexist with browser", get_tree().paused and ui.card_browser_open())
	PauseManager._close_pause()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	get_viewport().push_input(escape, true)
	check("closing restores combat interaction", not ui.card_browser_open())
	await frames()
	ui.controller.hand.clear()
	ui.controller.draw_pile = [card(&"strike"), card(&"bash", true)]
	ui.controller._draw_cards(1)
	check("draw signal updates count", ui.draw_pile_button.get_node("Count").text == "1")
	ui.controller._draw_cards(1)
	ui._open_draw_pile()
	check("empty draw pile has readable state", ui._card_browser.entries.is_empty() and ui._card_browser._cards.get_child_count() == 1)
	ui._close_card_browser()
	ui.controller.discard_pile = [card(&"defend"), card(&"strike"), card(&"bash")]
	ui.controller._draw_cards(1)
	check("reshuffle updates draw and discard counters", ui.draw_pile_button.get_node("Count").text == "2" and ui.discard_pile_view.get_node("Content/Labels/Count").text == "0")
	ui._open_draw_pile()
	ui.controller._draw_cards(1)
	check("external pile change closes stale browser", not ui.card_browser_open())
	ui.controller.phase = CombatController.Phase.ENEMY
	ui._open_draw_pile()
	check("enemy turn cannot open stale snapshot", not ui.card_browser_open())
	ui.queue_free()
	await frames()


func click(control: Control) -> void:
	await frames()
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event, true)
		await frames(2)


func capture(title: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	check("capture " + title, get_viewport().get_texture().get_image().save_png("res://Temp/card_browser_" + title + ".png") == OK)


func verify_pointer() -> void:
	RunState.start_new_run()
	var combat: CombatUI = Combat.instantiate()
	add_child(combat)
	await frames(10)
	await capture("combat")
	await click(combat.draw_pile_button)
	check("pointer opens draw pile", combat.card_browser_open())
	await capture("draw")
	var count := combat.controller.hand.size()
	# 底部结束回合与弹窗「返回战斗」位置重叠；在手牌位置点空白验证遮挡。
	await click(combat.hand_container.get_child(0))
	check("pointer cannot click through modal", combat.card_browser_open() and combat.controller.phase == CombatController.Phase.PLAYER and combat.controller.hand.size() == count)
	await click(combat._card_browser._back)
	check("pointer closes draw pile", not combat.card_browser_open())
	combat.controller.draw_pile.clear()
	await click(combat.draw_pile_button)
	await capture("empty")
	combat.queue_free()
	await frames()
	start_fixture()
	# 大牌组及长文本验证滚动，不改变任何运行时配置。
	for id in GameData.cards:
		RunState.deck.append(card(id, true, [GameData.enchants.keys()[0]]))
	var shop = Shop.instantiate()
	add_child(shop)
	await frames(10)
	await capture("shop")
	await click(shop.find_child("RemoveCardButton", true, false))
	var browser = shop._remove_browser
	check("pointer opens removal gallery", shop.removing and browser != null)
	await capture("gallery")
	var last := browser._cards.get_child(browser._cards.get_child_count() - 1).find_child("SelectCard", true, false) as Button
	browser._scroll.ensure_control_visible(last)
	await frames()
	check("last card reachable by scrolling", browser._scroll.get_global_rect().encloses(last.get_global_rect()))
	await capture("gallery_bottom")
	await click(last)
	check("pointer selects exact scrolled card", browser.selected_index == RunState.deck.size() - 1)
	await capture("confirm")
	var gold := RunState.gold
	var deck_count := RunState.deck.size()
	await click(browser._confirm)
	check("pointer confirms payment and removal", RunState.deck.size() == deck_count - 1 and RunState.gold == gold - shop.remove_cost)
	await capture("removed")
	shop.queue_free()
	await frames()
	start_fixture()
	var event = Event.instantiate()
	event._event = removal_event()
	add_child(event)
	await frames()
	await capture("event")
	var remove_option: Button
	for option in event._choice_buttons:
		if option.get_meta("remove_card", false):
			remove_option = option
	await click(remove_option)
	browser = event._remove_browser
	await click(browser._cards.get_child(0).find_child("SelectCard", true, false))
	await capture("event_confirm")
	await click(browser._confirm)
	check("pointer event removal completes", event._resolved and RunState.deck.size() == 3)
	await capture("event_result")
	event.queue_free()
	await frames()
	pointer_completed = true
