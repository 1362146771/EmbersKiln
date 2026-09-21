extends CanvasLayer
## 升级预览只读；来源页面收到确认后负责应用升级、消耗本次机会。
signal confirmed(index: int, snapshot: Dictionary)

const Widgets := preload("res://scripts/ui/CardBrowser.gd")
var _sources: Array = []
var _snapshots: Array = []
var _selected := -1
var _finished := false
var _modal: ColorRect
var _pair: HBoxContainer
var _message: Label
var _confirm: Button
var _back: Button
var _cancel: Button
var _grid: GridContainer
var _scroll: ScrollContainer


static func can_upgrade(entry: Dictionary) -> bool:
	var cd := GameData.get_card(StringName(entry.get("id", "")))
	var level := int(entry.get("upgrade_level", 1 if entry.get("upgraded", false) else 0))
	return cd != null and cd.has_upgrade() and (level == 0 or cd.repeatable_upgrade)


func _ready() -> void:
	layer = 100
	_sources = RunState.deck.duplicate()
	_snapshots = RunState.deck.duplicate(true)
	var cover := ColorRect.new()
	cover.color = Color("181b20", 0.96)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.theme = FormalUI.theme()
	add_child(cover)
	var body := _body(cover, 24)
	body.add_child(Widgets.label("升级一张卡牌", 36))
	body.add_child(Widgets.label("点击卡牌，查看升级前后效果", 22))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "CardGrid"
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 22)
	_scroll.add_child(_grid)
	for i in _snapshots.size():
		if not can_upgrade(_snapshots[i]): continue
		var card := _card(_snapshots[i], 18)
		_grid.add_child(card)
		var hit := Button.new()
		hit.name = "SelectCard"
		hit.set_meta("deck_index", i)
		hit.flat = true
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hit.pressed.connect(select_card.bind(i))
		card.add_child(hit)
	if _grid.get_child_count() == 0:
		body.add_child(Widgets.label("没有可升级的卡牌", 24))
	_back = _button("返回", close)
	body.add_child(_back)
	_build_comparison(cover)
	_back.grab_focus()


func _body(parent: Control, margin: int) -> VBoxContainer:
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, margin)
	parent.add_child(outer)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	outer.add_child(body)
	return body


func _button(text: String, callback: Callable) -> Button:
	var button := Widgets.button(text, callback)
	FormalUI.button(button)
	return button


func _card(entry: Dictionary, font_size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", Widgets.style(Color("30383e"), Color("646b6e")))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var cd := GameData.get_card(StringName(entry.id))
	var level := int(entry.get("upgrade_level", 1 if entry.get("upgraded", false) else 0))
	var visual := entry.duplicate(true)
	visual["display_name"] = Widgets.card_name(entry)
	visual["cost"] = cd.resolved_cost(level)
	column.add_child(FormalUI.card_visual(visual))
	var description := Widgets.label(CardMutation.summary(cd, entry), font_size)
	description.name = "Description"
	column.add_child(description)
	if not entry.get("enchants", []).is_empty():
		column.add_child(Widgets.label(CardMutation.note(entry), font_size))
	return panel


func _build_comparison(cover: Control) -> void:
	_modal = ColorRect.new()
	_modal.name = "UpgradeComparison"
	_modal.color = Color(0.02, 0.025, 0.03, 0.88)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(_modal)
	var body := _body(_modal, 24)
	body.add_child(Widgets.label("确认升级", 36))
	_message = Widgets.label("升级前                         升级后", 24)
	body.add_child(_message)
	var scroll := ScrollContainer.new()
	scroll.name = "ComparisonScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var comparison_column := VBoxContainer.new()
	comparison_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comparison_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(comparison_column)
	var top_space := Control.new()
	top_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	comparison_column.add_child(top_space)
	_pair = HBoxContainer.new()
	_pair.name = "ComparisonCards"
	_pair.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pair.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pair.add_theme_constant_override("separation", 12)
	comparison_column.add_child(_pair)
	var bottom_space := Control.new()
	bottom_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	comparison_column.add_child(bottom_space)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 18)
	body.add_child(footer)
	_cancel = _button("取消", _cancel_selection)
	footer.add_child(_cancel)
	_confirm = _button("确认升级", _confirm_selection)
	footer.add_child(_confirm)
	_modal.hide()


func select_card(index: int) -> void:
	if _finished or _modal.visible or index < 0 or index >= _snapshots.size(): return
	if not can_upgrade(_snapshots[index]): return
	_selected = index
	for child in _pair.get_children():
		_pair.remove_child(child)
		child.queue_free()
	var before: Dictionary = _snapshots[index]
	var after := before.duplicate(true)
	after["upgrade_level"] = int(before.get("upgrade_level", 1 if before.get("upgraded", false) else 0)) + 1
	after["upgraded"] = true
	_pair.add_child(_card(before, 22))
	var arrow := Widgets.label("→", 36)
	arrow.autowrap_mode = TextServer.AUTOWRAP_OFF
	arrow.custom_minimum_size.x = 40
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pair.add_child(arrow)
	var upgraded_card := _card(after, 22)
	_pair.add_child(upgraded_card)
	upgraded_card.get_child(0).get_node("Description").add_theme_color_override("font_color", Color("a8dbaa"))
	_message.text = "升级前 → 升级后 · 确认后生效"
	_confirm.disabled = false
	_back.disabled = true
	for card in _grid.get_children():
		card.get_node("SelectCard").disabled = true
	_modal.show()
	_cancel.grab_focus()


func _cancel_selection() -> void:
	_selected = -1
	_modal.hide()
	_back.disabled = false
	for card in _grid.get_children():
		card.get_node("SelectCard").disabled = false
	_back.grab_focus()


func _confirm_selection() -> void:
	if _finished or _selected < 0: return
	var i := _selected
	# 同名副本按实例校验；预览期间牌组改变时不能升级错牌。
	if i >= RunState.deck.size() or not is_same(_sources[i], RunState.deck[i]) or RunState.deck[i] != _snapshots[i] or not can_upgrade(RunState.deck[i]):
		_message.text = "牌组已变化，请返回后重新选择。"
		_confirm.disabled = true
		return
	_finished = true
	hide()
	queue_free()
	confirmed.emit(i, _snapshots[i])


func close() -> void:
	if _finished: return
	_finished = true
	hide()
	queue_free()


func _input(event: InputEvent) -> void:
	if not _finished and event.is_action_pressed("ui_cancel"):
		if _modal.visible: _cancel_selection()
		else: close()
		get_viewport().set_input_as_handled()
	elif not _finished and event is InputEventKey:
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or not get_child(0).is_ancestor_of(focus):
			if _modal.visible: _cancel.grab_focus()
			else: _back.grab_focus()
			get_viewport().set_input_as_handled()
