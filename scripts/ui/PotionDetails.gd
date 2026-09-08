extends Control
## 药水只读说明。关闭时吞掉当前点击，避免穿透到使用按钮。

func _ready() -> void:
	$Panel/Content/Close.pressed.connect(hide)
	gui_input.connect(_on_backdrop_input)

func present(potion: PotionData, source: Rect2) -> void:
	$Panel/Content/Title.text = potion.name
	$Panel/Content/Description.text = potion.description
	$Panel.size = Vector2(320, 0)
	show()
	_place.call_deferred(source)

func _place(source: Rect2) -> void:
	var panel: PanelContainer = $Panel
	# 先让固定宽度下的自动换行完成，再收紧弹窗高度。
	await get_tree().process_frame
	await get_tree().process_frame
	panel.reset_size()
	var bounds := get_viewport_rect()
	panel.position = Vector2(
		clampf(source.get_center().x - panel.size.x / 2.0, 8.0, maxf(8.0, bounds.size.x - panel.size.x - 8.0)),
		clampf(source.position.y - panel.size.y - 10.0, 8.0, maxf(8.0, bounds.size.y - panel.size.y - 8.0))
	)
	$Panel/Content/Close.grab_focus()

func _on_backdrop_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		hide()
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
