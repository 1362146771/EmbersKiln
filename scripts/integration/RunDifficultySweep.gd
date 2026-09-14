extends "res://scripts/integration/PlaythroughTest.gd"
## 整局难度采样：复用 PlaythroughTest 的真实地图、奖励与战斗驱动，
## 分别以新手档案和满成长档案执行既有 MAX_ATTEMPTS 次完整单局。
## 本测试只报告成功率，不自设未经策划确认的合格线。

const TEST_SAVE_PATH := "res://Temp/run_difficulty_sweep_save.json"


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	if not GameData.is_loaded:
		print("RUN_DIFFICULTY_RESULT:ERROR GameData 加载失败")
		return
	_total_all_floors = 0
	for act_config in GameData.act_configs:
		_total_all_floors += int(act_config.get("floor_count", 0))

	var original_profile := ProfileState.to_save_dict()
	var original_profile_autosave := ProfileManager.autosave_enabled
	var original_save_path := SaveManager.runtime_save_path
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = TEST_SAVE_PATH
	SaveManager.delete_save()

	var newcomer := await _sample_profile(false)
	var progressed := await _sample_profile(true)

	ProfileState.from_save_dict(original_profile, false, false)
	SaveManager.delete_save()
	SaveManager.runtime_save_path = original_save_path
	ProfileManager.autosave_enabled = original_profile_autosave
	_print_difficulty_report(newcomer, progressed)


func _sample_profile(fully_progressed: bool) -> Dictionary:
	if fully_progressed:
		_prepare_fully_progressed_test_profile()
	else:
		ProfileState.reset_to_defaults(false)
	var cc := CombatController.new()
	add_child(cc)
	var wins := 0
	var floors_sum := 0
	var winning_hp_sum := 0
	var best_floor := 0
	for _attempt in range(MAX_ATTEMPTS):
		RunState.start_new_run()
		var won := await _run_floors(cc)
		floors_sum += _floors_cleared
		best_floor = maxi(best_floor, _floors_cleared)
		if won:
			wins += 1
			winning_hp_sum += _final_hp
	cc.queue_free()
	return {
		"wins": wins,
		"attempts": MAX_ATTEMPTS,
		"win_rate": float(wins) / float(MAX_ATTEMPTS),
		"average_floors": float(floors_sum) / float(MAX_ATTEMPTS),
		"best_floor": best_floor,
		"average_winning_hp": float(winning_hp_sum) / float(maxi(1, wins)),
	}


func _print_difficulty_report(newcomer: Dictionary, progressed: Dictionary) -> void:
	print("===== 当前数据整局难度采样 =====")
	print("数据：cards=%d enemies=%d acts=%d attempts/profile=%d" % [
		GameData.cards.size(), GameData.enemies.size(), GameData.act_configs.size(), MAX_ATTEMPTS
	])
	_print_profile_line("新手档案", newcomer)
	_print_profile_line("满成长档案", progressed)
	print("RUN_DIFFICULTY_RESULT:COMPLETE")


func _print_profile_line(label: String, result: Dictionary) -> void:
	print("%s：胜利=%d/%d 胜率=%.1f%% 平均推进=%.1f/%d 最深=%d/%d 胜局平均终局HP=%.1f" % [
		label,
		int(result["wins"]),
		int(result["attempts"]),
		float(result["win_rate"]) * 100.0,
		float(result["average_floors"]),
		_total_all_floors,
		int(result["best_floor"]),
		_total_all_floors,
		float(result["average_winning_hp"]),
	])
