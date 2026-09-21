extends Node
## 保留原测试入口，验证主动弃牌已移除、叠牌图标数量和只读浏览。
var failed := 0
var passed := 0
var ui: CombatUI
var visual := false

func _ready() -> void:
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/pile_icons_verify_save.json"
	visual = OS.get_cmdline_user_args().has("--visual")
	for authored in [true, false]:
		RunState.start_new_run()
		RunState.pre_run_preparation_resolved = true
		RunState.pending_combat_enemy_ids = [&"claylump"]
		ui = load("res://scenes/combat/CombatPlay.tscn").instantiate() if authored else CombatUI.new()
		add_child(ui)
		await frames()
		check("manual discard controller API removed", not ui.controller.has_method("discard_card"))
		for pile in [ui.draw_pile_button, ui.discard_pile_view]:
			check("pile icon fits viewport", get_viewport().get_visible_rect().encloses(pile.get_global_rect()))
			check("pile touch target", pile.size.x >= 64 and pile.size.y >= 64)
		check("draw pile uses generated stack", ui.draw_pile_button.get_node("Icon").texture.resource_path.ends_with("ICO_DrawPile_v2.png"))
		check("discard pile uses generated stack", ui.discard_pile_view.get_node("Content/Icon").texture.resource_path.ends_with("ICO_DiscardPile_v2.png"))
		check("no discard drop instruction", ui.discard_pile_view.get_node_or_null("Content/Labels/Hint") == null)
		for energy in [0, 3]:
			for id in [&"strike", &"defend", &"wound", &"dazed"]:
				ui.controller.hand = [{"id": id, "upgraded": true, "enchants": [], "fixture": "preserved"}]
				ui.controller.energy = energy
				ui._refresh_all()
				await frames()
				var before := state()
				var view: CardView = ui.hand_container.get_child(0)
				var destination := ui.discard_pile_view.get_global_rect().get_center()
				ui._targeting.on_card_drag_started(view)
				ui._targeting.on_card_drag_moved(view, destination)
				check("discard icon is never a legal target " + String(id), ui.drop_layer.hit_test(destination) == -2)
				ui._targeting.on_card_drag_ended(view, destination)
				await get_tree().create_timer(0.25).timeout
				check("drop preserves all combat state " + String(id), state() == before)
				check("rejected drop clears drag locks", not ui._casting and not ui._drag_active and ui._ghost == null)
		ui.controller.hand = [{"id": &"defend", "upgraded": false, "enchants": []}]
		ui.controller.energy = 3
		ui.controller.draw_pile = [{"id": &"strike"}, {"id": &"bash"}]
		ui.controller.discard_pile = [{"id": &"anger"}]
		ui._refresh_all()
		await frames()
		check("both counters show live numbers", ui.draw_pile_button.get_node("Count").text == "2" and ui.discard_pile_view.get_node("Content/Labels/Count").text == "1")
		var before := state()
		ui.draw_pile_button.pressed.emit()
		check("draw icon opens ordered read-only browser", ui.card_browser_open() and not ui._card_browser.selectable and ui._card_browser.entries[0].id == &"strike")
		ui._close_card_browser()
		await frames()
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		ui.discard_pile_view.gui_input.emit(click)
		check("discard icon opens read-only browser", ui.card_browser_open() and not ui._card_browser.selectable)
		ui._close_card_browser()
		await frames()
		check("browsing piles does not change combat", state() == before)
		check("normal play still works", ui.controller.play_card(0, -1))
		await frames()
		check("played card still reaches discard and counter", ui.controller.discard_pile.size() == 2 and ui.discard_pile_view.get_node("Content/Labels/Count").text == "2")
		if visual and authored:
			ui.controller.hand = [{"id": &"strike"}, {"id": &"defend"}, {"id": &"anger"}]
			ui._refresh_all()
			await frames()
			await pointer_drop_on_pile()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://Temp/pile_icons_combat.png")
		ui.queue_free()
		await frames()
	print("PILE_ICONS_RESULT:%s PASS=%d FAIL=%d" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func pointer_drop_on_pile() -> void:
	var before := state()
	for pile in [ui.draw_pile_button, ui.discard_pile_view]:
		var at: Vector2 = pile.get_global_rect().get_center()
		await mouse_button(at, true)
		await mouse_button(at, false)
		check("real pointer clicks through icon to read-only browser", ui.card_browser_open() and not ui._card_browser.selectable)
		ui._close_card_browser()
		await frames()
	var start: Vector2 = ui.hand_container.get_child(0).get_global_rect().get_center()
	var destination := ui.discard_pile_view.get_global_rect().get_center()
	await mouse_button(start, true)
	for at in [start + Vector2(0, -35), destination]:
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
		await frames()
	check("real pointer starts card drag", ui._drag_active)
	await mouse_button(destination, false)
	await get_tree().create_timer(0.3).timeout
	check("real pointer drop cannot discard or open pile", state() == before and not ui.card_browser_open() and not ui._drag_active)

func mouse_button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	get_viewport().push_input(event, true)
	await frames()

func state() -> Dictionary:
	return {"hand": ui.controller.hand.duplicate(true), "draw": ui.controller.draw_pile.duplicate(true), "discard": ui.controller.discard_pile.duplicate(true), "energy": ui.controller.energy, "hp": ui.controller.player.hp, "block": ui.controller.player.block, "enemies": ui.controller.enemies.map(func(enemy): return enemy.hp)}

func frames() -> void:
	for i in 6: await get_tree().process_frame

func check(label: String, ok: bool) -> void:
	if ok: passed += 1
	else: failed += 1
	print("[PASS] " if ok else "[FAIL] ", label)
