extends CanvasLayer
var source: Control
var pinned := false
@onready var panel: PanelContainer = $Panel

func _ready() -> void:
	add_to_group("combat_icon_details")
	get_viewport().size_changed.connect(_layout)
	set_process(false)

func present(origin: Control, pin: bool) -> void:
	for other in get_tree().get_nodes_in_group("combat_icon_details"):
		if other != self: other.close()
	source = origin
	pinned = pin
	update_content(source.get_meta("info_title"), source.get_meta("info_body"), source.get_meta("info_texture"))
	panel.show()
	set_process(true)
	_layout()

func update_content(title: String, body: String, texture: Texture2D) -> void:
	$Panel/Body/Header/Title.text = title
	$Panel/Body/Header/Icon.texture = texture
	$Panel/Body/Description.text = body
	_layout.call_deferred()

func _layout() -> void:
	if not is_instance_valid(source) or not panel.visible: return
	var bounds := source.get_viewport_rect().grow(-12.0)
	panel.size = Vector2(minf(330.0, bounds.size.x), 0.0)
	panel.reset_size()
	# Width is fixed for wrapping; height follows the independently authored text.
	panel.size.x = minf(330.0, bounds.size.x)
	var anchor := source.get_global_rect()
	var point := Vector2(anchor.end.x + 10.0, anchor.position.y)
	if point.x + panel.size.x > bounds.end.x:
		point.x = anchor.position.x - panel.size.x - 10.0
	if point.x < bounds.position.x:
		point = Vector2(anchor.get_center().x - panel.size.x / 2.0, anchor.end.y + 10.0)
	point.x = clampf(point.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - panel.size.x))
	point.y = clampf(point.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - panel.size.y))
	panel.position = point

func close() -> void:
	panel.hide()
	pinned = false
	set_process(false)

func _process(_delta: float) -> void:
	if not is_instance_valid(source) or not source.is_visible_in_tree(): close()

func _input(event: InputEvent) -> void:
	if not panel.visible: return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var touch: bool = event is InputEventScreenTouch and event.pressed
	if not click and not touch: return
	if panel.get_global_rect().has_point(event.position): return
	if is_instance_valid(source) and source.get_global_rect().has_point(event.position): return
	var was_pinned := pinned
	close()
	# Tapping another icon directly changes its explanation; a dismissing tap
	# elsewhere is consumed so it cannot also play a card or select an enemy.
	for badge in get_tree().get_nodes_in_group("combat_info_badges"):
		if badge.is_visible_in_tree() and badge.get_global_rect().has_point(event.position): return
	if was_pinned: get_viewport().set_input_as_handled()
