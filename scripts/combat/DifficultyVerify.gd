extends Node
## 难度回归验证：系数 / 敌人上限 / 人数优先遇敌 / 精英数量。
## 全部确定性 + 统计断言，真实运行（headless）后用 stdout 判定 DIFF_RESULT。

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

	_test_coefficients()
	_test_enemy_roster()
	_test_encounter_generation_and_maps()

	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if detail != "" else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if detail != "" else ""])


# =====================================================================
# 系数回调至 1.0 / 上限 3
# =====================================================================
func _test_coefficients() -> void:
	var es: Dictionary = GameData.balance.get("enemy_scaling", {})

	check("难度等级=normal（归位）", GameData.balance.get("difficulty", "") == "normal",
		"difficulty=%s" % GameData.balance.get("difficulty", ""))
	check("伤害系数=1.0", abs(float(es.get("damage_multiplier", 1.0)) - 1.0) < 0.001,
		"dmg=%s" % es.get("damage_multiplier", ""))
	check("HP系数=1.0", abs(float(es.get("hp_multiplier", 1.0)) - 1.0) < 0.001,
		"hp=%s" % es.get("hp_multiplier", ""))
	check("单场敌人上限=3", int(es.get("max_enemies_per_combat", 2)) == 3,
		"max=%s" % es.get("max_enemies_per_combat", ""))

	# 缩放函数应等于基础值（乘 1.0）
	check("claylump 缩放HP=基础(44)", GameData.scaled_enemy_hp(44) == 44,
		"scaled=%d" % GameData.scaled_enemy_hp(44))
	check("Boss 缩放HP=基础(150)", GameData.scaled_enemy_hp(150) == 150,
		"scaled=%d" % GameData.scaled_enemy_hp(150))
	check("伤害缩放=基础(10)", GameData.scaled_enemy_damage(10) == 10,
		"scaled=%d" % GameData.scaled_enemy_damage(10))
	check("第1/2/3幕非Boss数值倍率=0.70/1.00/0.70",
		abs(float(GameData.act_configs[0].get("non_boss_stat_mult", 0.0)) - 0.70) < 0.001
		and abs(float(GameData.act_configs[1].get("non_boss_stat_mult", 0.0)) - 1.0) < 0.001
		and abs(float(GameData.act_configs[2].get("non_boss_stat_mult", 0.0)) - 0.70) < 0.001)


# =====================================================================
# 加精英数量：第3种精英敌 + 精英节点频率
# =====================================================================
func _test_enemy_roster() -> void:
	var elites: Array = GameData.get_enemies_by_tier(&"elite")
	check("精英敌=5（P-D 新增窑卫长/烬噬）", elites.size() == 5, "elites=%d" % elites.size())
	var elite_ids := ""
	for e in elites:
		elite_ids += e.id + " "
	check("精英池含 slagbeast", elite_ids.contains("slagbeast"), elite_ids.strip_edges())
	var sagger := GameData.get_enemy(&"sagger_matron")
	var kilnheart := GameData.get_enemy(&"kilnheart_ember")
	var chi := GameData.get_enemy(&"chi_the_first")
	check("三Boss基础耐久按本作牌值折算为180/200/190",
		sagger.base_hp == 180 and kilnheart.base_hp == 200 and chi.base_hp == 190)
	check("匣母循环提升为16攻/18格挡/32蓄力释放",
		int(sagger.find_move(&"bar").value) == 16 and int(sagger.find_move(&"seal").value) == 18 and int(sagger.find_move(&"fire").value) == 32)
	check("窑心后段具备16格挡与32蓄力释放",
		int(kilnheart.phases[1].moves[3].value) == 16 and int(kilnheart.phases[1].moves[5].value) == 32 and int(kilnheart.phases[2].moves[0].value) == 12)
	check("窑主后段具备18格挡与32蓄力释放",
		int(chi.phases[1].moves[3].value) == 18 and int(chi.phases[1].moves[5].value) == 32 and int(chi.phases[2].moves[0].value) == 14)

	var elite_w: float = float(GameData.map_config.get("type_weights", {}).get("elite", 0.0))
	check("精英节点频率>=0.15（0.1→0.18）", elite_w >= 0.15, "weight=%f" % elite_w)


# =====================================================================
# 人数优先遇敌：人数分布、跨幕解锁与强怪上限
# =====================================================================
func _test_encounter_generation_and_maps() -> void:
	var before: Dictionary = GameData.encounter_generation.get("before_triple_unlock", {})
	var after: Dictionary = GameData.encounter_generation.get("after_triple_unlock", {})
	check("未解锁人数权重=70/30/0",
		int(before.get("1", -1)) == 70 and int(before.get("2", -1)) == 30 and int(before.get("3", -1)) == 0)
	check("解锁后人数权重=65/25/10",
		int(after.get("1", -1)) == 65 and int(after.get("2", -1)) == 25 and int(after.get("3", -1)) == 10)
	var scaling: Dictionary = GameData.encounter_generation.get("third_act_deck_capacity_scaling", {})
	check("第三幕容量18..24映射多人权重加成0..20%",
		int(scaling.get("act", 0)) == 3 and int(scaling.get("capacity_min", 0)) == 18
		and int(scaling.get("capacity_max", 0)) == 24 and abs(float(scaling.get("max_multi_weight_bonus", 0.0)) - 0.20) < 0.001)
	var act2: Dictionary = GameData.act_configs[1]
	var act3: Dictionary = GameData.act_configs[2]
	var cap18 := MapGenerator._resolved_enemy_count_weights(act3, "after_triple_unlock", 18)
	var cap21 := MapGenerator._resolved_enemy_count_weights(act3, "after_triple_unlock", 21)
	var cap24 := MapGenerator._resolved_enemy_count_weights(act3, "after_triple_unlock", 24)
	var act2_cap24 := MapGenerator._resolved_enemy_count_weights(act2, "after_triple_unlock", 24)
	check("第三幕容量18保持65/25/10", is_equal_approx(float(cap18["1"]), 65.0) and is_equal_approx(float(cap18["2"]), 25.0) and is_equal_approx(float(cap18["3"]), 10.0))
	check("第三幕容量21多人权重+10%", is_equal_approx(float(cap21["1"]), 65.0) and is_equal_approx(float(cap21["2"]), 27.5) and is_equal_approx(float(cap21["3"]), 11.0))
	check("第三幕容量24+多人权重封顶20%", is_equal_approx(float(cap24["1"]), 65.0) and is_equal_approx(float(cap24["2"]), 30.0) and is_equal_approx(float(cap24["3"]), 12.0))
	check("第二幕容量变化不改变人数权重", is_equal_approx(float(act2_cap24["1"]), 65.0) and is_equal_approx(float(act2_cap24["2"]), 25.0) and is_equal_approx(float(act2_cap24["3"]), 10.0))
	var unlocks: Array[int] = []
	for cfg in GameData.act_configs:
		unlocks.append(int(cfg.get("triple_enemy_unlock_floor", -1)))
	check("三敌解锁层=幕1/2/3内部层5/4/3", unlocks == [5, 4, 3], "unlocks=%s" % str(unlocks))

	# 直接采样人数抽选，验证实现读取了配置而非旧固定编组路径。
	var pre_counts := [0, 0, 0, 0]
	var post_counts := [0, 0, 0, 0]
	var sample_count := 10000
	var act1: Dictionary = GameData.act_configs[0]
	for i in sample_count:
		pre_counts[MapGenerator._roll_enemy_count(1, act1)] += 1
		post_counts[MapGenerator._roll_enemy_count(5, act1)] += 1
	var pre_single := float(pre_counts[1]) / sample_count
	var pre_double := float(pre_counts[2]) / sample_count
	var post_single := float(post_counts[1]) / sample_count
	var post_double := float(post_counts[2]) / sample_count
	var post_triple := float(post_counts[3]) / sample_count
	check("未解锁实测约70%单/30%双且无三敌",
		abs(pre_single - 0.70) < 0.03 and abs(pre_double - 0.30) < 0.03 and pre_counts[3] == 0,
		"counts=%s" % str(pre_counts))
	check("解锁后实测约65%单/25%双/10%三",
		abs(post_single - 0.65) < 0.03 and abs(post_double - 0.25) < 0.03 and abs(post_triple - 0.10) < 0.03,
		"counts=%s" % str(post_counts))

	# 统计真实地图产出与编组约束。
	var elite_seen := 0
	var maps_ok := true
	var triple_seen := [false, false, false]
	for act_index in GameData.act_configs.size():
		var cfg: Dictionary = GameData.act_configs[act_index]
		var unlock := int(cfg.get("triple_enemy_unlock_floor", -1))
		for i in 300:
			var floors: Array = MapGenerator.generate(cfg)
			for row in floors:
				for node in row:
					if not (node is MapNode):
						continue
					if node.type == &"elite":
						elite_seen += 1
						if node.enemy_ids.size() != 1:
							maps_ok = false
					elif node.type == &"boss" and node.enemy_ids.size() != 1:
						maps_ok = false
					elif node.type == &"combat":
						if not _normal_encounter_valid(node.enemy_ids):
							maps_ok = false
						if node.floor < unlock and node.enemy_ids.size() == 3:
							maps_ok = false
						if node.floor >= unlock and node.enemy_ids.size() == 3:
							triple_seen[act_index] = true
	check("900张地图出现精英节点（频率生效）", elite_seen > 0, "elite=%d" % elite_seen)
	check("900张地图遇敌编组均满足强怪与重复上限", maps_ok)
	check("三幕解锁后均实际生成三敌战", triple_seen.all(func(v: bool) -> bool: return v), str(triple_seen))


func _normal_encounter_valid(ids: Array) -> bool:
	if ids.is_empty() or ids.size() > GameData.max_enemies_per_combat():
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
	lines.append("===== 难度系数归位验证 =====")
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("DIFF_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
