extends Control
## T3 地图生成测试（StS 式稀疏网格 DAG）。
## 覆盖：层数/列界/单一起点/固定层/单 Boss/出入边/连接列差/人数优先遇敌/祭坛≤1/类型门控/BFS 可达；
## 每幕再压力跑 100 次，校验结构不变量恒成立。

var _results: Array[bool] = []
var _names: Array[String] = []


func _ready() -> void:
	if not GameData.is_loaded:
		printerr("[FAIL] GameData 未加载")
		return
	RunState.start_new_run()
	var acts: Array = GameData.act_configs
	for act_cfg in acts:
		_test_act(act_cfg)
	_report()


func _test_act(cfg: Dictionary) -> void:
	var act_id: int = int(cfg.get("act", 0))
	var width: int = int(cfg.get("columns", 6))
	var height: int = int(cfg.get("floor_count", 15))
	var boss_floor: int = height - 1
	var preboss: int = height - 2
	var mid_t: int = int(cfg.get("mid_treasure_floor", height / 2))
	var gates: Dictionary = cfg.get("type_gates", {})
	var elite_min: int = int(gates.get("elite", 3))
	var rest_min: int = int(gates.get("rest", 5))
	var shop_min: int = int(gates.get("shop", 2))
	var single_start_node: bool = bool(cfg.get("single_start_node", false))

	# 单次结构详细检查
	var m: Array = MapGenerator.generate(cfg)
	check("Act%d 层数==floor_count" % act_id, m.size() == height)
	check("Act%d 首层全 combat" % act_id, _row_all_type(m, 0, &"combat"))
	if single_start_node:
		check("Act%d 首层只有一个怪物节点" % act_id, _single_combat_start(m))
		check("Act%d 首层连接全部第二层节点" % act_id, _start_links_all_second_floor(m))
	check("Act%d 次顶层全 rest" % act_id, _row_all_type(m, preboss, &"rest"))
	check("Act%d 中层全 treasure" % act_id, _row_all_type(m, mid_t, &"treasure"))
	check("Act%d 顶层单节点且为 boss" % act_id, _boss_singleton(m, boss_floor))
	check("Act%d 所有次顶层连向 Boss" % act_id, _all_preboss_link_boss(m, preboss, boss_floor))
	check("Act%d 列坐标合法(0..width-1)" % act_id, _cols_in_range(m, width))
	check("Act%d 每非末层节点有出边" % act_id, _all_have_out(m))
	check("Act%d 每非首层节点可达(有入边)" % act_id, _all_reachable(m))
	check("Act%d 出边列差合规" % act_id, _link_deltas_ok(m, boss_floor, single_start_node))
	check("Act%d 遇敌人数门控、强怪/重复上限、单体精英Boss合法" % act_id, _enemy_assignment_ok(m, cfg))
	check("Act%d BFS 可达 Boss" % act_id, _reach_boss(m))

	# 压力：N 次生成，结构不变量必须恒成立
	var N := 100
	var altar_max := 0
	var gates_ok := true
	var cols_ok := true
	var boss_ok := true
	var reachable_ok := true
	var single_start_ok := true
	var encounters_ok := true
	for it in N:
		var mm: Array = MapGenerator.generate(cfg)
		var altar := 0
		for row in mm:
			for node in row:
				if node.type == &"altar":
					altar += 1
				if node.col < 0 or node.col >= width:
					cols_ok = false
				if _gated_bad(node.type, node.floor, elite_min, rest_min, shop_min):
					gates_ok = false
		if altar > altar_max:
			altar_max = altar
		if not _boss_singleton(mm, boss_floor):
			boss_ok = false
		if not _all_reachable(mm):
			reachable_ok = false
		if not _enemy_assignment_ok(mm, cfg):
			encounters_ok = false
		if single_start_node and (not _single_combat_start(mm) or not _start_links_all_second_floor(mm)):
			single_start_ok = false
	check("Act%d 压力:%d次 祭坛≤1(实测max=%d)" % [act_id, N, altar_max], altar_max <= 1)
	check("Act%d 压力:%d次 类型门控恒定" % [act_id, N], gates_ok)
	check("Act%d 压力:%d次 列坐标恒定合法" % [act_id, N], cols_ok)
	check("Act%d 压力:%d次 顶层单Boss恒定" % [act_id, N], boss_ok)
	check("Act%d 压力:%d次 全节点可达恒定" % [act_id, N], reachable_ok)
	check("Act%d 压力:%d次 遇敌编组约束恒定" % [act_id, N], encounters_ok)
	if single_start_node:
		check("Act%d 压力:%d次 单一起点且全连第二层" % [act_id, N], single_start_ok)


# ---------- 断言辅助 ----------
func check(n: String, c: bool) -> void:
	_names.append(n)
	_results.append(c)


func _row_all_type(m: Array, r: int, t: StringName) -> bool:
	if r < 0 or r >= m.size():
		return false
	if m[r].is_empty():
		return false
	for node in m[r]:
		if node.type != t:
			return false
	return true


func _boss_singleton(m: Array, boss_floor: int) -> bool:
	var row: Array = m[boss_floor]
	if row.size() != 1:
		return false
	var b: MapNode = row[0]
	return b.type == &"boss" and b.enemy_ids.size() == 1


func _single_combat_start(m: Array) -> bool:
	if m.is_empty() or m[0].size() != 1:
		return false
	var start: MapNode = m[0][0]
	return start.type == &"combat" and start.enemy_ids.size() == 1


func _start_links_all_second_floor(m: Array) -> bool:
	if m.size() < 2 or m[0].size() != 1 or m[1].is_empty():
		return false
	var links: Array[int] = m[0][0].links
	if links.size() != m[1].size():
		return false
	for i in m[1].size():
		if not links.has(i):
			return false
	return true


func _all_preboss_link_boss(m: Array, preboss: int, boss_floor: int) -> bool:
	for node in m[preboss]:
		if node.links.is_empty() or not node.links.has(0):
			return false
	return true


func _cols_in_range(m: Array, width: int) -> bool:
	for row in m:
		for node in row:
			if node.col < 0 or node.col >= width:
				return false
	return true


func _all_have_out(m: Array) -> bool:
	for f in m.size() - 1:
		for node in m[f]:
			if node.links.is_empty():
				return false
	return true


func _all_reachable(m: Array) -> bool:
	for f in range(1, m.size()):
		var incoming: Dictionary = {}
		for prev in m[f - 1]:
			for j in prev.links:
				incoming[j] = true
		for j in m[f].size():
			if not incoming.has(j):
				return false
	return true


func _link_deltas_ok(m: Array, boss_floor: int, single_start_node: bool) -> bool:
	for f in m.size() - 1:
		for node in m[f]:
			for j in node.links:
				# 单一起点刻意扇出到第二层全部节点，不受通常的相邻列限制。
				if single_start_node and f == 0:
					continue
				var target: MapNode = m[f + 1][j]
				var d: int = absi(node.col - target.col)
				var limit: int = 2 if (f + 1) == boss_floor else 1
				if d > limit:
					return false
	return true


func _enemy_assignment_ok(m: Array, cfg: Dictionary) -> bool:
	var triple_unlock := int(cfg.get("triple_enemy_unlock_floor", -1))
	for row in m:
		for node in row:
			var combat_like: bool = node.type == &"combat" or node.type == &"elite" or node.type == &"boss"
			if combat_like and node.enemy_ids.is_empty():
				return false
			if not combat_like and not node.enemy_ids.is_empty():
				return false
			if (node.type == &"elite" or node.type == &"boss") and node.enemy_ids.size() != 1:
				return false
			if node.type == &"combat":
				if node.floor == 0 and node.enemy_ids.size() != 1:
					return false
				if node.floor < triple_unlock and node.enemy_ids.size() == 3:
					return false
				if not _normal_encounter_valid(node.enemy_ids):
					return false
	return true


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


func _gated_bad(t: StringName, r: int, elite_min: int, rest_min: int, shop_min: int) -> bool:
	if t == &"elite" and r < elite_min:
		return true
	if t == &"rest" and r < rest_min:
		return true
	if t == &"shop" and r < shop_min:
		return true
	return false


func _reach_boss(m: Array) -> bool:
	var visited: Dictionary = {}
	var queue: Array = []
	for node in m[0]:
		queue.append(node)
		visited[node] = true
	while not queue.is_empty():
		var node: MapNode = queue.pop_front()
		if node.floor == m.size() - 1:
			return true
		for j in node.links:
			var nxt: MapNode = m[node.floor + 1][j]
			if not visited.has(nxt):
				visited[nxt] = true
				queue.append(nxt)
	return false


func _report() -> void:
	var pass_c := 0
	for i in _results.size():
		var mark := "✓" if _results[i] else "✗"
		if _results[i]:
			pass_c += 1
		print("%s %s" % [mark, _names[i]])
	var total := _results.size()
	print("==== T3 地图(StS式) %d/%d PASS ====" % [pass_c, total])
	print("RESULT: %s" % ("PASS" if pass_c == total else "FAIL"))
