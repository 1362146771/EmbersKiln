extends RefCounted
## One independent description per icon; shared by intents and status stacks.
const DETAILS := preload("res://scenes/ui/CombatIconDetails.tscn")

static func configure(source: Control, title: String, body: String, texture: Texture2D) -> void:
	source.set_meta("info_title", title)
	source.set_meta("info_body", body)
	source.set_meta("info_texture", texture)
	source.tooltip_text = ""
	var popup = source.get_node_or_null("CombatIconDetails")
	if popup != null: popup.update_content(title, body, texture)
	if source.has_meta("info_wired"): return
	source.set_meta("info_wired", true)
	source.add_to_group("combat_info_badges")
	source.mouse_filter = Control.MOUSE_FILTER_STOP
	source.focus_mode = Control.FOCUS_ALL
	source.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	source.mouse_entered.connect(func():
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): show_for(source, false)
	)
	source.mouse_exited.connect(func():
		var current = source.get_node_or_null("CombatIconDetails")
		if current != null and not current.pinned: current.close()
	)
	source.focus_entered.connect(func(): show_for(source, false))
	source.focus_exited.connect(func():
		var current = source.get_node_or_null("CombatIconDetails")
		if current != null and not current.pinned: current.close()
	)
	source.gui_input.connect(func(event: InputEvent):
		var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		var touch: bool = event is InputEventScreenTouch and event.pressed
		if click or touch or event.is_action_pressed("ui_accept"):
			show_for(source, true)
			source.accept_event()
	)

static func show_for(source: Control, pin: bool) -> void:
	if not source.is_visible_in_tree(): return
	var popup = source.get_node_or_null("CombatIconDetails")
	if popup == null:
		popup = DETAILS.instantiate()
		popup.name = "CombatIconDetails"
		source.add_child(popup)
	popup.present(source, pin)
