extends Control
## 窑口镇最小可运行界面：查看火种、设施、项目与自然计时队列。

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
const MAP_PLAY := "res://scenes/map/MapPlay.tscn"
const PRE_RUN_PREPARATION := "res://scenes/main/PreRunPreparation.tscn"
const TownFieldScene := preload("res://scenes/town/TownField.tscn")
const TEXT_PRIMARY := Color("#F2E8D5")
const TEXT_MUTED := Color("#B8AA96")

@onready var _fireseed_balance: Label = %FireseedBalance
@onready var _facility_layer: Control = %FacilityLayer
@onready var _depart_button: Button = %DepartButton
@onready var _detail_panel: PanelContainer = %FacilityDetailPanel
@onready var _detail_name: Label = %DetailName
@onready var _detail_level: Label = %DetailLevel
@onready var _detail_description: Label = %DetailDescription
@onready var _status_content: VBoxContainer = %StatusContent
@onready var _project_content: VBoxContainer = %ProjectContent
var _selected_facility_id: StringName = &""
var _speedup_request_project: StringName = &""
var _speedup_status_by_project: Dictionary = {}


func _ready() -> void:
	if PauseManager != null:
		PauseManager.hide_pause_button()
	%BackButton.pressed.connect(_on_back)
	_depart_button.pressed.connect(_on_depart)
	%CloseDetailButton.pressed.connect(_close_facility_details)
	%RefreshTimer.timeout.connect(_on_timer)
	for child in _facility_layer.get_children():
		if child is TextureButton:
			var facility_id := StringName(String(child.get_meta("facility_id", "")))
			if facility_id != &"":
				child.pressed.connect(_on_facility_pressed.bind(facility_id))
	if not SignalBus.profile_changed.is_connected(_rebuild):
		SignalBus.profile_changed.connect(_rebuild)
	if not SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.connect(_on_ad_reward_resolved)
	WorkshopSystem.refresh()
	_rebuild()


func _exit_tree() -> void:
	if SignalBus.profile_changed.is_connected(_rebuild):
		SignalBus.profile_changed.disconnect(_rebuild)
	if SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.disconnect(_on_ad_reward_resolved)


func _rebuild() -> void:
	_fireseed_balance.text = "火种  %d" % ProfileState.fireseed_balance
	for child in _facility_layer.get_children():
		if not child is TextureButton:
			continue
		var button := child as TextureButton
		var facility_id := StringName(String(button.get_meta("facility_id", "")))
		var facility := _facility_data(facility_id)
		button.tooltip_text = String(facility.get("name", facility_id))
		var level_badge := button.get_node_or_null("LevelBadge") as Label
		if level_badge != null:
			level_badge.text = "Lv.%d" % int(ProfileState.facility_levels.get(String(facility_id), 0))
	if _detail_panel.visible and _selected_facility_id != &"":
		_refresh_facility_details()


func _on_facility_pressed(facility_id: StringName) -> void:
	_selected_facility_id = facility_id
	_depart_button.hide()
	_detail_panel.show()
	_refresh_facility_details()


func _close_facility_details() -> void:
	_detail_panel.hide()
	_depart_button.show()
	_selected_facility_id = &""


func _facility_data(facility_id: StringName) -> Dictionary:
	for facility in GameData.meta_facility_list():
		if facility is Dictionary and StringName(String(facility.get("id", ""))) == facility_id:
			return facility
	return {}


func _refresh_facility_details() -> void:
	var facility := _facility_data(_selected_facility_id)
	if facility.is_empty():
		_close_facility_details()
		return
	_detail_name.text = String(facility.get("name", _selected_facility_id))
	_detail_level.text = "等级 %d" % int(ProfileState.facility_levels.get(String(_selected_facility_id), 0))
	_detail_description.text = String(facility.get("description", ""))
	_clear_container(_status_content)
	_clear_container(_project_content)
	var has_queue_entry := false
	for entry in ProfileState.construction_queue:
		if not entry is Dictionary:
			continue
		var project := GameData.get_meta_project(StringName(String(entry.get("project_id", ""))))
		if StringName(String(project.get("facility_id", ""))) != _selected_facility_id:
			continue
		has_queue_entry = true
		_add_queue_detail(entry)
	if not has_queue_entry:
		_add_detail_hint(_status_content, "当前没有建造中的项目。")
	var next_project := _next_project_for_facility(GameData.meta_project_list(), _selected_facility_id)
	if next_project.is_empty():
		_add_detail_hint(_project_content, "该设施的工程已经全部完成。")
	else:
		_add_project_detail(next_project)


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _next_project_for_facility(projects: Array, facility_id: StringName) -> Dictionary:
	for project in projects:
		if not project is Dictionary or StringName(String(project.get("facility_id", ""))) != facility_id:
			continue
		var project_id := StringName(String(project.get("id", "")))
		if project_id != &"" and not ProfileState.completed_project_ids.has(project_id):
			return project
	return {}


## 每个设施只展示配置顺序中第一个尚未完成的工程。
## 正在建造或等待领取的工程仍属于“下一项”，领取后 profile_changed 会立即触发重建。
func _next_projects_by_facility(projects: Array) -> Array:
	var next_projects: Array = []
	for facility in GameData.meta_facility_list():
		if not facility is Dictionary:
			continue
		var facility_id := String(facility.get("id", ""))
		if facility_id.is_empty():
			continue
		for project in projects:
			if not project is Dictionary or String(project.get("facility_id", "")) != facility_id:
				continue
			var project_id := StringName(String(project.get("id", "")))
			if project_id == &"" or ProfileState.completed_project_ids.has(project_id):
				continue
			next_projects.append(project)
			break
	return next_projects


func _add_detail_hint(container: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", TEXT_MUTED)
	_add_detail_field(container, label)


func _add_detail_field(container: VBoxContainer, content: Control) -> void:
	var field := TownFieldScene.instantiate() as PanelContainer
	var content_margin := field.get_node("ContentMargin") as MarginContainer
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_child(content)
	container.add_child(field)


func _add_queue_detail(entry: Dictionary) -> void:
	var project_id := StringName(String(entry.get("project_id", "")))
	var project := GameData.get_meta_project(project_id)
	var name := String(project.get("name", String(project_id)))
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	var status := WorkshopSystem.project_status(project_id)
	label.text = "%s · %s" % [name, "可领取" if status == WorkshopSystem.STATUS_READY else "剩余 %s" % _format_duration(WorkshopSystem.remaining_seconds(project_id))]
	row.add_child(label)
	if status == WorkshopSystem.STATUS_READY:
		var claim := Button.new()
		claim.text = "领取"
		claim.custom_minimum_size = Vector2(0, 64)
		claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		claim.add_theme_font_size_override("font_size", 24)
		claim.pressed.connect(_on_claim_project.bind(project_id))
		row.add_child(claim)
	elif status == WorkshopSystem.STATUS_BUILDING and AdService.is_placement_enabled(WorkshopSystem.SPEEDUP_PLACEMENT):
		var speedup := Button.new()
		speedup.name = "WorkshopSpeedupAdButton_%s" % String(project_id)
		if WorkshopSystem.is_speedup_configured():
			speedup.text = "观看广告\n减少 %s（%d/%d）" % [
				_format_duration(WorkshopSystem.speedup_seconds()),
				WorkshopSystem.project_speedup_uses(project_id),
				WorkshopSystem.speedup_project_limit(),
			]
		else:
			speedup.text = "观看广告\n加热赶工"
		speedup.custom_minimum_size = Vector2(0, 72)
		speedup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		speedup.add_theme_font_size_override("font_size", 20)
		speedup.disabled = not WorkshopSystem.can_offer_speedup(project_id)
		speedup.tooltip_text = WorkshopSystem.speedup_block_reason(project_id) if speedup.disabled else "完整观看后立即减少准确显示的剩余时间"
		speedup.pressed.connect(_on_speedup_project.bind(project_id))
		row.add_child(speedup)
		var status_text := String(_speedup_status_by_project.get(String(project_id), ""))
		if status_text.is_empty() and speedup.disabled:
			status_text = WorkshopSystem.speedup_block_reason(project_id)
		if not status_text.is_empty():
			var hint := Label.new()
			hint.text = status_text
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.add_theme_font_size_override("font_size", 17)
			hint.add_theme_color_override("font_color", TEXT_MUTED)
			row.add_child(hint)
	_add_detail_field(_status_content, row)


func _add_project_detail(project: Dictionary) -> void:
	var project_id := StringName(String(project.get("id", "")))
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", TEXT_PRIMARY)
	var configured := WorkshopSystem.is_project_configured(project_id)
	if configured:
		label.text = "%s\n%s\n火种 %d · %s" % [
			project.get("name", project_id),
			project.get("description", ""),
			int(project["fireseed_cost"]),
			_format_duration(int(project["duration_seconds"])),
		]
	else:
		label.text = "%s\n数值待确认" % project.get("name", project_id)
	row.add_child(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 68)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 22)
	var status := WorkshopSystem.project_status(project_id)
	match status:
		WorkshopSystem.STATUS_LOCKED:
			button.text = "尚未解锁"
		WorkshopSystem.STATUS_BUILDING:
			button.text = "建造中"
		WorkshopSystem.STATUS_READY:
			button.text = "等待领取"
		WorkshopSystem.STATUS_COMPLETED:
			button.text = "已完成"
		_:
			button.text = "开始建造"
	button.disabled = status != WorkshopSystem.STATUS_AVAILABLE or not WorkshopSystem.project_block_reason(project_id).is_empty()
	button.tooltip_text = WorkshopSystem.project_block_reason(project_id)
	button.pressed.connect(_on_start_project.bind(project_id))
	row.add_child(button)
	_add_detail_field(_project_content, row)


func _format_duration(total_seconds: int) -> String:
	var hours := total_seconds / 3600
	var minutes := (total_seconds % 3600) / 60
	var seconds := total_seconds % 60
	if hours > 0:
		return "%d小时%02d分" % [hours, minutes]
	if minutes > 0:
		return "%d分%02d秒" % [minutes, seconds]
	return "%d秒" % seconds


func _on_timer() -> void:
	var changed := not WorkshopSystem.refresh().is_empty()
	if not changed and not ProfileState.construction_queue.is_empty():
		_rebuild()


func _on_start_project(project_id: StringName) -> void:
	WorkshopSystem.start_project(project_id)


func _on_claim_project(project_id: StringName) -> void:
	WorkshopSystem.claim_project(project_id)


func _on_speedup_project(project_id: StringName) -> void:
	var request_id := WorkshopSystem.request_speedup(project_id)
	if request_id.is_empty():
		_speedup_status_by_project[String(project_id)] = WorkshopSystem.speedup_block_reason(project_id)
	else:
		_speedup_request_project = project_id
		_speedup_status_by_project[String(project_id)] = "广告播放中……"
	_rebuild()


func _on_ad_reward_resolved(_transaction_id: String, placement_id: StringName, result: StringName) -> void:
	if placement_id != WorkshopSystem.SPEEDUP_PLACEMENT or _speedup_request_project == &"":
		return
	var project_id := _speedup_request_project
	_speedup_request_project = &""
	match result:
		&"granted":
			_speedup_status_by_project[String(project_id)] = "加热赶工完成，剩余时间已更新。"
		AdService.RESULT_SKIPPED, AdService.RESULT_CLOSED:
			_speedup_status_by_project[String(project_id)] = "广告未完整观看，建造时间没有变化。"
		AdService.RESULT_FAILED:
			_speedup_status_by_project[String(project_id)] = "广告播放失败，建造时间没有变化。"
		_:
			_speedup_status_by_project[String(project_id)] = "加速奖励待恢复，请稍后查看。"
	_rebuild()


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


func _on_depart() -> void:
	# 非战斗存档先回镇，再由这里继续原来的爬塔进度。
	if RunState.is_active:
		PreRunBuffSystem.prepare_offer()
		get_tree().change_scene_to_file(PRE_RUN_PREPARATION if PreRunBuffSystem.needs_preparation() else MAP_PLAY)
		return
	if SaveManager.has_save():
		SaveManager.delete_save()
	if RunState.start_new_run():
		PreRunBuffSystem.prepare_offer()
		get_tree().change_scene_to_file(PRE_RUN_PREPARATION if PreRunBuffSystem.needs_preparation() else MAP_PLAY)
