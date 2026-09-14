extends Node
## 短卡牌描述曾导致尺寸回调重入并原生崩溃；真实点击并等待布局稳定。
var failures := 0

func check(ok: bool, message: String) -> void:
	print("[PASS] " if ok else "[FAIL] ", message)
	if not ok: failures += 1

func _ready() -> void:
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/shrug_crash_save.json"
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	var ui = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	ui.pending_enemy_ids = ["claylump"]
	add_child(ui)
	for i in 15: await get_tree().process_frame
	ui.controller.hand = [{"id": &"shrug_it_off", "upgraded": false, "enchants": []}]
	ui._refresh_all()
	for i in 15: await get_tree().process_frame
	var before_energy: int = ui.controller.energy
	for attempt in 10:
		ui.controller.hand[0].upgraded = attempt >= 5
		ui._refresh_all()
		for i in 10: await get_tree().process_frame
		print("SHRUG_CLICK ", attempt)
		var view: Control = ui.hand_container.get_child(0)
		var at: Vector2 = view.get_global_transform_with_canvas() * (view.size * 0.5)
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = at
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			get_viewport().push_input(event, true)
			await get_tree().process_frame
		for i in 60: await get_tree().process_frame
		check(ui.card_browser_open(), "details open")
		if not ui.card_browser_open(): break
		if attempt in [2, 7]:
			get_window().size = Vector2i(810, 1440) if attempt == 2 else Vector2i(720, 1280)
			for i in 30: await get_tree().process_frame
		var face: Control = ui._card_browser._cards.find_child("CardImage", true, false)
		var art: TextureRect = face.get_node("CardArt")
		check(absf(art.size.x - art.size.y) < 1.0, "art remains square")
		var settled_size := face.size
		for i in 20: await get_tree().process_frame
		check(face.size.is_equal_approx(settled_size) and not face.is_processing(), "layout converges and stops updating")
		check(ui.controller.energy == before_energy, "details do not spend energy")
		print("SHRUG_OPEN ", attempt)
		ui._close_card_browser()
		for i in 10: await get_tree().process_frame
	print("CARD_POPUP_STABILITY_RESULT FAIL=", failures)
	get_tree().quit(0 if failures == 0 else 1)
