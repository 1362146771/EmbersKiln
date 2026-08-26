class_name MapGenerator
extends RefCounted
## 依据 map.json 的 act_configs 逐幕生成地图（支持多幕）。
## 铁律：节点数量/类型/固定层全部来自 config，不写死任何数值或名称。

const NODE_TYPES := [&"combat", &"elite", &"event", &"shop", &"rest", &"treasure", &"altar"]


## 返回 floors: Array[floor] -> Array[MapNode]
static func generate(config: Dictionary) -> Array:
	var floor_count: int = int(config.get("floor_count", 10))
	var nodes_per_floor: Array = config.get("nodes_per_floor", [])
	var fixed: Dictionary = config.get("fixed", {})
	var weights: Dictionary = config.get("type_weights", {})
	var altar_count := 0

	var floors: Array = []
	for f in floor_count:
		var n: int = int(nodes_per_floor[f]) if f < nodes_per_floor.size() else 1
		var floor_nodes: Array = []
		for i in n:
			var node := MapNode.new()
			node.floor = f
			node.index = i
			var key := "floor_%d" % f
			if fixed.has(key):
				node.type = StringName(fixed[key])
			else:
				node.type = _weighted_type(weights, altar_count)
				if node.type == &"altar":
					altar_count += 1
			_assign_enemies(node, config)
			floor_nodes.append(node)
		floors.append(floor_nodes)

	_connect(floors)
	return floors


static func _weighted_type(weights: Dictionary, altar_count: int = 0) -> StringName:
	var total := 0.0
	for t in NODE_TYPES:
		total += float(weights.get(t, 0.0))
	if total <= 0.0:
		return &"combat"
	var r := randf() * total
	for t in NODE_TYPES:
		var w := float(weights.get(t, 0.0))
		if w <= 0.0:
			continue
		if t == &"altar" and altar_count >= 1:
			continue
		r -= w
		if r <= 0.0:
			return t
	return &"combat"


static func _assign_enemies(node: MapNode, config: Dictionary) -> void:
	match node.type:
		&"combat":
			var normals := _pool_enemies(config, &"normal")
			# 教学层（f0）固定单怪；否则按编成表抽一组（受 max_enemies 约束），
			# 约 45% 概率触发多敌编成，未命中则随机单怪。
			if node.floor == 0 or normals.size() < 2 or randf() >= 0.45:
				node.enemy_ids = [_random_id(normals)]
			else:
				var forms := GameData.get_formations_for_floor(node.floor, int(config.get("act", 0)))
				if forms.is_empty():
					node.enemy_ids = [_random_id(normals)]
				else:
					node.enemy_ids = _weighted_formation(forms, normals)
		&"elite":
			node.enemy_ids = [_random_id(_pool_enemies(config, &"elite"))]
		&"boss":
			var bid: StringName = StringName(config.get("boss_id", ""))
			if bid != &"":
				node.enemy_ids = [bid]
			else:
				var bs := GameData.get_enemies_by_tier(&"boss")
				node.enemy_ids = [bs[0].id] if not bs.is_empty() else []
		_:
			node.enemy_ids = []


## 按当前幕 enemy_pool 取敌（P-D 敌池隔离）；池缺失/为空时回退到全 tier 池。
static func _pool_enemies(config: Dictionary, tier: StringName) -> Array:
	var pool: Dictionary = config.get("enemy_pool", {})
	var out: Array = []
	for eid in pool.get(String(tier), []):
		var ed: EnemyData = GameData.get_enemy(StringName(eid))
		if ed != null:
			out.append(ed)
	if out.is_empty():
		out = GameData.get_enemies_by_tier(tier)
	return out


static func _random_id(list: Array) -> StringName:
	if list.is_empty():
		return &""
	return list[randi_range(0, list.size() - 1)].id


## 按编成 weight 加权抽一组，返回该编成的敌人 id 列表（StringName 数组）。
## fallback 用当前幕敌池（保持 P-D 敌池隔离）；normals 缺省时回退全 tier 池（兼容旧调用）。
static func _weighted_formation(forms: Array, normals: Array = []) -> Array[StringName]:
	if normals.is_empty():
		normals = GameData.get_enemies_by_tier(&"normal")
	var total := 0.0
	for fm in forms:
		total += float(fm.get("weight", 1.0))
	if total <= 0.0:
		return [_random_id(normals)]
	var r := randf() * total
	for fm in forms:
		r -= float(fm.get("weight", 1.0))
		if r <= 0.0:
			var ids: Array[StringName] = []
			for eid in fm.get("enemies", []):
				ids.append(StringName(eid))
			return ids
	return [_random_id(normals)]


## 边连接：保证 (1) 每个下层节点有入边 (可达) (2) 每个本层节点有出边 (无死路)
static func _connect(floors: Array) -> void:
	for f in floors.size() - 1:
		var cur: Array = floors[f]
		var nxt: Array = floors[f + 1]
		for node in cur:
			node.links.clear()
		# 每个下层节点至少分配一个父节点
		for j in nxt.size():
			var p := randi_range(0, cur.size() - 1)
			if not cur[p].links.has(j):
				cur[p].links.append(j)
			if nxt.size() > 1 and randf() < 0.5:
				var p2 := randi_range(0, cur.size() - 1)
				if not cur[p2].links.has(j):
					cur[p2].links.append(j)
		# 每个本层节点至少一条出边
		for i in cur.size():
			var j := mini(i, nxt.size() - 1)
			if not cur[i].links.has(j):
				cur[i].links.append(j)
