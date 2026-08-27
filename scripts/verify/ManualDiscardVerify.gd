extends Node
## 运行：Godot --headless --path . scenes/verify/ManualDiscardVerify.tscn
## 图形验证：去掉 --headless，追加 -- --visual；截图存 logs/manual_discard_*.png。
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
	var retained := card(&"strike", true)
	retained.enchants = [GameData.enchants.keys()[0]]
	ctrl.hand = [retained]
	ctrl.discard_card(0)
	ctrl._draw_cards(1)
	check("discard reshuffles back with metadata intact", ctrl.discard_pile.is_empty() and ctrl.draw_pile.is_empty() and ctrl.hand == [retained])
	ctrl.end_player_turn()
	ctrl.enemy_phase_done()
	check("next turn can discard again, retained hand unaffected", ctrl.phase == CombatController.Phase.PLAYER and ctrl.hand == [retained] and ctrl.discard_card(0))
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
	# 真正轻点保持原出牌行为。
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
	check("normal tap still plays", ui.controller.hand.is_empty() and ui.controller.player.block > block_before)
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


func capture(label: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	check("screenshot " + label, get_viewport().get_texture().get_image().save_png("res://logs/manual_discard_" + label + ".png") == OK)
