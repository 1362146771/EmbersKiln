extends PanelContainer
## 只读遗物栏：持有列表来自 RunState，说明与图标来自 GameData，不结算效果。
## .tscn / CombatUI.new() 共用；不在战斗刷新时重建，仅响应库存与开局变化。

@onready var slots: HBoxContainer = $Row/Scroll/Slots
@onready var scroll: ScrollContainer = $Row/Scroll
@onready var count_label: Label = $Row/Caption/Count
@onready var details: ColorRect = $DetailsLayer/Details
@onready var detail_name: Label = $DetailsLayer/Details/Margin/Panel/Body/Name
@onready var detail_description: Label = $DetailsLayer/Details/Margin/Panel/Body/Description
@onready var detail_icon: TextureRect = $DetailsLayer/Details/Margin/Panel/Body/Icon
@onready var close_button: Button = $DetailsLayer/Details/Margin/Panel/Body/Close

var _selected_id: StringName = &""


func _ready() -> void:
	SignalBus.relic_gained.connect(_on_relic_gained)
	SignalBus.run_started.connect(refresh)
	close_button.pressed.connect(hide_details)
	details.gui_input.connect(_on_backdrop_input)
	refresh()


func _exit_tree() -> void:
	if SignalBus.relic_gained.is_connected(_on_relic_gained):
		SignalBus.relic_gained.disconnect(_on_relic_gained)
	if SignalBus.run_started.is_connected(refresh):
		SignalBus.run_started.disconnect(refresh)


func refresh() -> void:
	for child in slots.get_children():
		slots.remove_child(child)
		child.queue_free()
	count_label.text = "%d 件" % RunState.relic_ids.size()
	if RunState.relic_ids.is_empty():
		var empty := Label.new()
		empty.text = "暂无遗物"
		empty.add_theme_font_size_override("font_size", 16)
		slots.add_child(empty)
	for rid in RunState.relic_ids:
		var relic: RelicData = GameData.get_relic(rid)
		var button := Button.new()
		button.name = String(rid)
		button.custom_minimum_size = Vector2(48, 48)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 16)
		button.set_meta("relic_id", rid)
		var title := relic.name if relic != null else String(rid)
		var description := relic.description if relic != null else "遗物资料暂不可用。"
		button.tooltip_text = "%s\n%s" % [title, description]
		var texture: Texture2D = GameData.icon_texture(relic.icon) if relic != null else null
		if texture != null:
			var icon := TextureRect.new()
			icon.texture = texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(icon)
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 4
			icon.offset_top = 4
			icon.offset_right = -4
			icon.offset_bottom = -4
		else:
			# 缺图时仍可辨识、可点击，不加载不存在的资源。
			button.text = title.left(2) + ("\n" + title.substr(2, 2) if title.length() > 2 else "")
		button.pressed.connect(show_details.bind(rid))
		slots.add_child(button)
	if details.visible:
		if RunState.has_relic(_selected_id):
			show_details(_selected_id)
		else:
			hide_details()


func show_details(relic_id: StringName) -> void:
	if not RunState.has_relic(relic_id):
		return
	_selected_id = relic_id
	var relic: RelicData = GameData.get_relic(relic_id)
	detail_name.text = relic.name if relic != null else String(relic_id)
	detail_description.text = relic.description if relic != null else "遗物资料暂不可用。"
	detail_icon.texture = GameData.icon_texture(relic.icon) if relic != null else null
	detail_icon.visible = detail_icon.texture != null
	details.show()
	close_button.grab_focus()


func hide_details() -> void:
	details.hide()
	var slot := slots.get_node_or_null(NodePath(String(_selected_id))) as Button
	if slot != null:
		slot.grab_focus()
	_selected_id = &""


func _on_relic_gained(_relic_id: StringName) -> void:
	refresh()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hide_details()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if details.visible and event.is_action_pressed("ui_cancel"):
		hide_details()
		get_viewport().set_input_as_handled()
