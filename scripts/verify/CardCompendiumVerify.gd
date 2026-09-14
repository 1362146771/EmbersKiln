extends Node
## 图鉴专项验证：档案发现、进度呈现，以及主菜单/暂停菜单入口。

var pass_count := 0
var fail_count := 0
var original_profile: Dictionary
var original_autosave := true


func _ready() -> void:
	await get_tree().process_frame
	original_autosave = ProfileManager.autosave_enabled
	ProfileManager.autosave_enabled = false
	original_profile = ProfileState.to_save_dict()
	ProfileState.reset_to_defaults(false)

	_check("图鉴全集为 75 张职业牌", ProfileState.collectible_card_ids().size() == 75)
	_check("新档发现进度从三张起始牌开始", ProfileState.discovered_card_count() == 3)
	await _test_compendium_ui()
	await _test_loading_lifecycle()
	await _test_menu_entries()
	_test_run_acquisition_hook()
	_test_discovery_persistence()

	ProfileState.from_save_dict(original_profile, false)
	ProfileManager.autosave_enabled = original_autosave
	print("CARD_COMPENDIUM_RESULT:%s pass=%d fail=%d" % ["PASS" if fail_count == 0 else "FAIL", pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)


func _test_compendium_ui() -> void:
	var compendium := (load("res://scenes/ui/CardCompendium.tscn") as PackedScene).instantiate() as CardCompendium
	add_child(compendium)
	await get_tree().process_frame
	await get_tree().process_frame
	var progress := compendium.find_child("ProgressLabel", true, false) as Label
	var grid := compendium.find_child("CardGrid", true, false) as GridContainer
	_check("图鉴显示 3 / 75 发现进度", progress != null and "3 / 75" in progress.text)
	_check("图鉴同时显示已发现与未发现卡牌", grid != null
		and grid.find_children("Discovered_*", "PanelContainer", true, false).size() == 3
		and grid.find_children("Undiscovered_*", "PanelContainer", true, false).size() == CardCompendium.PAGE_SIZE - 3)
	var visited: Dictionary = {}
	while true:
		for card in grid.get_children():
			_check("分页不重复卡牌 %s" % card.name, not visited.has(card.name))
			visited[card.name] = true
		if compendium._next_page.disabled:
			break
		compendium._next_page.pressed.emit()
	_check("翻页可遍历全部 75 张牌", visited.size() == 75 and grid.get_child_count() == 3)
	compendium._set_filter(CardCompendium.FILTER_DISCOVERED)
	_check("切筛选回首页且只显示已发现", compendium._page == 0 and grid.get_child_count() == 3
		and compendium._previous_page.disabled and compendium._next_page.disabled)
	get_tree().paused = true
	var deadline := Time.get_ticks_msec() + 5000
	while not compendium._requested_art.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check("暂停时后台插画仍能完成加载", compendium._requested_art.is_empty())
	for art in grid.find_children("CardArt", "TextureRect", true, false):
		_check("已发现插画替换占位图", art.texture != null and not art.texture is PlaceholderTexture2D)
	get_tree().paused = false
	compendium._set_filter(CardCompendium.FILTER_UNDISCOVERED)
	_check("未发现筛选不加载隐藏插画", grid.get_child_count() == CardCompendium.PAGE_SIZE
		and grid.find_children("CardArt", "TextureRect", true, false).is_empty())
	_check("图鉴在暂停状态仍可处理输入", compendium.process_mode == Node.PROCESS_MODE_ALWAYS)
	compendium.close()
	await get_tree().process_frame


func _test_loading_lifecycle() -> void:
	var saved := ProfileState.to_save_dict()
	for id in ProfileState.collectible_card_ids():
		ProfileState.discover_card(id, false)
	var scene := load("res://scenes/ui/CardCompendium.tscn") as PackedScene
	var closing := scene.instantiate() as CardCompendium
	add_child(closing)
	for page in 3:
		closing._change_page(1)
	closing.close()
	await get_tree().process_frame
	var reopened := scene.instantiate() as CardCompendium
	add_child(reopened)
	reopened._change_page(1)
	reopened._change_page(-1)
	var deadline := Time.get_ticks_msec() + 5000
	while not reopened._requested_art.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check("快速翻页关闭重开后加载完成", reopened._requested_art.is_empty())
	_check("重开仍只创建一页卡牌", reopened._grid.get_child_count() == CardCompendium.PAGE_SIZE)
	for panel in reopened._grid.get_children():
		var id := StringName(String(panel.name).trim_prefix("Discovered_"))
		var art := panel.find_child("CardArt", true, false) as TextureRect
		_check("旧请求不会串图 %s" % id, art.texture.resource_path == GameData.get_card(id).art)
	reopened.close()
	ProfileState.from_save_dict(saved, false)
	await get_tree().process_frame


func _test_menu_entries() -> void:
	var main_menu := (load("res://scenes/main/MainMenu.tscn") as PackedScene).instantiate()
	add_child(main_menu)
	var main_button := main_menu.find_child("CompendiumButton", true, false) as Button
	_check("初始界面提供图鉴入口", main_button != null and main_button.pressed.get_connections().size() > 0)
	main_button.pressed.emit()
	await get_tree().process_frame
	var opened_from_main := main_menu.find_child("CardCompendium", true, false) as CardCompendium
	_check("初始界面入口可实际打开图鉴", opened_from_main != null)
	if opened_from_main != null:
		opened_from_main.close()
	main_menu.queue_free()

	var pause_menu := PauseManager._build_overlay()
	var pause_button := pause_menu.find_child("CompendiumButton", true, false) as Button
	_check("战斗暂停设置提供图鉴入口", pause_button != null and pause_button.pressed.get_connections().size() > 0
		and PauseManager.has_method("_open_compendium"))
	pause_button.pressed.emit()
	await get_tree().process_frame
	_check("暂停设置入口可实际打开图鉴", is_instance_valid(PauseManager._compendium))
	PauseManager._close_compendium()
	pause_menu.queue_free()


func _test_run_acquisition_hook() -> void:
	ProfileState.reset_to_defaults(false)
	_check("新局可用于验证首次获得入口", RunState.start_new_run())
	_check("卡牌进入永久牌组时同步登记图鉴", RunState.add_card(&"cleave")
		and ProfileState.is_card_discovered(&"cleave"))


func _test_discovery_persistence() -> void:
	ProfileState.reset_to_defaults(false)
	_check("首次获得牌写入发现记录", ProfileState.discover_card(&"cleave", false))
	var saved := ProfileState.to_save_dict()
	ProfileState.reset_to_defaults(false)
	_check("发现记录可随永久档案恢复", ProfileState.from_save_dict(saved, false)
		and ProfileState.is_card_discovered(&"cleave")
		and ProfileState.discovered_card_count() == 4)
	_check("生成状态牌不能污染图鉴", not ProfileState.discover_card(&"wound", false))


func _check(label: String, passed: bool) -> void:
	if passed:
		pass_count += 1
		print("[PASS] %s" % label)
	else:
		fail_count += 1
		push_error("[FAIL] %s" % label)
