extends Node
## Autoload: ProfileState —— 跨 Run 的永久玩家档案。
## 只保存长期状态；当前 Run 的牌组、HP、地图等仍归 RunState。

const PROFILE_VERSION := 7
const SUPPORTED_PROFILE_VERSIONS := [1, 2, 3, 4, 5, 6, 7]

var mutation_data: Dictionary = {}

var first_battle_started := false

var fireseed_balance: int = 0
var facility_levels: Dictionary = {}
var completed_project_ids: Array[StringName] = []
var unlocked_card_ids: Array[StringName] = []
var discovered_card_ids: Array[StringName] = []
var unlocked_relic_ids: Array[StringName] = []
var unlocked_potion_ids: Array[StringName] = []
var unlocked_enchant_ids: Array[StringName] = []
var unlocked_pre_run_buff_ids: Array[StringName] = []
var unlocked_loadout_ids: Array[StringName] = []
var construction_queue: Array[Dictionary] = []
var town_visual_stage: int = 0
var base_run_deck_capacity: int = -1
var reward_transaction_ids: Array[String] = []
var pending_reward_transactions: Array[Dictionary] = []
var ad_daily_usage: Dictionary = {}


func reset_to_defaults(emit_changed: bool = true) -> void:
	mutation_data.clear()
	first_battle_started = false
	fireseed_balance = 0
	facility_levels.clear()
	completed_project_ids.clear()
	unlocked_card_ids.clear()
	discovered_card_ids.assign(_starter_card_ids())
	unlocked_relic_ids.clear()
	unlocked_potion_ids.clear()
	unlocked_enchant_ids.clear()
	unlocked_pre_run_buff_ids.clear()
	unlocked_loadout_ids.clear()
	construction_queue.clear()
	town_visual_stage = 0
	base_run_deck_capacity = -1
	reward_transaction_ids.clear()
	pending_reward_transactions.clear()
	ad_daily_usage.clear()
	if emit_changed:
		SignalBus.profile_changed.emit()
		SignalBus.fireseed_changed.emit(fireseed_balance)


func to_save_dict() -> Dictionary:
	return {
		"version": PROFILE_VERSION,
		"mutation_data": mutation_data.duplicate(true),
		"first_battle_started": first_battle_started,
		"fireseed_balance": fireseed_balance,
		"facility_levels": facility_levels.duplicate(true),
		"completed_project_ids": _string_name_array_to_strings(completed_project_ids),
		"unlocked_card_ids": _string_name_array_to_strings(unlocked_card_ids),
		"discovered_card_ids": _string_name_array_to_strings(discovered_card_ids),
		"unlocked_relic_ids": _string_name_array_to_strings(unlocked_relic_ids),
		"unlocked_potion_ids": _string_name_array_to_strings(unlocked_potion_ids),
		"unlocked_enchant_ids": _string_name_array_to_strings(unlocked_enchant_ids),
		"unlocked_pre_run_buff_ids": _string_name_array_to_strings(unlocked_pre_run_buff_ids),
		"unlocked_loadout_ids": _string_name_array_to_strings(unlocked_loadout_ids),
		"construction_queue": construction_queue.duplicate(true),
		"town_visual_stage": town_visual_stage,
		"base_run_deck_capacity": base_run_deck_capacity,
		"reward_transaction_ids": reward_transaction_ids.duplicate(),
		"pending_reward_transactions": pending_reward_transactions.duplicate(true),
		"ad_daily_usage": ad_daily_usage.duplicate(true),
	}


## 先完整校验并构造临时状态，全部合法后才提交，避免坏档污染当前档案。
func from_save_dict(data: Dictionary, emit_changed: bool = true, report_errors: bool = true) -> bool:
	var normalized := _normalize_save_dict(data, report_errors)
	if normalized.is_empty():
		return false

	mutation_data = normalized["mutation_data"]
	first_battle_started = normalized["first_battle_started"]
	fireseed_balance = normalized["fireseed_balance"]
	facility_levels = normalized["facility_levels"]
	completed_project_ids.assign(normalized["completed_project_ids"])
	unlocked_card_ids.assign(normalized["unlocked_card_ids"])
	discovered_card_ids.assign(normalized["discovered_card_ids"])
	unlocked_relic_ids.assign(normalized["unlocked_relic_ids"])
	unlocked_relic_ids = unlocked_relic_ids.filter(func(id): return GameData.get_relic(id) != null)
	unlocked_potion_ids.assign(normalized["unlocked_potion_ids"])
	unlocked_enchant_ids.assign(normalized["unlocked_enchant_ids"])
	unlocked_pre_run_buff_ids.assign(normalized["unlocked_pre_run_buff_ids"])
	unlocked_loadout_ids.assign(normalized["unlocked_loadout_ids"])
	construction_queue.assign(normalized["construction_queue"])
	town_visual_stage = normalized["town_visual_stage"]
	base_run_deck_capacity = normalized["base_run_deck_capacity"]
	reward_transaction_ids.assign(normalized["reward_transaction_ids"])
	pending_reward_transactions.assign(normalized["pending_reward_transactions"])
	ad_daily_usage = normalized["ad_daily_usage"]
	_migrate_card_pool_unlocks()
	_migrate_discovered_cards()

	if emit_changed:
		SignalBus.profile_changed.emit()
		SignalBus.fireseed_changed.emit(fireseed_balance)
	return true


func _migrate_card_pool_unlocks() -> void:
	var migrated: Array[StringName] = []
	for old_id in unlocked_card_ids:
		var card_id := old_id
		if GameData.get_card(card_id) == null:
			card_id = StringName(String(GameData.legacy_card_id_map.get(String(card_id), "")))
		if GameData.get_card(card_id) != null and not migrated.has(card_id):
			migrated.append(card_id)
	# 已完成研究沿用原项目 id，按当前 grants 补发换池后的对应卡牌。
	for project_id in completed_project_ids:
		var project := GameData.get_meta_project(project_id)
		for granted_id in project.get("grants", {}).get("unlocked_card_ids", []):
			var card_id := StringName(String(granted_id))
			if GameData.get_card(card_id) != null and not migrated.has(card_id):
				migrated.append(card_id)
	unlocked_card_ids.assign(migrated)


## 图鉴只记录能永久进入单局牌组的职业牌；生成状态牌不计入收藏进度。
func _migrate_discovered_cards() -> void:
	var migrated: Array[StringName] = []
	for old_id in discovered_card_ids:
		var card_id := _normalized_collectible_card_id(old_id)
		if card_id != &"" and not migrated.has(card_id):
			migrated.append(card_id)
	for starter_id in _starter_card_ids():
		if not migrated.has(starter_id):
			migrated.append(starter_id)
	discovered_card_ids.assign(migrated)


func discover_card(card_id: StringName, emit_changed: bool = true) -> bool:
	var normalized_id := _normalized_collectible_card_id(card_id)
	if normalized_id == &"" or discovered_card_ids.has(normalized_id):
		return false
	discovered_card_ids.append(normalized_id)
	if emit_changed:
		SignalBus.card_discovered.emit(normalized_id)
		SignalBus.profile_changed.emit()
	return true


func discover_cards(card_ids: Array, emit_changed: bool = true) -> int:
	var added: Array[StringName] = []
	for raw_id in card_ids:
		var normalized_id := _normalized_collectible_card_id(StringName(String(raw_id)))
		if normalized_id != &"" and not discovered_card_ids.has(normalized_id):
			discovered_card_ids.append(normalized_id)
			added.append(normalized_id)
	if emit_changed and not added.is_empty():
		for card_id in added:
			SignalBus.card_discovered.emit(card_id)
		SignalBus.profile_changed.emit()
	return added.size()


func is_card_discovered(card_id: StringName) -> bool:
	return discovered_card_ids.has(card_id)


func collectible_card_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for value in GameData.cards.values():
		var card := value as CardData
		if card != null and card.rarity in [&"starter", &"common", &"uncommon", &"rare"]:
			result.append(card.id)
	return result


func discovered_card_count() -> int:
	var count := 0
	for card_id in discovered_card_ids:
		if _normalized_collectible_card_id(card_id) != &"":
			count += 1
	return count


func _normalized_collectible_card_id(card_id: StringName) -> StringName:
	var normalized_id := card_id
	var card := GameData.get_card(normalized_id)
	if card == null:
		normalized_id = StringName(String(GameData.legacy_card_id_map.get(String(card_id), "")))
		card = GameData.get_card(normalized_id)
	if card == null or not card.rarity in [&"starter", &"common", &"uncommon", &"rare"]:
		return &""
	return normalized_id


func _starter_card_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for raw_id in GameData.balance.get("starting_deck", []):
		var card_id := _normalized_collectible_card_id(StringName(String(raw_id)))
		if card_id != &"" and not result.has(card_id):
			result.append(card_id)
	return result


func add_fireseed(amount: int) -> bool:
	if amount <= 0:
		return false
	fireseed_balance += amount
	SignalBus.fireseed_changed.emit(fireseed_balance)
	SignalBus.profile_changed.emit()
	return true


func spend_fireseed(amount: int) -> bool:
	if amount < 0 or fireseed_balance < amount:
		return false
	fireseed_balance -= amount
	SignalBus.fireseed_changed.emit(fireseed_balance)
	SignalBus.profile_changed.emit()
	return true


func set_facility_level(facility_id: StringName, level: int) -> bool:
	if facility_id == &"" or level < 0:
		return false
	facility_levels[String(facility_id)] = level
	SignalBus.profile_changed.emit()
	return true


## 原子提交“扣除火种 + 加入建造队列”。监听者只会在两项状态都完成后收到信号。
func commit_construction_start(
	project_id: StringName,
	cost: int,
	started_at: int,
	finish_at: int,
	queue_capacity: int
) -> bool:
	if project_id == &"" or cost < 0 or started_at < 0 or finish_at < started_at or queue_capacity <= 0:
		return false
	if fireseed_balance < cost or construction_queue.size() >= queue_capacity:
		return false
	if completed_project_ids.has(project_id) or construction_index(project_id) >= 0:
		return false

	fireseed_balance -= cost
	construction_queue.append({
		"project_id": String(project_id),
		"started_at": started_at,
		"finish_at": finish_at,
		"status": "building",
	})
	SignalBus.fireseed_changed.emit(fireseed_balance)
	SignalBus.profile_changed.emit()
	return true


## 将所有自然到时的项目切换为可领取；只在实际发生变化时触发一次存档。
func mark_ready_projects(now_unix: int) -> Array[StringName]:
	var ready_ids: Array[StringName] = []
	if now_unix < 0:
		return ready_ids
	for index in construction_queue.size():
		var entry: Dictionary = construction_queue[index]
		if String(entry.get("status", "building")) != "building":
			continue
		if int(entry.get("finish_at", 0)) > now_unix:
			continue
		entry["status"] = "ready"
		construction_queue[index] = entry
		ready_ids.append(StringName(String(entry.get("project_id", ""))))
	if not ready_ids.is_empty():
		SignalBus.profile_changed.emit()
	return ready_ids


## 原子提交“移出队列 + 永久解锁”。grants 必须先完整合法，才会修改档案。
func commit_construction_claim(project_id: StringName, grants: Dictionary) -> bool:
	var index := construction_index(project_id)
	if index < 0 or completed_project_ids.has(project_id):
		return false
	if String(construction_queue[index].get("status", "building")) != "ready":
		return false
	if not _validate_project_grants(grants):
		return false

	for facility_id in grants.get("facility_levels", {}):
		var level := int(grants["facility_levels"][facility_id])
		facility_levels[String(facility_id)] = maxi(int(facility_levels.get(String(facility_id), 0)), level)
	_append_unique_string_names(unlocked_card_ids, grants.get("unlocked_card_ids", []))
	_append_unique_string_names(unlocked_relic_ids, grants.get("unlocked_relic_ids", []))
	_append_unique_string_names(unlocked_potion_ids, grants.get("unlocked_potion_ids", []))
	_append_unique_string_names(unlocked_enchant_ids, grants.get("unlocked_enchant_ids", []))
	_append_unique_string_names(unlocked_pre_run_buff_ids, grants.get("unlocked_pre_run_buff_ids", []))
	_append_unique_string_names(unlocked_loadout_ids, grants.get("unlocked_loadout_ids", []))
	if grants.get("town_visual_stage", null) != null:
		town_visual_stage = maxi(town_visual_stage, int(grants["town_visual_stage"]))
	if grants.get("base_run_deck_capacity", null) != null:
		base_run_deck_capacity = maxi(base_run_deck_capacity, int(grants["base_run_deck_capacity"]))

	construction_queue.remove_at(index)
	completed_project_ids.append(project_id)
	SignalBus.profile_changed.emit()
	return true


func construction_index(project_id: StringName) -> int:
	for index in construction_queue.size():
		if StringName(String(construction_queue[index].get("project_id", ""))) == project_id:
			return index
	return -1


func _validate_project_grants(grants: Dictionary) -> bool:
	var facility_grants: Variant = grants.get("facility_levels", {})
	if not facility_grants is Dictionary:
		return false
	for facility_id in facility_grants:
		var id_text := String(facility_id).strip_edges()
		var raw_level: Variant = facility_grants[facility_id]
		if id_text.is_empty() or not (raw_level is int or raw_level is float) or int(raw_level) < 0:
			return false
	for field in [
		"unlocked_card_ids",
		"unlocked_relic_ids",
		"unlocked_potion_ids",
		"unlocked_enchant_ids",
		"unlocked_pre_run_buff_ids",
		"unlocked_loadout_ids",
	]:
		var values: Variant = grants.get(field, [])
		if not values is Array:
			return false
		for value in values:
			if String(value).strip_edges().is_empty():
				return false
	var raw_stage: Variant = grants.get("town_visual_stage", null)
	if raw_stage != null and (not (raw_stage is int or raw_stage is float) or int(raw_stage) < 0):
		return false
	var raw_capacity: Variant = grants.get("base_run_deck_capacity", null)
	return raw_capacity == null or ((raw_capacity is int or raw_capacity is float) and int(raw_capacity) > 0)


func _append_unique_string_names(target: Array[StringName], values: Array) -> void:
	for value in values:
		var id := StringName(String(value).strip_edges())
		if id != &"" and not target.has(id):
			target.append(id)


func record_reward_transaction(transaction_id: String) -> bool:
	var clean_id := transaction_id.strip_edges()
	if clean_id.is_empty() or reward_transaction_ids.has(clean_id):
		return false
	var pending_index := pending_reward_transaction_index(clean_id)
	if pending_index >= 0:
		pending_reward_transactions.remove_at(pending_index)
	reward_transaction_ids.append(clean_id)
	SignalBus.profile_changed.emit()
	return true


func has_reward_transaction(transaction_id: String) -> bool:
	return reward_transaction_ids.has(transaction_id.strip_edges())


## 广告完成后先持久化待发事务，奖励处理器随后以 transaction_id 幂等结算。
func begin_reward_transaction(transaction_id: String, placement_id: StringName, context: Dictionary) -> bool:
	var clean_id := transaction_id.strip_edges()
	if clean_id.is_empty() or placement_id == &"" or has_reward_transaction(clean_id) or pending_reward_transaction_index(clean_id) >= 0:
		return false
	pending_reward_transactions.append({
		"transaction_id": clean_id,
		"placement_id": String(placement_id),
		"context": context.duplicate(true),
	})
	SignalBus.profile_changed.emit()
	return true


func complete_reward_transaction(transaction_id: String) -> bool:
	var clean_id := transaction_id.strip_edges()
	var index := pending_reward_transaction_index(clean_id)
	if clean_id.is_empty() or has_reward_transaction(clean_id) or index < 0:
		return false
	pending_reward_transactions.remove_at(index)
	reward_transaction_ids.append(clean_id)
	SignalBus.profile_changed.emit()
	return true


## 火种奖励与事务完成一次提交；基础结算可不要求 pending，广告加成必须要求。
func commit_fireseed_reward(transaction_id: String, amount: int, require_pending: bool = false) -> bool:
	var clean_id := transaction_id.strip_edges()
	var pending_index := pending_reward_transaction_index(clean_id)
	if clean_id.is_empty() or amount < 0 or has_reward_transaction(clean_id):
		return false
	if require_pending and pending_index < 0:
		return false
	if pending_index >= 0:
		pending_reward_transactions.remove_at(pending_index)
	fireseed_balance += amount
	reward_transaction_ids.append(clean_id)
	SignalBus.fireseed_changed.emit(fireseed_balance)
	SignalBus.profile_changed.emit()
	return true


## 工坊减时、次数、每日计数与广告事务完成一次提交。
func commit_workshop_speedup(
	transaction_id: String,
	project_id: StringName,
	seconds_reduced: int,
	max_per_project: int,
	day_key: String,
	max_per_day: int,
	now_unix: int
) -> bool:
	var clean_id := transaction_id.strip_edges()
	var clean_day := day_key.strip_edges()
	var pending_index := pending_reward_transaction_index(clean_id)
	var queue_index := construction_index(project_id)
	if clean_id.is_empty() or clean_day.is_empty() or pending_index < 0 or queue_index < 0:
		return false
	if seconds_reduced <= 0 or max_per_project <= 0 or max_per_day <= 0 or now_unix < 0:
		return false
	if has_reward_transaction(clean_id):
		return false
	var entry: Dictionary = construction_queue[queue_index]
	if String(entry.get("status", "building")) != "building" or int(entry.get("finish_at", 0)) <= now_unix:
		return false
	var project_uses := int(entry.get("ad_speedup_count", 0))
	var usage_key := "workshop_speedup:%s" % clean_day
	var daily_uses := int(ad_daily_usage.get(usage_key, 0))
	if project_uses >= max_per_project or daily_uses >= max_per_day:
		return false

	entry["finish_at"] = maxi(now_unix, int(entry["finish_at"]) - seconds_reduced)
	entry["ad_speedup_count"] = project_uses + 1
	if int(entry["finish_at"]) <= now_unix:
		entry["status"] = "ready"
	construction_queue[queue_index] = entry
	ad_daily_usage[usage_key] = daily_uses + 1
	pending_reward_transactions.remove_at(pending_index)
	reward_transaction_ids.append(clean_id)
	SignalBus.profile_changed.emit()
	if String(entry.get("status", "")) == "ready":
		SignalBus.construction_ready.emit(project_id)
	return true


func daily_ad_usage(placement_id: StringName, day_key: String) -> int:
	return int(ad_daily_usage.get("%s:%s" % [String(placement_id), day_key.strip_edges()], 0))


func pending_reward_transaction_index(transaction_id: String) -> int:
	var clean_id := transaction_id.strip_edges()
	for index in pending_reward_transactions.size():
		if String(pending_reward_transactions[index].get("transaction_id", "")) == clean_id:
			return index
	return -1


func has_pending_reward_transaction(transaction_id: String) -> bool:
	return pending_reward_transaction_index(transaction_id) >= 0


func _normalize_save_dict(data: Dictionary, report_errors: bool = true) -> Dictionary:
	var source_version := int(data.get("version", -1))
	if not SUPPORTED_PROFILE_VERSIONS.has(source_version):
		if report_errors:
			push_error("[ProfileState] 不支持的档案版本：%d" % source_version)
		return {}
	if not _has_expected_container_types(data):
		if report_errors:
			push_error("[ProfileState] 档案字段类型无效")
		return {}
	if not _has_expected_scalar_types(data):
		if report_errors:
			push_error("[ProfileState] 档案数值字段类型无效")
		return {}

	var normalized_balance := int(data.get("fireseed_balance", 0))
	var normalized_stage := int(data.get("town_visual_stage", 0))
	var normalized_capacity := int(data.get("base_run_deck_capacity", -1))
	if normalized_balance < 0 or normalized_stage < 0 or normalized_capacity < -1:
		if report_errors:
			push_error("[ProfileState] 档案含负数状态")
		return {}

	var source_levels: Dictionary = data.get("facility_levels", {})
	var normalized_levels: Dictionary = {}
	for key in source_levels:
		var key_text := String(key).strip_edges()
		var raw_level: Variant = source_levels[key]
		if key_text.is_empty() or not (raw_level is int or raw_level is float) or int(raw_level) < 0:
			if report_errors:
				push_error("[ProfileState] 设施等级无效：%s" % key)
			return {}
		normalized_levels[key_text] = int(raw_level)

	var normalized_queue: Array[Dictionary] = []
	for entry in data.get("construction_queue", []):
		if not (entry is Dictionary):
			if report_errors:
				push_error("[ProfileState] 建造队列含非法条目")
			return {}
		var normalized_entry: Dictionary = entry.duplicate(true)
		var project_id := String(normalized_entry.get("project_id", "")).strip_edges()
		if project_id.is_empty():
			if report_errors:
				push_error("[ProfileState] 建造队列项目缺少 project_id")
			return {}
		normalized_entry["project_id"] = project_id
		for time_field in ["started_at", "finish_at"]:
			if normalized_entry.has(time_field):
				if not (normalized_entry[time_field] is int or normalized_entry[time_field] is float):
					if report_errors:
						push_error("[ProfileState] 建造队列时间字段类型无效：%s" % time_field)
					return {}
				var normalized_time := int(normalized_entry[time_field])
				if normalized_time < 0:
					if report_errors:
						push_error("[ProfileState] 建造队列时间无效：%s" % time_field)
					return {}
				normalized_entry[time_field] = normalized_time
		var speedup_count: Variant = normalized_entry.get("ad_speedup_count", 0)
		if not (speedup_count is int or speedup_count is float) or int(speedup_count) < 0:
			if report_errors:
				push_error("[ProfileState] 工坊广告加速次数无效")
			return {}
		normalized_entry["ad_speedup_count"] = int(speedup_count)
		normalized_queue.append(normalized_entry)

	var source_daily_usage: Dictionary = data.get("ad_daily_usage", {})
	var normalized_daily_usage: Dictionary = {}
	for key in source_daily_usage:
		var clean_key := String(key).strip_edges()
		var count: Variant = source_daily_usage[key]
		if clean_key.is_empty() or not (count is int or count is float) or int(count) < 0:
			if report_errors:
				push_error("[ProfileState] 广告每日计数无效：%s" % key)
			return {}
		normalized_daily_usage[clean_key] = int(count)

	var normalized_completed_transactions := _normalize_string_array(data.get("reward_transaction_ids", []))
	var normalized_pending_transactions: Array[Dictionary] = []
	var pending_ids: Dictionary = {}
	for entry in data.get("pending_reward_transactions", []):
		if not entry is Dictionary:
			if report_errors:
				push_error("[ProfileState] 待发奖励事务含非法条目")
			return {}
		var transaction_id := String(entry.get("transaction_id", "")).strip_edges()
		var placement_id := String(entry.get("placement_id", "")).strip_edges()
		var context: Variant = entry.get("context", {})
		if transaction_id.is_empty() or placement_id.is_empty() or not context is Dictionary:
			if report_errors:
				push_error("[ProfileState] 待发奖励事务字段无效")
			return {}
		if pending_ids.has(transaction_id) or normalized_completed_transactions.has(transaction_id):
			if report_errors:
				push_error("[ProfileState] 奖励事务 id 重复：%s" % transaction_id)
			return {}
		pending_ids[transaction_id] = true
		normalized_pending_transactions.append({
			"transaction_id": transaction_id,
			"placement_id": placement_id,
			"context": context.duplicate(true),
		})

	return {
		"mutation_data": data.get("mutation_data", {}).duplicate(true),
		"first_battle_started": bool(data.get("first_battle_started", source_version < 6)),
		"fireseed_balance": normalized_balance,
		"facility_levels": normalized_levels,
		"completed_project_ids": _normalize_string_name_array(data.get("completed_project_ids", [])),
		"unlocked_card_ids": _normalize_string_name_array(data.get("unlocked_card_ids", [])),
		"discovered_card_ids": _normalize_string_name_array(data.get("discovered_card_ids", [])),
		"unlocked_relic_ids": _normalize_string_name_array(data.get("unlocked_relic_ids", [])),
		"unlocked_potion_ids": _normalize_string_name_array(data.get("unlocked_potion_ids", [])),
		"unlocked_enchant_ids": _normalize_string_name_array(data.get("unlocked_enchant_ids", [])),
		"unlocked_pre_run_buff_ids": _normalize_string_name_array(data.get("unlocked_pre_run_buff_ids", [])),
		"unlocked_loadout_ids": _normalize_string_name_array(data.get("unlocked_loadout_ids", [])),
		"construction_queue": normalized_queue,
		"town_visual_stage": normalized_stage,
		"base_run_deck_capacity": normalized_capacity,
		"reward_transaction_ids": normalized_completed_transactions,
		"pending_reward_transactions": normalized_pending_transactions,
		"ad_daily_usage": normalized_daily_usage,
	}


func _has_expected_container_types(data: Dictionary) -> bool:
	var mutation: Variant = data.get("mutation_data", {})
	if not mutation is Dictionary: return false
	if not mutation.get("patterns", {}) is Dictionary or not mutation.get("pending", {}) is Dictionary: return false
	for cid in mutation.get("patterns", {}):
		if not cid is String or not mutation["patterns"][cid] is String: return false
	if not mutation.get("rng_state", "") is String: return false
	if not (mutation.get("revision", 0) is int or mutation.get("revision", 0) is float): return false
	var receipt: Dictionary = mutation.get("pending", {})
	if not receipt.is_empty():
		for field in ["card_id", "old_id", "new_id"]:
			if not receipt.get(field) is String: return false
		if not (receipt.get("revision") is int or receipt.get("revision") is float): return false
	var array_fields := [
		"completed_project_ids",
		"unlocked_card_ids",
		"discovered_card_ids",
		"unlocked_relic_ids",
		"unlocked_potion_ids",
		"unlocked_enchant_ids",
		"unlocked_pre_run_buff_ids",
		"unlocked_loadout_ids",
		"construction_queue",
		"reward_transaction_ids",
		"pending_reward_transactions",
	]
	if data.has("facility_levels") and not data["facility_levels"] is Dictionary:
		return false
	if data.has("ad_daily_usage") and not data["ad_daily_usage"] is Dictionary:
		return false
	for field in array_fields:
		if data.has(field) and not data[field] is Array:
			return false
	return true


func _has_expected_scalar_types(data: Dictionary) -> bool:
	for field in ["fireseed_balance", "town_visual_stage", "base_run_deck_capacity"]:
		if data.has(field) and not (data[field] is int or data[field] is float):
			return false
	return true


func _normalize_string_name_array(source: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for value in source:
		var id := StringName(String(value).strip_edges())
		if id != &"" and not out.has(id):
			out.append(id)
	return out


func _normalize_string_array(source: Array) -> Array[String]:
	var out: Array[String] = []
	for value in source:
		var text := String(value).strip_edges()
		if not text.is_empty() and not out.has(text):
			out.append(text)
	return out


func _string_name_array_to_strings(source: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for value in source:
		out.append(String(value))
	return out
