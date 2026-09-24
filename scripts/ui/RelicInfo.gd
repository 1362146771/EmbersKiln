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
	if source.has_meta("relic_info_wired"): return
	# Offers are assembled before they are parented under their scroll container.
	if not source.is_inside_tree():
		if not source.has_meta("relic_info_pending"):
			source.set_meta("relic_info_pending", true)
			source.ready.connect(func(): attach(source, StringName(source.get_meta("inspect_relic_id"))), CONNECT_ONE_SHOT)
		return
	source.mouse_filter = Control.MOUSE_FILTER_PASS
	source.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	source.tooltip_text = "点击查看遗物信息"
	source.set_meta("relic_info_wired", true)
	if MobileScroll.parent_scroll(source) == null:
		source.mouse_filter = Control.MOUSE_FILTER_STOP
		source.focus_mode = Control.FOCUS_ALL
		source.gui_input.connect(func(event: InputEvent):
			var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
			var touch: bool = event is InputEventScreenTouch and event.pressed
			if click or touch or event.is_action_pressed("ui_accept"):
				show_for(source, StringName(source.get_meta("inspect_relic_id")))
				source.accept_event())
		return
	# Opening on touch-down prevents a list from recognizing a swipe.
	# BaseButton cancels its release action when a ScrollContainer starts moving.
	var button := Button.new()
	button.name = "InspectRelic"
	button.flat = true
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = source.tooltip_text
	# Focus is drawn even on a flat button; inherited themed artwork must never cover the relic.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	source.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.pressed.connect(func(): show_for(source, StringName(source.get_meta("inspect_relic_id"))))
