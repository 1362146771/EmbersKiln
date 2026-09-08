extends Node
## 永久档案基础验证：往返、坏档拒绝、防重复事务、原子文件替换与路径隔离。

const TEST_PATH := "res://Temp/profile_verify_test.json"

var pass_count := 0
var fail_count := 0
var results: Array[String] = []
var original_profile: Dictionary
var original_autosave: bool


func _ready() -> void:
	await get_tree().process_frame
	original_autosave = ProfileManager.autosave_enabled
	ProfileManager.autosave_enabled = false
	original_profile = ProfileState.to_save_dict()
	_cleanup_test_files()
	_test_roundtrip()
	_test_invalid_data_is_transactional()
	_test_v1_migration()
	_test_card_discovery()
	_test_reward_transaction_idempotency()
	_test_atomic_replace()
	_test_run_profile_path_isolation()
	ProfileState.from_save_dict(original_profile, false)
	ProfileManager.autosave_enabled = original_autosave
	_cleanup_test_files()
	_print_report()


func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if not detail.is_empty() else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if not detail.is_empty() else ""])


func _test_roundtrip() -> void:
	ProfileState.reset_to_defaults(false)
	ProfileState.add_fireseed(37)
	ProfileState.set_facility_level(&"card_workshop", 2)
	ProfileState.completed_project_ids.append(&"project_alpha")
	ProfileState.unlocked_card_ids.assign([&"strike", &"bash"])
	ProfileState.discover_card(&"cleave", false)
	ProfileState.construction_queue.assign([{"project_id": "project_beta", "finish_at": 12345, "ad_speedup_count": 0}])
	ProfileState.town_visual_stage = 3
	ProfileState.record_reward_transaction("run-test:base")
	var expected := ProfileState.to_save_dict()

	check("永久档案写入成功", ProfileManager.save_to_file(TEST_PATH, expected))
	check("临时文件已提交", not FileAccess.file_exists(TEST_PATH + ".tmp"))
	ProfileState.reset_to_defaults(false)
	check("永久档案读取成功", ProfileManager.load_profile_from_file(TEST_PATH, false))
	var actual := ProfileState.to_save_dict()
	check("往返数据一致", actual == expected, "expected=%s actual=%s" % [expected, actual] if actual != expected else "")


func _test_invalid_data_is_transactional() -> void:
	var before := ProfileState.to_save_dict()
	var bad_version := before.duplicate(true)
	bad_version["version"] = 999
	check("版本不匹配被拒绝", not ProfileState.from_save_dict(bad_version, false, false))
	check("版本错误不污染当前档案", ProfileState.to_save_dict() == before)

	var bad_balance := before.duplicate(true)
	bad_balance["fireseed_balance"] = -1
	check("负数火种被拒绝", not ProfileState.from_save_dict(bad_balance, false, false))
	check("非法数值不污染当前档案", ProfileState.to_save_dict() == before)


func _test_v1_migration() -> void:
	var legacy := ProfileState.to_save_dict()
	legacy["version"] = 1
	legacy.erase("pending_reward_transactions")
	legacy.erase("base_run_deck_capacity")
	legacy.erase("ad_daily_usage")
	legacy.erase("discovered_card_ids")
	check("v1 永久档案可迁移", ProfileState.from_save_dict(legacy, false))
	check("迁移后使用当前版本结构", int(ProfileState.to_save_dict().get("version", -1)) == ProfileState.PROFILE_VERSION)
	check("迁移后待发事务默认为空", ProfileState.pending_reward_transactions.is_empty())
	check("迁移后牌库容量默认未配置", ProfileState.base_run_deck_capacity == -1)
	check("迁移后每日广告计数为空", ProfileState.ad_daily_usage.is_empty())
	check("旧档迁移后默认发现三张起始牌", ProfileState.discovered_card_count() == 3)

	var v2 := ProfileState.to_save_dict()
	v2["version"] = 2
	v2.erase("base_run_deck_capacity")
	v2.erase("ad_daily_usage")
	v2.erase("discovered_card_ids")
	check("v2 永久档案可迁移", ProfileState.from_save_dict(v2, false))
	check("v2 迁移后使用当前版本结构", int(ProfileState.to_save_dict().get("version", -1)) == ProfileState.PROFILE_VERSION)


func _test_card_discovery() -> void:
	ProfileState.reset_to_defaults(false)
	check("新档默认发现三张起始牌", ProfileState.discovered_card_count() == 3
		and ProfileState.is_card_discovered(&"strike")
		and ProfileState.is_card_discovered(&"defend")
		and ProfileState.is_card_discovered(&"bash"))
	check("首次获得职业牌写入图鉴", ProfileState.discover_card(&"cleave", false)
		and ProfileState.is_card_discovered(&"cleave"))
	check("重复获得不会重复计数", not ProfileState.discover_card(&"cleave", false)
		and ProfileState.discovered_card_count() == 4)
	check("生成状态牌不计入图鉴", not ProfileState.discover_card(&"wound", false)
		and not ProfileState.is_card_discovered(&"wound"))


func _test_reward_transaction_idempotency() -> void:
	ProfileState.reset_to_defaults(false)
	check("首次奖励事务可登记", ProfileState.record_reward_transaction("run-1:ad_bonus"))
	check("重复奖励事务被拒绝", not ProfileState.record_reward_transaction("run-1:ad_bonus"))
	check("事务查询命中", ProfileState.has_reward_transaction("run-1:ad_bonus"))
	check("重复事务只保存一次", ProfileState.reward_transaction_ids.size() == 1)


func _test_atomic_replace() -> void:
	ProfileState.reset_to_defaults(false)
	ProfileState.add_fireseed(5)
	check("首次原子保存", ProfileManager.save_to_file(TEST_PATH, ProfileState.to_save_dict()))
	ProfileState.add_fireseed(7)
	var second := ProfileState.to_save_dict()
	check("覆盖原档成功", ProfileManager.save_to_file(TEST_PATH, second))
	check("覆盖后无备份残留", not FileAccess.file_exists(TEST_PATH + ".bak"))
	ProfileState.reset_to_defaults(false)
	check("覆盖后的档案可读", ProfileManager.load_profile_from_file(TEST_PATH, false))
	check("读取的是最新内容", ProfileState.to_save_dict() == second)


func _test_run_profile_path_isolation() -> void:
	check("Run 与 Profile 路径不同", SaveManager.SAVE_PATH != ProfileManager.PROFILE_PATH)
	check("Profile 使用独立文件", ProfileManager.PROFILE_PATH.get_file() == "profile.json")
	check("Run 删档 API 不指向 Profile", SaveManager.SAVE_PATH.get_file() != ProfileManager.PROFILE_PATH.get_file())


func _cleanup_test_files() -> void:
	var dir := DirAccess.open("res://Temp")
	if dir == null:
		return
	for name in dir.get_files():
		if name.begins_with(TEST_PATH.get_file()):
			dir.remove(name)


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== 永久档案验证 =====")
	for result in results:
		lines.append(result)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("PROFILE_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
