extends RefCounted
## 任意已展示遗物均可只读查看，包括尚未购买的商品；不授予遗物、不扣款。
const DETAILS := preload("res://scenes/ui/RelicDetails.tscn")

static func show_for(source: Control, relic_id: StringName) -> void:
	var popup = source.get_node_or_null("RelicDetailsPopup")
	if popup == null:
		popup = DETAILS.instantiate()
		popup.name = "RelicDetailsPopup"
		source.add_child(popup)
	popup.present(relic_id, source)

static func attach(source: Control, relic_id: StringName) -> void:
	source.set_meta("inspect_relic_id", relic_id)
	source.mouse_filter = Control.MOUSE_FILTER_STOP
	source.focus_mode = Control.FOCUS_ALL
	source.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	source.tooltip_text = "点击查看遗物信息"
	if source.has_meta("relic_info_wired"): return
	source.set_meta("relic_info_wired", true)
	source.gui_input.connect(func(event: InputEvent):
		var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		var touch: bool = event is InputEventScreenTouch and event.pressed
		if click or touch or event.is_action_pressed("ui_accept"):
			show_for(source, StringName(source.get_meta("inspect_relic_id")))
			source.accept_event()
	)
