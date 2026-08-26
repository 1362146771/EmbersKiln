class_name EnemyAI
extends RefCounted
## 敌人意图选择。纯取数：根据 EnemyData 的 ai 模式挑出下一手 move。
## weighted_random：按 chance 加权随机。
## scripted_phases：按当前 HP 比例选阶段（hp_threshold 递减），再在阶段内加权。
## 不写死任何数值，全部来自 EnemyData.moves / phases。

static func choose_intent(ed: EnemyData, hp_ratio: float) -> Dictionary:
	if ed == null or ed.moves.is_empty() and ed.phases.is_empty():
		return {}

	if ed.ai == &"scripted_phases" and not ed.phases.is_empty():
		return _choose_from_phases(ed, hp_ratio)
	return _weighted_pick(ed.moves)


static func _choose_from_phases(ed: EnemyData, hp_ratio: float) -> Dictionary:
	# phases 按 hp_threshold 降序；取「最深（阈值最低）且 hp_ratio <= 阈值」的阶段。
	# 注意：不能遇到第一个满足条件的阶段就 break，否则永远落在 phase 0。
	var chosen: Dictionary = ed.phases[0]
	for ph in ed.phases:
		var th := float(ph.get("hp_threshold", 1.0))
		if hp_ratio <= th:
			chosen = ph
	return _weighted_pick(chosen.get("moves", []))


## 返回当前 HP 比例下所处阶段的索引（从 0 起），供阶段切换检测（on_enter 触发）。
static func phase_index_for(ed: EnemyData, hp_ratio: float) -> int:
	if ed.phases.is_empty():
		return 0
	var idx := 0
	for i in ed.phases.size():
		var th := float(ed.phases[i].get("hp_threshold", 1.0))
		if hp_ratio <= th:
			idx = i
	return idx


static func _weighted_pick(moves: Array) -> Dictionary:
	if moves.is_empty():
		return {}
	var total := 0.0
	for m in moves:
		total += float(m.get("chance", 1.0))
	var roll := randf() * total
	var acc := 0.0
	for m in moves:
		acc += float(m.get("chance", 1.0))
		if roll <= acc:
			return m
	return moves[moves.size() - 1]
