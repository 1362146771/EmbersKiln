extends Node
## 图标和名称共用轻点/拖拽手势；全局接收松手，避免移出药水槽后丢失输入。

var ui: CombatUI
var slot := -1
var potion_id: StringName = &""
var start := Vector2.ZERO
var touch_index := -1
var dragging := false
var ghost: TextureRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(false)
	set_process(false)


func connect_source(source: Control, index: int) -> void:
	source.mouse_filter = Control.MOUSE_FILTER_STOP
	source.focus_mode = Control.FOCUS_ALL
	source.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	source.gui_input.connect(_on_source_input.bind(source, index))


func _can_use() -> bool:
	return not get_tree().paused and not ui.combat_over and not ui._casting and not BattleDirector.input_locked and ui.controller.phase == CombatController.Phase.PLAYER and not ui.card_browser_open()


func _on_source_input(event: InputEvent, source: Control, index: int) -> void:
	if slot >= 0 or ui._drag_active or ui._casting or ui.card_browser_open() or get_tree().paused:
		return
	if index >= RunState.potions.size():
		return
	if event.is_action_pressed("ui_accept"):
		ui._targeting.on_potion_pressed(index)
		source.accept_event()
		return
	var mouse_press: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	var touch_press: bool = event is InputEventScreenTouch and event.pressed
	if not mouse_press and not touch_press:
		return
	slot = index
	potion_id = RunState.potions[index]
	start = source.get_global_transform() * event.position
	touch_index = event.index if touch_press else -1
	set_process_input(true)
	set_process(true)
	source.accept_event()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
		return
	var moved := false
	var released := false
	var pos := Vector2.ZERO
	if touch_index >= 0:
		if event is InputEventScreenDrag and event.index == touch_index:
			moved = true
			pos = event.position
		elif event is InputEventScreenTouch and event.index == touch_index and not event.pressed:
			if event.canceled:
				cancel()
				return
			released = true
			pos = event.position
	else:
		if event is InputEventMouseMotion:
			moved = true
			pos = event.position
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			released = true
			pos = event.position
	if moved:
		move_pointer(pos)
	elif released:
		release_pointer(pos)
	if moved or released:
		get_viewport().set_input_as_handled()


func move_pointer(pos: Vector2) -> void:
	if not dragging and start.distance_to(pos) >= CardView.DRAG_THRESHOLD:
		if not _can_use():
			cancel()
			return
		var potion := GameData.get_potion(potion_id)
		if potion == null:
			cancel()
			return
		dragging = true
		ui._drag_active = true
		ui._targeting.build_drop_targets(false)
		ui.drop_layer.highlight(potion.target)
		ghost = TextureRect.new()
		ghost.texture = GameData.icon_texture(potion.icon)
		ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.size = ui.potion_icons[slot].size
		ui.drag_layer.add_child(ghost)
	if dragging:
		ghost.global_position = pos - ghost.size * 0.5
		ui.drop_layer.hover_update(pos)
		ui.drop_layer.set_arrow(start, pos)


func release_pointer(pos: Vector2) -> void:
	var index := slot
	var id := potion_id
	var was_dragging := dragging
	# 松手前重新获取存活目标，禁止命中已死亡敌人后回退到默认敌人。
	if dragging:
		ui._targeting.build_drop_targets(false)
	var target := ui.drop_layer.hit_test(pos) if dragging else -2
	var allowed := _can_use()
	cancel()
	if index < 0 or index >= RunState.potions.size() or RunState.potions[index] != id:
		return
	if not was_dragging:
		ui._targeting.on_potion_pressed(index)
	elif allowed and target != -2:
		if ui.controller.use_potion(index, target):
			ui.selected_target = -1
			ui._refresh_all()


func cancel() -> void:
	if dragging:
		ui._drag_active = false
		ui.drop_layer.clear()
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null
	dragging = false
	slot = -1
	potion_id = &""
	touch_index = -1
	set_process_input(false)
	set_process(false)
	if ui._needs_refresh and not ui._casting and not get_tree().paused:
		ui._needs_refresh = false
		ui._refresh_all()


func _process(_delta: float) -> void:
	if get_tree().paused or (dragging and not _can_use()):
		cancel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and slot >= 0:
		cancel()
