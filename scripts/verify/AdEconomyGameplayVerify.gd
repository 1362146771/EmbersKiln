extends Node
## 第四阶段验证：局末火种、工坊加速、商店刷新与单局牌库容量。
## 正式配置闭环检查 + 隔离数值下的边界与事务验证。

const TEST_SAVE_PATH := "res://Temp/ad_economy_gameplay_verify.json"

var pass_count := 0
var fail_count := 0
var results: Array[String] = []
var original_profile: Dictionary
var original_run: Dictionary
var original_autosave: bool
var original_save_path: String
var original_provider: RewardedAdProvider
var original_meta_progression: Dictionary
var original_meta_projects: Dictionary
var original_ad_economy: Dictionary
var fake: FakeRewardedAdProvider


func _ready() -> void:
	await get_tree().process_frame
	_backup_state()
	_test_production_config()
	_install_verify_config()
	ProfileState.reset_to_defaults(false)
	check("验证配置可创建新局", RunState.start_new_run())
	await _test_run_end_rewards()
	await _test_workshop_speedup()
	await _test_shop_refresh()
	await _test_deck_capacity_and_shop_purchase()
	_test_run_save_migration()
	_restore_state()
	_print_report()


func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if not detail.is_empty() else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if not detail.is_empty() else ""])


func _backup_state() -> void:
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
	fake = FakeRewardedAdProvider.new()
	AdService.set_provider(fake)
	for placement in AdService.PLACEMENTS:
		fake.set_available(placement, true)


func _test_production_config() -> void:
	check("正式局末基础火种已配置", RunEndRewardSystem.is_base_configured())
	check("正式局末广告加成已配置", RunEndRewardSystem.is_ad_bonus_configured())
	check("正式工坊加速已配置", WorkshopSystem.is_speedup_configured())
	check("正式商店刷新已配置", ShopInventorySystem.is_refresh_configured())
	check("正式单局基础牌库容量为 18", int(GameData.meta_progression.get("base_run_deck_capacity", -1)) == 18)
	check("正式广告扩容已配置", CardAcquireService.is_expand_configured())


func _install_verify_config() -> void:
	GameData.meta_progression = original_meta_progression.duplicate(true)
	GameData.meta_progression["base_run_deck_capacity"] = 12
	GameData.meta_progression["run_end_rewards"] = {
		"floor_index_offset": 1,
		"per_floor": 2,
		"per_defeated_enemy": 3,
		"victory_bonus": 10,
		"base_cap": 100,
	}
	GameData.meta_progression["workshop"] = {"queue_capacity": 1}
	var project := {
		"id": "verify_speedup",
		"name": "广告加速验证",
		"facility_id": "hearth",
		"fireseed_cost": 0,
		"duration_seconds": 3600,
		"prerequisite_project_ids": [],
		"grants": {},
	}
	GameData.meta_progression["projects"] = [project]
	GameData.meta_projects = {&"verify_speedup": project}

	GameData.ad_economy = original_ad_economy.duplicate(true)
	var placements: Dictionary = GameData.ad_economy["placements"]
	placements["run_end_currency"].merge({"bonus_multiplier": 0.5, "bonus_cap": 20, "rounding": "floor"}, true)
	placements["workshop_speedup"].merge({"seconds_reduced": 600, "max_per_project": 1, "max_per_day": 1}, true)
	placements["shop_refresh"].merge({"max_per_shop": 1}, true)
	placements["deck_capacity_expand"].merge({"slots_per_view": 2, "max_per_run": 3}, true)
	GameData.ad_economy["placements"] = placements


func _test_run_end_rewards() -> void:
	RunState.current_floor = 4
	RunState.defeated.assign([&"clayling", &"ashcrawler"])
	check("局末基础火种立即结算", RunEndRewardSystem.settle_base_reward(true))
	check("基础火种按层数、击败数与胜利计算", RunState.run_end_base_fireseed == 26 and ProfileState.fireseed_balance == 26)
	check("基础火种防重复结算", not RunEndRewardSystem.settle_base_reward(true) and ProfileState.fireseed_balance == 26)
	check("局末广告奖励预览正确", RunEndRewardSystem.preview_ad_bonus() == 13)
	fake.enqueue_result(AdService.RESULT_COMPLETED)
	var request_id := RunEndRewardSystem.request_ad_bonus()
	var resolved: Array = await SignalBus.ad_reward_resolved
	check("完整观看追加局末火种", not request_id.is_empty() and resolved[2] == &"granted" and ProfileState.fireseed_balance == 39)
	check("局末广告奖励只可领取一次", RunEndRewardSystem.request_ad_bonus().is_empty() and RunState.run_end_ad_bonus_fireseed == 13)


func _test_workshop_speedup() -> void:
	var now := int(Time.get_unix_time_from_system())
	check("验证工坊项目可开工", WorkshopSystem.start_project(&"verify_speedup", now))
	var before := WorkshopSystem.remaining_seconds(&"verify_speedup", now)
	fake.enqueue_result(AdService.RESULT_COMPLETED)
	var request_id := WorkshopSystem.request_speedup(&"verify_speedup")
	var resolved: Array = await SignalBus.ad_reward_resolved
	var after := WorkshopSystem.remaining_seconds(&"verify_speedup", now)
	var entry: Dictionary = ProfileState.construction_queue[0]
	check("完整观看减少工坊时间", not request_id.is_empty() and resolved[2] == &"granted" and before - after == 600)
	check("工坊项目次数原子落档", int(entry.get("ad_speedup_count", 0)) == 1)
	check("工坊每日次数原子落档", ProfileState.daily_ad_usage(&"workshop_speedup", Time.get_date_string_from_system()) == 1)
	check("达到项目/每日上限后不再展示", not WorkshopSystem.can_offer_speedup(&"verify_speedup"))


func _test_shop_refresh() -> void:
	RunState.current_act = 0
	RunState.current_floor = 5
	var shop_id := ShopInventorySystem.current_shop_id()
	var bought_card := _card_item(&"heavy_blade", 10, true)
	var open_card := _card_item(&"twin_strike", 11, false)
	check("商店库存可持久化", ShopInventorySystem.capture_state(shop_id, [bought_card, open_card], [], [], 0))
	fake.enqueue_result(AdService.RESULT_COMPLETED)
	var request_id := ShopInventorySystem.request_refresh(shop_id)
	var resolved: Array = await SignalBus.ad_reward_resolved
	var state := ShopInventorySystem.get_state(shop_id)
	var cards: Array = state.get("card_stock", [])
	check("完整观看刷新商店", not request_id.is_empty() and resolved[2] == &"granted" and int(state.get("refresh_count", 0)) == 1)
	check("已购买槽位不会复活或变化", cards[0] == bought_card)
	check("未购买槽位替换为不同卡牌", String(cards[1].get("card", {}).get("id", "")) != "twin_strike")
	check("同一商店达到刷新上限", not ShopInventorySystem.can_offer_refresh(shop_id))


func _test_deck_capacity_and_shop_purchase() -> void:
	check("局外基础容量带入新局", RunState.base_run_deck_capacity == 12 and RunState.current_deck_capacity() == 12)
	while RunState.deck.size() < RunState.current_deck_capacity():
		check("容量未满时可直接获得卡牌", CardAcquireService.acquire_free_card(&"heavy_blade", false, &"verify") == CardAcquireService.RESULT_ACQUIRED)
	var full_size := RunState.deck.size()
	check("满库后新卡进入待处理", CardAcquireService.acquire_free_card(&"cleave", false, &"reward") == CardAcquireService.RESULT_FULL)
	fake.enqueue_result(AdService.RESULT_FAILED)
	var failed_request := CardAcquireService.request_expand()
	var failed: Array = await SignalBus.ad_reward_resolved
	check("广告失败不扩容且保留待选卡", not failed_request.is_empty() and failed[2] == AdService.RESULT_FAILED and RunState.deck.size() == full_size and not RunState.pending_card_acquisition.is_empty())
	check("广告失败不消耗本局扩容次数", RunState.deck_capacity_ad_uses == 0 and RunState.run_ad_deck_capacity_bonus == 0)
	fake.enqueue_result(AdService.RESULT_COMPLETED)
	CardAcquireService.request_expand()
	var granted: Array = await SignalBus.ad_reward_resolved
	check("完整观看扩容并继续原卡牌获取", granted[2] == &"granted" and RunState.current_deck_capacity() == 14 and RunState.deck.size() == full_size + 1)
	check("扩容次数与待处理状态正确", RunState.deck_capacity_ad_uses == 1 and RunState.pending_card_acquisition.is_empty())

	while RunState.deck.size() < RunState.current_deck_capacity():
		RunState.add_card(&"strike")
	RunState.gold = 100
	RunState.current_floor = 6
	var shop_id := ShopInventorySystem.current_shop_id()
	var sale := _card_item(&"bludgeon", 50, false)
	ShopInventorySystem.capture_state(shop_id, [sale], [], [], 0)
	check("满库购买商店卡时先不扣金币", CardAcquireService.acquire_shop_card(shop_id, 0, &"bludgeon", 50) == CardAcquireService.RESULT_FULL and RunState.gold == 100)
	fake.enqueue_result(AdService.RESULT_COMPLETED)
	CardAcquireService.request_expand()
	await SignalBus.ad_reward_resolved
	var purchased_state := ShopInventorySystem.get_state(shop_id)
	check("扩容后原商店购买自动继续", RunState.gold == 50 and bool(purchased_state.get("card_stock", [])[0].get("bought", false)))
	check("商店卡仅在事务成功后入库", RunState.deck.back().get("id", &"") == &"bludgeon")
	RunState.remove_card_at(RunState.deck.size() - 1)
	check("删牌会立即释放容量", RunState.can_add_permanent_card())


func _test_run_save_migration() -> void:
	var legacy := RunState.to_save_dict()
	legacy["version"] = 2
	for field in ["run_id", "base_run_deck_capacity", "run_ad_deck_capacity_bonus", "deck_capacity_ad_uses", "pending_card_acquisition", "shop_states", "ad_reward_transaction_ids", "run_end_base_fireseed", "run_end_ad_bonus_fireseed", "run_end_base_settled", "pre_run_buff_offer_ids", "pre_run_buff_id", "pre_run_buff_remaining_floors", "pre_run_buff_claimed", "pre_run_preparation_resolved", "resolved_floor_keys", "combat_checkpoint", "combat_death_pending", "revive_used_count"]:
		legacy.erase(field)
	check("v2 单局存档可迁移", RunState.from_save_dict(legacy))
	check("v2 迁移不追溯启用牌库上限", RunState.base_run_deck_capacity == -1 and not RunState.run_id.is_empty())
	check("v2 迁移不追溯弹出局前准备", RunState.pre_run_preparation_resolved and not RunState.combat_death_pending)
	check("迁移后写出 v5 单局存档", int(RunState.to_save_dict().get("version", -1)) == 5)


func _card_item(card_id: StringName, price: int, bought: bool) -> Dictionary:
	var card: CardData = GameData.get_card(card_id)
	return {
		"card": {
			"id": card.id,
			"name": card.name,
			"rarity": card.rarity,
			"cost": card.cost,
			"type": card.type,
			"desc": card.get_description(false),
		},
		"price": price,
		"bought": bought,
	}


func _restore_state() -> void:
	CardAcquireService.abandon_pending()
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


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== 广告经济玩法验证 =====")
	for result in results:
		lines.append(result)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("AD_ECONOMY_GAMEPLAY_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
