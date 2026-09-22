class_name CardCompendium
extends CanvasLayer
## 永久卡牌图鉴：只展示职业牌；发现状态来自 ProfileState，不修改单局牌组。

signal closed

const FILTER_ALL := &"all"
const FILTER_DISCOVERED := &"discovered"
const FILTER_UNDISCOVERED := &"undiscovered"
const RARITY_ORDER := {&"starter": 0, &"common": 1, &"uncommon": 2, &"rare": 3}
const PAGE_SIZE := 8  # 仅控制图鉴呈现与同时持有的插画数量，不影响卡池。

var _filter: StringName = FILTER_ALL
var _grid: GridContainer
var _progress_label: Label
var _progress_bar: ProgressBar
var _empty_label: Label
var _filter_buttons: Dictionary = {}
var _finished := false
var _page := 0
var _scroll: ScrollContainer
var _page_label: Label
var _previous_page: Button
var _next_page: Button
var _art_targets: Dictionary = {}
var _requested_art: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 196
	set_process(false)
	_build_interface()
	_refresh()


func _build_interface() -> void:
	var cover := ColorRect.new()
	cover.name = "CompendiumCover"
	cover.color = Color(0.025, 0.03, 0.035, 0.97)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := FormalUI.menu_background()
	background.modulate = Color(0.38, 0.4, 0.43, 0.42)
	cover.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	cover.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)

	var panel := PanelContainer.new()
	panel.name = "CompendiumPanel"
	panel.add_theme_stylebox_override("panel", FormalUI.stone("bd_main_setting.png", 48))
	margin.add_child(panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	panel.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	body.add_child(header)
	var title := Label.new()
	title.text = "卡牌图鉴"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 36)
	header.add_child(title)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "返回"
	close_button.custom_minimum_size = Vector2(138, 64)
	FormalUI.button(close_button, "btn_return_normal_small.png")
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_progress_label = Label.new()
	_progress_label.name = "ProgressLabel"
	_progress_label.add_theme_font_size_override("font_size", 24)
	body.add_child(_progress_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "DiscoveryProgress"
	_progress_bar.custom_minimum_size.y = 24
	_progress_bar.show_percentage = false
	body.add_child(_progress_bar)

	var explanation := Label.new()
	explanation.text = "研究解锁决定卡牌能否进入奖励池；图鉴记录你在远征中实际获得过的卡牌。"
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 17)
	explanation.add_theme_color_override("font_color", Color("c9c1b4"))
	body.add_child(explanation)

	var filters := HBoxContainer.new()
	filters.name = "Filters"
	filters.add_theme_constant_override("separation", 10)
	body.add_child(filters)
	_add_filter_button(filters, FILTER_ALL, "全部")
	_add_filter_button(filters, FILTER_DISCOVERED, "已发现")
	_add_filter_button(filters, FILTER_UNDISCOVERED, "未发现")

	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.name = "CardScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_grid = GridContainer.new()
	_grid.name = "CardGrid"
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)

	_empty_label = Label.new()
	_empty_label.name = "EmptyLabel"
	_empty_label.text = "当前筛选下没有卡牌"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", 24)
	_empty_label.hide()
	body.add_child(_empty_label)

	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", 12)
	body.add_child(pages)
	_previous_page = Button.new()
	_previous_page.name = "PreviousPage"
	_previous_page.text = "上一页"
	_previous_page.custom_minimum_size = Vector2(130, 58)
	FormalUI.button(_previous_page, "btn_event_normal.png")
	_previous_page.pressed.connect(_change_page.bind(-1))
	pages.add_child(_previous_page)
	_page_label = Label.new()
	_page_label.name = "PageLabel"
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(_page_label)
	_next_page = Button.new()
	_next_page.name = "NextPage"
	_next_page.text = "下一页"
	_next_page.custom_minimum_size = Vector2(130, 58)
	FormalUI.button(_next_page, "btn_event_normal.png")
	_next_page.pressed.connect(_change_page.bind(1))
	pages.add_child(_next_page)


func _add_filter_button(parent: HBoxContainer, filter_id: StringName, text: String) -> void:
	var button := Button.new()
	button.name = "%sFilter" % String(filter_id).capitalize()
	button.text = text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 58)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FormalUI.button(button, "btn_event_normal.png")
	button.pressed.connect(_set_filter.bind(filter_id))
	parent.add_child(button)
	_filter_buttons[filter_id] = button


func _set_filter(filter_id: StringName) -> void:
	if _filter == filter_id:
		return
	_filter = filter_id
	_page = 0
	_refresh()


func _change_page(direction: int) -> void:
	SignalBus.sound_requested.emit(&"ui_page")
	_page += direction
	_refresh()


func _refresh() -> void:
	var cards := _collectible_cards()
	var discovered := ProfileState.discovered_card_count()
	_progress_label.text = "发现进度  %d / %d" % [discovered, cards.size()]
	_progress_bar.max_value = maxi(cards.size(), 1)
	_progress_bar.value = discovered
	for filter_id in _filter_buttons:
		(_filter_buttons[filter_id] as Button).button_pressed = filter_id == _filter
	_art_targets.clear()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var filtered: Array[CardData] = []
	for card in cards:
		var is_discovered := ProfileState.is_card_discovered(card.id)
		if _filter == FILTER_DISCOVERED and not is_discovered:
			continue
		if _filter == FILTER_UNDISCOVERED and is_discovered:
			continue
		filtered.append(card)
	var page_count := maxi(1, ceili(filtered.size() / float(PAGE_SIZE)))
	_page = clampi(_page, 0, page_count - 1)
	for index in range(_page * PAGE_SIZE, mini((_page + 1) * PAGE_SIZE, filtered.size())):
		var card := filtered[index]
		var is_discovered := ProfileState.is_card_discovered(card.id)
		_grid.add_child(_discovered_card(card) if is_discovered else _undiscovered_card(card))
	_empty_label.visible = filtered.is_empty()
	_page_label.text = "%d / %d 页 · %d 张" % [_page + 1, page_count, filtered.size()]
	_previous_page.disabled = _page == 0
	_next_page.disabled = _page >= page_count - 1
	_scroll.scroll_vertical = 0


func _collectible_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	for card_id in ProfileState.collectible_card_ids():
		var card := GameData.get_card(card_id)
		if card != null:
			cards.append(card)
	cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		var rarity_a := int(RARITY_ORDER.get(a.rarity, 99))
		var rarity_b := int(RARITY_ORDER.get(b.rarity, 99))
		return a.name < b.name if rarity_a == rarity_b else rarity_a < rarity_b)
	return cards


func _discovered_card(card: CardData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Discovered_%s" % String(card.id)
	panel.custom_minimum_size = Vector2(0, 340)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FormalUI.card_face(panel, {
		"id": card.id,
		"name": card.name,
		"rarity": card.rarity,
		"cost": card.cost,
		"desc": card.description,
		"upgraded": false,
	}, true)
	var art := panel.find_child("CardArt", true, false) as TextureRect
	if art != null:
		_art_targets[card.art] = weakref(art)
		if not _requested_art.has(card.art):
			if ResourceLoader.load_threaded_request(card.art, "Texture2D") == OK:
				_requested_art[card.art] = true
		set_process(true)
	return panel


func _process(_delta: float) -> void:
	for path in _requested_art.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			# 只在完成后取资源，主线程不等待解码。快速翻页的旧请求只回收，不写入新页。
			var texture := ResourceLoader.load_threaded_get(path) as Texture2D
			var target: TextureRect = _art_targets[path].get_ref() if _art_targets.has(path) else null
			if is_instance_valid(target) and not target.is_queued_for_deletion():
				target.texture = texture
		_requested_art.erase(path)
	set_process(not _requested_art.is_empty())


func _undiscovered_card(card: CardData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Undiscovered_%s" % String(card.id)
	panel.custom_minimum_size = Vector2(0, 340)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	FormalUI.card_face(panel, {"name": "未发现", "desc": "在远征中获得后解锁资料。", "cost": 0}, true)
	panel.find_child("CardEnergyCost", true, false).get_node("Badge/Value").text = "？"
	panel.find_child("CardDescription", true, false).get_child(0).text = "在远征中获得后解锁资料。"
	var art: TextureRect = panel.find_child("CardArt", true, false)
	var mark := Label.new()
	mark.text = "？"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_font_size_override("font_size", 56)
	art.add_child(mark)
	mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return panel


func close() -> void:
	if _finished:
		return
	_finished = true
	hide()
	closed.emit()
	queue_free()


func _exit_tree() -> void:
	# 关闭窗口不等待后台读取；完成后释放请求引用，避免多次打开积累纹理。
	_release_art_requests(_requested_art.keys(), get_tree())
	_requested_art.clear()


static func _release_art_requests(paths: Array, tree: SceneTree) -> void:
	while not paths.is_empty():
		for path in paths.duplicate():
			var status := ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				continue
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				ResourceLoader.load_threaded_get(path)
			paths.erase(path)
		if not paths.is_empty():
			await tree.process_frame


func _unhandled_input(event: InputEvent) -> void:
	if not _finished and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
