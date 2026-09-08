extends Node
## 正式局外经济曲线：产出、递增成本、封顶纵向成长与横向内容覆盖。

const TEST_SAVE_PATH := "res://Temp/meta_economy_curve_verify.json"

var passed := 0
var failed := 0
var original_profile: Dictionary
var original_run: Dictionary
var original_autosave: bool
var original_save_path: String


func _ready() -> void:
	await get_tree().process_frame
	_backup()
	_test_formal_curve()
	_test_reward_scenarios()
	_test_vertical_caps()
	_test_unlock_coverage()
	_restore()
	print("META_ECONOMY_CURVE_RESULT:%s %d PASS / %d FAIL" % ["PASS" if failed == 0 else "FAIL", passed, failed])
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
	original_autosave = ProfileManager.autosave_enabled
	original_save_path = SaveManager.runtime_save_path
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = TEST_SAVE_PATH
	_cleanup_test_save()


func _test_formal_curve() -> void:
	var projects := GameData.meta_project_list()
	check("正式成长线包含 21 个项目", projects.size() == 21)
	check("工坊允许两项并行建造", WorkshopSystem.queue_capacity() == 2)
	var costs: Array[int] = []
	var durations: Array[int] = []
	for project in projects:
		costs.append(int(project.get("fireseed_cost", 0)))
		durations.append(int(project.get("duration_seconds", 0)))
	var nondecreasing_costs := true
	var nondecreasing_durations := true
	for index in range(1, costs.size()):
		nondecreasing_costs = nondecreasing_costs and costs[index] >= costs[index - 1]
		nondecreasing_durations = nondecreasing_durations and durations[index] >= durations[index - 1]
	check("项目成本按投放顺序不下降", nondecreasing_costs)
	check("建造时间按投放顺序不下降", nondecreasing_durations)
	check("总养成消耗为 2735 火种", _sum(costs) == 2735)
	check("首项 15 火种且终项 360 火种", costs.front() == 15 and costs.back() == 360)
	check("建造时间从 1 分钟递增到 24 小时", durations.front() == 60 and durations.back() == 86400)
	check("商店每店广告刷新一次", int(GameData.ad_placement_config(&"shop_refresh").get("max_per_shop", 0)) == 1)
	check("工坊广告每次减 1 小时且单项目最多 2 次", WorkshopSystem.speedup_seconds() == 3600 and WorkshopSystem.speedup_project_limit() == 2)
	check("工坊广告每日上限为 6 次", WorkshopSystem.speedup_day_limit() == 6)
	check("牌库广告每次扩 3 张且每局最多 2 次", int(GameData.ad_placement_config(&"deck_capacity_expand").get("slots_per_view", 0)) == 3 and int(GameData.ad_placement_config(&"deck_capacity_expand").get("max_per_run", 0)) == 2)


func _test_reward_scenarios() -> void:
	check("早期失败基础火种为 11", _settle_scenario(0, 4, 6, false) == 11)
	check("进入第二幕后早败基础火种为 34", _settle_scenario(1, 0, 18, false) == 34)
	var full_reward := _settle_scenario(2, 14, 45, true)
	check("完整通关基础火种封顶为 100", full_reward == 100)
	check("完整通关广告额外火种封顶为 30", RunEndRewardSystem.preview_ad_bonus() == 30)


func _settle_scenario(act: int, floor: int, defeated_count: int, victory: bool) -> int:
	ProfileState.reset_to_defaults(false)
	RunState.start_new_run()
	RunState.current_act = act
	RunState.current_floor = floor
	RunState.defeated.clear()
	for _index in defeated_count:
		RunState.defeated.append(&"claylump")
	RunEndRewardSystem.settle_base_reward(victory)
	return RunState.run_end_base_fireseed


func _test_vertical_caps() -> void:
	ProfileState.reset_to_defaults(false)
	RunState.start_new_run()
	check("未升级新局为 80 生命、0 金币、18 容量", RunState.max_hp == 80 and RunState.gold == 0 and RunState.base_run_deck_capacity == 18)
	ProfileState.facility_levels["hearth"] = 1
	RunState.start_new_run()
	check("炉心 I 提高到 82 生命", RunState.max_hp == 82 and RunState.gold == 0)
	ProfileState.facility_levels["hearth"] = 2
	RunState.start_new_run()
	check("炉心 II 提高到 84 生命并给 20 金币", RunState.max_hp == 84 and RunState.gold == 20)
	ProfileState.facility_levels["hearth"] = 3
	RunState.start_new_run()
	check("炉心 III 纵向封顶为 87 生命和 40 金币", RunState.max_hp == 87 and RunState.gold == 40)


func _test_unlock_coverage() -> void:
	ProfileState.reset_to_defaults(false)
	check("初始池不包含后期稀有卡", GameData.is_card_unlocked(&"anger") and not GameData.is_card_unlocked(&"demon_form"))
	ProfileState.unlocked_card_ids.append(&"demon_form")
	check("完成研究后卡牌进入候选池", GameData.is_card_unlocked(&"demon_form"))
	check("卡牌成长覆盖全部非起始卡", _covered_ids("card_ids", "unlocked_card_ids").size() == _nonstarter_card_count())
	check("遗物成长覆盖全部非起始遗物", _covered_ids("relic_ids", "unlocked_relic_ids").size() == _nonstarter_relic_count())
	check("药水成长覆盖全部药水", _covered_ids("potion_ids", "unlocked_potion_ids").size() == GameData.potions.size())
	check("附魔成长覆盖全部附魔", _covered_ids("enchant_ids", "unlocked_enchant_ids").size() == GameData.enchants.size())


func _covered_ids(initial_field: String, grant_field: String) -> Dictionary:
	var covered: Dictionary = {}
	for content_id in GameData.meta_progression.get("initial_unlocks", {}).get(initial_field, []):
		covered[String(content_id)] = true
	for project in GameData.meta_project_list():
		for content_id in project.get("grants", {}).get(grant_field, []):
			covered[String(content_id)] = true
	return covered


func _nonstarter_card_count() -> int:
	var count := 0
	for card in GameData.cards.values():
		if not card.rarity in [&"starter", &"special"]:
			count += 1
	return count


func _nonstarter_relic_count() -> int:
	var count := 0
	for relic in GameData.relics.values():
		if relic.rarity != &"starter":
			count += 1
	return count


func _sum(values: Array[int]) -> int:
	var total := 0
	for value in values:
		total += value
	return total


func _restore() -> void:
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
