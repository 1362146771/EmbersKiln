extends Node
## 第二阶段验证：正式养成配置、原子开工、离线计时、前置、领取与防重。

var pass_count := 0
var fail_count := 0
var results: Array[String] = []
var original_profile: Dictionary
var original_autosave: bool
var original_meta_progression: Dictionary
var original_meta_projects: Dictionary


func _ready() -> void:
	await get_tree().process_frame
	original_autosave = ProfileManager.autosave_enabled
	ProfileManager.autosave_enabled = false
	original_profile = ProfileState.to_save_dict()
	original_meta_progression = GameData.meta_progression.duplicate(true)
	original_meta_projects = GameData.meta_projects.duplicate(true)

	_test_production_config()
	_install_verify_config()
	_test_atomic_start_and_queue_rules()
	_test_natural_and_offline_completion()
	_test_claim_and_prerequisite()
	_test_insufficient_balance_is_transactional()

	GameData.meta_progression = original_meta_progression
	GameData.meta_projects = original_meta_projects
	ProfileState.from_save_dict(original_profile, false)
	ProfileManager.autosave_enabled = original_autosave
	_print_report()


func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if not detail.is_empty() else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if not detail.is_empty() else ""])


func _test_production_config() -> void:
	check("正式工坊队列容量为 2", WorkshopSystem.queue_capacity() == 2)
	check("正式工坊项目已配置 21 项", GameData.meta_project_list().size() == 21)
	check("六类窑口镇设施已登记", GameData.meta_facility_list().size() == 6)


func _install_verify_config() -> void:
	var verify_projects: Array = [
		{
			"id": "verify_hearth",
			"name": "验证炉心",
			"facility_id": "hearth",
			"fireseed_cost": 30,
			"duration_seconds": 60,
			"prerequisite_project_ids": [],
			"grants": {
				"facility_levels": {"hearth": 1},
				"unlocked_card_ids": ["strike"],
				"town_visual_stage": 1,
			},
		},
		{
			"id": "verify_recipe",
			"name": "验证配方",
			"facility_id": "card_mold_workshop",
			"fireseed_cost": 10,
			"duration_seconds": 5,
			"prerequisite_project_ids": ["verify_hearth"],
			"grants": {"unlocked_loadout_ids": ["verify_loadout"]},
		},
		{
			"id": "verify_expensive",
			"name": "验证昂贵项目",
			"facility_id": "town_restoration",
			"fireseed_cost": 999,
			"duration_seconds": 5,
			"prerequisite_project_ids": [],
			"grants": {},
		},
	]
	GameData.meta_progression = original_meta_progression.duplicate(true)
	GameData.meta_progression["workshop"] = {"queue_capacity": 1}
	GameData.meta_progression["projects"] = verify_projects
	GameData.meta_projects.clear()
	for project in verify_projects:
		GameData.meta_projects[StringName(project["id"])] = project


func _test_atomic_start_and_queue_rules() -> void:
	ProfileState.reset_to_defaults(false)
	ProfileState.add_fireseed(100)
	check("有资格项目可开工", WorkshopSystem.start_project(&"verify_hearth", 1000))
	check("开工原子扣除火种", ProfileState.fireseed_balance == 70)
	check("开工原子创建队列", ProfileState.construction_queue.size() == 1)
	var entry: Dictionary = ProfileState.construction_queue[0]
	check("建造时间来自项目配置", int(entry.get("started_at", 0)) == 1000 and int(entry.get("finish_at", 0)) == 1060)
	var before := ProfileState.to_save_dict()
	check("同一项目不能重复开工", not WorkshopSystem.start_project(&"verify_hearth", 1001))
	check("重复开工不改变档案", ProfileState.to_save_dict() == before)
	check("队列满时拒绝其他项目", not WorkshopSystem.start_project(&"verify_expensive", 1001))
	check("未完成前置的项目保持锁定", WorkshopSystem.project_status(&"verify_recipe", 1001) == WorkshopSystem.STATUS_LOCKED)


func _test_natural_and_offline_completion() -> void:
	check("到时前仍在建造", WorkshopSystem.refresh(1059).is_empty())
	var saved := ProfileState.to_save_dict()
	ProfileState.reset_to_defaults(false)
	check("模拟重启可恢复建造队列", ProfileState.from_save_dict(saved, false))
	var ready := WorkshopSystem.refresh(1060)
	check("关闭游戏后仍按现实时间完成", ready == [&"verify_hearth"])
	check("到时项目进入可领取状态", WorkshopSystem.project_status(&"verify_hearth", 1060) == WorkshopSystem.STATUS_READY)
	check("完成项目剩余时间归零", WorkshopSystem.remaining_seconds(&"verify_hearth", 1060) == 0)


func _test_claim_and_prerequisite() -> void:
	check("到时项目可领取", WorkshopSystem.claim_project(&"verify_hearth", 1060))
	check("领取移出建造队列", ProfileState.construction_queue.is_empty())
	check("领取记录永久完成", ProfileState.completed_project_ids.has(&"verify_hearth"))
	check("设施等级奖励落档", int(ProfileState.facility_levels.get("hearth", 0)) == 1)
	check("横向卡牌解锁落档", ProfileState.unlocked_card_ids.has(&"strike"))
	check("镇貌阶段奖励落档", ProfileState.town_visual_stage == 1)
	var after_claim := ProfileState.to_save_dict()
	check("完成项目不能重复领取", not WorkshopSystem.claim_project(&"verify_hearth", 1061))
	check("重复领取不改变档案", ProfileState.to_save_dict() == after_claim)
	check("前置完成后后续项目解锁", WorkshopSystem.project_status(&"verify_recipe", 1061) == WorkshopSystem.STATUS_AVAILABLE)
	check("后续项目可开工", WorkshopSystem.start_project(&"verify_recipe", 2000))
	check("后续项目按配置扣费", ProfileState.fireseed_balance == 60)
	check("后续项目自然完成", WorkshopSystem.refresh(2005) == [&"verify_recipe"])
	check("后续横向解锁可领取", WorkshopSystem.claim_project(&"verify_recipe", 2005))
	check("起始方案解锁落档", ProfileState.unlocked_loadout_ids.has(&"verify_loadout"))


func _test_insufficient_balance_is_transactional() -> void:
	var before := ProfileState.to_save_dict()
	check("火种不足时拒绝开工", not WorkshopSystem.start_project(&"verify_expensive", 3000))
	check("火种不足不扣款也不入队", ProfileState.to_save_dict() == before)


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== 局外成长与工坊验证 =====")
	for result in results:
		lines.append(result)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("META_WORKSHOP_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
