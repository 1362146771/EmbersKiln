class_name CardCompendium
extends CanvasLayer
## 永久卡牌图鉴：只展示职业牌；发现状态来自 ProfileState，不修改单局牌组。

signal closed

const FILTER_ALL := &"all"
const FILTER_DISCOVERED := &"discovered"
const FILTER_UNDISCOVERED := &"undiscovered"
const RARITY_ORDER := {&"starter": 0, &"common": 1, &"uncommon": 2, &"rare": 3}

var _filter: StringName = FILTER_ALL
var _grid: GridContainer
var _progress_label: Label
var _progress_bar: ProgressBar
var _empty_label: Label
var _filter_buttons: Dictionary = {}
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 196
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
	_filter = filter_id
	_refresh()


func _refresh() -> void:
	var cards := _collectible_cards()
	var discovered := ProfileState.discovered_card_count()
	_progress_label.text = "发现进度  %d / %d" % [discovered, cards.size()]
	_progress_bar.max_value = maxi(cards.size(), 1)
	_progress_bar.value = discovered
	for filter_id in _filter_buttons:
		(_filter_buttons[filter_id] as Button).button_pressed = filter_id == _filter
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var visible_count := 0
	for card in cards:
		var is_discovered := ProfileState.is_card_discovered(card.id)
		if _filter == FILTER_DISCOVERED and not is_discovered:
			continue
		if _filter == FILTER_UNDISCOVERED and is_discovered:
			continue
		_grid.add_child(_discovered_card(card) if is_discovered else _undiscovered_card(card))
		visible_count += 1
	_empty_label.visible = visible_count == 0


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
	})
	return panel


func _undiscovered_card(card: CardData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Undiscovered_%s" % String(card.id)
	panel.custom_minimum_size = Vector2(0, 340)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := FormalUI.stone("bd_zhanLiPin_card.png", 5)
	box.modulate_color = Color(0.24, 0.26, 0.29, 0.92)
	panel.add_theme_stylebox_override("panel", box)
	var center := CenterContainer.new()
	panel.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	var mark := Label.new()
	mark.text = "？"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 72)
	mark.add_theme_color_override("font_color", Color("8d929b"))
	column.add_child(mark)
	var status := Label.new()
	status.text = "未发现\n在远征中获得后解锁资料"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_color", Color("aeb2b9"))
	column.add_child(status)
	return panel


func close() -> void:
	if _finished:
		return
	_finished = true
	hide()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not _finished and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
