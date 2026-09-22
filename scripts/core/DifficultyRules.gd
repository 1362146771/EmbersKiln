class_name DifficultyRules
extends RefCounted
## 只读规则与永久通关记录；每局使用开局快照，不修改共享敌人资源。

static func tiers() -> Array:
	return GameData.difficulties.get("tiers", [])

static func default_id() -> String:
	return String(GameData.difficulties.get("default_id", "normal"))

static func tier(id: String) -> Dictionary:
	for item in tiers():
		if String(item.id) == id: return item
	return {}

static func unlocked(id: String) -> bool:
	var list := tiers()
	for i in list.size():
		if String(list[i].id) == id:
			return i == 0 or ProfileState.difficulty_data.get("cleared", []).has(String(list[i - 1].id))
	return false

static func valid_profile(value: Variant) -> bool:
	if not value is Dictionary: return false
	if not value.get("hidden_unlocked", false) is bool: return false
	for key in ["cleared", "hidden_cleared"]:
		if not value.get(key, []) is Array: return false
		for id in value.get(key, []):
			if not id is String: return false
	return true

static func record_clear(hidden: bool = false) -> bool:
	var before: Dictionary = ProfileState.difficulty_data.duplicate(true)
	var id := String(RunState.difficulty_snapshot.get("id", default_id()))
	var field := "hidden_cleared" if hidden else "cleared"
	var records: Array = ProfileState.difficulty_data.get(field, []).duplicate()
	if not records.has(id): records.append(id)
	ProfileState.difficulty_data[field] = records
	if not hidden and id == String(GameData.difficulties.get("hidden_unlock_id", "")):
		ProfileState.difficulty_data["hidden_unlocked"] = true
	if ProfileManager.autosave_enabled and not ProfileManager.save_profile():
		ProfileState.difficulty_data = before
		return false
	SignalBus.profile_changed.emit()
	return true

static func current_name() -> String:
	return String(RunState.difficulty_snapshot.get("name", tier(default_id()).get("name", "普通")))

static func can_select_at_opening() -> bool:
	return GrannyStory.needs_opening() and not RunState.difficulty_snapshot.is_empty()

static func select_at_opening(id: String) -> bool:
	if not can_select_at_opening() or not unlocked(id): return false
	var previous: Dictionary = RunState.difficulty_snapshot.duplicate(true)
	RunState.difficulty_snapshot = tier(id).duplicate(true)
	RunState.difficulty_snapshot["version"] = GameData.difficulties.get("version")
	if SaveManager.save_game(): return true
	RunState.difficulty_snapshot = previous
	return false

static func attack_bonus(tier_id: StringName, intent: Dictionary) -> int:
	if not RunState.is_active or int(intent.get("times", 1)) != 1: return 0
	if not String(intent.get("intent", "")) in ["attack", "aoe_debuff"]: return 0
	if int(intent.get("value", 0)) <= 0: return 0
	return int(RunState.difficulty_snapshot.get("single_hit_bonus", {}).get(String(tier_id), 0))

static func rest_percent() -> float:
	return float(RunState.difficulty_snapshot.get("rest_heal_percent", GameData.balance.get("rest", {}).get("heal_percent", 0.0)))
