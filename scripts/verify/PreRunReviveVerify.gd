extends Node
## 第五阶段验证：局前 Buff 生命周期、战斗开始检查点与每局一次广告复燃。
## 正式配置闭环检查；复杂边界继续使用当前验证进程的隔离数值。

const TEST_SAVE_PATH := "res://Temp/pre_run_revive_verify.json"
const TEST_BUFF_ID := &"verify_opening_guard"
const TEST_BUFF_BLOCK := 7

var pass_count := 0
var fail_count := 0
var results: Array[String] = []
var run_end_count := 0

var original_profile: Dictionary
var original_run: Dictionary
var original_autosave: bool
var original_save_path: String
var original_provider: RewardedAdProvider
var original_meta_progression: Dictionary
var original_meta_pre_run_buffs: Dictionary
var original_ad_economy: Dictionary
var fake: FakeRewardedAdProvider


func _ready() -> void:
	await get_tree().process_frame
	_backup_state()
	_test_production_config()
	_install_verify_config()
	await _test_pre_run_buff()
	await _test_combat_revive()
	_test_v3_migration()
	_restore_state()
	_print_report()
	get_tree().quit(0 if fail_count == 0 else 1)


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
	original_meta_pre_run_buffs = GameData.meta_pre_run_buffs.duplicate(true)
	original_ad_economy = GameData.ad_economy.duplicate(true)
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = TEST_SAVE_PATH
	_cleanup_test_save()
	fake = FakeRewardedAdProvider.new()
	AdService.set_provider(fake)
	fake.set_available(&"pre_run_buff", true)
	fake.set_available(&"death_revive", true)
	if not SignalBus.run_ended.is_connected(_on_run_ended):
		SignalBus.run_ended.connect(_on_run_ended)


func _test_production_config() -> void:
	check("正式局前 Buff 已配置", GameData.pre_run_buff_list().size() == 1)
	check("正式局前 Buff 广告配置有效", PreRunBuffSystem.is_configured())
	check("死亡复燃上限读取已确认配置", CombatReviveSystem.max_per_run() == 1)


func _install_verify_config() -> void:
	var buff := {
		"id": String(TEST_BUFF_ID),
		"name": "验证·起手护窑",
		"description": "验证进程专用：每场战斗开始获得格挡。",
		"effects": [{"kind": "combat_start_block", "value": TEST_BUFF_BLOCK}],
	}
	GameData.meta_progression = original_meta_progression.duplicate(true)
	GameData.meta_progression["pre_run_buffs"] = [buff]
	GameData.meta_pre_run_buffs = {TEST_BUFF_ID: buff}
	GameData.ad_economy = original_ad_economy.duplicate(true)
	var placements: Dictionary = GameData.ad_economy["placements"]
	placements["pre_run_buff"].merge({"choice_count": 1, "buff_ids": [String(TEST_BUFF_ID)]}, true)
	GameData.ad_economy["placements"] = placements


func _test_pre_run_buff() -> void:
	ProfileState.reset_to_defaults(false)
	ProfileState.unlocked_pre_run_buff_ids.assign([TEST_BUFF_ID])
	check("验证配置可创建新局", RunState.start_new_run())
	var offer := PreRunBuffSystem.prepare_offer()
	check("仅从已解锁池生成并持久化候选", offer == [TEST_BUFF_ID] and RunState.pre_run_buff_offer_ids == offer)

	fake.enqueue_result(AdService.RESULT_FAILED)
	var failed_request := PreRunBuffSystem.request_buff(TEST_BUFF_ID)
	var failed: Array = await SignalBus.ad_reward_resolved
	check("广告失败不领取局前 Buff", not failed_request.is_empty() and failed[2] == AdService.RESULT_FAILED and not RunState.pre_run_buff_claimed)
	check("广告失败仍可继续选择或跳过", not RunState.pre_run_preparation_resolved and RunState.pre_run_buff_offer_ids == [TEST_BUFF_ID])

	fake.enqueue_result(AdService.RESULT_COMPLETED)
	var granted_request := PreRunBuffSystem.request_buff(TEST_BUFF_ID)
	var granted: Array = await SignalBus.ad_reward_resolved
	check("完整观看原子领取局前 Buff", not granted_request.is_empty() and granted[2] == &"granted" and RunState.pre_run_buff_claimed)
	check("领取后记录已确认的前10层时限", RunState.pre_run_buff_id == TEST_BUFF_ID and RunState.pre_run_buff_remaining_floors == 10)
	check("每局局前 Buff 只能领取一次", PreRunBuffSystem.request_buff(TEST_BUFF_ID).is_empty())

	var controller := CombatController.new()
	add_child(controller)
	controller.start_combat([&"claylump"])
	check("配置化局前 Buff 在战斗开始生效", controller.player.block == TEST_BUFF_BLOCK)
	controller.queue_free()
	await get_tree().process_frame

	var node_types: Array[StringName] = [&"combat", &"event", &"shop", &"rest", &"treasure", &"combat", &"event", &"shop", &"rest", &"treasure"]
	for floor_index in node_types.size():
		RunState.current_floor = floor_index
		RunState.current_node_type = node_types[floor_index]
		var before := RunState.pre_run_buff_remaining_floors
		check("第%d层结算计入局前 Buff 时限" % (floor_index + 1), RunState.resolve_current_floor() and RunState.pre_run_buff_remaining_floors == before - 1)
		if floor_index == 0:
			check("同一地图层重复结算不会重复扣除", not RunState.resolve_current_floor() and RunState.pre_run_buff_remaining_floors == before - 1)
	check("第10层结算后 Buff 到期", RunState.pre_run_buff_remaining_floors == 0 and RunState.active_pre_run_buff().is_empty())
	check("局前 Buff 剩余层数可保存", SaveManager.save_game())
	RunState.pre_run_buff_remaining_floors = 99
	check("局前 Buff 剩余层数可读档恢复", SaveManager.load_game() and RunState.pre_run_buff_remaining_floors == 0)


func _test_combat_revive() -> void:
	ProfileState.reset_to_defaults(false)
	check("复燃验证可创建新局", RunState.start_new_run())
	RunState.pre_run_preparation_resolved = true
	RunState.current_act = 0
	RunState.current_floor = 3
	RunState.current_node_type = &"combat"
	RunState.hp = RunState.max_hp - 9
	RunState.gold = 42
	RunState.add_potion(&"ash_salve")
	RunState.add_relic(&"kilnmark")
	RunState.deck[0]["enchants"] = [&"kiln_quench"]
	var checkpoint_hp := RunState.hp
	var checkpoint_gold := RunState.gold
	var checkpoint_deck := RunState.deck.duplicate(true)
	var checkpoint_potions := RunState.potions.duplicate()
	var checkpoint_relics := RunState.relic_ids.duplicate()
	var encounter: Array[StringName] = [&"sootling", &"embermoth"]
	check("进入多敌战斗前创建完整检查点", RunState.create_combat_checkpoint(encounter) and SaveManager.save_game())

	var first := CombatController.new()
	add_child(first)
	first.start_combat(encounter)
	var first_hand := _card_ids(first.hand)
	var first_intents := _enemy_intents(first.enemies)
	var checkpoint_start_ally_count := first.allies.size()
	first._summon_minion(&"emberhound", 1)
	RunState.gold = 1
	RunState.deck.pop_back()
	RunState.potions.clear()
	RunState.relic_ids.clear()
	first.player.hp = 0
	first.check_player_death()
	check("致命伤害冻结战斗而不立即结束 Run", RunState.is_active and RunState.combat_death_pending and run_end_count == 0 and not first.combat_active())

	fake.enqueue_result(AdService.RESULT_FAILED)
	var failed_request := CombatReviveSystem.request_revive()
	var failed: Array = await SignalBus.ad_reward_resolved
	check("复燃广告失败不消耗资格", not failed_request.is_empty() and failed[2] == AdService.RESULT_FAILED and RunState.revive_used_count == 0)
	check("复燃广告失败保留死亡选择", RunState.combat_death_pending and RunState.is_active)

	fake.enqueue_result(AdService.RESULT_COMPLETED)
	var granted_request := CombatReviveSystem.request_revive()
	var granted: Array = await SignalBus.ad_reward_resolved
	check("完整观看后使用本局唯一复燃", not granted_request.is_empty() and granted[2] == &"granted" and RunState.revive_used_count == 1)
	check("复燃恢复战前 HP 与金币", RunState.hp == checkpoint_hp and RunState.gold == checkpoint_gold)
	check("复燃恢复战前牌组实例、附魔与药水", RunState.deck == checkpoint_deck and RunState.potions == checkpoint_potions)
	check("复燃恢复战前遗物", RunState.relic_ids == checkpoint_relics)
	check("复燃状态已落盘", not RunState.combat_death_pending and SaveManager.load_game() and RunState.revive_used_count == 1)

	var retry := CombatController.new()
	add_child(retry)
	retry.start_combat(encounter)
	check("复燃沿用原战斗随机种子与起手", _card_ids(retry.hand) == first_hand)
	check("复燃沿用原战斗随机种子与敌人意图", _enemy_intents(retry.enemies) == first_intents)
	check("复燃重建战斗而不保留中途召唤物", retry.allies.size() == checkpoint_start_ally_count)
	retry.player.hp = 0
	retry.check_player_death()
	check("第二次死亡不再展示复燃并正常结束", not RunState.is_active and run_end_count == 1 and not RunState.has_combat_checkpoint())
	first.queue_free()
	retry.queue_free()
	await get_tree().process_frame

	check("Boss 复燃验证可创建新局", RunState.start_new_run())
	RunState.pre_run_preparation_resolved = true
	RunState.current_floor = 14
	RunState.current_node_type = &"boss"
	check("Boss 节点可创建同规则检查点", RunState.create_combat_checkpoint([&"sagger_matron"]))
	var boss := CombatController.new()
	add_child(boss)
	boss.start_combat([&"sagger_matron"])
	boss.player.hp = 0
	boss.check_player_death()
	check("Boss 致命伤害同样进入复燃待决", RunState.combat_death_pending and RunState.is_active)
	boss.finalize_player_death()
	boss.queue_free()
	await get_tree().process_frame


func _test_v3_migration() -> void:
	check("迁移验证可创建新局", RunState.start_new_run())
	var legacy := RunState.to_save_dict()
	legacy["version"] = 3
	for field in ["pre_run_buff_offer_ids", "pre_run_buff_id", "pre_run_buff_remaining_floors", "pre_run_buff_claimed", "pre_run_preparation_resolved", "resolved_floor_keys", "combat_checkpoint", "combat_death_pending", "revive_used_count"]:
		legacy.erase(field)
	check("v3 单局存档可迁移到 v5", RunState.from_save_dict(legacy) and int(RunState.to_save_dict().get("version", -1)) == 5)
	check("旧局不会被追溯插入局前广告", RunState.pre_run_preparation_resolved and not RunState.combat_death_pending and RunState.revive_used_count == 0)


func _card_ids(cards: Array) -> Array[String]:
	var output: Array[String] = []
	for card in cards:
		output.append(String(card.get("id", "")))
	return output


func _enemy_intents(units: Array[CombatUnit]) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for unit in units:
		output.append(unit.intent.duplicate(true))
	return output


func _on_run_ended(_victory: bool) -> void:
	run_end_count += 1


func _restore_state() -> void:
	if SignalBus.run_ended.is_connected(_on_run_ended):
		SignalBus.run_ended.disconnect(_on_run_ended)
	GameData.meta_progression = original_meta_progression
	GameData.meta_pre_run_buffs = original_meta_pre_run_buffs
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
	lines.append("===== 局前 Buff 与死亡复燃验证 =====")
	for result in results:
		lines.append(result)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("PRE_RUN_REVIVE_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
