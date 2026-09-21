extends Node
## tools/run_transition_verify.py --suite pause-abandon [--render]，仅运行于隔离副本。
const MENU := "res://scenes/main/MainMenu.tscn"
const COMBAT := "res://scenes/combat/CombatPlay.tscn"
const MAP := "res://scenes/map/MapPlay.tscn"
var checks := 0
var failures := 0
var ended_count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_cmdline_user_args().has("--pause-abandon-verify"):
		return
	var path := ProjectSettings.globalize_path("res://").replace("\\", "/")
	if not path.contains("/Temp/transition-verify-") or not OS.get_user_data_dir().replace("\\", "/").begins_with(path):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	_run.call_deferred()


func _run() -> void:
	get_tree().create_timer(60.0, true, false, true).timeout.connect(func(): get_tree().quit(2))
	SignalBus.run_ended.connect(func(_victory): ended_count += 1)
	get_tree().current_scene._on_play()
	await _wait_transition()
	_check("进入真实战斗并创建检查点", _at(COMBAT) and RunState.has_combat_checkpoint())
	var run_id := RunState.run_id
	# 先回归原有保存并返回、继续游戏行为。
	PauseManager._open_pause()
	await _wait_transition()
	_press("MainMenuButton")
	await _wait_transition()
	_check("保存返回保留继续入口", _at(MENU) and get_tree().current_scene.play_button.text == "继续游戏")
	get_tree().current_scene._on_play()
	await _wait_transition()
	_check("继续仍恢复原战斗", _at(COMBAT) and RunState.run_id == run_id)
	await _exercise_abandon("combat")
	get_tree().current_scene._on_play()
	await _wait_transition()
	_check("放弃后开始游戏返回城镇", get_tree().current_scene.scene_file_path == "res://scenes/town/Town.tscn" and not RunState.is_active)
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	SaveManager.save_game()
	TransitionManager.change_scene_to_file(MAP)
	await _wait_transition()
	_check("进入真实地图", _at(MAP))
	await _exercise_abandon("map")
	print("PAUSE_ABANDON_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _exercise_abandon(context: String) -> void:
	var source := get_tree().current_scene
	var before := RunState.to_save_dict().duplicate(true)
	var save_before := FileAccess.get_file_as_string(SaveManager.runtime_save_path)
	var profile_before := FileAccess.get_file_as_string(ProfileManager.PROFILE_PATH)
	PauseManager._open_pause()
	await _wait_transition()
	_check("%s 暂停显示放弃按钮" % context, not _button("AbandonButton").disabled and get_tree().paused)
	await _capture(context + "-pause")
	_press("AbandonButton")
	await get_tree().process_frame
	_check("确认框默认聚焦取消", PauseManager._is_abandon_confirmation_open() and _button("CancelAbandonButton").has_focus())
	await _capture(context + "-confirm")
	_check("打开确认不改变存档或场景", source == get_tree().current_scene and FileAccess.get_file_as_string(SaveManager.runtime_save_path) == save_before)
	_press("CancelAbandonButton")
	_check("取消保留暂停与完整本局状态", get_tree().paused and not PauseManager._is_abandon_confirmation_open() and RunState.to_save_dict() == before)
	_press("AbandonButton")
	PauseManager._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	_check("手机返回键只取消确认", get_tree().paused and not PauseManager._is_abandon_confirmation_open())
	_press("ResumeButton")
	await _wait_transition()
	_check("取消后可正常继续", not get_tree().paused and source == get_tree().current_scene and RunState.is_active)
	PauseManager._open_pause()
	await _wait_transition()
	_press("AbandonButton")
	_press("ConfirmAbandonButton")
	_press("ConfirmAbandonButton")
	_check("确认立即锁输入", TransitionManager.is_transitioning)
	await _wait_transition()
	_check("确认放弃返回主菜单且解除暂停", _at(MENU) and not get_tree().paused and not PauseManager._open and PauseManager._overlay == null)
	_check("本局存档删除且不可恢复", not SaveManager.has_save() and not SaveManager.load_game() and not RunState.is_active and not RunState.has_combat_checkpoint())
	_check("待战斗及待结算状态清除", RunState.pending_combat_enemy_ids.is_empty() and not RunState.pending_post_combat and not RunState.pending_post_reward and RunState.pending_reward_data.is_empty())
	_check("主菜单入口恢复开始游戏", get_tree().current_scene.play_button.text == "开始游戏")
	_check("保留永久档案且不触发胜败奖励", FileAccess.get_file_as_string(ProfileManager.PROFILE_PATH) == profile_before and ended_count == 0)
	SaveManager._notification(NOTIFICATION_APPLICATION_PAUSED)
	_check("后台自动保存不会复活被放弃的局", not SaveManager.has_save())
	await _capture(context + "-menu")


func _button(node_name: String) -> Button:
	return PauseManager._overlay.find_child(node_name, true, false) as Button


func _press(node_name: String) -> void:
	_button(node_name).pressed.emit()


func _wait_transition() -> void:
	while TransitionManager.is_transitioning:
		await get_tree().process_frame
	await get_tree().process_frame


func _at(path: String) -> bool:
	return get_tree().current_scene.scene_file_path == path


func _check(label: String, condition: bool) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://abandon-%s.png" % label)
