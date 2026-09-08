extends Node
## 运行：Godot --headless --path . scenes/verify/ManualDiscardVerify.tscn
## 图形验证：去掉 --headless，追加 -- --visual；截图存 Temp/manual_discard_*.png。
## 测试 fixture 数字仅用于断言，不是玩法配置。不写玩家存档。

var passed := 0
var failed := 0
var visual := false
var ui: CombatUI


func _ready() -> void:
	for sig in [SignalBus.combat_ended, SignalBus.floor_entered, SignalBus.act_changed, SignalBus.run_ended]:
		for connection in sig.get_connections():
			if connection.callable.get_object() == SaveManager:
				sig.disconnect(connection.callable)
	await get_tree().process_frame
	visual = OS.get_cmdline_user_args().has("--visual")
	RunState.start_new_run()
	verify_rules()
	await verify_ui(false)
	await verify_ui(true)
	await verify_card_interactions()
	if visual:
		await verify_pointer_input()
	print("MANUAL_DISCARD_RESULT:%s PASS=%d FAIL=%d" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])


func card(id: StringName, upgraded := false) -> Dictionary:
	return {"id": id, "upgraded": upgraded, "enchants": []}


func verify_rules() -> void:
	var ctrl := CombatController.new()
	add_child(ctrl)
	ctrl.start_combat(["claylump"])
	var deck_before := RunState.deck.duplicate(true)
	var totals := {"discarded": 0, "played": 0, "drawn": 0, "exhausted": 0}
	var on_discard := func(_id): totals.discarded += 1
	var on_play := func(_id, _target): totals.played += 1
	var on_draw := func(_id): totals.drawn += 1
	var on_exhaust := func(_id): totals.exhausted += 1
	SignalBus.card_discarded.connect(on_discard)
	SignalBus.card_played.connect(on_play)
	SignalBus.card_drawn.connect(on_draw)
	SignalBus.card_exhausted.connect(on_exhaust)
	var before := ctrl.hand.duplicate(true)
	check("negative/out-of-range index rejected", not ctrl.discard_card(-1) and not ctrl.discard_card(ctrl.hand.size()) and ctrl.hand == before)
	ctrl.energy = 0
	var draw_before := ctrl.draw_pile.duplicate(true)
	var hp_before := ctrl.enemies[0].hp
	var player_hp := ctrl.player.hp
	# 所有已定义卡都可弃置，包括 ability/summon/exhaust/升级/附魔。
	for id in GameData.cards:
		var entry := card(id, true)
		entry.enchants = [GameData.enchants.keys()[0]]
		entry["instance_marker"] = String(id)
		ctrl.hand = [entry]
		check("zero-energy discard " + String(id), ctrl.discard_card(0) and ctrl.hand.is_empty() and ctrl.discard_pile.back() == entry)
	check("discard does not play/draw/exhaust or change resources", totals.played == 0 and totals.drawn == 0 and totals.exhausted == 0 and ctrl.energy == 0 and ctrl.kiln_heat == 0 and ctrl.player.block == 0 and ctrl.player.hp == player_hp and ctrl.enemies[0].hp == hp_before and ctrl.powers.is_empty() and ctrl.allies.is_empty() and not ctrl._first_attack_done and not ctrl._attack_played_this_turn)
	check("no extra draw and permanent deck unchanged", ctrl.draw_pile == draw_before and RunState.deck == deck_before)
	check("one discard signal per successful move", totals.discarded == GameData.cards.size())
	ctrl.hand = [card(&"strike"), card(&"strike", true), card(&"defend")]
	var last: Dictionary = ctrl.hand.back()
	check("duplicate IDs remove only selected index", ctrl.discard_card(1) and ctrl.hand.size() == 2 and not ctrl.hand[0].upgraded and ctrl.hand[1] == last and ctrl.discard_pile.back().upgraded)
	while not ctrl.hand.is_empty():
		check("repeat until hand empty", ctrl.discard_card(0))
	check("empty hand rejects without emitting", not ctrl.discard_card(0))
	ctrl.hand = [card(&"defend")]
	for phase in [CombatController.Phase.NONE, CombatController.Phase.ENEMY, CombatController.Phase.ENDED]:
		ctrl.phase = phase
		check("reject phase " + str(phase), not ctrl.discard_card(0) and ctrl.hand.size() == 1)
	ctrl.phase = CombatController.Phase.PLAYER
	ctrl._combat_active = false
	check("reject inactive combat", not ctrl.discard_card(0))
	ctrl._combat_active = true
	ctrl.player.hp = 0
	check("reject dead player", not ctrl.discard_card(0))
	ctrl.player.hp = player_hp
	ctrl.discard_pile.clear()
	ctrl.draw_pile.clear()
	var cycled := card(&"strike", true)
	cycled.enchants = [GameData.enchants.keys()[0]]
	ctrl.hand = [cycled]
	ctrl.discard_card(0)
	ctrl._draw_cards(1)
	check("discard reshuffles back with metadata intact", ctrl.discard_pile.is_empty() and ctrl.draw_pile.is_empty() and ctrl.hand == [cycled])
	ctrl.end_player_turn()
	check("end turn moves the unplayed card out of hand", ctrl.phase == CombatController.Phase.ENEMY and ctrl.hand.is_empty() and ctrl.discard_pile == [cycled])
	ctrl.enemy_phase_done()
	check("next turn can draw and manually discard the cycled card again", ctrl.phase == CombatController.Phase.PLAYER and ctrl.hand == [cycled] and ctrl.discard_card(0))
	SignalBus.card_discarded.disconnect(on_discard)
	SignalBus.card_played.disconnect(on_play)
	SignalBus.card_drawn.disconnect(on_draw)
	SignalBus.card_exhausted.disconnect(on_exhaust)
	ctrl.queue_free()


func frames(n := 4) -> void:
	for i in n:
		await get_tree().process_frame


func verify_ui(use_scene: bool) -> void:
	var signals_before := SignalBus.card_discarded.get_connections().size()
	ui = load("res://scenes/combat/CombatPlay.tscn").instantiate() if use_scene else CombatUI.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui)
	await frames()
	var label := ".tscn" if use_scene else ".new()"
	check(label + " pile visible inside viewport with touch-sized target", ui.discard_pile_view != null and ui.discard_pile_view.size.x >= 64 and ui.discard_pile_view.size.y >= 64 and get_viewport().get_visible_rect().encloses(ui.discard_pile_view.get_global_rect()))
	check(label + " initial pile count", ui.discard_pile_view.get_node("Content/Labels/Count").text == "弃牌堆\n0")
	ui.controller.energy = 0
	ui.controller.hand = [card(&"strike"), card(&"defend")]
	ui._refresh_all()
	await frames()
	var view: CardView = ui.hand_container.get_child(0)
	check(label + " insufficient-energy card remains draggable", view.mouse_filter == Control.MOUSE_FILTER_STOP)
	ui._targeting.on_card_tapped(view)
	check(label + " insufficient-energy tap cannot play", not ui._casting and ui.controller.hand.size() == 2 and ui.controller.discard_pile.is_empty())
	check(label + " insufficient-energy tap opens details", ui.card_browser_open())
	ui._close_card_browser()
	await get_tree().create_timer(0.35).timeout
	ui._targeting.on_card_drag_started(view)
	var pile_center := ui.discard_pile_view.get_global_rect().get_center()
	ui._targeting.on_card_drag_moved(view, pile_center)
	check(label + " discard hover and target", ui.drop_layer.hit_test(pile_center) == DropLayer.DISCARD_TARGET and ui.discard_pile_view.get_node("Content/Labels/Hint").text == "松手弃牌")
	ui._targeting.on_card_drag_ended(view, pile_center)
	ui._targeting.on_card_drag_ended(view, pile_center)
	check(label + " duplicate release is harmless", ui.controller.hand.size() == 1 and ui.controller.discard_pile.size() == 1)
	await get_tree().create_timer(0.3).timeout
	check(label + " discard animation releases locks/ghost and updates count", not ui._casting and not ui._drag_active and ui._ghost == null and ui.drag_layer.get_child_count() == 0 and ui.hand_container.get_child_count() == 1 and ui.discard_pile_view.get_node("Content/Labels/Count").text == "弃牌堆\n1")
	view = ui.hand_container.get_child(0)
	ui._targeting.on_card_drag_started(view)
	ui._targeting.on_card_drag_ended(view, Vector2(-100, -100))
	await get_tree().create_timer(0.25).timeout
	check(label + " invalid drop snaps back unchanged", ui.controller.hand.size() == 1 and ui.controller.discard_pile.size() == 1 and ui._ghost == null and not ui._casting)
	view = ui.hand_container.get_child(0)
	for lock in ["enemy", "ended", "director", "casting"]:
		ui.controller.phase = CombatController.Phase.ENEMY if lock == "enemy" else CombatController.Phase.PLAYER
		ui.combat_over = lock == "ended"
		BattleDirector.input_locked = lock == "director"
		ui._casting = lock == "casting"
		ui._targeting.on_card_drag_started(view)
		check(label + " UI rejects " + lock, not ui._drag_active and ui._ghost == null)
	ui.controller.phase = CombatController.Phase.PLAYER
	ui.combat_over = false
	BattleDirector.input_locked = false
	ui._casting = false
	ui._targeting.on_card_drag_started(view)
	ui.controller.phase = CombatController.Phase.ENEMY
	ui._targeting.on_card_drag_ended(view, pile_center)
	await get_tree().create_timer(0.25).timeout
	check(label + " phase changes during drag cancel discard", ui.controller.hand.size() == 1 and ui.controller.discard_pile.size() == 1 and ui._ghost == null)
	ui.controller.phase = CombatController.Phase.PLAYER
	ui.controller.draw_pile.clear()
	ui.controller._draw_cards(1)
	check(label + " reshuffle updates pile count", ui.discard_pile_view.get_node("Content/Labels/Count").text == "弃牌堆\n0")
	ui.queue_free()
	await frames()
	check(label + " signal cleanup", SignalBus.card_discarded.get_connections().size() == signals_before)


func motion(at: Vector2, held := false) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_viewport().push_input(ev, true)
	await frames(2)


func button(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = at
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	get_viewport().push_input(ev, true)
	await frames(2)


func pointer_drag(to: Vector2, capture_hover := false) -> void:
	var from: Vector2 = ui.hand_container.get_child(0).get_global_rect().get_center()
	await motion(from)
	await button(from, true)
	await motion(from + Vector2(0, -30), true)
	await motion(to, true)
	check("pointer drag starts outside source card", ui._drag_active)
	if capture_hover:
		check("pointer hover offers discard", ui.discard_pile_view.get_node("Content/Labels/Hint").text == "松手弃牌")
		check("drag ghost leaves drop prompt visible", ui._ghost != null and not ui._ghost.get_global_rect().intersects(ui.discard_pile_view.get_global_rect()))
		await capture("hover")
	await button(to, false)
	await get_tree().create_timer(0.4).timeout


func verify_pointer_input() -> void:
	ui = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	PauseManager.show_pause_button()
	await frames(8)
	await capture("ready")
	ui.controller.hand = [card(&"strike"), card(&"defend"), card(&"bash")]
	ui.controller.energy = 0
	ui._refresh_all()
	await frames()
	var dest := ui.discard_pile_view.get_global_rect().get_center()
	await pointer_drag(dest, true)
	check("pointer release over pile discards at zero energy", ui.controller.hand.size() == 2 and ui.controller.discard_pile.size() == 1 and ui.controller.energy == 0)
	await capture("discarded")
	await pointer_drag(Vector2(12, 400))
	check("pointer invalid drop keeps hand", ui.controller.hand.size() == 2 and ui.controller.discard_pile.size() == 1)
	await pointer_drag(dest)
	await pointer_drag(dest)
	check("pointer can discard all cards", ui.controller.hand.is_empty() and ui.controller.discard_pile.size() == 3 and ui.drag_layer.get_child_count() == 0)
	await capture("empty_hand")
	ui.controller.hand = [card(&"defend")]
	ui.controller.energy = GameData.get_card(&"defend").cost
	ui._refresh_all()
	await frames()
	await pointer_drag(ui.player_panel.get_global_rect().get_center())
	await get_tree().create_timer(1.0).timeout
	check("normal drag-to-play still resolves", ui.controller.hand.is_empty() and ui.controller.player.block > 0 and ui.controller.energy == 0)
	check("normal played card updates discard count", ui.discard_pile_view.get_node("Content/Labels/Count").text == "弃牌堆\n4")
	# 手牌多于可见区时，滚到末张并验证拖拽移除的仍是正确实例。
	ui.controller.hand.clear()
	for i in int(GameData.player_config().hand_max):
		var entry := card(&"strike")
		entry["instance_marker"] = i
		ui.controller.hand.append(entry)
	ui._refresh_all()
	await frames()
	var scroll: ScrollContainer = ui.hand_container.get_parent()
	var last_view: CardView = ui.hand_container.get_child(ui.hand_container.get_child_count() - 1)
	scroll.ensure_control_visible(last_view)
	await frames()
	var from := last_view.get_global_rect().get_center()
	await motion(from)
	await button(from, true)
	await motion(from + Vector2(0, -30), true)
	await motion(dest, true)
	await button(dest, false)
	await get_tree().create_timer(0.35).timeout
	check("scrolled card discards correct instance", ui.controller.hand.size() == int(GameData.player_config().hand_max) - 1 and ui.controller.discard_pile.back().get("instance_marker") == int(GameData.player_config().hand_max) - 1)
	# 真正轻点只查看详情，不结算卡牌。
	ui.controller.hand = [card(&"defend")]
	ui.controller.energy = GameData.get_card(&"defend").cost
	ui._refresh_all()
	await frames()
	var tap_at: Vector2 = ui.hand_container.get_child(0).get_global_rect().get_center()
	var block_before := ui.controller.player.block
	await motion(tap_at)
	await button(tap_at, true)
	await button(tap_at, false)
	await get_tree().create_timer(1.0).timeout
	check("normal tap opens details without playing", ui.card_browser_open() and ui.controller.hand.size() == 1 and ui.controller.player.block == block_before)
	ui._close_card_browser()
	ui.queue_free()
	await frames()
	ui = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	ui.pending_enemy_ids = ["claylump", "sootling", "claylump"]
	add_child(ui)
	await frames(8)
	check("three-enemy scene leaves discard pile inside viewport", get_viewport().get_visible_rect().encloses(ui.discard_pile_view.get_global_rect()))
	await capture("three_enemies")
	ui.queue_free()
	await frames()


func verify_card_interactions() -> void:
	RunState.start_new_run()
	ui = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	ui.pending_enemy_ids = ["claylump", "claylump"]
	add_child(ui)
	await frames()
	# 全卡库点击只读；详情使用实例的升级/附魔数据，未改变库存或资源。
	for id in GameData.cards:
		var cd: CardData = GameData.get_card(id)
		var entry := card(id, true)
		entry.enchants = [GameData.enchants.keys()[0]]
		ui.controller.hand = [entry]
		ui.controller.energy = cd.cost
		ui._refresh_all()
		await frames(1)
		var view: CardView = ui.hand_container.get_child(0)
		var before := interaction_state()
		var resolved_cost := ui.controller.card_cost(entry, cd)
		var cost_text := "X" if resolved_cost < 0 else str(resolved_cost)
		check("compact card " + String(id), view.get_node("Body").text == "%s+\n[%s能]" % [cd.name, cost_text] and not view.get_node("EnchantIcon").visible)
		view.tapped.emit(view)
		var browser = ui._card_browser
		check("read-only details " + String(id), ui.card_browser_open() and browser.entries == [entry] and not browser.selectable and browser._cards.columns == 1 and interaction_state() == before)
		var texts := ""
		for label in browser._cards.find_children("*", "Label", true, false):
			texts += label.text + "\n"
		check("full upgraded/enchant text " + String(id), texts.contains(cd.get_description(true)) and texts.contains(GameData.get_enchant(entry.enchants[0]).description))
		ui._targeting.on_end_turn()
		ui._targeting.on_card_drag_started(view)
		check("details block underlying actions " + String(id), interaction_state() == before and not ui._drag_active)
		if visual and id == &"strike":
			await capture("card_details")
		ui._close_card_browser()
		await frames(1)
	await verify_popup_layout()
	# 用真实视口事件验证点击和拖拽分离，并指定第二个敌人而非默认目标。
	await prepare_interaction_card(&"strike")
	var tap_at: Vector2 = ui.hand_container.get_child(0).get_global_rect().get_center()
	var before := interaction_state()
	await motion(tap_at)
	await button(tap_at, true)
	await button(tap_at, false)
	check("pointer tap cannot spend or attack", ui.card_browser_open() and interaction_state() == before)
	var back_at: Vector2 = ui.end_turn_btn.get_global_rect().get_center()
	await motion(back_at)
	await button(back_at, true)
	await button(back_at, false)
	check("outside click closes without activating end turn", not ui.card_browser_open() and interaction_state() == before)
	# 直接调用旧施放入口也不能绕过拖拽。
	ui._targeting.cast_card(ui.hand_container.get_child(0), 0)
	check("no non-drag cast path", interaction_state() == before and not ui._casting)
	await pointer_drag(ui.player_panel.get_global_rect().get_center())
	check("attack on player snaps back", interaction_state() == before and ui._ghost == null)
	var second: Control = ui.unit_panels[ui.controller.enemies[1]]
	var first_hp := ui.controller.enemies[0].hp
	var second_hp := ui.controller.enemies[1].hp
	await pointer_drag(second.get_global_rect().get_center())
	await get_tree().create_timer(1.0).timeout
	check("attack hits dropped enemy only", ui.controller.enemies[0].hp == first_hp and ui.controller.enemies[1].hp < second_hp and ui.controller.hand.is_empty() and ui.controller.energy == 0)
	await prepare_interaction_card(&"defend")
	before = interaction_state()
	await pointer_drag(second.get_global_rect().get_center())
	check("self card on enemy snaps back", interaction_state() == before)
	await pointer_drag(ui.player_sprite.get_global_rect().get_center())
	await get_tree().create_timer(1.0).timeout
	check("self card on player sprite grants block", ui.controller.hand.is_empty() and ui.controller.player.block > before.block and ui.controller.energy == 0)
	# 群体目标依旧由数据定义：在任一敌人上松手，所有敌人受到效果。
	var area_id: StringName = &""
	for id in GameData.cards:
		var cd: CardData = GameData.get_card(id)
		if cd.target == &"all_enemies" and cd.effects.any(func(effect): return effect.get("kind") == "aoe_damage"):
			area_id = id
			break
	check("area damage fixture exists", area_id != &"")
	if area_id != &"":
		await prepare_interaction_card(area_id)
		first_hp = ui.controller.enemies[0].hp
		second_hp = ui.controller.enemies[1].hp
		await pointer_drag(second.get_global_rect().get_center())
		await get_tree().create_timer(1.0).timeout
		check("area card dropped on enemy affects all", ui.controller.enemies[0].hp < first_hp and ui.controller.enemies[1].hp < second_hp and ui.controller.hand.is_empty())
	await prepare_interaction_card(&"strike")
	ui.controller.energy = 0
	ui._refresh_all()
	await frames()
	before = interaction_state()
	await pointer_drag(second.get_global_rect().get_center())
	check("insufficient energy cannot play by drag", interaction_state() == before and ui._ghost == null)
	await pointer_drag(ui.discard_pile_view.get_global_rect().get_center())
	check("insufficient energy can still discard", ui.controller.hand.is_empty() and ui.controller.energy == 0)
	ui.queue_free()
	await frames()


func verify_popup_layout() -> void:
	await prepare_interaction_card(&"defend")
	var view: CardView = ui.hand_container.get_child(0)
	view.tapped.emit(view)
	await frames(5)
	var popup = ui._card_browser
	var rect: Rect2 = popup._popup.get_global_rect()
	check("single card is a nearby compact popup", rect.size.x > view.size.x and rect.size.x <= view.size.x * 1.9 and rect.size.y > view.size.y and rect.size.y <= view.size.y * 1.7 and rect.end.y <= view.global_position.y)
	check("popup stays inside viewport without dimming combat", get_viewport().get_visible_rect().encloses(rect) and popup._cover.color.a == 0.0)
	var small_fonts := true
	for text in popup._cards.find_children("*", "Label", true, false):
		small_fonts = small_fonts and text.get_theme_font_size("font_size") <= 22
	check("popup uses small fonts without full page heading or footer", small_fonts and popup._back == null and popup._title == "")
	if visual:
		await capture("compact_defend_details")
	var at := rect.get_center()
	await motion(at)
	await button(at, true)
	await button(at, false)
	check("clicking popup content does not dismiss", ui.card_browser_open())
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	get_viewport().push_input(cancel, true)
	await frames()
	check("escape closes floating details", not ui.card_browser_open())
	# 长详情保留全部文字并滚动，不撑大浮窗；右侧手牌浮窗不会越界。
	ui.controller.hand.clear()
	for i in int(GameData.player_config().hand_max):
		var entry := card(&"bash", true)
		entry.enchants = GameData.enchants.keys()
		ui.controller.hand.append(entry)
	ui._refresh_all()
	await frames()
	view = ui.hand_container.get_child(ui.hand_container.get_child_count() - 1)
	ui.hand_container.get_parent().ensure_control_visible(view)
	await frames()
	view.tapped.emit(view)
	await frames(5)
	popup = ui._card_browser
	rect = popup._popup.get_global_rect()
	check("rightmost long detail is clamped and scrollable", get_viewport().get_visible_rect().encloses(rect) and rect.size.y <= view.size.y * 1.7 and popup._scroll.get_v_scroll_bar().max_value > popup._scroll.get_v_scroll_bar().page)
	var labels: Array = popup._cards.find_children("*", "Label", true, false)
	var last_label: Label = labels.back()
	popup._scroll.ensure_control_visible(last_label)
	await frames()
	check("long details can scroll to the last line", popup._scroll.get_global_rect().encloses(last_label.get_global_rect()))
	if visual:
		await capture("compact_details_scrolled")
	ui._close_card_browser()
	await frames()


func prepare_interaction_card(id: StringName) -> void:
	ui.controller.hand = [card(id)]
	ui.controller.energy = GameData.get_card(id).cost
	# 测试敌人保活，避免结算胜利造成场景跳转。
	for enemy in ui.controller.enemies:
		enemy.hp = 1000
	ui._refresh_all()
	await frames()


func interaction_state() -> Dictionary:
	return {"hand": ui.controller.hand.duplicate(true), "energy": ui.controller.energy,
		"block": ui.controller.player.block, "hp": ui.controller.player.hp,
		"enemy_hp": ui.controller.enemies.map(func(enemy): return enemy.hp),
		"discard": ui.controller.discard_pile.duplicate(true), "heat": ui.controller.kiln_heat,
		"phase": ui.controller.phase}


func capture(label: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	check("screenshot " + label, get_viewport().get_texture().get_image().save_png("res://Temp/manual_discard_" + label + ".png") == OK)
