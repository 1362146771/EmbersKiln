extends Control
## 局前准备：从已解锁候选中选择一个 Buff，完整观看广告后激活；可直接跳过。

const MAP_PLAY := "res://scenes/map/MapPlay.tscn"
const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
const CREAM := Color(0.984, 0.953, 0.894)
const ORANGE := Color(0.941, 0.600, 0.482)
const DARK := Color(0.25, 0.20, 0.18)
const MUTED := Color(0.45, 0.39, 0.35)

var _column: VBoxContainer
var _request_active := false


func _ready() -> void:
	if PauseManager != null:
		PauseManager.hide_pause_button()
	if not RunState.is_active:
		get_tree().change_scene_to_file(MAIN_MENU)
		return
	if not SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.connect(_on_ad_reward_resolved)
	PreRunBuffSystem.prepare_offer()
	if not PreRunBuffSystem.needs_preparation():
		_go_map()
		return
	_build()


func _exit_tree() -> void:
	if SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.disconnect(_on_ad_reward_resolved)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var background := ColorRect.new()
	background.color = CREAM
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 22)
	margin.add_child(_column)
	_column.add_child(_label("风箱台 · 临行添薪", 42, ORANGE))
	var hint := _label("选择一项已解锁增益。观看广告后，它将在本局前 %d 层生效。" % int(GameData.ad_placement_config(PreRunBuffSystem.PLACEMENT)["duration_floors"]), 24, DARK)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(hint)
	for buff_id in RunState.pre_run_buff_offer_ids:
		var buff := GameData.get_pre_run_buff(buff_id)
		var button := Button.new()
		button.text = "%s\n%s\n观看广告 · 激活" % [buff.get("name", buff_id), buff.get("description", "" )]
		button.custom_minimum_size = Vector2(620, 150)
		button.add_theme_font_size_override("font_size", 23)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = _request_active or not AdService.is_available(PreRunBuffSystem.PLACEMENT)
		button.tooltip_text = "当前无可用广告" if button.disabled else "完整观看后激活"
		button.pressed.connect(_on_buff_pressed.bind(buff_id))
		_column.add_child(button)
	var skip := Button.new()
	skip.text = "跳过，直接出发"
	skip.custom_minimum_size = Vector2(620, 78)
	skip.add_theme_font_size_override("font_size", 25)
	skip.disabled = _request_active
	skip.pressed.connect(_on_skip)
	_column.add_child(skip)
	var note := _label("不看广告不会影响正常开局或基础奖励。", 21, MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(note)


func _on_buff_pressed(buff_id: StringName) -> void:
	_request_active = true
	_build()
	if PreRunBuffSystem.request_buff(buff_id).is_empty():
		_request_active = false
		_build()


func _on_skip() -> void:
	if PreRunBuffSystem.skip_preparation():
		_go_map()


func _on_ad_reward_resolved(_transaction_id: String, placement_id: StringName, result: StringName) -> void:
	if placement_id != PreRunBuffSystem.PLACEMENT:
		return
	if result == &"granted":
		_go_map()
		return
	_request_active = false
	_build()


func _go_map() -> void:
	get_tree().change_scene_to_file(MAP_PLAY)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
