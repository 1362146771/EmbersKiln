extends Node
## 12 张扩充牌的确定性运行验证。输出 CARD_EXPANSION_RESULT:PASS / FAIL。

const NEW_CARD_IDS: Array[StringName] = [
	&"spark_screen", &"pack_assault", &"paired_kiln_call", &"kiln_chorus",
	&"ash_scatter", &"ash_rupture", &"sealed_furnace", &"thermal_shock",
	&"crack_chaser", &"shield_ram", &"fixed_glaze", &"slag_echo",
]

var controller: CombatController
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	GameData.enemies[&"card_expansion_dummy"] = EnemyData.from_dict({
		"id": "card_expansion_dummy", "name": "扩充牌测试木桩", "tier": "normal", "hp": 500,
		"ai": "weighted_random",
		"moves": [{"id": "wait", "intent": "defend", "value": 0, "chance": 1.0}],
	})
	if not RunState.is_active:
		RunState.start_new_run()
	controller = CombatController.new()
	add_child(controller)

	_test_data_and_pool()
	_test_approved_values()
	_test_spark_screen()
	_test_scaled_damage()
	_test_paired_call()
	_test_kiln_chorus_and_power_cycle()
	_test_ash_cards()
	_test_control_cards()
	_test_fixed_glaze()
	_test_slag_echo()
	_finish()


func _check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		pass_count += 1
		print("[PASS] " + name)
	else:
		fail_count += 1
		print("[FAIL] %s  %s" % [name, detail])


func _begin(card_id: StringName, upgraded: bool = false, enemy_count: int = 1) -> void:
	RunState.deck.clear()
	for i in 5:
		RunState.deck.append({"id": card_id, "upgraded": upgraded})
	var enemy_ids: Array = []
	for i in enemy_count:
		enemy_ids.append(&"card_expansion_dummy")
	controller.start_combat(enemy_ids)
	controller.max_energy = 20
	controller.energy = 20


func _play_first(target_index: int = 0) -> bool:
	return controller.play_card(0, target_index)


func _type_count(type_id: StringName) -> int:
	var count := 0
	for card in GameData.cards.values():
		if card.type == type_id:
			count += 1
	return count


func _rarity_count(rarity_id: StringName) -> int:
	var count := 0
	for card in GameData.cards.values():
		if card.rarity == rarity_id:
			count += 1
	return count


func _test_data_and_pool() -> void:
	_check("正式卡库为 62 张", GameData.cards.size() == 62, "actual=%d" % GameData.cards.size())
	_check("类型分布为攻击25/技能25/能力12",
		_type_count(&"attack") == 25 and _type_count(&"skill") == 25 and _type_count(&"power") == 12)
	_check("稀有度分布为初始3/普通23/精良22/稀有14",
		_rarity_count(&"starter") == 3 and _rarity_count(&"common") == 23
		and _rarity_count(&"uncommon") == 22 and _rarity_count(&"rare") == 14)
	var all_classified := true
	for card in GameData.cards.values():
		all_classified = all_classified and not card.mechanics.is_empty()
	_check("全部卡牌具有 JSON 机制分类", all_classified)
	var all_new_available := true
	var all_new_covered := true
	var initial_cards: Array = GameData.meta_progression.get("initial_unlocks", {}).get("card_ids", [])
	for card_id in NEW_CARD_IDS:
		var card: CardData = GameData.get_card(card_id)
		all_new_available = all_new_available and card != null and card.has_upgrade()
		all_new_available = all_new_available and card.rarity not in [&"starter", &"special"]
		var covered := initial_cards.has(String(card_id))
		for project in GameData.meta_projects.values():
			covered = covered or project.get("grants", {}).get("unlocked_card_ids", []).has(String(card_id))
		all_new_covered = all_new_covered and covered
	_check("12 张新牌已加载、可升级且符合奖励/商店稀有度规则", all_new_available)
	_check("12 张新牌均已接入初始或牌模研究解锁表", all_new_covered)
	var original_unlocks: Array[StringName] = ProfileState.unlocked_card_ids.duplicate()
	for card_id in NEW_CARD_IDS:
		if not ProfileState.unlocked_card_ids.has(card_id):
			ProfileState.unlocked_card_ids.append(card_id)
	var rolled_ids: Array[StringName] = []
	for choice in RewardBuilder.roll_card_choices_excluding(GameData.cards.size(), []):
		rolled_ids.append(StringName(choice.get("id", "")))
	var all_new_rolled := true
	for card_id in NEW_CARD_IDS:
		all_new_rolled = all_new_rolled and rolled_ids.has(card_id)
	ProfileState.unlocked_card_ids.assign(original_unlocks)
	_check("奖励生成器可实际枚举全部 12 张新牌", all_new_rolled, "rolled=%s" % str(rolled_ids))
	var original_completed: Array[StringName] = ProfileState.completed_project_ids.duplicate()
	ProfileState.unlocked_card_ids.erase(&"paired_kiln_call")
	ProfileState.unlocked_card_ids.erase(&"kiln_chorus")
	ProfileState.completed_project_ids.append(&"card_pack_summon_1")
	_check("老存档已完成召唤研究时可动态取得新增奖励",
		GameData.is_card_unlocked(&"paired_kiln_call") and GameData.is_card_unlocked(&"kiln_chorus"))
	ProfileState.unlocked_card_ids.assign(original_unlocks)
	ProfileState.completed_project_ids.assign(original_completed)


func _effect(card_id: StringName, upgraded: bool, kind: String, status: String = "") -> Dictionary:
	var card: CardData = GameData.get_card(card_id)
	if card == null:
		return {}
	for effect in card.get_effects(upgraded):
		if effect is Dictionary and String(effect.get("kind", "")) == kind:
			if status.is_empty() or String(effect.get("status", "")) == status:
				return effect
	return {}


func _test_approved_values() -> void:
	var costs := {
		&"spark_screen": 1, &"pack_assault": 1, &"paired_kiln_call": 2, &"kiln_chorus": 1,
		&"ash_scatter": 1, &"ash_rupture": 1, &"sealed_furnace": 2, &"thermal_shock": 1,
		&"crack_chaser": 1, &"shield_ram": 1, &"fixed_glaze": 2, &"slag_echo": 1,
	}
	var values_ok := true
	for card_id in costs:
		values_ok = values_ok and GameData.get_card(card_id).cost == costs[card_id]
	values_ok = values_ok and _effect(&"spark_screen", false, "block").get("value") == 5
	values_ok = values_ok and _effect(&"spark_screen", true, "block").get("value") == 8
	values_ok = values_ok and _effect(&"pack_assault", false, "scaled_damage").get("base") == 5
	values_ok = values_ok and _effect(&"pack_assault", true, "scaled_damage").get("base") == 7
	values_ok = values_ok and _effect(&"pack_assault", true, "scaled_damage").get("per") == 2
	values_ok = values_ok and GameData.get_card(&"paired_kiln_call").effects.size() == 2
	values_ok = values_ok and GameData.get_card(&"paired_kiln_call").upgrade_effects.size() == 3
	values_ok = values_ok and _effect(&"kiln_chorus", false, "power_on_summon_command").get("value") == 1
	values_ok = values_ok and _effect(&"kiln_chorus", true, "power_on_summon_command").get("value") == 2
	values_ok = values_ok and _effect(&"ash_scatter", false, "apply_status", "ashrot").get("value") == 2
	values_ok = values_ok and _effect(&"ash_scatter", true, "apply_status", "ashrot").get("value") == 3
	values_ok = values_ok and _effect(&"ash_rupture", false, "scaled_damage").get("base") == 6
	values_ok = values_ok and _effect(&"ash_rupture", false, "scaled_damage").get("per") == 2
	values_ok = values_ok and _effect(&"ash_rupture", true, "scaled_damage").get("base") == 8
	values_ok = values_ok and _effect(&"ash_rupture", true, "scaled_damage").get("per") == 3
	values_ok = values_ok and _effect(&"sealed_furnace", false, "multiply_status").get("multiplier") == 2
	values_ok = values_ok and _effect(&"sealed_furnace", true, "multiply_status").get("multiplier") == 3
	values_ok = values_ok and _effect(&"thermal_shock", false, "apply_status", "crazed").get("value") == 1
	values_ok = values_ok and _effect(&"thermal_shock", false, "apply_status", "damp").get("value") == 2
	values_ok = values_ok and _effect(&"thermal_shock", true, "apply_status", "crazed").get("value") == 2
	values_ok = values_ok and _effect(&"thermal_shock", true, "apply_status", "damp").get("value") == 3
	values_ok = values_ok and _effect(&"crack_chaser", false, "scaled_damage").get("base") == 6
	values_ok = values_ok and _effect(&"crack_chaser", true, "scaled_damage").get("base") == 8
	values_ok = values_ok and _effect(&"shield_ram", false, "scaled_damage").get("per") == 1
	values_ok = values_ok and _effect(&"fixed_glaze", true, "power_start_turn_block").get("value") == 3
	values_ok = values_ok and _effect(&"slag_echo", false, "scaled_damage").get("base") == 6
	values_ok = values_ok and _effect(&"slag_echo", false, "scaled_damage").get("per") == 2
	values_ok = values_ok and _effect(&"slag_echo", true, "scaled_damage").get("base") == 8
	values_ok = values_ok and _effect(&"slag_echo", true, "scaled_damage").get("per") == 3
	_check("12 张牌基础/升级数值与已确认台账一致", values_ok)


func _test_spark_screen() -> void:
	_begin(&"spark_screen")
	_play_first()
	_check("火灵掩护获得 5 格挡并成功召唤火灵",
		controller.player.block == 5 and controller.allies.size() == 1 and controller.allies[0].id == &"spark")
	_begin(&"spark_screen", true)
	_play_first()
	_check("火灵掩护+获得 8 格挡", controller.player.block == 8)


func _test_scaled_damage() -> void:
	_begin(&"pack_assault")
	controller._summon_minion(&"spark", 2)
	var hp_before: int = controller.enemies[0].hp
	_play_first()
	_check("群窑扑袭按 2 个随从造成 5+2x2 伤害",
		controller.enemies[0].hp == hp_before - 9)

	_begin(&"shield_ram")
	controller.player.block = 9
	hp_before = controller.enemies[0].hp
	_play_first()
	_check("借盾撞造成等于当前格挡的伤害且不消耗格挡",
		controller.enemies[0].hp == hp_before - 9 and controller.player.block == 9)
	_begin(&"shield_ram")
	hp_before = controller.enemies[0].hp
	_play_first()
	_check("借盾撞在 0 格挡时造成 0 伤害", controller.enemies[0].hp == hp_before)


func _test_paired_call() -> void:
	_begin(&"paired_kiln_call")
	_play_first()
	_check("犬卫并炉召唤窑犬与釉卫",
		controller.allies.size() == 2 and controller.allies[0].id == &"emberhound"
		and controller.allies[1].id == &"glazeward")
	_begin(&"paired_kiln_call", true)
	_play_first()
	_check("犬卫并炉+额外获得 1 层领袖气质", controller.player.get_status(&"command") == 1)


func _test_kiln_chorus_and_power_cycle() -> void:
	_begin(&"kiln_chorus")
	_play_first()
	_check("群窑共鸣作为能力牌进入消耗堆",
		controller.exhaust_pile.size() == 1 and controller.discard_pile.is_empty())
	controller._summon_minion(&"spark", 1)
	_check("群窑共鸣在成功召唤后给予 1 层领袖气质", controller.player.get_status(&"command") == 1)
	controller._summon_minion(&"spark", 2)
	var command_before_reject: int = controller.player.get_status(&"command")
	controller._summon_minion(&"spark", 1)
	_check("满召唤栏拒绝时不触发群窑共鸣",
		controller.allies.size() == 3 and controller.player.get_status(&"command") == command_before_reject)

	_begin(&"rage")
	_play_first()
	_check("现有能力牌同样离开抽弃循环",
		controller.exhaust_pile.size() == 1 and controller.discard_pile.is_empty())


func _test_ash_cards() -> void:
	_begin(&"ash_scatter", false, 2)
	_play_first()
	_check("撒灰对所有敌人施加 2 层燃烧",
		controller.enemies[0].get_status(&"ashrot") == 2 and controller.enemies[1].get_status(&"ashrot") == 2)

	_begin(&"ash_rupture")
	controller.enemies[0].add_status(&"ashrot", 3)
	var hp_before: int = controller.enemies[0].hp
	_play_first()
	_check("灰烬决口按燃烧层数增伤后清除燃烧",
		controller.enemies[0].hp == hp_before - 12 and controller.enemies[0].get_status(&"ashrot") == 0)

	_begin(&"sealed_furnace")
	controller.enemies[0].add_status(&"ashrot", 4)
	_play_first()
	_check("封炉将 4 层燃烧变为 8 层并消耗", controller.enemies[0].get_status(&"ashrot") == 8
		and controller.exhaust_pile.size() == 1)
	_begin(&"sealed_furnace")
	_play_first()
	_check("封炉不会从 0 层凭空生成燃烧", controller.enemies[0].get_status(&"ashrot") == 0)
	_begin(&"sealed_furnace", true)
	controller.enemies[0].add_status(&"ashrot", 4)
	_play_first()
	_check("封炉+将燃烧变为 3 倍", controller.enemies[0].get_status(&"ashrot") == 12)


func _test_control_cards() -> void:
	_begin(&"thermal_shock")
	_play_first()
	_check("冷热骤变施加易伤1与虚弱2", controller.enemies[0].get_status(&"crazed") == 1
		and controller.enemies[0].get_status(&"damp") == 2)

	_begin(&"crack_chaser")
	controller.enemies[0].add_status(&"crazed", 2)
	controller.draw_pile.append({"id": &"strike", "upgraded": false, "enchants": []})
	var hp_before: int = controller.enemies[0].hp
	_play_first()
	var drew_strike := controller.hand.any(func(entry: Dictionary) -> bool: return entry.get("id") == &"strike")
	_check("追裂先按易伤层成长，再应用易伤承伤修正，并抽 1 张牌",
		controller.enemies[0].hp == hp_before - 12 and drew_strike)


func _test_fixed_glaze() -> void:
	_begin(&"fixed_glaze")
	_play_first()
	controller.player.block = 7
	controller._start_player_turn()
	_check("固釉不坠保留回合开始前的格挡", controller.player.block == 7)
	_begin(&"fixed_glaze", true)
	_play_first()
	controller.player.block = 7
	controller._start_player_turn()
	_check("固釉不坠+保留格挡并追加 3 格挡", controller.player.block == 10)


func _test_slag_echo() -> void:
	_begin(&"slag_echo")
	controller.exhaust_pile.assign([
		{"id": &"throw_rock", "upgraded": false},
		{"id": &"last_stand", "upgraded": false},
		{"id": &"sealed_furnace", "upgraded": false},
	])
	var hp_before: int = controller.enemies[0].hp
	_play_first()
	_check("炉渣回响按 3 张消耗牌造成 6+3x2 伤害", controller.enemies[0].hp == hp_before - 12)


func _finish() -> void:
	var verdict := "PASS" if fail_count == 0 else "FAIL"
	print("CARD_EXPANSION_RESULT:%s  (%d 项通过, %d 项失败)" % [verdict, pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)
