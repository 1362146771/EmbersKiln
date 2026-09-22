class_name HiddenActFlow
extends RefCounted
## 第四幕只在常规通关后追加；既有地图、资源与复燃资格全部沿用。

static func is_hidden() -> bool:
	return bool(RunState.hidden_act_state.get("entered", false)) and RunState.current_act >= GameData.act_configs.size()

static func config() -> Dictionary:
	var raw: Dictionary = RunState.hidden_act_state.get("config", {})
	if raw.is_empty(): return {}
	var result: Dictionary = GameData.act_configs.back().duplicate(true)
	result["title"] = raw.title
	result["boss_id"] = raw.boss_id
	result["floor_count"] = raw.nodes.size()
	result["boss_floor"] = raw.nodes.size() - 1
	result["columns"] = 1
	result["transition_heal"] = 0.0
	return result

static func choice_pending() -> bool:
	return RunState.is_active and bool(RunState.hidden_act_state.get("choice_pending", false))

static func record_ordinary_clear() -> bool:
	if not DifficultyRules.record_clear(): return false
	var previous := RunState.hidden_act_state.duplicate(true)
	var was_cleared := RunState.ordinary_cleared
	RunState.ordinary_cleared = true
	if not RunState.hidden_act_state.has("ordinary_reward"):
		RunState.hidden_act_state["ordinary_reward"] = RunEndRewardSystem.preview_base_reward(true)
	RunState.hidden_act_state["choice_pending"] = RunState.hidden_act_state.has("config") and bool(ProfileState.difficulty_data.get("hidden_unlocked", false))
	if SaveManager.save_game(): return true
	RunState.hidden_act_state = previous
	RunState.ordinary_cleared = was_cleared
	return false

static func enter() -> bool:
	if not choice_pending() or not RunState.ordinary_cleared or not bool(ProfileState.difficulty_data.get("hidden_unlocked", false)): return false
	if RunState.current_act != GameData.act_configs.size() - 1: return false
	var previous := RunState.to_save_dict()
	var route: Array = []
	var nodes: Array = RunState.hidden_act_state.config.nodes
	for i in nodes.size():
		var node := MapNode.new()
		node.floor = i
		node.type = StringName(nodes[i].type)
		node.enemy_ids = nodes[i].get("enemy_ids", []).duplicate()
		if i + 1 < nodes.size(): node.links.append(0)
		route.append([node])
	RunState.act_cleared_flags[RunState.current_act] = true
	RunState.act_maps.append(route)
	RunState.act_cleared_flags.append(false)
	RunState.current_act += 1
	RunState.current_floor = 0
	RunState.current_node_type = &""
	RunState.hidden_act_state["entered"] = true
	RunState.hidden_act_state["choice_pending"] = false
	RunState.pending_post_reward = false
	RunState.pending_reward_data.clear()
	if not SaveManager.save_game():
		RunState.from_save_dict(previous)
		return false
	SignalBus.act_changed.emit(RunState.current_act)
	SignalBus.map_generated.emit(RunState.current_map())
	return true

static func record_hidden_clear() -> bool:
	if not is_hidden() or not DifficultyRules.record_clear(true): return false
	RunState.hidden_act_state["cleared"] = true
	return true
