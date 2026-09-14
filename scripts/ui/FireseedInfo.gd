extends Control
var _return_focus: Control

func _ready() -> void:
	$Dismiss.pressed.connect(close)
	$Center/Panel/Column/Close.pressed.connect(close)

func open(source: Control = null) -> void:
	_return_focus = source if source != null else get_viewport().gui_get_focus_owner()
	show()
	$Center/Panel/Column/Close.grab_focus()

func close() -> void:
	hide()
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
