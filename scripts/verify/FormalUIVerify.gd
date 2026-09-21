extends Node
## 串行验证正式 UI 场景、交互绑定、弹窗边界；--visual 额外输出真实渲染截图。

var failed := 0
var visual := false
var reward_claimed := false

func _ready() -> void:
	# End-of-run routing may replace current_scene; keep this suite alive like the entry-flow harness.
	get_tree().current_scene = null
	visual = OS.get_cmdline_user_args().has("--visual")
	if visual:
		get_tree().root.size = Vector2i(1080, 1920)
	_verify_authored_scenes()
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/formal_ui_verify_save.json"
	await get_tree().process_frame
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	var menu := await show_scene("res://scenes/main/MainMenu.tscn", "home")
	check(menu.get_node("MenuCenter/MenuColumn/PlayButton/Surface").texture == load("res://art/ui/main_menu/OptionSlate.tres"), "menu uses shared translucent slate button")
	await remove_screen(menu)
	var map_ui := await show_scene("res://scenes/map/MapPlay.tscn", "map")
	check(map_ui.has_node("FormalHeader"), "map header")
	check(get_tree().root.content_scale_size == Vector2i(720, 1280), "720x1280 shared editor and runtime canvas")
	check(is_equal_approx(get_tree().root.content_scale_factor, 1.0), "window stretch handles output scaling without extra content scaling")
	var legend: Control = map_ui.get_node("MapLegend")
	check(map_ui.get_global_rect().encloses(legend.get_global_rect()), "entire legend stays in viewport")
	check(legend.position.x >= map_ui.map_scroller.get_rect().end.x, "legend has a separate right column")
	check(legend.size.x >= 215.0, "legend artwork has readable width")
	var legend_inner: Rect2 = legend.get_global_rect().grow(-14.0)
	check(legend_inner.encloses(legend.get_node("Column/Title").get_global_rect()), "legend title clears artwork edges")
	for entry in FormalUI.MAP_LEGEND:
		var row := legend.find_child(String(entry[0]), true, false)
		check(row != null and row.get_node("Heading/Icon").texture != null, "legend icon: " + String(entry[0]))
		check(row.get_node("Heading/Icon").size.x >= 48.0 and legend_inner.encloses(row.get_node("Description").get_global_rect()), "legend icon size and description inset: " + String(entry[0]))
	var legend_position := legend.global_position
	map_ui.map_scroller.scroll_vertical = 0
	await capture("map_top")
	check(legend.global_position == legend_position, "legend remains fixed while map scrolls")
	for node in map_ui.map_area.get_children():
		if node is Button:
			check(node.position.x >= 0 and node.get_rect().end.x <= map_ui.map_area.size.x, "map node stays inside route column")
	map_ui._build_map_view()
	await get_tree().process_frame
	var clickable := 0
	for node in map_ui.map_area.get_children():
		if node is Button and not node.disabled:
			clickable += 1
	check(clickable == 1, "single map starting node remains reachable")
	PauseManager._open_pause()
	await capture("pause")
	check(get_tree().paused, "pause freezes game")
	PauseManager._close_pause()
	check(not get_tree().paused, "resume unpauses")
	await remove_screen(map_ui)
	# 仅验证进程的测试钱包，确保可购买状态也覆盖。
	RunState.gold = int(GameData.balance["shop"]["remove_card_cost"]) + int(GameData.balance["shop"]["enchant_cost"])
	var shop := await show_scene("res://scenes/map/ShopUI.tscn", "shop")
	var footer: Control = shop.get_node("Dim/Center/MainPanel/Footer")
	for heading in ["CardTitle", "RelicTitle", "PotionTitle"]:
		var label: Label = shop.get_node("Dim/Center/MainPanel/ContentScroll/Content/" + heading)
		var frame: StyleBox = label.get_theme_stylebox("normal")
		check(label.size.x >= 150.0 and label.size.y >= 58.0 and frame.get_content_margin(SIDE_LEFT) >= 18.0 and frame.get_content_margin(SIDE_TOP) >= 14.0, "shop artwork and title inset: " + heading)
	check(footer.get_global_rect().end.y <= get_viewport().get_visible_rect().end.y, "shop footer stays in viewport")
	check(shop.get_node("Dim/Center/MainPanel/ContentScroll/Content/CardScroll/CardRow").get_child_count() == shop.card_stock.size(), "all configured card offers shown")
	shop._build_main()
	await capture("shop_refresh")
	check(shop.get_node("Dim/Center/MainPanel/Footer/LeaveButton").pressed.get_connections().size() == 1, "shop refresh preserves single leave callback")
	shop._build_enchant(0)
	await capture("shop_enchant")
	shop._build_main()
	await capture("shop_return")
	check(shop.has_node("Dim/Center/MainPanel/Footer"), "shop subpage returns to formal layout")
	await remove_screen(shop)
	for path in ["map/RestUI", "map/TreasureUI", "map/AltarUI", "town/Town", "main/PreRunPreparation"]:
		if path == "main/PreRunPreparation":
			# 测试准备页须有候选，避免已完成准备的 Run 自动切回地图。
			RunState.pre_run_preparation_resolved = false
			var config := GameData.ad_placement_config(PreRunBuffSystem.PLACEMENT)
			RunState.pre_run_buff_offer_ids.assign(config["buff_ids"].slice(0, int(config["choice_count"])))
		var extra := await show_scene("res://scenes/" + path + ".tscn", path.get_file())
		check(extra.size == get_viewport().get_visible_rect().size, "page fills logical viewport: " + path)
		await remove_screen(extra)
	RunState.pre_run_preparation_resolved = true
	RunState.pre_run_buff_offer_ids.clear()
	var event := await show_scene("res://scenes/map/EventUI.tscn", "event")
	var panel: Control = event.get_node("Dim/Center/MainPanel")
	for event_data in GameData.events:
		event._event = event_data
		event._build_main()
		for frame in 5:
			await get_tree().process_frame
		check(panel.get_global_rect().encloses(event.get_node("Dim/Center/MainPanel/Content/Title").get_global_rect()), "event title inside panel: " + str(event_data.get("title", "")))
		for button in event._choice_buttons:
			check(panel.get_global_rect().encloses(button.get_global_rect()), "event option inside panel")
	await capture("event")
	event._choice_buttons[-1].pressed.emit()
	await capture("event_result")
	await remove_screen(event)
	RunState.pending_reward_data = {"tier": &"combat", "gold": 20, "cards": RewardBuilder.roll_card_choices(3, &"combat")}
	var reward := await show_scene("res://scenes/rewards/RewardUI.tscn", "reward")
	RunState.upgrade_shards = RunState.upgrade_shard_cost()
	check(reward.get_node("Dim/Center/MainPanel/Content/CardScroll/Cards").get_child_count() == 3, "reward choices retained")
	reward._build_upgrade()
	await capture("upgrade")
	# Upgrade selection is now a modal; close it before clicking the underlying reward.
	var upgrade_picker: CanvasLayer = reward.get("_upgrade_picker")
	if is_instance_valid(upgrade_picker):
		upgrade_picker.close()
		await get_tree().process_frame
	reward._build_main()
	await capture("reward_return")
	check(reward.has_node("Dim/Center/MainPanel/Content/Actions"), "reward returns to formal layout")
	var before_count := RunState.deck.size()
	reward.on_done = func(): reward_claimed = true
	var first_card: Button = reward.get_node("Dim/Center/MainPanel/Content/CardScroll/Cards").get_child(0)
	if visual:
		var point := first_card.get_global_rect().position + Vector2(60, 90)
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = get_viewport().get_final_transform() * point
			click.pressed = pressed
			Input.parse_input_event(click)
			await get_tree().process_frame
		while TransitionManager.is_transitioning:
			await get_tree().process_frame
		check(reward_claimed and RunState.deck.size() == before_count + 1, "card text overlay passes real pointer clicks to reward")
	else:
		first_card.pressed.emit()
		while TransitionManager.is_transitioning:
			await get_tree().process_frame
		check(reward_claimed and RunState.deck.size() == before_count + 1, "reward callback acquires card")
	await remove_screen(reward)
	map_ui = await show_scene("res://scenes/map/MapPlay.tscn", "map_return")
	RunState.end_run(false)
	map_ui._show_result(false)
	await capture("defeat")
	check(map_ui.find_child("ReturnTownButton", true, false) != null, "defeat retains town exit")
	await remove_screen(map_ui)
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	var combat := await show_scene("res://scenes/combat/CombatPlay.tscn", "combat")
	check(combat.controller.hand.size() > 0, "combat starts with background and hand")
	PauseManager._open_pause()
	await capture("combat_pause")
	PauseManager._close_pause()
	await remove_screen(combat)
	print("FORMAL_UI_RESULT:%s FAIL=%d" % ["PASS" if failed == 0 else "FAIL", failed])
	get_tree().quit(0 if failed == 0 else 1)

func show_scene(path: String, screenshot: String) -> Node:
	var screen := (load(path) as PackedScene).instantiate()
	add_child(screen)
	await capture(screenshot)
	return screen

func remove_screen(screen) -> void:
	if not is_instance_valid(screen):
		return
	remove_child(screen)
	screen.queue_free()
	await get_tree().process_frame

func capture(file: String) -> void:
	for i in 5:
		await get_tree().process_frame
	if visual:
		await RenderingServer.frame_post_draw
		var rendered := get_viewport().get_texture().get_image()
		check(rendered.get_size() == Vector2i(1080, 1920), "native 1080x1920 render: " + file)
		var result := rendered.save_png("res://Temp/formal_" + file + ".png")
		check(result == OK, "capture " + file)

func check(ok: bool, title: String) -> void:
	if not ok:
		failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", title])

func _verify_authored_scenes() -> void:
	# 不加入 SceneTree，不执行 _ready：确保编辑器加载时资源已经就绪。
	var paths := ["main/MainMenu", "map/MapPlay", "map/EventUI", "map/ShopUI", "rewards/RewardUI", "ui/PauseMenu", "ui/RunResult", "combat/CombatPlay"]
	for path in paths:
		var screen := (load("res://scenes/" + path + ".tscn") as PackedScene).instantiate()
		if path == "main/MainMenu":
			check(screen.get_node("Background").texture != null and screen.has_node("MenuCenter/MenuColumn/Logo"), "authored main menu background and logo")
			check(screen.theme.get_stylebox("normal", "Button") is StyleBoxTexture, "authored menu button theme")
		elif path in ["map/EventUI", "rewards/RewardUI"]:
			check(screen.get_node("Dim/Center/MainPanel").get_theme_stylebox("panel") is StyleBoxTexture, "authored popup skin: " + path)
			check(screen.get_node("FormalMapBackdrop/Background").texture != null, "authored popup background: " + path)
		elif path in ["map/MapPlay", "combat/CombatPlay"]:
			check(screen.get_node("FormalBackground").texture != null, "authored background: " + path)
		elif path == "map/ShopUI":
			check(screen.get_node("FormalShopBackground").texture != null and screen.has_node("Dim/Center/MainPanel/FooterBackground"), "authored shop background and footer")
		else:
			check(screen.find_child("QuitButton" if path == "ui/PauseMenu" else "RestartButton", true, false) != null, "authored overlay buttons: " + path)
		screen.free()

