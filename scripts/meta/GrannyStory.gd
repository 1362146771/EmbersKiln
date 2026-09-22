extends Node
## 每局开场馈赠。候选、代价与领取收据跟随单局存档，旧的镇内话题不再播放。
const UpgradePicker := preload("res://scripts/ui/CardUpgradePicker.gd")
var _claiming := false


func _ready() -> void:
	SignalBus.run_ended.connect(_on_run_ended)


func _on_run_ended(won: bool) -> void:
	if RunState.run_id.is_empty(): return
	ProfileState.narrative_data["last_run"] = RunState.run_id
	ProfileState.narrative_data["last_outcome"] = "won" if won else "failed"
	SignalBus.profile_changed.emit()


func at_start() -> bool:
	return RunState.is_active and RunState.current_act == 0 and RunState.current_floor == 0 and not RunState.has_combat_checkpoint() and RunState.resolved_floor_keys.is_empty()


func needs_opening() -> bool:
	return at_start() and not bool(RunState.granny_opening.get("resolved", false))


func chosen() -> bool:
	return not String(RunState.granny_opening.get("chosen", "")).is_empty()


func prepare() -> bool:
	if not needs_opening(): return true
	if not RunState.granny_opening.get("offers", []).is_empty(): return true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(RunState.run_id + ":granny")
	var offers: Array = []
	for group in GameData.granny_opening.get("groups", []):
		var pool: Array = []
		for definition in GameData.granny_opening.get("rewards", []):
			if definition.get("group", "") != group["id"]: continue
			var offer := _materialize(definition, rng)
			if not offer.is_empty(): pool.append(offer)
		for i in mini(int(group["count"]), pool.size()):
			var index := rng.randi_range(0, pool.size() - 1)
			offers.append(pool.pop_at(index))
	if offers.is_empty(): return false
	var previous := RunState.granny_opening.duplicate(true)
	var lines: Array = GameData.granny_opening.get("greetings", {}).get(String(ProfileState.narrative_data.get("last_outcome", "")), [])
	if lines.is_empty(): lines = GameData.granny_opening.get("greetings", {}).get("default", [])
	RunState.granny_opening = {"offers": offers, "line": String(lines[rng.randi_range(0, lines.size() - 1)]) if not lines.is_empty() else "选一样带上，路上用得着。"}
	if SaveManager.save_game(): return true
	RunState.granny_opening = previous
	return false


func _materialize(definition: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var offer := definition.duplicate(true)
	var kind := String(offer.get("kind", ""))
	var pool: Array = []
	if kind in ["card", "transform"]:
		for card in GameData.cards.values():
			if card.rarity in [&"starter", &"special"] or not GameData.is_card_unlocked(card.id): continue
			if not String(offer.get("rarity", "")).is_empty() and String(card.rarity) != offer["rarity"]: continue
			pool.append(String(card.id))
		if pool.is_empty(): return {}
		offer["card_id"] = pool[rng.randi_range(0, pool.size() - 1)]
	elif kind == "relic":
		for relic in GameData.relics.values():
			if String(relic.rarity) == offer["rarity"] and GameData.is_relic_unlocked(relic.id) and not RunState.relic_ids.has(relic.id): pool.append(String(relic.id))
		if pool.is_empty(): return {}
		offer["relic_id"] = pool[rng.randi_range(0, pool.size() - 1)]
	elif kind == "potions":
		for potion in GameData.potions.values():
			if GameData.is_potion_unlocked(potion.id): pool.append(String(potion.id))
		if pool.is_empty(): return {}
		offer["potion_ids"] = []
		for i in int(offer["amount"]): offer["potion_ids"].append(pool[rng.randi_range(0, pool.size() - 1)])
	return offer


func offer_for(id: String) -> Dictionary:
	for offer in RunState.granny_opening.get("offers", []):
		if offer.get("id", "") == id: return offer
	return {}


func describe(offer: Dictionary) -> String:
	# Opening rewards show only their type, quantity and cost, never the rolled contents.
	return String(offer.get("description", ""))


func blocked_reason(offer: Dictionary) -> String:
	if not needs_opening() or chosen() or _claiming: return "本局馈赠已领取"
	if offer.is_empty(): return "奖励不存在"
	if RunState.hp <= int(offer.get("lose_hp", 0)) or RunState.max_hp <= int(offer.get("lose_max_hp", 0)): return "生命不足以承担代价"
	match String(offer.get("kind", "")):
		"card":
			if not RunState.can_add_permanent_card(): return "牌库容量不足"
		"potions":
			if RunState.potions.size() + offer.get("potion_ids", []).size() > int(GameData.balance.get("potions", {}).get("max_carry", 0)): return "药水栏空间不足"
		"remove":
			if not RunState.can_remove_card(): return "牌组已达最低保留数量"
		"upgrade":
			if not RunState.deck.any(UpgradePicker.can_upgrade): return "没有可升级的卡牌"
	return ""


func claim(id: String, target_index: int = -1, snapshot: Dictionary = {}) -> bool:
	var offer := offer_for(id)
	if not blocked_reason(offer).is_empty(): return false
	var kind := String(offer["kind"])
	if kind in ["upgrade", "remove", "transform"]:
		if target_index < 0 or target_index >= RunState.deck.size() or RunState.deck[target_index] != snapshot: return false
	var old_run := RunState.to_save_dict()
	var old_profile := ProfileState.to_save_dict()
	var autosave := ProfileManager.autosave_enabled
	ProfileManager.autosave_enabled = false
	_claiming = true
	SignalBus.sound_batch_muted.emit(true)
	# Lock before inventory signals; the receipt is persisted with the actual reward.
	RunState.granny_opening["chosen"] = id
	var success := true
	match kind:
		"gold": RunState.add_gold(int(offer["amount"]))
		"max_hp": RunState.increase_max_hp(int(offer["amount"]))
		"card": success = RunState.add_card(StringName(offer["card_id"]))
		"relic": success = RunState.add_relic(StringName(offer["relic_id"]))
		"potions":
			for potion_id in offer["potion_ids"]:
				if not RunState.add_potion(StringName(potion_id)): success = false
		"upgrade": success = RunState.upgrade_card_at(target_index)
		"remove": success = RunState.try_remove_card(target_index, RunState.deck[target_index], 0)
		"transform":
			RunState.deck[target_index] = RunState._new_card_entry(StringName(offer["card_id"]))
			RunState.normalize_enchant_selection()
			ProfileState.discover_card(StringName(offer["card_id"]))
			SignalBus.deck_changed.emit()
		_: success = false
	if success:
		RunState.granny_opening["result_text"] = describe(offer)
		RunState.max_hp -= int(offer.get("lose_max_hp", 0))
		RunState.hp = mini(RunState.hp, RunState.max_hp) - int(offer.get("lose_hp", 0))
		SignalBus.player_hp_changed.emit(RunState.hp, RunState.max_hp)
		success = SaveManager.save_game()
	if not success:
		RunState.from_save_dict(old_run)
		ProfileState.from_save_dict(old_profile, false)
	ProfileManager.autosave_enabled = autosave
	_claiming = false
	SignalBus.sound_batch_muted.emit(false)
	if success: SignalBus.sound_requested.emit(&"granny_blessing")
	if success: SignalBus.profile_changed.emit()
	return success


func finish() -> bool:
	if not needs_opening(): return RunState.is_active
	if not chosen(): return false
	RunState.granny_opening["resolved"] = true
	if SaveManager.save_game(): return true
	RunState.granny_opening.erase("resolved")
	return false
