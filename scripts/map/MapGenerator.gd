class_name MapGenerator
extends RefCounted
## 模仿《杀戮尖塔》的地图生成：稀疏网格 DAG + 路径编织上升。
## 铁律：列数/路径数/类型权重/固定层/门控全部来自 config（map.json 的 act 配置），不写死任何数值或名称。

const NODE_TYPES := [&"combat", &"elite", &"event", &"shop", &"rest", &"treasure", &"altar"]


## 返回 floors: Array[floor] -> Array[MapNode]，floor 内按列(col)升序排列，links 指向下一层 index。
static func generate(config: Dictionary) -> Array:
	var width: int = int(config.get("columns", 6))
	var height: int = int(config.get("floor_count", 15))
	var num_paths: int = int(config.get("num_paths", width))
	num_paths = clampi(num_paths, 1, width)
	var boss_floor: int = height - 1
	var preboss_rest: int = height - 2
	var mid_treasure: int = int(config.get("mid_treasure_floor", height / 2))
	var center: int = int(width / 2)
	var single_start_node: bool = bool(config.get("single_start_node", false))

	# 1) 先用互异列生成路径，让第二层及以上保持足够的路线分布。
	var starts: Array = _pick_starts(width, num_paths)

	# 2) 逐路径生成列序列（带防交叉 + 顶部向中心收敛）。
	#    生成第 p 条时仅参考已生成的 0..p-1 条（与 StS 一致）。
	var paths: Array = []
	for p in num_paths:
		paths.append(_gen_path(int(starts[p]), width, height, center, paths))
	# 每幕可配置为单一起点：所有路径共用首层中央节点，第二层起再分叉。
	if single_start_node:
		for path in paths:
			path[0] = center

	# 3) 落格：grid[r][col] = MapNode | null
	var grid: Array = []
	for r in height:
		grid.append({})
	for p in num_paths:
		for r in height:
			var c: int = int(paths[p][r])
			var grow: Dictionary = grid[r]
			if not grow.has(c):
				var node := MapNode.new()
				node.floor = r
				node.col = c
				node.type = &"combat"
				node.enemy_ids = []
				grow[c] = node

	# 4) 按深度规则分配节点类型（含祭坛≤1/幕上限、精英/休/店 最小层门控）
	_assign_types(grid, config, paths, width, height, boss_floor, preboss_rest, mid_treasure)

	# 5) 排序成 floors[] 并据路径建立 links
	var floors: Array = []
	var col_to_idx: Array = []
	for r in height:
		var grow: Dictionary = grid[r]
		var cols: Array = grow.keys()
		cols.sort()
		var row: Array = []
		var cmap: Dictionary = {}
		for i in cols.size():
			var c: int = int(cols[i])
			var node: MapNode = grow[c]
			node.index = i
			row.append(node)
			cmap[c] = i
		floors.append(row)
		col_to_idx.append(cmap)

	for p in num_paths:
		for r in height - 1:
			var c: int = int(paths[p][r])
			var c2: int = int(paths[p][r + 1])
			var from_node: MapNode = grid[r][c]
			var to_idx: int = int(col_to_idx[r + 1][c2])
			if not from_node.links.has(to_idx):
				from_node.links.append(to_idx)
	# 单一起点必须能选择第二层的任意节点，不依赖随机路径去重结果。
	if single_start_node and height > 1 and not floors[0].is_empty():
		var start_node: MapNode = floors[0][0]
		start_node.links.clear()
		for i in floors[1].size():
			start_node.links.append(i)

	# 6) 分配敌人：普通战先抽数量、再按该数量的怪物权重组队；精英/Boss 固定单体。
	for r in height:
		for node in floors[r]:
			_assign_enemies(node, config)

	return floors


## 从 [0,width) 取 num_paths 个互异起点列（打乱后截取）。
static func _pick_starts(width: int, num_paths: int) -> Array:
	var cols: Array = []
	for c in width:
		cols.append(c)
	cols.shuffle()
	return cols.slice(0, num_paths)


## 单条路径：从 start_col 出发，每层列 ±1 移动（受边界约束），
## 剔除会与已有路径段交叉的选项；最后 3 层向中心列收敛，顶行强制中心（单一 Boss）。
static func _gen_path(start_col: int, width: int, height: int, center: int, existing: Array) -> Array:
	var col: int = start_col
	var seq: Array = [col]
	for r in range(1, height):
		var cands: Array = []
		for d in [-1, 0, 1]:
			var nc: int = col + d
			if nc >= 0 and nc < width:
				cands.append(nc)
		# 防交叉：剔除会与已有路径本层段交叉的选项
		var filtered: Array = []
		for nc in cands:
			if not _crosses(existing, seq, r, col, nc):
				filtered.append(nc)
		if filtered.is_empty():
			filtered = cands
		# 顶部收敛：最后 3 层优先靠近中心列
		if r >= height - 3:
			filtered.sort_custom(func(a, b): return absi(int(a) - center) < absi(int(b) - center))
			var best_delta: int = absi(int(filtered[0]) - center)
			var top: Array = []
			for nc in filtered:
				if absi(int(nc) - center) == best_delta:
					top.append(nc)
			filtered = top
		col = int(filtered[randi_range(0, filtered.size() - 1)])
		seq.append(col)
	seq[height - 1] = center
	return seq


## 我方段 (col@r-1 -> nc@r) 是否与已有路径 q 的段 (qc@r-1 -> qc2@r) 交叉。
static func _crosses(existing: Array, seq: Array, r: int, col: int, nc: int) -> bool:
	for q in existing.size():
		var qpath: Array = existing[q]
		if r >= qpath.size():
			continue
		var qc: int = int(qpath[r - 1])
		var qc2: int = int(qpath[r])
		if (col < qc and nc > qc2) or (col > qc and nc < qc2):
			return true
	return false


## 按深度分配类型：固定层先落（首层 combat / 中层宝箱 / 次顶休整 / 顶 Boss），
## 其余沿路径游走按权重抽样（受门控与「同路径不连续 3 个同类型」约束，祭坛≤1/幕）。
static func _assign_types(grid: Array, config: Dictionary, paths: Array, width: int, height: int, boss_floor: int, preboss_rest: int, mid_treasure: int) -> void:
	var fixed_rows: Dictionary = config.get("fixed_rows", {})
	var weights: Dictionary = config.get("type_weights", {})
	var gates: Dictionary = config.get("type_gates", {})
	var elite_min: int = int(gates.get("elite", 3))
	var rest_min: int = int(gates.get("rest", 5))
	var shop_min: int = int(gates.get("shop", 2))
	var altar_count: int = 0

	# 固定层先落
	for r in height:
		var fkey: String = "%d" % r
		var forced: String = String(fixed_rows.get(fkey, ""))
		if forced == "":
			continue
		var grow: Dictionary = grid[r]
		for c in grow.keys():
			var node: MapNode = grow[c]
			node.type = StringName(forced)

	# 按路径游走分配随机层（先写者胜：固定层/已定节点保留，仅更新本路径追踪）
	for p in paths.size():
		var qpath: Array = paths[p]
		var prev: StringName = &""
		var prevprev: StringName = &""
		for r in height:
			var c: int = int(qpath[r])
			var node: MapNode = grid[r][c]
			if node.type != &"combat" or r == 0:
				prevprev = prev
				prev = node.type
				continue
			var t: StringName = _sample(weights)
			var guard: int = 0
			while (_blocked(t, r, elite_min, rest_min, shop_min) or (t == prev and t == prevprev)) and guard < 12:
				t = _sample(weights)
				guard += 1
			if _blocked(t, r, elite_min, rest_min, shop_min):
				t = &"combat"
			if t == &"altar":
				if altar_count >= 1:
					t = &"combat"
				else:
					altar_count += 1
			node.type = t
			prevprev = prev
			prev = t


## 权重抽样出一个节点类型（权重总和不要求归一）。
static func _sample(weights: Dictionary) -> StringName:
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
		r -= w
		if r <= 0.0:
			return t
	return &"combat"


## 门控：精英/休/店 未达最小层则禁止。
static func _blocked(t: StringName, r: int, elite_min: int, rest_min: int, shop_min: int) -> bool:
	if t == &"elite" and r < elite_min:
		return true
	if t == &"rest" and r < rest_min:
		return true
	if t == &"shop" and r < shop_min:
		return true
	return false


static func _assign_enemies(node: MapNode, config: Dictionary) -> void:
	match node.type:
		&"combat":
			var normals := _pool_enemies(config, &"normal")
			var enemy_count := _roll_enemy_count(node.floor, config)
			node.enemy_ids = _pick_weighted_enemies(normals, enemy_count)
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


## 教学层固定单怪；之后按当前幕的三敌解锁层读取人数权重。
## 第三幕额外按当前牌库容量为多怪权重提供 0..配置上限的线性加成。
static func _roll_enemy_count(floor: int, config: Dictionary) -> int:
	if floor == 0:
		return 1
	var triple_unlock := int(config.get("triple_enemy_unlock_floor", -1))
	var rule_name := "after_triple_unlock" if floor >= triple_unlock else "before_triple_unlock"
	var weights := _resolved_enemy_count_weights(config, rule_name)
	var max_count := GameData.max_enemies_per_combat()
	var total := 0.0
	for enemy_count in range(1, max_count + 1):
		total += maxf(0.0, float(weights.get(str(enemy_count), 0.0)))
	if total <= 0.0:
		return 1
	var roll := randf() * total
	for enemy_count in range(1, max_count + 1):
		roll -= maxf(0.0, float(weights.get(str(enemy_count), 0.0)))
		if roll <= 0.0:
			return enemy_count
	return 1


## 返回当前容量下的实际人数权重。override 仅供确定性验证；负值表示读取 RunState。
static func _resolved_enemy_count_weights(config: Dictionary, rule_name: String, deck_capacity_override: int = -1) -> Dictionary:
	var weights: Dictionary = GameData.encounter_generation.get(rule_name, {}).duplicate(true)
	var scaling: Dictionary = GameData.encounter_generation.get("third_act_deck_capacity_scaling", {})
	if int(config.get("act", 0)) != int(scaling.get("act", -1)):
		return weights
	var capacity := deck_capacity_override
	if capacity < 0 and RunState != null:
		capacity = RunState.current_deck_capacity()
	var capacity_min := int(scaling.get("capacity_min", 0))
	var capacity_max := int(scaling.get("capacity_max", capacity_min))
	if capacity < 0:
		capacity = capacity_min
	var progress := 0.0
	if capacity_max > capacity_min:
		progress = clampf(float(capacity - capacity_min) / float(capacity_max - capacity_min), 0.0, 1.0)
	var multi_bonus := float(scaling.get("max_multi_weight_bonus", 0.0)) * progress
	for enemy_count in range(2, GameData.max_enemies_per_combat() + 1):
		var key := str(enemy_count)
		weights[key] = float(weights.get(key, 0.0)) * (1.0 + multi_bonus)
	return weights


## 按目标敌人数对应的怪物权重逐个抽取；强怪共享编组上限，同种怪受副本上限约束。
static func _pick_weighted_enemies(pool: Array, requested_count: int) -> Array[StringName]:
	var picked: Array[StringName] = []
	if pool.is_empty():
		return picked
	var target_count := clampi(requested_count, 1, GameData.max_enemies_per_combat())
	var picked_per_id: Dictionary = {}
	var strong_count := 0
	var max_strong := int(GameData.encounter_generation.get("max_strong_per_encounter", 0))
	for _slot in target_count:
		var candidates: Array = []
		var weights: Array[float] = []
		for enemy in pool:
			var ed := enemy as EnemyData
			if ed == null:
				continue
			var weight := ed.encounter_weight(target_count)
			if weight <= 0.0:
				continue
			var copies := int(picked_per_id.get(ed.id, 0))
			if copies >= ed.max_copies_per_encounter:
				continue
			if ed.encounter_class == &"strong" and strong_count >= max_strong:
				continue
			candidates.append(ed)
			weights.append(weight)
		if candidates.is_empty():
			break
		var chosen: EnemyData = _weighted_enemy(candidates, weights)
		if chosen == null:
			break
		picked.append(chosen.id)
		picked_per_id[chosen.id] = int(picked_per_id.get(chosen.id, 0)) + 1
		if chosen.encounter_class == &"strong":
			strong_count += 1
	if picked.is_empty():
		picked.append(_random_id(pool))
	return picked


static func _weighted_enemy(candidates: Array, weights: Array[float]) -> EnemyData:
	var total := 0.0
	for weight in weights:
		total += maxf(0.0, weight)
	if total <= 0.0 or candidates.is_empty():
		return null
	var roll := randf() * total
	for i in candidates.size():
		roll -= maxf(0.0, weights[i])
		if roll <= 0.0:
			return candidates[i] as EnemyData
	return candidates.back() as EnemyData
