extends Node
## 失败结算回归：不得提前新开 Run；基础火种、广告按钮与返回窑口镇入口必须保留。
## 所有火种数值仅注入当前验证进程，不写入正式配置。

const TEST_SAVE_PATH := "res://Temp/run_result_flow_verify.json"

var passed := 0
var failed := 0
var original_profile: Dictionary
var original_run: Dictionary
var original_meta_progression: Dictionary
var original_ad_economy: Dictionary
var original_autosave: bool
var original_save_path: String


func _ready() -> void:
	await get_tree().process_frame
	_backup()
	_install_test_values()
	ProfileState.reset_to_defaults(false)
	check("调试构建提供可点击的模拟广告", AdService.is_debug_simulation() and AdService.is_available(&"run_end_currency"))
	check("可创建结算验证 Run", RunState.start_new_run())
	RunState.pre_run_preparation_resolved = true
	RunState.current_floor = 4
	RunState.defeated.assign([&"claylump", &"sootling"])
	var ended_run_id := RunState.run_id
	RunState.last_combat_victory = false
	RunState.pending_post_combat = true
	RunState.end_run(false)
	var base_balance := ProfileState.fireseed_balance
	check("失败 Run 立即获得基础火种", RunState.run_end_base_settled and base_balance > 0)

	var map_ui: Variant = (load("res://scenes/map/MapPlay.tscn") as PackedScene).instantiate()
	add_child(map_ui)
	await get_tree().process_frame
	check("失败结算不会提前创建下一局", not RunState.is_active and RunState.run_id == ended_run_id)
	check("结算面板保留本局火种结果", map_ui._result_fireseed_label != null and map_ui._result_fireseed_label.text.contains("已到账"))
	var return_town := map_ui.find_child("ReturnTownButton", true, false) as Button
	check("倒下结算提供返回窑口镇按钮", return_town != null and not return_town.disabled and not return_town.pressed.get_connections().is_empty())
	check("局终广告按钮可以点击", map_ui._result_ad_button != null and not map_ui._result_ad_button.disabled)
	map_ui._result_ad_button.pressed.emit()
	var resolved: Array = await SignalBus.ad_reward_resolved
	check("模拟完整观看后追加火种", resolved[2] == &"granted" and ProfileState.fireseed_balance > base_balance)
	check("广告追加后按钮消失且结果更新", not map_ui._result_ad_button.visible and map_ui._result_fireseed_label.text.contains("广告额外"))
	map_ui.queue_free()
	await get_tree().process_frame
	_restore()
	print("RUN_RESULT_FLOW_RESULT:%s %d PASS / %d FAIL" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])


func _backup() -> void:
	original_profile = ProfileState.to_save_dict()
	original_run = RunState.to_save_dict()
	original_meta_progression = GameData.meta_progression.duplicate(true)
	original_ad_economy = GameData.ad_economy.duplicate(true)
	original_autosave = ProfileManager.autosave_enabled
	original_save_path = SaveManager.runtime_save_path
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = TEST_SAVE_PATH
	_cleanup_test_save()


func _install_test_values() -> void:
	GameData.meta_progression = original_meta_progression.duplicate(true)
	GameData.meta_progression["run_end_rewards"] = {
		"floor_index_offset": 1,
		"per_floor": 2,
		"per_defeated_enemy": 3,
		"victory_bonus": 10,
		"base_cap": 100,
	}
	GameData.ad_economy = original_ad_economy.duplicate(true)
	GameData.ad_economy["placements"]["run_end_currency"].merge({
		"bonus_multiplier": 0.5,
		"bonus_cap": 20,
		"rounding": "floor",
	}, true)


func _restore() -> void:
	GameData.meta_progression = original_meta_progression
	GameData.ad_economy = original_ad_economy
	ProfileState.from_save_dict(original_profile, false)
	RunState.from_save_dict(original_run)
	ProfileManager.autosave_enabled = original_autosave
	_cleanup_test_save()
	SaveManager.runtime_save_path = original_save_path


func _cleanup_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		var directory := DirAccess.open("res://Temp")
		if directory != null:
			directory.remove(TEST_SAVE_PATH.get_file())
