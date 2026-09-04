extends Node
## 「巨像 / 残酷」确定性运行验证。输出 COLOSSUS_CRUELTY_RESULT:PASS / FAIL。

var controller: CombatController
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	GameData.enemies[&"colossus_cruelty_dummy"] = EnemyData.from_dict({
		"id": "colossus_cruelty_dummy", "name": "易伤联动测试木桩", "tier": "normal", "hp": 500,
		"ai": "weighted_random",
		"moves": [{"id": "wait", "intent": "defend", "value": 0, "chance": 1.0}],
	})
	if not RunState.is_active:
		RunState.start_new_run()
	controller = CombatController.new()
	add_child(controller)

	_test_data_and_unlocks()
	_test_colossus()
	_test_cruelty()
	_finish()


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		pass_count += 1
		print("[PASS] " + name)
	else:
		fail_count += 1
		print("[FAIL] %s  %s" % [name, detail])


func _begin(card_id: StringName, upgraded: bool = false) -> void:
	RunState.deck.clear()
	for i in 5:
		RunState.deck.append({"id": card_id, "upgraded": upgraded})
	controller.start_combat([&"colossus_cruelty_dummy"])
	controller.max_energy = 20
	controller.energy = 20


func _effect(card_id: StringName, upgraded: bool, kind: String) -> Dictionary:
	var card: CardData = GameData.get_card(card_id)
	if card == null:
		return {}
	for effect in card.get_effects(upgraded):
		if effect is Dictionary and String(effect.get("kind", "")) == kind:
			return effect
	return {}


func _project_unlocks(project_id: StringName, card_id: StringName) -> bool:
	var project: Dictionary = GameData.meta_projects.get(project_id, {})
	return project.get("grants", {}).get("unlocked_card_ids", []).has(String(card_id))


func _test_data_and_unlocks() -> void:
	var colossus: CardData = GameData.get_card(&"colossus")
	var cruelty: CardData = GameData.get_card(&"cruelty")
	_check("正式卡库为 62 张", GameData.cards.size() == 62, "actual=%d" % GameData.cards.size())
	_check("巨像为 1 费精良技能",
		colossus != null and colossus.cost == 1 and colossus.type == &"skill" and colossus.rarity == &"uncommon")
	_check("巨像格挡为 4→7",
		_effect(&"colossus", false, "block").get("value") == 4
		and _effect(&"colossus", true, "block").get("value") == 7)
	_check("巨像条件伤害倍率为 0.5，升级不变",
		is_equal_approx(float(_effect(&"colossus", false, "vulnerable_enemy_damage_multiplier").get("value", 0.0)), 0.5)
		and is_equal_approx(float(_effect(&"colossus", true, "vulnerable_enemy_damage_multiplier").get("value", 0.0)), 0.5))
	_check("残酷为 1 费稀有能力",
		cruelty != null and cruelty.cost == 1 and cruelty.type == &"power" and cruelty.rarity == &"rare")
	_check("残酷易伤额外增伤为 0.25→0.50",
		is_equal_approx(float(_effect(&"cruelty", false, "power_vulnerable_bonus_damage").get("value", 0.0)), 0.25)
		and is_equal_approx(float(_effect(&"cruelty", true, "power_vulnerable_bonus_damage").get("value", 0.0)), 0.5))
	_check("巨像接入铁壁配方 I", _project_unlocks(&"card_pack_ironwall_1", &"colossus"))
	_check("残酷接入控场配方 II", _project_unlocks(&"card_pack_control_2", &"cruelty"))

	var original_unlocks: Array[StringName] = ProfileState.unlocked_card_ids.duplicate()
	for card_id in [&"colossus", &"cruelty"]:
		if not ProfileState.unlocked_card_ids.has(card_id):
			ProfileState.unlocked_card_ids.append(card_id)
	var rolled_ids: Array[StringName] = []
	for choice in RewardBuilder.roll_card_choices_excluding(GameData.cards.size(), []):
		rolled_ids.append(StringName(choice.get("id", "")))
	ProfileState.unlocked_card_ids.assign(original_unlocks)
	_check("两张牌均进入奖励生成器候选", rolled_ids.has(&"colossus") and rolled_ids.has(&"cruelty"), str(rolled_ids))


func _test_colossus() -> void:
	_begin(&"colossus")
	var enemy: CombatUnit = controller.enemies[0]
	enemy.add_status(&"crazed", 2)
	var hp_before: int = controller.player.hp
	_check("巨像打出后获得 4 格挡", controller.play_card(0) and controller.player.block == 4)
	controller.end_player_turn()
	enemy.intent = {"intent": "attack", "value": 10}
	controller._execute_enemy_intent(enemy)
	_check("易伤敌人的 10 点攻击减半后由 4 格挡吸收，仅失去 1 生命",
		controller.player.hp == hp_before - 1, "hp=%d block=%d" % [controller.player.hp, controller.player.block])
	controller.enemy_phase_done()
	_check("巨像在下个玩家回合开始失效",
		controller._dmg.compute_outgoing(enemy, controller.player, 10) == 10)

	_begin(&"colossus")
	enemy = controller.enemies[0]
	controller.play_card(0)
	_check("无易伤敌人的攻击不被巨像降低",
		controller._dmg.compute_outgoing(enemy, controller.player, 10) == 10)

	_begin(&"colossus")
	enemy = controller.enemies[0]
	enemy.add_status(&"crazed", 2)
	controller.play_card(0)
	controller.play_card(0)
	_check("同回合重复打出巨像不会重复乘算减伤",
		controller._dmg.compute_outgoing(enemy, controller.player, 10) == 5)

	_begin(&"colossus", true)
	controller.play_card(0)
	_check("巨像+获得 7 格挡", controller.player.block == 7)


func _test_cruelty() -> void:
	_begin(&"cruelty")
	var enemy: CombatUnit = controller.enemies[0]
	_check("残酷作为能力打出后进入消耗堆",
		controller.play_card(0) and controller.exhaust_pile.size() == 1 and controller.discard_pile.is_empty())
	_check("残酷不影响无易伤目标",
		controller._dmg.compute_outgoing(controller.player, enemy, 8) == 8)
	enemy.add_status(&"crazed", 2)
	_check("残酷使基础易伤倍率由 1.50 加至 1.75",
		controller._dmg.compute_outgoing(controller.player, enemy, 8) == 14)

	controller._summon_minion(&"spark", 1)
	_check("残酷同样强化友方随从对易伤敌人的攻击",
		controller._dmg.compute_outgoing(controller.allies[0], enemy, 8) == 14)

	_begin(&"cruelty", true)
	enemy = controller.enemies[0]
	enemy.add_status(&"crazed", 2)
	controller.play_card(0)
	_check("残酷+使易伤总倍率达到 2.00",
		controller._dmg.compute_outgoing(controller.player, enemy, 8) == 16)

	_begin(&"cruelty")
	enemy = controller.enemies[0]
	enemy.add_status(&"crazed", 2)
	controller.play_card(0)
	controller.play_card(0)
	_check("两张残酷按额外百分比加算",
		controller._dmg.compute_outgoing(controller.player, enemy, 8) == 16)


func _finish() -> void:
	var verdict := "PASS" if fail_count == 0 else "FAIL"
	print("COLOSSUS_CRUELTY_RESULT:%s  (%d 项通过, %d 项失败)" % [verdict, pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)
