extends Node
## P3 内容扩展验证：卡池深化 / 人数优先的加权遇敌 / Boss 三阶段觉醒。
## 全部确定性断言，真实运行（headless）后用 stdout 判定 P3_RESULT。

var results: Array[String] = []
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	if not GameData.is_loaded:
		check("GameData 加载", false, "加载失败")
		_print_report()
		return

	_test_card_pool()
	_test_boss_phase3()
	_test_encounter_generation()

	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if detail != "" else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if detail != "" else ""])


# =====================================================================
# 4.1 卡池深化
# =====================================================================
func _test_card_pool() -> void:
	check("卡池=75 张职业牌 + 3 张生成状态牌", GameData.cards.size() == 78, "cards=%d" % GameData.cards.size())

	var new_ids := ["anger", "flame_barrier", "shockwave", "immolate",
		"corruption", "demon_form", "barricade", "reaper"]
	for cid in new_ids:
		check("新卡存在: %s" % cid, GameData.get_card(StringName(cid)) != null, "")

	# 每系至少补到 1 张高稀有度终端卡
	check("力量终端熔身存在", GameData.get_card(&"demon_form") != null)
	check("格挡终端固釉不坠存在", GameData.get_card(&"barricade") != null)
	check("控制牌震荡波存在", GameData.get_card(&"shockwave") != null)
	check("状态牌联动燔祭存在", GameData.get_card(&"immolate") != null)

	# gain_kiln_heat effect 真实生效：累计窑温并触发窑变（贯穿伤害）
	_run_kiln_heat_effect()


# 直接用战斗核心 _resolve_effects 验证 gain_kiln_heat（免抽牌随机）。
func _run_kiln_heat_effect() -> void:
	var cc := CombatController.new()
	add_child(cc)
	RunState.start_new_run()
	RunState.hp = 80
	cc.start_combat([StringName("claylump")])   # 单弱敌即可验证窑变
	var before_hp: int = cc.enemies[0].hp
	# 一次性 +5 窑温 -> 触发一次窑变（贯穿 5，无视格挡）
	cc._resolve_effects([{"kind": "gain_kiln_heat", "value": 5}], cc.player, null)
	check("gain_kiln_heat 触发窑变：敌人受 5 贯穿", cc.enemies[0].hp == before_hp - 5,
		"enemy_hp %d -> %d" % [before_hp, cc.enemies[0].hp])
	check("gain_kiln_heat 窑变后窑温归零", cc.kiln_heat == 0, "heat=%d" % cc.kiln_heat)
	cc.queue_free()


# =====================================================================
# 4.3 Boss 三阶段觉醒
# =====================================================================
func _test_boss_phase3() -> void:
	var cc := CombatController.new()
	add_child(cc)
	RunState.start_new_run()
	RunState.current_act = 2
	RunState.hp = 80
	cc.start_combat([StringName("chi_the_first")])

	var boss: CombatUnit = cc.enemies[0]
	check("Boss 初始阶段=0", boss.phase_index == 0, "phase_index=%d" % boss.phase_index)

	# 模拟第三幕 Boss 被打到 25% 以下。
	var scaled_hp: int = boss.max_hp
	boss.hp = int(floor(scaled_hp * 0.24))
	# 清掉战斗开局可能抽到的蓄力(charge_next)，避免强制释放招式掩盖阶段计算
	boss.charge_next = &""
	cc._roll_enemy_intent(boss)
	check("跨阶段先预告觉醒，不提前强化", boss.get_status(&"heat") == 0 and boss.intent.get("intent") == "buff")
	var preparation_hp := cc.player.hp
	cc._execute_enemy_intent(boss)
	cc._roll_enemy_intent(boss)
	cc._execute_enemy_intent(boss)
	cc._roll_enemy_intent(boss)
	check("跨两阶段分别用回合觉醒，不攻击", cc.player.hp == preparation_hp)

	check("跨两阶段各+3力量，共6力量", boss.get_status(&"heat") == 6,
		"heat=%d" % boss.get_status(&"heat"))
	check("觉醒阶段预告暗焰爆发", boss.intent.get("id", "") == "echo_last" and String(boss.intent.get("intent", "")) == "attack",
		"intent=%s" % str(boss.intent.get("intent", "")))

	var p_hp_before: int = boss.hp   # not used; track player
	var player_hp_before: int = cc.player.hp
	cc._execute_enemy_intent(boss)
	var expected := int(boss.intent.get("value", 0)) + boss.get_status(&"heat")
	check("觉醒爆发命中玩家（含力量加成=%d）" % expected,
		cc.player.hp == player_hp_before - expected,
		"player %d -> %d" % [player_hp_before, cc.player.hp])
	check("阶段强化仅触发一次", boss.get_status(&"heat") == 6)

	cc.queue_free()


# =====================================================================
# 4.2 先抽人数、再按规模权重组队
# =====================================================================
func _test_encounter_generation() -> void:
	var before: Dictionary = GameData.encounter_generation.get("before_triple_unlock", {})
	var after: Dictionary = GameData.encounter_generation.get("after_triple_unlock", {})
	check("三敌未解锁：单70%/双30%/三0%",
		int(before.get("1", -1)) == 70 and int(before.get("2", -1)) == 30 and int(before.get("3", -1)) == 0)
	check("三敌已解锁：单65%/双25%/三10%",
		int(after.get("1", -1)) == 65 and int(after.get("2", -1)) == 25 and int(after.get("3", -1)) == 10)
	check("每场强怪上限=1", int(GameData.encounter_generation.get("max_strong_per_encounter", -1)) == 1)

	var enemy_data_ok := true
	for enemy in GameData.enemies.values():
		var expected: Array = _expected_encounter_rule(enemy.encounter_class)
		if enemy.effective_stats:
			expected = [0, 0, 0, 2 if enemy.id in [&"escort_assault", &"escort_bomb"] else 1]
			if enemy.id in [&"coalseer_act3", &"kilnstatue_act3"]:
				expected = [10, 0, 0, 1]
			elif enemy.id in [&"cinderfiend_act3", &"magmawhelp_act3"]:
				expected = [0, 6, 2, 1]
			elif enemy.id == &"glazetick_act3":
				expected = [0, 8, 10, 1]
		if expected.is_empty():
			enemy_data_ok = false
			continue
		for count in range(1, 4):
			if int(enemy.encounter_weight(count)) != int(expected[count - 1]):
				enemy_data_ok = false
		if enemy.max_copies_per_encounter != int(expected[3]):
			enemy_data_ok = false
	check("所有敌人的规模权重与重复上限完整", enemy_data_ok)

	var direct_pick_ok := true
	for cfg in GameData.act_configs:
		var normals := MapGenerator._pool_enemies(cfg, &"normal")
		for requested_count in range(1, 4):
			for i in 100:
				var picked := MapGenerator._pick_weighted_enemies(normals, requested_count)
				if not _encounter_is_valid(picked, requested_count):
					direct_pick_ok = false
	check("三幕按目标人数抽怪：人数准确、强怪≤1、重复合法", direct_pick_ok)

	var maps_ok := true
	var triple_seen_after := [false, false, false]
	for act_index in GameData.act_configs.size():
		var cfg: Dictionary = GameData.act_configs[act_index]
		var unlock := int(cfg.get("triple_enemy_unlock_floor", -1))
		for i in 200:
			var floors: Array = MapGenerator.generate(cfg)
			for row in floors:
				for node in row:
					if not (node is MapNode):
						continue
					if node.type == &"combat":
						if not _encounter_is_valid(node.enemy_ids):
							maps_ok = false
						if node.floor == 0 and node.enemy_ids.size() != 1:
							maps_ok = false
						if node.floor < unlock and node.enemy_ids.size() == 3:
							maps_ok = false
						if node.floor >= unlock and node.enemy_ids.size() == 3:
							triple_seen_after[act_index] = true
					elif (node.type == &"elite" or node.type == &"boss") and node.enemy_ids.size() != 1:
						maps_ok = false
	check("600 张地图：人数门控、强怪上限、精英/Boss 主怪ID均合法", maps_ok)
	check("三幕解锁后均实际生成过三敌战", triple_seen_after.all(func(v: bool) -> bool: return v), str(triple_seen_after))


func _expected_encounter_rule(encounter_class: StringName) -> Array:
	match encounter_class:
		&"strong":
			return [10, 2, 0, 1]
		&"medium":
			return [6, 6, 2, 1]
		&"weak":
			return [2, 8, 10, 2]
		&"solo_only":
			return [10, 0, 0, 1]
	return []


func _encounter_is_valid(ids: Array, expected_count: int = -1) -> bool:
	if ids.is_empty() or ids.size() > GameData.max_enemies_per_combat():
		return false
	if expected_count >= 0 and ids.size() != expected_count:
		return false
	var copies: Dictionary = {}
	var strong_count := 0
	for raw_id in ids:
		var enemy: EnemyData = GameData.get_enemy(StringName(raw_id))
		if enemy == null or enemy.tier != &"normal":
			return false
		copies[enemy.id] = int(copies.get(enemy.id, 0)) + 1
		if int(copies[enemy.id]) > enemy.max_copies_per_encounter:
			return false
		if enemy.encounter_class == &"strong":
			strong_count += 1
	return strong_count <= int(GameData.encounter_generation.get("max_strong_per_encounter", 0))


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== P3 内容扩展验证（卡池/人数优先遇敌/Boss三阶段）=====")
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("P3_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
