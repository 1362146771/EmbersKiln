extends CanvasLayer
## 共用卡牌浏览器：只展示快照。选择模式只发确认信号，扣费/移除由来源场景校验。

signal confirmed(index: int, snapshot: Dictionary)
signal closed

const INK := Color("1b1612")
const SLATE := Color("3a4554")
const PAPER := Color("f2e8d5")
const HIGHLIGHT := Color("e0c1ac")

var entries: Array = []
var selectable := false
var selected_index := -1
var _title := ""
var _subtitle := ""
var _confirm_text := ""
var _warning := ""
var _selection_description := ""
var _require_selection := false
var _finished := false
var _single_card := false
var _source_card: Control
var _popup: PanelContainer
var _popup_layout_pending := false
var _cover: ColorRect
var _body: VBoxContainer
var _scroll: ScrollContainer
var _cards: GridContainer
var _detail: VBoxContainer
var _hint: Label
var _back: Button
var _confirm: Button


func setup(title: String, subtitle: String, cards: Array, allow_selection: bool = false,
		confirm_text: String = "", warning: String = "", selection_description: String = "",
		require_selection: bool = false) -> void:
	_title = title
	_subtitle = subtitle
	entries = cards.duplicate(true)
	selectable = allow_selection
	_confirm_text = confirm_text
	_warning = warning
	_selection_description = selection_description
	_require_selection = require_selection


func setup_details(entry: Dictionary, hint: String, source_card: Control) -> void:
	setup("", hint, [entry])
	_single_card = true
	_source_card = source_card


func _ready() -> void:
	layer = 100  # 高于战斗/VFX，低于全局暂停菜单。
	_cover = ColorRect.new()
	_cover.color = Color.TRANSPARENT if _single_card else Color(0.08, 0.07, 0.08, 0.94)
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	# 独立主题避免从旧浅色页面继承文字颜色。
	_cover.theme = Theme.new()
	_cover.theme.default_font = ThemeDB.fallback_font
	add_child(_cover)
	if _single_card:
		_build_popup()
		return
	var outer := MarginContainer.new()
	_cover.add_child(outer)
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + edge, 24)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style(SLATE, Color("68665e")))
	outer.add_child(panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 16)
	panel.add_child(_body)
	_body.add_child(label(_title, 56))
	_hint = label(_subtitle, 22)
	_body.add_child(_hint)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(_scroll)
	_cards = GridContainer.new()
	_cards.columns = 1 if _single_card else 2
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("h_separation", 14)
	_cards.add_theme_constant_override("v_separation", 14)
	_scroll.add_child(_cards)
	for i in entries.size():
		_cards.add_child(_card_panel(entries[i], i, selectable))
	if entries.is_empty():
		var empty := label("抽牌堆已空\n再次需要抽牌时，会将弃牌堆洗回。\n消耗牌不会参与洗回。", 26)
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_cards.columns = 1
		_cards.add_child(empty)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 20)
	_detail.hide()
	_scroll.add_child(_detail)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	_body.add_child(footer)
	_back = button("取消" if selectable else "返回战斗", _go_back)
	if _require_selection:
		_back.text = "必须选择一张"
		_back.disabled = true
	footer.add_child(_back)
	_confirm = button(_confirm_text, _confirm_selection)
	_confirm.add_theme_stylebox_override("normal", style(Color("7e504e"), HIGHLIGHT))
	_confirm.hide()
	footer.add_child(_confirm)
	_back.grab_focus()


## 单卡详情只显示卡片附近的小浮窗；透明输入层用于点外部关闭，不遮暗战斗。
func _build_popup() -> void:
	_popup = PanelContainer.new()
	_popup.name = "CardDetailPopup"
	_popup.modulate.a = 0.0
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := style(SLATE, Color("68665e"))
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	_popup.add_theme_stylebox_override("panel", box)
	_cover.add_child(_popup)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.add_child(_scroll)
	# 固定预留滚动条宽度，避免短描述在「有/无滚动条」间反复切换，
	# 导致卡图宽度、最小高度与弹窗内容高度互相反馈。
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_cards = GridContainer.new()
	_cards.columns = 1
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_cards)
	_cards.add_child(_card_panel(entries[0], 0, false))
	_cover.gui_input.connect(_on_popup_backdrop)
	get_viewport().size_changed.connect(_schedule_popup_layout)
	_schedule_popup_layout()


func _schedule_popup_layout() -> void:
	if _finished or _popup_layout_pending:
		return
	_popup_layout_pending = true
	_layout_popup.call_deferred()


func _layout_popup() -> void:
	if _finished or not is_instance_valid(_source_card):
		_popup_layout_pending = false
		close()
		return
	var viewport_rect := get_viewport().get_visible_rect().grow(-8.0)
	var source_rect := _source_card.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _source_card.size)
	# 全宽插画需要额外高度，首屏仍留出卡牌效果；长文继续滚动。
	var popup_width := minf(maxf(source_rect.size.x * 1.8, 216.0), viewport_rect.size.x)
	var max_height := minf(maxf(source_rect.size.y * 2.6, 360.0), viewport_rect.size.y)
	_popup.size = Vector2(popup_width, max_height)
	# 容器先按指定宽度折行，再收紧至实际内容高度。
	await get_tree().process_frame
	await get_tree().process_frame
	if _finished:
		return
	var content_height := _cards.get_combined_minimum_size().y + 20.0
	_popup.size.y = minf(maxf(content_height, source_rect.size.y * 1.15), max_height)
	var position := Vector2(source_rect.get_center().x - _popup.size.x * 0.5, source_rect.position.y - _popup.size.y - 8.0)
	if position.y < viewport_rect.position.y:
		position.y = source_rect.end.y + 8.0
	position.x = clampf(position.x, viewport_rect.position.x, viewport_rect.end.x - _popup.size.x)
	position.y = clampf(position.y, viewport_rect.position.y, viewport_rect.end.y - _popup.size.y)
	_popup.position = position
	_popup.modulate.a = 1.0
	_popup_layout_pending = false


func _on_popup_backdrop(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_cover.accept_event()
		if not event.pressed:
			close()


static func label(text: String, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", PAPER)
	node.add_theme_color_override("font_outline_color", INK)
	node.add_theme_constant_override("outline_size", 1)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func style(fill: Color, border: Color = INK) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box


static func button(text: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 64
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", 24)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, PAPER)
	node.add_theme_color_override("font_disabled_color", Color("94826f"))
	node.add_theme_stylebox_override("normal", style(Color("332831")))
	node.add_theme_stylebox_override("hover", style(SLATE, HIGHLIGHT))
	node.add_theme_stylebox_override("pressed", style(INK, HIGHLIGHT))
	node.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, HIGHLIGHT))
	node.add_theme_stylebox_override("disabled", style(Color("35392c")))
	node.pressed.connect(callback)
	return node


static func card_name(entry: Dictionary) -> String:
	var cd: CardData = GameData.get_card(StringName(entry.get("id", "")))
	var level := maxi(maxi(int(entry.get("upgrade_level", 0)), int(entry.get("combat_upgrade_level", 0))), 1 if bool(entry.get("upgraded", false)) else 0)
	return (cd.name if cd != null else String(entry.get("id", "未知卡牌"))) + ("+" + (str(level) if level > 1 else "") if level > 0 else "")


func _card_panel(entry: Dictionary, index: int, with_select: bool) -> PanelContainer:
	var cd: CardData = GameData.get_card(StringName(entry.get("id", "")))
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := style(Color("332831"))
	card_style.content_margin_left = 4
	card_style.content_margin_right = 4
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new() if _single_card else card_style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6 if _single_card else 10)
	panel.add_child(column)
	var level := maxi(maxi(int(entry.get("upgrade_level", 0)), int(entry.get("combat_upgrade_level", 0))), 1 if bool(entry.get("upgraded", false)) else 0)
	if cd != null:
		column.add_child(FormalUI.card_visual({"id": cd.id, "display_name": card_name(entry), "cost": cd.resolved_cost(level)}))
		column.add_child(label(GameData.card_taxonomy_name(&"rarities", cd.rarity), 18))
		column.add_child(label(cd.get_description(level), 20 if _single_card else 22))
		if not cd.mechanics.is_empty():
			var mechanic_names: Array[String] = []
			for mechanic in cd.mechanics:
				mechanic_names.append(GameData.card_taxonomy_name(&"mechanics", mechanic))
			column.add_child(label("机制 · %s" % " / ".join(mechanic_names), 16 if _single_card else 18))
		if cd.exhausts_on_play(level):
			column.add_child(label("消耗：打出后本场不再抽到", 20))
		elif cd.type == &"power":
			column.add_child(label("能力：生效后移出本场抽弃循环", 20))
	else:
		column.add_child(label("卡牌资料暂不可用", 22))
	for id in entry.get("enchants", []):
		var enchant: EnchantData = GameData.get_enchant(StringName(id))
		column.add_child(label("附魔 · %s\n%s" % [enchant.name if enchant != null else String(id), enchant.description if enchant != null else "资料暂不可用"], 20))
	if _single_card:
		_hint = label(_subtitle, 18)
		column.add_child(_hint)
		column.add_child(label("点击外部关闭", 16))
	if with_select:
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(spacer)
		var select := button("选择此牌", select_card.bind(index))
		select.name = "SelectCard"
		select.set_meta("card_index", index)
		select.disabled = cd == null
		column.add_child(select)
	return panel


func select_card(index: int) -> void:
	if _finished or not selectable or index < 0 or index >= entries.size():
		return
	selected_index = index
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	_hint.text = "确认选择 · %s" % card_name(entries[index])
	var detail_text := _selection_description
	if detail_text.is_empty():
		detail_text = "该卡会从本局牌组中永久消失，后续战斗不再抽到。此操作不是弃牌，也不是消耗。"
	_detail.add_child(label((_warning + "\n\n" + detail_text).strip_edges(), 24))
	_detail.add_child(_card_panel(entries[index], index, false))
	_cards.hide()
	_detail.show()
	_scroll.scroll_vertical = 0
	_back.text = "重新选牌"
	_back.disabled = false
	_confirm.show()
	_back.grab_focus()  # 不默认聚焦破坏性确认。


func _go_back() -> void:
	if selected_index >= 0:
		selected_index = -1
		_detail.hide()
		_cards.show()
		_hint.text = _subtitle
		_back.text = "必须选择一张" if _require_selection else "取消"
		_back.disabled = _require_selection
		_confirm.hide()
	else:
		if _require_selection:
			return
		close()


func _confirm_selection() -> void:
	if _finished or not selectable or selected_index < 0:
		return
	_finished = true  # 同步信号可能导致来源场景销毁；先锁定并隐藏。
	hide()
	queue_free()
	confirmed.emit(selected_index, entries[selected_index])


func close() -> void:
	if _finished:
		return
	_finished = true
	hide()
	queue_free()
	closed.emit()


func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		if _single_card:
			get_viewport().set_input_as_handled()
			return
		# 键盘焦点只能在本窗口内，不能激活底层结束回合/服务按钮。
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or not _cover.is_ancestor_of(focus):
			_back.grab_focus()
			get_viewport().set_input_as_handled()
