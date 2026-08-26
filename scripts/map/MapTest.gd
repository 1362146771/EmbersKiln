extends Control
## T3 地图生成冒烟测试。验证：层数、节点数、固定层、连通性、敌人编成、Boss 路径。

var _results: Array[bool] = []
var _names: Array[String] = []


func _ready() -> void:
	RunState.start_new_run()
	var m: Array = RunState.current_map()
	var cfg: Dictionary = GameData.map_config

	# 1 层数 == floor_count
	check("层数 == floor_count", m.size() == int(cfg.get("floor_count", 10)))

	# 2 每层节点数符合 nodes_per_floor
	var npf: Array = cfg.get("nodes_per_floor", [])
	var counts_ok := true
	for f in m.size():
		var exp := int(npf[f]) if f < npf.size() else 1
		if m[f].size() != exp:
			counts_ok = false
	check("每层节点数符合配置", counts_ok)

	# 3 固定层类型正确
	var fixed: Dictionary = cfg.get("fixed", {})
	for key in fixed.keys():
		var f := int(String(key).replace("floor_", ""))
		var t: StringName = StringName(fixed[key])
		check("固定层 %s == %s" % [key, t], m[f][0].type == t)

	# 4 每非末层节点都有出边
	var out_ok := true
	for f in m.size() - 1:
		for node in m[f]:
			if node.links.is_empty():
				out_ok = false
	check("每非末层节点有出边", out_ok)

	# 5 每层(除首层)节点都有入边（可达）
	var reach_ok := true
	for f in range(1, m.size()):
		var incoming: Dictionary = {}
		for prev in m[f - 1]:
			for j in prev.links:
				incoming[j] = true
		for j in m[f].size():
			if not incoming.has(j):
				reach_ok = false
	check("每层节点可达(有入边)", reach_ok)

	# 6 战斗/精英/Boss 节点含敌人编成
	var enemy_ok := true
	for f in m:
		for node in f:
			if node.is_combat_like():
				if node.enemy_ids.is_empty():
					enemy_ok = false
	check("战斗/精英/Boss 节点含敌人", enemy_ok)

	# 7 Boss 层节点指向 Boss 敌人
	var boss_id: StringName = &""
	for e in GameData.get_enemies_by_tier(&"boss"):
		boss_id = e.id
	var last: Array = m[m.size() - 1]
	check("Boss 层节点指向 Boss 敌人",
		last[0].type == &"boss" and last[0].enemy_ids.size() == 1 and last[0].enemy_ids[0] == boss_id)

	# 8 从首层 BFS 能到达 Boss 层
	check("存在通往 Boss 的路径", _reach_boss(m))

	_report()


func check(n: String, c: bool) -> void:
	_names.append(n)
	_results.append(c)


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
	print("==== T3 地图冒烟 %d/%d PASS ====" % [pass_c, total])
	print("RESULT: %s" % ("PASS" if pass_c == total else "FAIL"))
