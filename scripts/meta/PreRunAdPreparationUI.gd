extends Control
## 局前准备：从已解锁候选中选择一个 Buff，完整观看广告后激活；可直接跳过。

const MAP_PLAY := "res://scenes/map/MapPlay.tscn"
const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
@onready var _hint: Label = %Hint
@onready var _options: VBoxContainer = %BuffOptions
@onready var _skip_button: Button = %SkipButton
var _request_active := false
var _leaving := false
var _transition_destination: PackedScene


func _ready() -> void:
	_load_courtyard()
	FormalUI.button(_skip_button, "btn_hall_normal_small.png")
	if PauseManager != null:
		PauseManager.hide_pause_button()
	if not RunState.is_active:
		_route_scene(MAIN_MENU)
		return
	if GrannyStory.needs_opening():
		_route_scene("res://scenes/main/PreRunPreparation.tscn")
		return
	if not SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.connect(_on_ad_reward_resolved)
	_skip_button.pressed.connect(_on_skip)
	%BackButton.pressed.connect(_back)
	PreRunBuffSystem.prepare_offer()
	_build()


func _exit_tree() -> void:
	if SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.disconnect(_on_ad_reward_resolved)


func _build() -> void:
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	_hint.text = "选择一项增益，完整观看广告后激活。\n本局前 %d 层生效。" % int(GameData.ad_placement_config(PreRunBuffSystem.PLACEMENT)["duration_floors"])
	if not PreRunBuffSystem.needs_preparation():
		_hint.text = "护窑余温已领取，可以出发了。" if RunState.pre_run_buff_claimed else "修复风箱台后，可在这里观看广告获得护窑余温。"
	var available := AdService.is_available(PreRunBuffSystem.PLACEMENT)
	%AdStatus.text = "正在等待广告结果…" if _request_active else ("完整观看后即可携带增益出发" if available else "暂无可用广告，可直接出发")
	if not PreRunBuffSystem.needs_preparation(): %AdStatus.text = "陶婆的馈赠已收好，可以直接出发。"
	for buff_id in RunState.pre_run_buff_offer_ids:
		var buff := GameData.get_pre_run_buff(buff_id)
		var panel := preload("res://scenes/main/BuffOffer.tscn").instantiate()
		_options.add_child(panel)
		panel.get_node("Column/Info/Copy/Title").text = String(buff.get("name", buff_id))
		panel.get_node("Column/Info/Copy/Description").text = String(buff.get("description", ""))
		var button: Button = panel.get_node("Column/Activate")
		button.name = "AdBuffButton"
		button.text = "等待广告结果…" if _request_active else ("观看广告 · 激活增益" if available else "广告暂不可用")
		button.custom_minimum_size = Vector2(0, 64)
		FormalUI.button(button)
		button.add_theme_font_size_override("font_size", 23)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = _request_active or not AdService.is_available(PreRunBuffSystem.PLACEMENT)
		button.tooltip_text = "当前无可用广告" if button.disabled else "完整观看后激活"
		button.pressed.connect(_on_buff_pressed.bind(buff_id))
	_skip_button.disabled = _request_active
	%BackButton.disabled = _request_active


func _load_courtyard() -> void:
	var visuals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/town_visuals.json"))
	var paths: Array = visuals["facilities"]["bellows_station"]["courtyards"]
	var level := clampi(int(ProfileState.facility_levels.get("bellows_station", 0)), 0, paths.size() - 1)
	%Courtyard.texture = load(String(paths[level])) as Texture2D


func _on_buff_pressed(buff_id: StringName) -> void:
	if _request_active or _leaving or not PreRunBuffSystem.needs_preparation(): return
	_request_active = true
	_build()
	if PreRunBuffSystem.request_buff(buff_id).is_empty():
		_request_active = false
		_build()


func _on_skip() -> void:
	if _request_active or _leaving or TransitionManager.is_transitioning:
		return
	if RunState.pre_run_preparation_resolved or PreRunBuffSystem.skip_preparation():
		_go_map()
	else:
		%AdStatus.text = "保存失败，请重试。"


func _on_ad_reward_resolved(_transaction_id: String, placement_id: StringName, result: StringName) -> void:
	if placement_id != PreRunBuffSystem.PLACEMENT:
		return
	if result == &"granted":
		_go_map()
		return
	_request_active = false
	_build()
	%AdStatus.text = "广告未完成，加成未领取。陶婆的馈赠仍保留，可直接出发。"


func _go_map() -> void:
	if _leaving: return
	_leaving = true
	_route_scene(MAP_PLAY)


func _back() -> void:
	if _request_active or _leaving or TransitionManager.is_transitioning: return
	if SaveManager.save_game():
		_leaving = true
		_route_scene(MAIN_MENU)
	else: %AdStatus.text = "保存失败，请重试。"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST: _back()

func _route_scene(path: String) -> void:
	if TransitionManager.is_transitioning:
		_transition_destination = load(path) as PackedScene
	else:
		TransitionManager.change_scene_to_file.call_deferred(path)

func take_transition_destination() -> PackedScene:
	var next := _transition_destination
	_transition_destination = null
	return next
