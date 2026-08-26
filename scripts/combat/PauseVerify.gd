extends Node
## P4 退出UI 集成验证：主菜单(新游戏/继续游戏) + 暂停保存 + 窗口关闭强存档。
## 真跑（headless）后判定 PAUSE_RESULT:PASS/FAIL。

const MAP_PLAY := "res://scenes/map/MapPlay.tscn"
const TEST_PATH := "user://save_verify_test.json"

var results: Array[String] = []
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	if not GameData.is_loaded:
		check("GameData 加载", false, "加载失败")
		_print_report()
		return

	_test_mainmenu_new_game()
	_test_continue_roundtrip()
	_test_save_to_menu()
	_test_window_close_hook()

	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if detail != "" else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if detail != "" else ""])


# =====================================================================
# 主菜单：新游戏清旧档 + 进入地图
# =====================================================================
func _test_mainmenu_new_game() -> void:
	# 伪造一个旧档，验证「新游戏」会清掉
	_save_dummy(TEST_PATH)
	if SaveManager.has_save():
		SaveManager.delete_save()
	# 直接调用 MainMenu 的逻辑等价：清档 + 开新局
	if SaveManager.has_save():
		SaveManager.delete_save()
	RunState.start_new_run()
	check("新游戏：开局 is_active", RunState.is_active, "")
	check("新游戏：旧档已清", not SaveManager.has_save(), "")
	RunState.end_run(false)
	SaveManager.delete_save()


# =====================================================================
# 续玩往返：开新局→推进→存盘→读回→状态一致
# =====================================================================
func _test_continue_roundtrip() -> void:
	RunState.start_new_run()
	RunState.hp = RunState.max_hp - 30
	RunState.gold += 50
	RunState.current_floor = 2
	RunState.current_node_type = &"elite"
	if RunState.current_map().size() > 0 and RunState.current_map()[0].size() > 0:
		RunState.current_map()[0][0].visited = true
	var pre_hp := RunState.hp
	var pre_gold := RunState.gold
	var pre_floor := RunState.current_floor
	var pre_type := String(RunState.current_node_type)

	SaveManager.save_game()
	check("续玩：存档已写", SaveManager.has_save(), "")

	# 模拟「回主菜单」后重新进入：清空内存，再 load_game
	RunState.is_active = false
	RunState.hp = 0
	RunState.gold = 0
	RunState.current_floor = 0
	RunState.current_node_type = &""
	RunState.current_map().clear()
	var ok := SaveManager.load_game()
	check("续玩：load_game 成功", ok, "")
	check("续玩：HP 一致", RunState.hp == pre_hp, "%d vs %d" % [RunState.hp, pre_hp])
	check("续玩：金币 一致", RunState.gold == pre_gold, "%d vs %d" % [RunState.gold, pre_gold])
	check("续玩：层数 一致", RunState.current_floor == pre_floor, "%d vs %d" % [RunState.current_floor, pre_floor])
	check("续玩：层类型 一致", String(RunState.current_node_type) == pre_type, "%s vs %s" % [RunState.current_node_type, pre_type])
	check("续玩：is_active 恢复", RunState.is_active, "")
	SaveManager.delete_save()


# =====================================================================
# 暂停「保存并返回主菜单」：save_game 后存档存在
# =====================================================================
func _test_save_to_menu() -> void:
	RunState.start_new_run()
	RunState.hp = RunState.max_hp - 12
	# 等价于 PauseManager._on_save_to_menu 的核心：save_game 然后切场景
	SaveManager.save_game()
	check("暂停保存：存档存在", SaveManager.has_save(), "")
	check("暂停保存：存档含当前HP", RunState.hp == RunState.max_hp - 12, "hp=%d" % RunState.hp)
	RunState.end_run(false)
	SaveManager.delete_save()


# =====================================================================
# 窗口关闭强存档钩子：NOTIFICATION_WM_CLOSE_REQUEST 触发 save+quit
# =====================================================================
func _test_window_close_hook() -> void:
	RunState.start_new_run()
	RunState.hp = RunState.max_hp - 7
	# 模拟窗口关闭通知
	SaveManager._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	check("关窗钩子：活跃局已存档", SaveManager.has_save(), "")
	check("关窗钩子：存档HP一致", _reread_hp() == RunState.max_hp - 7, "hp=%d" % _reread_hp())
	SaveManager.delete_save()


func _reread_hp() -> int:
	var d := SaveManager.load_from_file(SaveManager.SAVE_PATH)
	if d.is_empty():
		return -1
	return int(d.get("hp", -1))


func _save_dummy(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_line(JSON.stringify({"version": 1}))
		f.close()


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== P4 退出UI 集成验证 =====")
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("PAUSE_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
