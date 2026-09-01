extends Control
## 窑口镇最小可运行界面：查看火种、设施、项目与自然计时队列。

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
const MAP_PLAY := "res://scenes/map/MapPlay.tscn"
const PRE_RUN_PREPARATION := "res://scenes/main/PreRunPreparation.tscn"
const CREAM := Color(0.984, 0.953, 0.894)
const ORANGE := Color(0.941, 0.600, 0.482)
const DARK := Color(0.25, 0.20, 0.18)
const MUTED := Color(0.45, 0.39, 0.35)

var _content: VBoxContainer
var _speedup_request_project: StringName = &""
var _speedup_status_by_project: Dictionary = {}


func _ready() -> void:
	if PauseManager != null:
		PauseManager.hide_pause_button()
	_build_shell()
	if not SignalBus.profile_changed.is_connected(_rebuild):
		SignalBus.profile_changed.connect(_rebuild)
	if not SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.connect(_on_ad_reward_resolved)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_timer)
	add_child(timer)
	WorkshopSystem.refresh()
	_rebuild()


func _exit_tree() -> void:
	if SignalBus.profile_changed.is_connected(_rebuild):
		SignalBus.profile_changed.disconnect(_rebuild)
	if SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.disconnect(_on_ad_reward_resolved)


func _build_shell() -> void:
	var bg := ColorRect.new()
	bg.color = CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	margin.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := Label.new()
	title.text = "窑口镇"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(120, 64)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(_on_back)
	header.add_child(back)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 18)
	scroll.add_child(_content)


func _rebuild() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()

	var balance := Label.new()
	balance.text = "火种  %d" % ProfileState.fireseed_balance
	balance.add_theme_font_size_override("font_size", 34)
	balance.add_theme_color_override("font_color", DARK)
	_content.add_child(balance)

	var depart := Button.new()
	depart.text = "从风箱台出发"
	depart.custom_minimum_size = Vector2(620, 76)
	depart.add_theme_font_size_override("font_size", 26)
	depart.pressed.connect(_on_depart)
	_content.add_child(depart)

	_add_section_title("设施")
	for facility in GameData.meta_facility_list():
		if not facility is Dictionary:
			continue
		var facility_id := String(facility.get("id", ""))
		var level := int(ProfileState.facility_levels.get(facility_id, 0))
		var label := Label.new()
		label.text = "%s · 等级 %d\n%s" % [facility.get("name", facility_id), level, facility.get("description", "")]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", DARK)
		_content.add_child(label)

	_add_section_title("建造队列")
	if ProfileState.construction_queue.is_empty():
		_add_hint("当前没有建造中的项目。")
	else:
		for entry in ProfileState.construction_queue:
			_add_queue_entry(entry)

	_add_section_title("可研究项目")
	var projects := GameData.meta_project_list()
	if projects.is_empty():
		_add_hint("项目成本、建造时间与成长效果尚待数值确认；确认后将由配置直接开放。")
	else:
		for project in projects:
			if project is Dictionary:
				_add_project_entry(project)


func _add_section_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", ORANGE)
	_content.add_child(label)


func _add_hint(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", MUTED)
	_content.add_child(label)


func _add_queue_entry(entry: Dictionary) -> void:
	var project_id := StringName(String(entry.get("project_id", "")))
	var project := GameData.get_meta_project(project_id)
	var name := String(project.get("name", String(project_id)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", DARK)
	var status := WorkshopSystem.project_status(project_id)
	label.text = "%s · %s" % [name, "可领取" if status == WorkshopSystem.STATUS_READY else "剩余 %s" % _format_duration(WorkshopSystem.remaining_seconds(project_id))]
	row.add_child(label)
	if status == WorkshopSystem.STATUS_READY:
		var claim := Button.new()
		claim.text = "领取"
		claim.custom_minimum_size = Vector2(120, 64)
		claim.add_theme_font_size_override("font_size", 24)
		claim.pressed.connect(_on_claim_project.bind(project_id))
		row.add_child(claim)
	elif status == WorkshopSystem.STATUS_BUILDING and AdService.is_placement_enabled(WorkshopSystem.SPEEDUP_PLACEMENT):
		var controls := VBoxContainer.new()
		controls.add_theme_constant_override("separation", 4)
		row.add_child(controls)
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
		speedup.custom_minimum_size = Vector2(160, 72)
		speedup.add_theme_font_size_override("font_size", 20)
		speedup.disabled = not WorkshopSystem.can_offer_speedup(project_id)
		speedup.tooltip_text = WorkshopSystem.speedup_block_reason(project_id) if speedup.disabled else "完整观看后立即减少准确显示的剩余时间"
		speedup.pressed.connect(_on_speedup_project.bind(project_id))
		controls.add_child(speedup)
		var status_text := String(_speedup_status_by_project.get(String(project_id), ""))
		if status_text.is_empty() and speedup.disabled:
			status_text = WorkshopSystem.speedup_block_reason(project_id)
		if not status_text.is_empty():
			var hint := Label.new()
			hint.text = status_text
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.add_theme_font_size_override("font_size", 17)
			hint.add_theme_color_override("font_color", MUTED)
			controls.add_child(hint)


func _add_project_entry(project: Dictionary) -> void:
	var project_id := StringName(String(project.get("id", "")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", DARK)
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
	button.custom_minimum_size = Vector2(140, 64)
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
	if SaveManager.has_save():
		SaveManager.delete_save()
	if RunState.start_new_run():
		PreRunBuffSystem.prepare_offer()
		get_tree().change_scene_to_file(PRE_RUN_PREPARATION if PreRunBuffSystem.needs_preparation() else MAP_PLAY)
