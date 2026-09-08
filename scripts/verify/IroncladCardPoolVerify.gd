extends Node
## 《杀戮尖塔 1》战士卡池替换专项验证：数据规模、投放、升级和代表性机制。

var pass_count := 0
var fail_count := 0
var controller: CombatController


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	_check("GameData 可加载", GameData.is_loaded, str(GameData.load_errors))
	if not GameData.is_loaded:
		_finish()
		return
	_test_pool_shape()
	_test_unlock_coverage()
	_test_upgrade_data()
	_test_save_migration()
	_test_profile_migration()
	_test_combat_mechanics()
	_test_every_profession_card_resolves()
	_finish()


func _test_pool_shape() -> void:
	var counts := {"starter":0,"common":0,"uncommon":0,"rare":0,"special":0}
	for card in GameData.cards.values():
		counts[String(card.rarity)] = int(counts.get(String(card.rarity), 0)) + 1
	_check("完整加载 75 张职业牌与 3 张生成状态牌", GameData.cards.size() == 78, str(counts))
	_check("稀有度分布为 3/20/36/16/3",
		counts == {"starter":3,"common":20,"uncommon":36,"rare":16,"special":3}, str(counts))
	_check("功能相近牌保留项目名", GameData.get_card(&"strike").name == "劈砍"
		and GameData.get_card(&"defend").name == "格挡"
		and GameData.get_card(&"bash").name == "敲釉"
		and GameData.get_card(&"body_slam").name == "借盾撞")
	_check("其余牌使用战士牌名", GameData.get_card(&"anger").name == "愤怒"
		and GameData.get_card(&"corruption").name == "腐化"
		and GameData.get_card(&"reaper").name == "死亡收割")
	_check("旧原创卡不再是正式卡", GameData.get_card(&"colossus") == null
		and GameData.get_card(&"summon_hound") == null and GameData.get_card(&"cruelty") == null)
	var start: Array = GameData.balance.get("starting_deck", [])
	_check("起始牌组为 5 劈砍 / 4 格挡 / 1 敲釉",
		start.count("strike") == 5 and start.count("defend") == 4 and start.count("bash") == 1 and start.size() == 10,
		str(start))


func _test_unlock_coverage() -> void:
	var unlocked: Dictionary = {}
	for card_id in GameData.meta_progression.get("initial_unlocks", {}).get("card_ids", []):
		unlocked[String(card_id)] = true
	for project in GameData.meta_progression.get("projects", []):
		for card_id in project.get("grants", {}).get("unlocked_card_ids", []):
			unlocked[String(card_id)] = true
	var reward_count := 0
	var all_covered := true
	for card in GameData.cards.values():
		if card.rarity in [&"starter", &"special"]:
			continue
		reward_count += 1
		all_covered = all_covered and unlocked.has(String(card.id))
	_check("72 张奖励牌全部由初始池或工坊研究覆盖", reward_count == 72 and all_covered,
		"reward=%d unlocked=%d" % [reward_count, unlocked.size()])


func _test_upgrade_data() -> void:
	var searing: CardData = GameData.get_card(&"searing_blow")
	_check("灼热攻击可重复升级 12→16→21→27",
		searing.repeatable_upgrade
		and int(searing.get_effects(0)[0].value) == 12
		and int(searing.get_effects(1)[0].value) == 16
		and int(searing.get_effects(2)[0].value) == 21
		and int(searing.get_effects(3)[0].value) == 27)
	_check("升级可改变费用/固有/消耗",
		GameData.get_card(&"body_slam").resolved_cost(1) == 0
		and GameData.get_card(&"brutality").is_innate(1)
		and not GameData.get_card(&"limit_break").exhausts_on_play(1))


func _test_save_migration() -> void:
	RunState.start_new_run()
	var saved := RunState.to_save_dict()
	saved["version"] = 5
	saved["deck"] = [
		{"id":"heavy_slash","upgraded":true,"enchants":[]},
		{"id":"colossus","upgraded":false,"enchants":[]},
		{"id":"summon_hound","upgraded":false,"enchants":[]}
	]
	var loaded := RunState.from_save_dict(saved)
	_check("v5 旧卡池存档迁移到 v6：可映射牌保留、其余旧牌删除",
		loaded and RunState.deck.size() == 1
		and RunState.deck[0].get("id") == &"heavy_blade"
		and int(RunState.deck[0].get("upgrade_level", 0)) == 1
		and int(RunState.to_save_dict().get("version", 0)) == 6,
		str(RunState.deck))


func _test_profile_migration() -> void:
	var original := ProfileState.to_save_dict()
	var legacy := original.duplicate(true)
	legacy["version"] = 3
	legacy["unlocked_card_ids"] = ["warlord", "colossus"]
	legacy["completed_project_ids"] = ["card_pack_berserk_2"]
	var loaded := ProfileState.from_save_dict(legacy, false)
	_check("v3 永久档按已完成研究补发新卡池解锁",
		loaded and ProfileState.unlocked_card_ids.has(&"demon_form")
		and ProfileState.unlocked_card_ids.has(&"limit_break")
		and ProfileState.unlocked_card_ids.has(&"bludgeon")
		and not ProfileState.unlocked_card_ids.has(&"colossus"),
		str(ProfileState.unlocked_card_ids))
	ProfileState.from_save_dict(original, false)


func _test_combat_mechanics() -> void:
	GameData.enemies[&"ironclad_verify_dummy"] = EnemyData.from_dict({
		"id":"ironclad_verify_dummy","name":"卡池验证木桩","tier":"normal","hp":999,
		"sprite":"","moves":[{"id":"wait","intent":"defend","value":0,"chance":1.0}]
	})
	RunState.start_new_run()
	controller = CombatController.new()
	add_child(controller)
	controller.start_combat([&"ironclad_verify_dummy"])
	var enemy := controller.enemies[0]

	_set_hand([_entry(&"whirlwind")], 3)
	var hp_before := enemy.hp
	_check("卷灰按 X=3 对全体造成 15 并耗尽能量",
		controller.play_card(0, 0) and hp_before - enemy.hp == 15 and controller.energy == 0)

	_set_hand([_entry(&"flex"), _entry(&"heavy_blade")], 2)
	hp_before = enemy.hp
	var flex_ok := controller.play_card(0, -1)
	var heavy_ok := controller.play_card(0, 0)
	_check("守窑式 2 力量令重劈按 3 倍力量造成 20", flex_ok and heavy_ok and hp_before - enemy.hp == 20,
		"damage=%d strength=%d" % [hp_before - enemy.hp, controller.player.get_status(&"heat")])

	_set_hand([_entry(&"armaments"), _entry(&"strike")], 1)
	var armaments_ok := controller.play_card(0, -1)
	_check("武装开启必选卡牌流程", armaments_ok and not controller.pending_card_choice.is_empty())
	_check("武装选择后使对应手牌战斗内升级",
		controller.resolve_card_choice(0) and controller._card_upgrade_state(controller.hand[0]) == 1)

	_set_hand([_entry(&"corruption")], 3)
	var corruption_ok := controller.play_card(0, -1)
	_set_hand([_entry(&"defend")], 0)
	var skill_ok := controller.play_card(0, -1)
	_check("腐化令技能 0 费且打出后消耗",
		corruption_ok and skill_ok and controller.exhaust_pile.any(func(entry): return entry.get("id") == &"defend"))

	_set_hand([_entry(&"power_through")], 1)
	var power_ok := controller.play_card(0, -1)
	_check("硬撑生成 2 张伤口并获得 15 格挡",
		power_ok and controller.hand.count(_entry(&"wound")) == 2 and controller.player.block >= 15,
		"hand=%s block=%d" % [controller.hand, controller.player.block])

	_set_hand([_entry(&"burn")], 0)
	var player_hp_before := controller.player.hp
	controller.end_player_turn()
	_check("灼伤在回合结束失去 2 生命并进入弃牌堆",
		player_hp_before - controller.player.hp == 2
		and controller.discard_pile.any(func(entry): return entry.get("id") == &"burn"))


func _test_every_profession_card_resolves() -> void:
	var failed: Array[String] = []
	var played_count := 0
	for card in GameData.cards.values():
		if card.rarity == &"special":
			continue
		controller._combat_active = true
		controller.phase = CombatController.Phase.PLAYER
		controller.energy = 20
		controller.powers.clear()
		controller.pending_card_choice.clear()
		controller._card_hp_loss_count = 0
		controller._no_draw_this_turn = false
		controller._temporary_strength = 0
		controller._temporary_attack_block = 0
		controller._double_tap_charges = 0
		controller.player.hp = controller.player.max_hp
		controller.player.block = 0
		controller.player.statuses.clear()
		controller.enemies[0].hp = controller.enemies[0].max_hp
		controller.enemies[0].block = 0
		controller.enemies[0].statuses.clear()
		controller.enemies[0].intent = {"intent":"attack","value":1}
		controller.hand = [_entry(card.id), _entry(&"strike")]
		controller.draw_pile = [_entry(&"strike")]
		controller.discard_pile = [_entry(&"strike")]
		controller.exhaust_pile = [_entry(&"strike")]
		controller.removed_pile.clear()
		var played := controller.play_card(0, 0)
		if not controller.pending_card_choice.is_empty():
			played = controller.resolve_card_choice(0) and played
		if not played:
			failed.append(String(card.id))
		else:
			played_count += 1
	_check("75 张职业牌均可通过通用解释器完成一次结算",
		played_count == 75 and failed.is_empty(),
		"played=%d failed=%s" % [played_count, failed])


func _set_hand(entries: Array, energy: int) -> void:
	controller.hand = entries
	controller.energy = energy
	controller.phase = CombatController.Phase.PLAYER
	controller.pending_card_choice.clear()


func _entry(card_id: StringName) -> Dictionary:
	return {"id":card_id,"upgraded":false,"upgrade_level":0,"enchants":[]}


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		pass_count += 1
		print("[PASS] " + name)
	else:
		fail_count += 1
		printerr("[FAIL] %s %s" % [name, detail])


func _finish() -> void:
	print("IRONCLAD_CARD_POOL_RESULT:%s pass=%d fail=%d" % [
		"PASS" if fail_count == 0 else "FAIL", pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)
