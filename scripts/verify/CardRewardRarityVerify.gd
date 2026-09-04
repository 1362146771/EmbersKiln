extends Node
## 卡牌投放确定性验证：来源概率、隐藏补偿、Boss 奖励、升级率与 v5 存档迁移。

var pass_count := 0
var fail_count := 0
var original_unlocks: Array[StringName] = []


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	if not GameData.is_loaded:
		_check("GameData 可加载", false, str(GameData.load_errors))
		_finish()
		return

	original_unlocks.assign(ProfileState.unlocked_card_ids)
	_unlock_all_reward_cards()
	RunState.start_new_run()

	_test_configured_probabilities()
	_test_pity_updates()
	_test_reward_generation()
	_test_upgrade_chances()
	_test_save_and_migration()

	ProfileState.unlocked_card_ids.assign(original_unlocks)
	_finish()


func _unlock_all_reward_cards() -> void:
	for card in GameData.cards.values():
		if card.rarity in [&"starter", &"special"]:
			continue
		if not ProfileState.unlocked_card_ids.has(card.id):
			ProfileState.unlocked_card_ids.append(card.id)


func _test_configured_probabilities() -> void:
	var pity: Dictionary = GameData.balance.get("card_rewards", {}).get("rare_pity", {})
	var initial := int(pity.get("initial_offset", 0))
	var maximum := int(pity.get("max_offset", 0))

	var combat := RewardBuilder.rarity_probabilities(&"combat", initial)
	_check("普通战初始补偿后为 65/35/0",
		int(combat.get(&"common", -1)) == 65
		and int(combat.get(&"uncommon", -1)) == 35
		and int(combat.get(&"rare", -1)) == 0,
		str(combat))

	var elite := RewardBuilder.rarity_probabilities(&"elite", initial)
	_check("精英战初始补偿后为 55/40/5",
		int(elite.get(&"common", -1)) == 55
		and int(elite.get(&"uncommon", -1)) == 40
		and int(elite.get(&"rare", -1)) == 5,
		str(elite))

	var shop := RewardBuilder.rarity_probabilities(&"shop", initial)
	_check("商店初始补偿后为 59/37/4",
		int(shop.get(&"common", -1)) == 59
		and int(shop.get(&"uncommon", -1)) == 37
		and int(shop.get(&"rare", -1)) == 4,
		str(shop))

	var full_pity := RewardBuilder.rarity_probabilities(&"combat", maximum)
	_check("普通战满补偿后为 20/37/43",
		int(full_pity.get(&"common", -1)) == 20
		and int(full_pity.get(&"uncommon", -1)) == 37
		and int(full_pity.get(&"rare", -1)) == 43,
		str(full_pity))

	var boss := RewardBuilder.rarity_probabilities(&"boss", initial)
	_check("Boss 来源强制 100% 稀有",
		int(boss.get(&"common", -1)) == 0
		and int(boss.get(&"uncommon", -1)) == 0
		and int(boss.get(&"rare", -1)) == 100,
		str(boss))


func _test_pity_updates() -> void:
	var pity: Dictionary = GameData.balance.get("card_rewards", {}).get("rare_pity", {})
	var initial := int(pity.get("initial_offset", 0))
	var increment := int(pity.get("common_increment", 0))
	var reset := int(pity.get("rare_reset_offset", 0))
	var maximum := int(pity.get("max_offset", 0))

	RunState.card_rare_offset = initial
	RewardBuilder.apply_rarity_result(&"common", &"combat")
	_check("普通奖励牌令补偿 +1", RunState.card_rare_offset == initial + increment)
	var after_common := RunState.card_rare_offset
	RewardBuilder.apply_rarity_result(&"uncommon", &"combat")
	_check("精良奖励牌不改变补偿", RunState.card_rare_offset == after_common)
	RewardBuilder.apply_rarity_result(&"rare", &"combat")
	_check("稀有奖励牌把补偿重置为 -5", RunState.card_rare_offset == reset)

	RunState.card_rare_offset = maximum
	RewardBuilder.apply_rarity_result(&"common", &"combat")
	_check("补偿不会超过 +40", RunState.card_rare_offset == maximum)
	RewardBuilder.apply_rarity_result(&"common", &"shop")
	_check("商店生成不推进补偿", RunState.card_rare_offset == maximum)


func _test_reward_generation() -> void:
	var pity: Dictionary = GameData.balance.get("card_rewards", {}).get("rare_pity", {})
	RunState.card_rare_offset = int(pity.get("max_offset", 0))
	var boss_choices := RewardBuilder.roll_card_choices(3, &"boss")
	var boss_all_rare := boss_choices.size() == 3
	var boss_ids: Dictionary = {}
	for choice in boss_choices:
		boss_all_rare = boss_all_rare and StringName(choice.get("rarity", "")) == &"rare"
		boss_all_rare = boss_all_rare and not bool(choice.get("upgraded", false))
		boss_ids[String(choice.get("id", ""))] = true
	_check("Boss 生成三张不重复且未升级的稀有牌", boss_all_rare and boss_ids.size() == 3, str(boss_choices))
	_check("Boss 稀有奖励重置补偿",
		RunState.card_rare_offset == int(pity.get("rare_reset_offset", 0)))

	var before_shop := RunState.card_rare_offset
	var shop_choices := RewardBuilder.roll_card_choices(4, &"shop")
	var shop_ids: Dictionary = {}
	var shop_shape_ok := shop_choices.size() == 4
	for choice in shop_choices:
		shop_shape_ok = shop_shape_ok and choice.has("upgraded") and not bool(choice.get("upgraded", true))
		shop_ids[String(choice.get("id", ""))] = true
	_check("商店生成四张不重复且未升级的牌", shop_shape_ok and shop_ids.size() == 4, str(shop_choices))
	_check("整组商店商品不改变补偿", RunState.card_rare_offset == before_shop)


func _test_upgrade_chances() -> void:
	_check("第一幕普通/精良战利牌升级率为 0%",
		is_equal_approx(RewardBuilder.random_upgrade_chance(&"combat", &"common", 0), 0.0))
	_check("第二幕普通/精良战利牌升级率为 25%",
		is_equal_approx(RewardBuilder.random_upgrade_chance(&"combat", &"uncommon", 1), 0.25))
	_check("第三幕普通/精良战利牌升级率为 50%",
		is_equal_approx(RewardBuilder.random_upgrade_chance(&"elite", &"common", 2), 0.5))
	_check("稀有战利牌不随机升级",
		is_equal_approx(RewardBuilder.random_upgrade_chance(&"combat", &"rare", 2), 0.0))
	_check("商店牌不随机升级",
		is_equal_approx(RewardBuilder.random_upgrade_chance(&"shop", &"common", 2), 0.0))


func _test_save_and_migration() -> void:
	var pity: Dictionary = GameData.balance.get("card_rewards", {}).get("rare_pity", {})
	var persisted_offset := int(pity.get("initial_offset", 0)) + int(pity.get("common_increment", 0))
	RunState.card_rare_offset = persisted_offset
	var saved := RunState.to_save_dict()
	_check("v5 存档写入隐藏稀有补偿",
		int(saved.get("version", -1)) == 5
		and int(saved.get("card_rare_offset", 999)) == persisted_offset)

	RunState.card_rare_offset = int(pity.get("max_offset", 0))
	_check("v5 读档恢复隐藏稀有补偿",
		RunState.from_save_dict(saved) and RunState.card_rare_offset == persisted_offset)

	var legacy := saved.duplicate(true)
	legacy["version"] = 4
	legacy.erase("card_rare_offset")
	_check("v4 旧档迁移时使用初始补偿并写出 v5",
		RunState.from_save_dict(legacy)
		and RunState.card_rare_offset == int(pity.get("initial_offset", 0))
		and int(RunState.to_save_dict().get("version", -1)) == 5)


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		pass_count += 1
		print("[PASS] " + name)
	else:
		fail_count += 1
		printerr("[FAIL] %s %s" % [name, detail])


func _finish() -> void:
	print("CARD_REWARD_RARITY_RESULT:%s pass=%d fail=%d" % [
		"PASS" if fail_count == 0 else "FAIL",
		pass_count,
		fail_count,
	])
	get_tree().quit(0 if fail_count == 0 else 1)
