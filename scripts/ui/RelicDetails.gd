extends CanvasLayer
var _source: Control

func _ready() -> void:
	$Details/Margin/Panel/Body/Close.pressed.connect(close)
	$Details.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			close()
			get_viewport().set_input_as_handled()
	)

func present(relic_id: StringName, source: Control) -> void:
	_source = source
	var relic: RelicData = GameData.get_relic(relic_id)
	$Details/Margin/Panel/Body/Name.text = relic.name if relic != null else String(relic_id)
	$Details/Margin/Panel/Body/Description.text = relic.description if relic != null else "遗物资料暂不可用。"
	$Details/Margin/Panel/Body/Icon.texture = GameData.icon_texture(relic.icon) if relic != null else null
	$Details.show()
	$Details/Margin/Panel/Body/Close.grab_focus()

func close() -> void:
	$Details.hide()
	if is_instance_valid(_source):
		var button := _source.get_node_or_null("InspectRelic") as Button
		if button != null: button.grab_focus()
		else: _source.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if $Details.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
