class_name CardMutation
extends RefCounted
## 永久配方与重铸事务。只在完整存档成功后发布新状态。

static var storage_path := "user://profile.json"

static func config() -> Dictionary:
	return GameData.meta_progression.get("card_mutation", {})

static func directions(card_id: String) -> Array:
	return config().get("card_directions", {}).get(card_id, [])

static func unlocked() -> bool:
	return ProfileState.completed_project_ids.has(StringName(config().get("required_project", "")))

static func research_error(card_id: String) -> String:
	if not unlocked(): return "领取药釉研究 I 后开放窑变。"
	if directions(card_id).is_empty(): return "这张牌未开放窑变。"
	if not GameData.is_card_unlocked(StringName(card_id)): return "请先完成这张牌的配方研究。"
	if not ProfileState.is_card_discovered(StringName(card_id)): return "请先在冒险中获得这张牌。"
	var current := pattern(card_id)
	if current != "" and not directions(card_id).has(current): return "原配方暂不可用，已保留记录。"
	return ""

static func pattern(card_id: String) -> String:
	return String(ProfileState.mutation_data.get("patterns", {}).get(card_id, ""))

static func price(card_id: String) -> int:
	return int(config()["initial_cost" if pattern(card_id) == "" else "reroll_cost"])

static func revision() -> int:
	return int(ProfileState.mutation_data.get("revision", 0))

static func pending() -> Dictionary:
	return ProfileState.mutation_data.get("pending", {})

static func begin(card_id: String, expected_revision: int) -> String:
	var error := research_error(card_id)
	if error != "": return error
	if not pending().is_empty(): return "请先处理上一炉结果。"
	if revision() != expected_revision: return "配方已变化，请重新查看。"
	var cost := price(card_id)
	if ProfileState.fireseed_balance < cost: return "火种不足。"
	var pool := directions(card_id).duplicate()
	pool.erase(pattern(card_id))
	if pool.is_empty(): return "没有其他可用方向。"
	var rng := RandomNumberGenerator.new()
	var state_text := String(ProfileState.mutation_data.get("rng_state", ""))
	if state_text == "": rng.randomize()
	else: rng.state = int(state_text)
	var result_id := String(pool[rng.randi_range(0, pool.size() - 1)])
	var next := ProfileState.to_save_dict()
	var mutation: Dictionary = next["mutation_data"]
	mutation["rng_state"] = str(rng.state)
	mutation["revision"] = expected_revision + 1
	mutation["pending"] = {"card_id": card_id, "old_id": pattern(card_id), "new_id": result_id, "revision": expected_revision + 1}
	# 首次附魔立即拥有结果；pending 仍保留演出/确认收据，强退不丢失。
	if pattern(card_id) == "":
		if not mutation.has("patterns"): mutation["patterns"] = {}
		mutation["patterns"][card_id] = result_id
	next["fireseed_balance"] = ProfileState.fireseed_balance - cost
	return "" if _commit(next) else "存档失败，未扣火种。请重试。"

static func resolve(accept: bool, expected_revision: int) -> String:
	var receipt := pending()
	if receipt.is_empty() or int(receipt.get("revision", -1)) != expected_revision:
		return "本炉结果已经处理。"
	var cid := String(receipt.get("card_id", ""))
	var eid := String(receipt.get("new_id", ""))
	if not directions(cid).has(eid): return "结果资料暂不可用，记录已保留。"
	var next := ProfileState.to_save_dict()
	if accept: next["mutation_data"]["patterns"][cid] = eid
	next["mutation_data"]["pending"] = {}
	return "" if _commit(next) else "保存失败，原结果仍在。请重试。"

static func _commit(next: Dictionary) -> bool:
	if ProfileState._normalize_save_dict(next, false).is_empty(): return false
	if not ProfileManager.save_to_file(storage_path, next): return false
	if not ProfileState.from_save_dict(next, false): return false
	var old_autosave := ProfileManager.autosave_enabled
	ProfileManager.autosave_enabled = false
	SignalBus.fireseed_changed.emit(ProfileState.fireseed_balance)
	SignalBus.profile_changed.emit()
	ProfileManager.autosave_enabled = old_autosave
	return true

static func valid_patterns(source: Dictionary) -> Dictionary:
	var result := {}
	for cid in source:
		if directions(String(cid)).has(source[cid]): result[String(cid)] = String(source[cid])
	return result

static func preview(entry: Dictionary) -> Dictionary:
	var result := entry.duplicate(true)
	if not result.get("enchants", []).is_empty() or result.has("instance_id") or result.has("enchant_active"): return result
	var eid := String(RunState.mutation_patterns_snapshot.get(String(entry.get("id", "")), ""))
	result["enchants"] = [eid] if eid != "" else []
	if eid != "": result["enchant_preview"] = true
	return result

static func is_active(entry: Dictionary) -> bool:
	if entry.has("enchant_active"): return bool(entry["enchant_active"])
	if entry.has("enchant_preview"): return true
	return RunState.selected_enchant_instance_ids.has(String(entry.get("instance_id", "")))

static func effective_ids(entry: Dictionary) -> Array:
	return entry.get("enchants", []) if is_active(entry) else []

static func town_enchant(entry: Dictionary) -> EnchantData:
	for eid in effective_ids(entry):
		var data := GameData.get_enchant(StringName(eid))
		if data != null and data.acquisition_scope == "town_only": return data
	return null

static func note(entry: Dictionary) -> String:
	var parts: Array[String] = []
	for eid in entry.get("enchants", []):
		var data := GameData.get_enchant(StringName(eid))
		if data == null: continue
		var state := "领取后附魔 · 配印后生效" if entry.get("enchant_preview", false) else ("附魔生效" if is_active(entry) else "附魔待命")
		parts.append("%s · %s\n%s" % [state, data.name, data.description])
	return "\n".join(parts)

static func strip_copy(entry: Dictionary) -> Dictionary:
	var copy := entry.duplicate(true)
	copy["enchants"] = []
	copy["enchant_active"] = false
	for key in ["instance_id", "enchant_origin", "_x_spent", "_active_card_id", "_mutation_exhausted"]:
		copy.erase(key)
	return copy

static func summary(cd: CardData, entry: Dictionary) -> String:
	var level := maxi(int(entry.get("upgrade_level", 1 if entry.get("upgraded", false) else 0)), int(entry.get("combat_upgrade_level", 0)))
	var text := cd.get_description(level)
	var ed := town_enchant(entry)
	if ed == null: return text
	if ed.mods.get("remove_ethereal", false): text = text.replace("虚无。", "").replace("虚无，", "")
	# 原说明保留；额外列出可直接比较的修改后基础值，状态加成另计。
	var effects := cd.get_effects(level).duplicate(true)
	ed.apply_value_mods(effects)
	var values: Array[String] = []
	for index in effects.size():
		var eff: Dictionary = effects[index]
		if index >= cd.get_effects(level).size() or eff == cd.get_effects(level)[index]: continue
		var title: String = {"damage":"伤害", "aoe_damage":"群体伤害", "block":"格挡", "heal_unblocked_aoe":"吸血群伤", "exhaust_hand_damage":"每张消耗牌伤害", "power_start_turn_strength":"每回合力量", "power_on_block_damage":"格挡触发伤害", "temporary_thorns":"本回合反伤"}.get(String(eff.get("kind", "")), "")
		if String(eff.get("kind", "")) == "apply_status":
			var status := GameData.get_status(StringName(eff.get("status", "")))
			if status != null: title = status.name
		if title != "": values.append("%s %d" % [title, int(eff.get("value", 0))])
	if not values.is_empty(): text += "\n附魔后基础值：" + "；".join(values)
	return text

static func confirm_run_replace(owner_node: Node, index: int, enchant_id: StringName, callback: Callable) -> void:
	if index < 0 or index >= RunState.deck.size(): return
	var entry: Dictionary = RunState.deck[index].duplicate(true)
	if entry.get("enchants", []).is_empty():
		callback.call()
		return
	var ed := GameData.get_enchant(enchant_id)
	if ed == null: return
	var browser = load("res://scripts/ui/CardBrowser.gd").new()
	browser.setup("替换本局附魔", "仅替换此副本；镇中永久配方保持不变。", [entry], true,
		"确认替换", "新附魔 · %s\n%s" % [ed.name, ed.description], "此副本的原附魔将被替换，仍占用原配印资格；原来的待命牌仍需配印。")
	browser.confirmed.connect(func(_selected: int, _snapshot: Dictionary):
		if index < RunState.deck.size() and RunState.deck[index] == entry: callback.call())
	owner_node.add_child(browser)
