extends Node
## 商店刷新与工坊加速前后端专项；所有数值仅注入当前验证进程。

const TEST_SAVE_PATH := "res://Temp/ad_placement_ui_verify.json"
const TEST_PROJECT_ID := &"verify_ui_speedup"

var passed := 0
var failed := 0
var original_profile: Dictionary
var original_run: Dictionary
var original_autosave: bool
var original_save_path: String
var original_provider: RewardedAdProvider
var original_meta_progression: Dictionary
var original_meta_projects: Dictionary
var original_ad_economy: Dictionary


func _ready() -> void:
	await get_tree().process_frame
	_backup()
	ProfileState.reset_to_defaults(false)
	check("可创建 UI 验证 Run", RunState.start_new_run())
	RunState.pre_run_preparation_resolved = true
	RunState.current_floor = 5

	var shop: Variant = (load("res://scenes/map/ShopUI.tscn") as PackedScene).instantiate()
	add_child(shop)
	await get_tree().process_frame
	var pending_shop_button := shop.find_child("ShopRefreshAdButton", true, false) as Button
	check("正式商店刷新入口已启用", pending_shop_button != null and not pending_shop_button.disabled and pending_shop_button.text.contains("剩余"))
	shop.queue_free()
	await get_tree().process_frame

	_install_test_values()
	var fake := FakeRewardedAdProvider.new()
	fake.default_available = true
	fake.fallback_result = AdService.RESULT_COMPLETED
	AdService.set_provider(fake)

	shop = (load("res://scenes/map/ShopUI.tscn") as PackedScene).instantiate()
	add_child(shop)
	await get_tree().process_frame
	var shop_inventory_system := get_node("/root/ShopInventorySystem")
	var shop_button := shop.find_child("ShopRefreshAdButton", true, false) as Button
	check("配置完成后商店刷新按钮可点击", shop_button != null and not shop_button.disabled and shop_button.text.contains("剩余"))
	var shop_id: String = shop_inventory_system.current_shop_id()
	shop_button.pressed.emit()
	var shop_resolved: Array = await SignalBus.ad_reward_resolved
	check("商店广告完整观看后后端刷新库存", shop_resolved[2] == &"granted" and int(shop_inventory_system.get_state(shop_id).get("refresh_count", 0)) == 1)
	check("商店前端刷新后显示次数已用尽", shop.find_child("ShopRefreshAdButton", true, false).disabled)
	shop.queue_free()
	await get_tree().process_frame

	ProfileState.add_fireseed(100)
	var now := int(Time.get_unix_time_from_system())
	check("验证工坊项目可开始建造", WorkshopSystem.start_project(TEST_PROJECT_ID, now))
	var before := WorkshopSystem.remaining_seconds(TEST_PROJECT_ID, now)
	var town: Variant = (load("res://scenes/main/Town.tscn") as PackedScene).instantiate()
	add_child(town)
	await get_tree().process_frame
	var speedup_button := town.find_child("WorkshopSpeedupAdButton_%s" % String(TEST_PROJECT_ID), true, false) as Button
	check("工坊建造中显示可点击广告加速", speedup_button != null and not speedup_button.disabled and speedup_button.text.contains("减少"))
	speedup_button.pressed.emit()
	var speedup_resolved: Array = await SignalBus.ad_reward_resolved
	# 让结果监听器完成 UI 重建，并清理 queue_free 的旧按钮。
	await get_tree().process_frame
	var after := WorkshopSystem.remaining_seconds(TEST_PROJECT_ID, now)
	check("工坊广告完整观看后减少配置时长", speedup_resolved[2] == &"granted" and before - after == 600)
	check("工坊前端更新项目加速次数", town.find_child("WorkshopSpeedupAdButton_%s" % String(TEST_PROJECT_ID), true, false).disabled)
	town.queue_free()
	await get_tree().process_frame
	_restore()
	print("AD_PLACEMENT_UI_RESULT:%s %d PASS / %d FAIL" % ["PASS" if failed == 0 else "FAIL", passed, failed])
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
	original_provider = AdService.provider
	original_meta_progression = GameData.meta_progression.duplicate(true)
	original_meta_projects = GameData.meta_projects.duplicate(true)
	original_ad_economy = GameData.ad_economy.duplicate(true)
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = TEST_SAVE_PATH
	_cleanup_test_save()


func _install_test_values() -> void:
	var project := {
		"id": String(TEST_PROJECT_ID),
		"name": "广告加速 UI 验证",
		"facility_id": "hearth",
		"fireseed_cost": 10,
		"duration_seconds": 3600,
		"prerequisite_project_ids": [],
		"grants": {},
	}
	GameData.meta_progression = original_meta_progression.duplicate(true)
	GameData.meta_progression["workshop"] = {"queue_capacity": 1}
	GameData.meta_progression["projects"] = [project]
	GameData.meta_projects = {TEST_PROJECT_ID: project}
	GameData.ad_economy = original_ad_economy.duplicate(true)
	GameData.ad_economy["placements"]["shop_refresh"]["max_per_shop"] = 1
	GameData.ad_economy["placements"]["workshop_speedup"].merge({
		"seconds_reduced": 600,
		"max_per_project": 1,
		"max_per_day": 1,
	}, true)


func _restore() -> void:
	GameData.meta_progression = original_meta_progression
	GameData.meta_projects = original_meta_projects
	GameData.ad_economy = original_ad_economy
	ProfileState.from_save_dict(original_profile, false)
	RunState.from_save_dict(original_run)
	AdService.set_provider(original_provider)
	ProfileManager.autosave_enabled = original_autosave
	_cleanup_test_save()
	SaveManager.runtime_save_path = original_save_path


func _cleanup_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		var directory := DirAccess.open("res://Temp")
		if directory != null:
			directory.remove(TEST_SAVE_PATH.get_file())
