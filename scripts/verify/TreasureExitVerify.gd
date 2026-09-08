extends Node
## 使用正式宝箱场景验证发奖+退出；-- --visual 额外注入鼠标点击。
## 自动存档断开，仅改测试进程的内存态。测试 fixture 数字不是玩法配置。

const TreasureScene := preload("res://scenes/map/TreasureUI.tscn")
var passed := 0
var failed := 0


func _ready() -> void:
	for sig in [SignalBus.combat_ended, SignalBus.floor_entered, SignalBus.act_changed, SignalBus.run_ended]:
		for connection in sig.get_connections():
			if connection.callable.get_object() == SaveManager:
				sig.disconnect(connection.callable)
	await get_tree().process_frame
	for mode in ["card", "relic", "potion", "full_potions", "all_relics", "all_rewards_empty", "empty_cards", "empty_potions", "missing_icon"]:
		await verify_scene(mode)
	await verify_callback()
	verify_detached()
	if OS.get_cmdline_user_args().has("--visual"):
		for choice in 3:
			await verify_click(choice)
	print("TREASURE_EXIT_RESULT:%s PASS=%d FAIL=%d" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func check(label: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])


func open_treasure() -> Control:
	var tree := get_tree()
	if tree.current_scene != self and tree.current_scene != null:
		var previous := tree.current_scene
		tree.root.remove_child(previous)
		previous.queue_free()
	var ui: Control = TreasureScene.instantiate()
	tree.root.add_child(ui)
	tree.current_scene = ui
	return ui


func inventory_sizes() -> Array:
	return [RunState.deck.size(), RunState.relic_ids.size(), RunState.potions.size()]


func verify_scene(mode: String) -> void:
	RunState.start_new_run()
	var saved_cards: Dictionary = GameData.cards.duplicate()
	var saved_potions: Dictionary = GameData.potions.duplicate()
	var saved_icons := {}
	var choice := 0
	var expected := [0, 0, 0]
	match mode:
		"card": expected[0] = 1
		"relic", "missing_icon":
			choice = 1
			expected[1] = 1
			if mode == "missing_icon":
				for id in GameData.relics:
					saved_icons[id] = GameData.relics[id].icon
					GameData.relics[id].icon = ""
		"potion":
			choice = 2
			expected[2] = 1
		"full_potions":
			choice = 2
			for i in RunState._potion_cap():
				RunState.potions.append(GameData.potions.keys()[0])
		"all_relics", "all_rewards_empty":
			choice = 1
			for id in GameData.relics:
				RunState.relic_ids.append(id)
			if mode == "all_rewards_empty":
				GameData.cards.clear()
			else:
				expected[0] = 1
		"empty_cards": GameData.cards.clear()
		"empty_potions":
			choice = 2
			GameData.potions.clear()
	var tree := get_tree()
	var ui = open_treasure()
	await tree.process_frame
	var buttons: Array = ui._choice_buttons
	check(mode + " exactly three controls and one connection each", buttons.size() == 3 and buttons.all(func(b): return b.pressed.get_connections().size() == 1))
	var before := inventory_sizes()
	# 库存信号同步重入：发奖尚未返回时尝试领取其他奖励。
	var on_deck := func():
		ui._on_take_card()
		ui._on_take_relic()
		ui._on_take_potion()
	var on_relic := func(_id):
		ui._on_take_card()
		ui._on_take_relic()
		ui._on_take_potion()
	SignalBus.deck_changed.connect(on_deck)
	SignalBus.relic_gained.connect(on_relic)
	buttons[choice].pressed.emit()
	SignalBus.deck_changed.disconnect(on_deck)
	SignalBus.relic_gained.disconnect(on_relic)
	# 结果页停留期间，重复领取仍应安全。
	for button in buttons:
		button.pressed.emit()
	if choice == 2 and expected[2] == 1:
		await tree.process_frame
		var potion: PotionData = GameData.get_potion(RunState.potions.back())
		check("potion waits on result with granted name and icon", ui.is_inside_tree() and not ui._finished and ui._result_panel.visible and ui._result_name.text == potion.name and ui._result_icon.texture == GameData.icon_texture(potion.icon))
		check("potion effect initially waits for icon click", ui._result_description.text == "点击药水图标查看效果")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		ui._result_icon.gui_input.emit(click)
		check("potion icon reveals exact effect without consuming potion", ui._result_description.text == potion.description and RunState.potions.size() == before[2] + 1)
		ui._continue_button.pressed.emit()
	if choice == 1:
		await tree.process_frame
		check(mode + " waits on result until explicit continue", ui.is_inside_tree() and ui._result_panel.visible and not ui._choice_panel.visible and not ui._finished and not RunState.pending_node_resolved)
		if expected[1] == 1:
			var relic: RelicData = GameData.get_relic(RunState.relic_ids.back())
			check(mode + " displays granted relic name and effect", ui._result_name.text == relic.name and ui._result_description.text == relic.description)
			check(mode + " icon or safe fallback", ui._result_icon.visible == (GameData.icon_texture(relic.icon) != null))
		else:
			check(mode + " explains fallback", ui._result_description.text.contains("遗物已全部拥有"))
		ui._continue_button.pressed.emit()
	ui._finish()
	ui._finish()
	var after := inventory_sizes()
	check(mode + " exactly the expected reward, despite reentry", after == [before[0]+expected[0], before[1]+expected[1], before[2]+expected[2]])
	check(mode + " all choices disabled", buttons.all(func(b): return b.disabled))
	check(mode + " leaves scene and resolves node", not ui.is_inside_tree() and RunState.pending_node_resolved)
	# 在地图重新构建前恢复测试临时置空的数据表。
	GameData.cards = saved_cards
	GameData.potions = saved_potions
	for id in saved_icons:
		GameData.relics[id].icon = saved_icons[id]
	if not ui.is_inside_tree():
		await tree.scene_changed
	check(mode + " returns to map and consumes resolution flag", tree.current_scene.scene_file_path == "res://scenes/map/MapPlay.tscn" and not RunState.pending_node_resolved)


func verify_callback() -> void:
	RunState.start_new_run()
	var ui = TreasureScene.instantiate()
	var calls := [0]
	ui.setup(func(): calls[0] += 1)
	add_child(ui)
	check("setup then ready does not duplicate controls", ui.find_children("*", "Button", true, false).size() == 4)
	var before := inventory_sizes()
	ui._on_take_relic()
	ui._on_take_card()
	ui._on_take_potion()
	check("legacy result waits before invoking callback", calls[0] == 0 and not ui.is_queued_for_deletion() and ui._result_panel.visible)
	ui._continue_button.pressed.emit()
	ui._finish()
	check("legacy callback fires once and queues close", calls[0] == 1 and ui.is_queued_for_deletion())
	check("legacy path grants only chosen reward", inventory_sizes() == [before[0], before[1]+1, before[2]])
	await get_tree().process_frame
	check("legacy overlay is freed", not is_instance_valid(ui))


func verify_detached() -> void:
	var ui = TreasureScene.instantiate()
	var before := inventory_sizes()
	ui._on_take_card()
	ui._on_take_relic()
	ui._on_take_potion()
	ui._finish()
	check("detached instance rejects input and completion safely", inventory_sizes() == before)
	ui.free()


func verify_click(choice: int) -> void:
	RunState.start_new_run()
	var tree := get_tree()
	var ui = open_treasure()
	for i in 5:
		await tree.process_frame
	var button: Button = ui._choice_buttons[choice]
	var at := button.get_global_rect().get_center()
	var before := inventory_sizes()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		get_viewport().push_input(event, true)
		if down:
			await tree.process_frame
	if choice in [1, 2]:
		for i in 5:
			await tree.process_frame
		check("pointer reward click stays on result", ui.is_inside_tree() and ui._result_panel.visible)
		if choice == 2:
			at = ui._result_icon.get_global_rect().get_center()
			for down in [true, false]:
				var icon_click := InputEventMouseButton.new()
				icon_click.position = at
				icon_click.button_index = MOUSE_BUTTON_LEFT
				icon_click.pressed = down
				get_viewport().push_input(icon_click, true)
				await tree.process_frame
			var potion: PotionData = GameData.get_potion(RunState.potions.back())
			check("real pointer reveals potion effect", ui._result_description.text == potion.description)
		await RenderingServer.frame_post_draw
		check("reward result screenshot", get_viewport().get_texture().get_image().save_png("res://Temp/treasure_result_%d.png" % choice) == OK)
		check("result and continue fit viewport", get_viewport().get_visible_rect().encloses(ui._result_panel.get_global_rect()))
		at = ui._continue_button.get_global_rect().get_center()
		motion = InputEventMouseMotion.new()
		motion.position = at
		get_viewport().push_input(motion, true)
		for down in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = at
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			get_viewport().push_input(event, true)
			if down:
				await tree.process_frame
	check("pointer click %d starts return" % choice, not ui.is_inside_tree())
	if not ui.is_inside_tree():
		await tree.scene_changed
	var expected := before.duplicate()
	expected[choice] += 1
	check("pointer click %d rewards once and returns to map" % choice, inventory_sizes() == expected and tree.current_scene.scene_file_path == "res://scenes/map/MapPlay.tscn")
