extends Node
## 难度系数归位验证：系数回调至 1.0 / 单场敌人上限 3 / 加精英数量。
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
	_test_formations_and_maps()

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

	var elite_w: float = float(GameData.map_config.get("type_weights", {}).get("elite", 0.0))
	check("精英节点频率>=0.15（0.1→0.18）", elite_w >= 0.15, "weight=%f" % elite_w)


# =====================================================================
# 多敌上限 3：存在3敌编成 + 地图真实产出3敌节点且命中编成
# =====================================================================
func _test_formations_and_maps() -> void:
	var three := 0
	for fm in GameData.formations:
		if fm.get("enemies", []).size() == 3:
			three += 1
	check("存在3敌编成（上限3已生效）", three >= 1, "3敌编成=%d" % three)

	# 统计产出：300 张地图是否出现精英节点与3敌战斗节点
	var elite_seen := 0
	var three_seen := 0
	for i in 300:
		var floors: Array = MapGenerator.generate(GameData.map_config)
		for row in floors:
			for node in row:
				if node is MapNode:
					if node.type == &"elite":
						elite_seen += 1
					if node.type == &"combat" and node.enemy_ids.size() == 3:
						three_seen += 1
	check("300张地图出现精英节点（频率生效）", elite_seen > 0, "elite=%d" % elite_seen)
	check("300张地图出现3敌战斗节点（上限生效）", three_seen > 0, "3enemy=%d" % three_seen)

	# 所有3敌战斗节点必须命中某编成（无野怪对）
	var bad3 := 0
	for i in 300:
		var floors: Array = MapGenerator.generate(GameData.map_config)
		for row in floors:
			for node in row:
				if node is MapNode and node.type == &"combat" and node.enemy_ids.size() == 3:
					if not _matches_some_formation(node.enemy_ids):
						bad3 += 1
	check("3敌战斗节点均命中编成", bad3 == 0, "bad=%d" % bad3)


func _matches_some_formation(ids: Array) -> bool:
	for fm in GameData.formations:
		if _same_ids(ids, fm.get("enemies", [])):
			return true
	return false


func _same_ids(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		var found := false
		for y in b:
			if String(x) == String(y):
				found = true
				break
		if not found:
			return false
	return true


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== 难度系数归位验证 =====")
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("DIFF_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
