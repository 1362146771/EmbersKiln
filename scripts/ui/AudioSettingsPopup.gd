extends CanvasLayer

@onready var column: VBoxContainer = $Cover/Center/Panel/Margin/Column

func _ready() -> void:
	column.get_node("CloseButton").pressed.connect(queue_free)
	column.get_node("Tabs/AudioTab").pressed.connect(_show_page.bind(false))
	column.get_node("Tabs/GraphicsTab").pressed.connect(_show_page.bind(true))
	var fps := column.get_node("Graphics/FrameLimit/Options") as OptionButton
	for value in GraphicsSettings.FRAME_LIMITS:
		fps.add_item("不限" if value == 0 else "%d 帧" % value, value)
	fps.select(fps.get_item_index(GraphicsSettings.frame_limit))
	fps.item_selected.connect(func(index: int): GraphicsSettings.set_frame_limit(fps.get_item_id(index)))
	var aa := column.get_node("Graphics/Antialiasing/Options") as OptionButton
	for index in GraphicsSettings.AA_MODES.size():
		aa.add_item(["关闭", "2×", "4×"][index], GraphicsSettings.AA_MODES[index])
	aa.select(aa.get_item_index(GraphicsSettings.antialiasing))
	aa.item_selected.connect(func(index: int): GraphicsSettings.set_antialiasing(aa.get_item_id(index)))
	_show_page(false)
	column.get_node("Tabs/AudioTab").grab_focus()
	SignalBus.sound_requested.emit(&"ui_open")


func _show_page(graphics: bool) -> void:
	column.get_node("AudioSettings").visible = not graphics
	column.get_node("Graphics").visible = graphics
	column.get_node("Tabs/AudioTab").set_pressed_no_signal(not graphics)
	column.get_node("Tabs/GraphicsTab").set_pressed_no_signal(graphics)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST: queue_free()
