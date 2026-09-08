extends Node
## Autoload: RunState —— 单局运行时状态（RuntimeData）。
## 跨场景持有：牌组、HP、金币、遗物、当前层数、多幕地图。
## 铁律：初始值全部来自 GameData.balance，此处不写死数值。

## 牌组条目：{ "id": StringName, "upgraded": bool, "enchants": Array[StringName] }
var deck: Array[Dictionary] = []
## 携带药水（仅战斗中可用，Free Action 消耗）。上限由 balance.potions.max_carry 控制，兜底 3。
var potions: Array[StringName] = []
const POTION_CAP := 3
var relic_ids: Array[StringName] = []

var max_hp: int = 0
var hp: int = 0
var gold: int = 0
var _removing_card := false

var current_floor: int = 0
var current_node_type: StringName = &""
var is_active: bool = false
## 卡牌奖励隐藏稀有补偿；新局初值、增长、重置和上限均来自 balance.card_rewards。
var card_rare_offset: int = 0

## 多幕地图容器：Array[act] -> Array[floor] -> Array[MapNode]
var act_maps: Array = []
var current_act: int = 0
var act_cleared_flags: Array = []      # Array[bool]，每幕是否已通关（Boss 已击败）

## 注：单张 `map` 兼容 getter 已在 P-B 移除；所有调用方改用 `current_map()`。

var victory: bool = false

## 本局已击败的敌人 id（用于奖励与统计）
var defeated: Array[StringName] = []

## 局外商业化相关单局状态；未确认容量以 -1 表示功能未启用，不改变既有玩法。
var run_id := ""
var base_run_deck_capacity: int = -1
var run_ad_deck_capacity_bonus: int = 0
var deck_capacity_ad_uses: int = 0
var pending_card_acquisition: Dictionary = {}
var shop_states: Dictionary = {}
var ad_reward_transaction_ids: Array[String] = []
var run_end_base_fireseed: int = 0
var run_end_ad_bonus_fireseed: int = 0
var run_end_base_settled := false
var pre_run_buff_offer_ids: Array[StringName] = []
var pre_run_buff_id: StringName = &""
var pre_run_buff_remaining_floors: int = 0
var pre_run_buff_claimed := false
var pre_run_preparation_resolved := false
var resolved_floor_keys: Array[String] = []
var combat_checkpoint: Dictionary = {}
var combat_death_pending := false
var revive_used_count: int = 0

## 瞬时字段（不进 to_save_dict，安全）：战斗场景化（P1）的跨场景传参。
## combat（overlay 模式已废弃，战斗改为独立场景切换）：
var pending_combat_enemy_ids: Array = []   # 进入战斗前由 MapUI 写入，CombatUI 读取
var last_combat_victory: bool = false       # 战斗结果，回地图后结算用
var pending_post_combat: bool = false       # 标记当前是「战斗结束返回地图」，MapPlay._ready 据此走结算分支

## 子屏场景化（P2）瞬时字段：非战斗节点 / 奖励界面完成后经 RunState 通知地图重建。
var pending_node_resolved: bool = false    # 非战斗节点（休/店/宝/事/坛）完成，回地图弹「行动完成」面板
var pending_post_reward: bool = false       # 奖励界面完成，回地图走 _on_reward_done（幕转场/通关/继续）
var pending_reward_data: Dictionary = {}   # 奖励数据，由 _grant_reward 写入、RewardUI._ready 读取


func _ready() -> void:
	SignalBus.data_loaded.connect(_on_data_loaded)


func _on_data_loaded() -> void:
	# 数据就绪后不自动开局；由 Main 场景显式调用 start_new_run()。
	pass


func start_new_run() -> bool:
	if not GameData.is_loaded:
		push_error("[RunState] GameData 未就绪，无法开局")
		return false

	# 开局装配期间先标记为非活跃：否则上一局残留的 is_active=true 会让
	# generate_acts() 发出的 act_changed(0) 被 SaveManager 误当作幕间推进而落档。
	is_active = false

	var pc: Dictionary = GameData.player_config()
	var progression_bonuses := GameData.profile_run_start_bonuses()
	max_hp = int(pc.get("max_hp", 80)) + int(progression_bonuses.get("max_hp_bonus", 0))
	hp = max_hp
	gold = int(progression_bonuses.get("starting_gold_bonus", 0))
	current_floor = 0
	current_node_type = &""
	card_rare_offset = int(GameData.balance.get("card_rewards", {}).get("rare_pity", {}).get("initial_offset", 0))
	victory = false
	defeated.clear()
	run_id = _new_run_id()
	base_run_deck_capacity = -1
	run_ad_deck_capacity_bonus = 0
	deck_capacity_ad_uses = 0
	pending_card_acquisition.clear()
	shop_states.clear()
	ad_reward_transaction_ids.clear()
	run_end_base_fireseed = 0
	run_end_ad_bonus_fireseed = 0
	run_end_base_settled = false
	pre_run_buff_offer_ids.clear()
	pre_run_buff_id = &""
	pre_run_buff_remaining_floors = 0
	pre_run_buff_claimed = false
	pre_run_preparation_resolved = false
	resolved_floor_keys.clear()
	combat_checkpoint.clear()
	combat_death_pending = false
	revive_used_count = 0
	# 重置战斗/子屏场景化瞬时字段，避免上一局残留污染新局
	pending_combat_enemy_ids.clear()
	last_combat_victory = false
	pending_post_combat = false
	pending_node_resolved = false
	pending_post_reward = false
	pending_reward_data.clear()

	deck.clear()
	potions.clear()
	for cid in GameData.balance.get("starting_deck", []):
		deck.append({"id": StringName(cid), "upgraded": false, "upgrade_level": 0, "enchants": []})
	_record_deck_discoveries()
	base_run_deck_capacity = _resolved_profile_deck_capacity()
	if base_run_deck_capacity >= 0 and base_run_deck_capacity < deck.size():
		push_error("[RunState] 新局基础牌库容量 %d 低于起始牌组 %d" % [base_run_deck_capacity, deck.size()])
		return false

	# 新局不携带遗物；仅保留后续获得与读档恢复机制。
	relic_ids.clear()

	generate_acts()

	is_active = true
	SignalBus.run_started.emit()
	SignalBus.player_hp_changed.emit(hp, max_hp)
	SignalBus.gold_changed.emit(gold)
	SignalBus.deck_changed.emit()
	print("[RunState] 开局 — HP %d/%d，牌组 %d 张，遗物 %d 个" % [hp, max_hp, deck.size(), relic_ids.size()])
	return true


## 依据 GameData.act_configs 生成本局多幕地图并存入 runtime。不写死任何配置。
func generate_acts() -> void:
	if not GameData.is_loaded:
		push_error("[RunState] GameData 未就绪，无法生成多幕地图")
		return
	act_maps.clear()
	act_cleared_flags.clear()
	for cfg in GameData.act_configs:
		act_maps.append(MapGenerator.generate(cfg))
		act_cleared_flags.append(false)
	current_act = 0
	SignalBus.act_changed.emit(current_act)
	SignalBus.map_generated.emit(current_map())
	print("[RunState] 多幕地图生成 — %d 幕，Act1 %d 层" % [act_maps.size(), current_map().size()])


## 幕间推进：标记本幕通关，进入下一幕并按 transition_heal 回血；已是终幕则整局胜利。
func advance_act() -> void:
	if current_act < act_cleared_flags.size():
		act_cleared_flags[current_act] = true
	current_act += 1
	if current_act >= act_maps.size():
		end_run(true)
		return
	var heal_pct: float = float(current_act_config().get("transition_heal", 0.0))
	if heal_pct > 0.0:
		heal(int(round(max_hp * heal_pct)))
	current_floor = 0
	current_node_type = &""
	SignalBus.act_changed.emit(current_act)
	SignalBus.map_generated.emit(current_map())
	print("[RunState] 进入第 %d 幕（%s），HP 恢复至 %d/%d" % [current_act + 1, String(current_act_config().get("title", "")), hp, max_hp])


func end_run(is_victory: bool) -> void:
	is_active = false
	victory = is_victory
	SignalBus.run_ended.emit(is_victory)


# ---------- HP ----------
func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	hp = maxi(0, hp - amount)
	SignalBus.player_hp_changed.emit(hp, max_hp)
	if hp == 0:
		SignalBus.unit_died.emit(true, -1)
		end_run(false)


func heal(amount: int) -> void:
	if amount <= 0:
		return
	hp = mini(max_hp, hp + amount)
	SignalBus.player_hp_changed.emit(hp, max_hp)


func increase_max_hp(amount: int) -> void:
	var gained := maxi(0, amount)
	if gained <= 0:
		return
	max_hp += gained
	hp += gained
	SignalBus.player_hp_changed.emit(hp, max_hp)


# ---------- 金币 ----------
func add_gold(amount: int) -> void:
	var bonus_percent := 0
	for rid in relic_ids:
		var r: RelicData = GameData.get_relic(rid)
		if r != null and r.effect == &"gold_bonus_percent":
			bonus_percent += r.value
	var final_amount := int(round(amount * (1.0 + bonus_percent / 100.0)))
	gold = maxi(0, gold + final_amount)
	SignalBus.gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	SignalBus.gold_changed.emit(gold)
	return true


# ---------- 牌组 ----------
func add_card(card_id: StringName, upgraded: bool = false) -> bool:
	if card_id == &"" or GameData.get_card(card_id) == null or not can_add_permanent_card():
		return false
	deck.append({"id": card_id, "upgraded": upgraded, "upgrade_level":1 if upgraded else 0, "enchants": []})
	ProfileState.discover_card(card_id)
	SignalBus.deck_changed.emit()
	return true


func _record_deck_discoveries() -> void:
	var card_ids: Array = []
	for entry in deck:
		card_ids.append(StringName(String(entry.get("id", ""))))
	ProfileState.discover_cards(card_ids)


func current_deck_capacity() -> int:
	if base_run_deck_capacity < 0:
		return -1
	return base_run_deck_capacity + run_ad_deck_capacity_bonus


func has_deck_capacity_limit() -> bool:
	return current_deck_capacity() >= 0


func can_add_permanent_card() -> bool:
	return not has_deck_capacity_limit() or deck.size() < current_deck_capacity()


func shop_session_id() -> String:
	return "%s:act%d:floor%d" % [run_id, current_act, current_floor]


func has_run_ad_transaction(transaction_id: String) -> bool:
	return ad_reward_transaction_ids.has(transaction_id.strip_edges())


func record_run_ad_transaction(transaction_id: String) -> bool:
	var clean_id := transaction_id.strip_edges()
	if clean_id.is_empty() or ad_reward_transaction_ids.has(clean_id):
		return false
	ad_reward_transaction_ids.append(clean_id)
	return true


func active_pre_run_buff() -> Dictionary:
	if pre_run_buff_id == &"" or pre_run_buff_remaining_floors <= 0:
		return {}
	return GameData.get_pre_run_buff(pre_run_buff_id)


func resolve_current_floor() -> bool:
	if not is_active or current_floor < 0:
		return false
	var key := "%d:%d" % [current_act, current_floor]
	if resolved_floor_keys.has(key):
		return false
	resolved_floor_keys.append(key)
	if pre_run_buff_remaining_floors > 0:
		pre_run_buff_remaining_floors -= 1
	SignalBus.floor_resolved.emit(current_floor, current_node_type)
	return true


func create_combat_checkpoint(enemy_ids: Array) -> bool:
	if not is_active or enemy_ids.is_empty():
		return false
	var checkpoint_deck: Array = []
	for entry in deck:
		checkpoint_deck.append({
			"id": String(entry.get("id", "")),
			"upgraded": bool(entry.get("upgraded", false)),
			"upgrade_level": int(entry.get("upgrade_level", 1 if bool(entry.get("upgraded", false)) else 0)),
			"enchants": entry.get("enchants", []).duplicate(),
		})
	var checkpoint_potions: Array = []
	for potion_id in potions:
		checkpoint_potions.append(String(potion_id))
	var checkpoint_relics: Array = []
	for relic_id in relic_ids:
		checkpoint_relics.append(String(relic_id))
	var checkpoint_defeated: Array = []
	for enemy_id in defeated:
		checkpoint_defeated.append(String(enemy_id))
	var checkpoint_enemies: Array = []
	for enemy_id in enemy_ids:
		checkpoint_enemies.append(String(enemy_id))
	combat_checkpoint = {
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"deck": checkpoint_deck,
		"potions": checkpoint_potions,
		"relic_ids": checkpoint_relics,
		"defeated": checkpoint_defeated,
		"current_act": current_act,
		"current_floor": current_floor,
		"current_node_type": String(current_node_type),
		"enemy_ids": checkpoint_enemies,
		"combat_seed": randi(),
		"pre_run_buff_id": String(pre_run_buff_id),
		"pre_run_buff_remaining_floors": pre_run_buff_remaining_floors,
		"pre_run_buff_claimed": pre_run_buff_claimed,
		"base_run_deck_capacity": base_run_deck_capacity,
		"run_ad_deck_capacity_bonus": run_ad_deck_capacity_bonus,
		"deck_capacity_ad_uses": deck_capacity_ad_uses,
	}
	pending_combat_enemy_ids.assign(enemy_ids)
	combat_death_pending = false
	return true


func has_combat_checkpoint() -> bool:
	return not combat_checkpoint.is_empty() and not combat_checkpoint.get("enemy_ids", []).is_empty()


func combat_seed() -> int:
	return int(combat_checkpoint.get("combat_seed", 0))


func mark_combat_death_pending() -> bool:
	if not is_active or not has_combat_checkpoint() or combat_death_pending:
		return false
	combat_death_pending = true
	return true


func restore_combat_checkpoint() -> bool:
	if not has_combat_checkpoint():
		return false
	var checkpoint := combat_checkpoint
	max_hp = int(checkpoint.get("max_hp", max_hp))
	hp = int(checkpoint.get("hp", hp))
	gold = int(checkpoint.get("gold", gold))
	deck.clear()
	for entry in checkpoint.get("deck", []):
		deck.append({
			"id": StringName(String(entry.get("id", ""))),
			"upgraded": bool(entry.get("upgraded", false)),
			"upgrade_level": int(entry.get("upgrade_level", 1 if bool(entry.get("upgraded", false)) else 0)),
			"enchants": entry.get("enchants", []).duplicate(),
		})
	potions.clear()
	for potion_id in checkpoint.get("potions", []):
		potions.append(StringName(String(potion_id)))
	relic_ids.clear()
	for relic_id in checkpoint.get("relic_ids", []):
		relic_ids.append(StringName(String(relic_id)))
	defeated.clear()
	for enemy_id in checkpoint.get("defeated", []):
		defeated.append(StringName(String(enemy_id)))
	current_act = int(checkpoint.get("current_act", current_act))
	current_floor = int(checkpoint.get("current_floor", current_floor))
	current_node_type = StringName(String(checkpoint.get("current_node_type", current_node_type)))
	pending_combat_enemy_ids.clear()
	for enemy_id in checkpoint.get("enemy_ids", []):
		pending_combat_enemy_ids.append(StringName(String(enemy_id)))
	pre_run_buff_id = StringName(String(checkpoint.get("pre_run_buff_id", pre_run_buff_id)))
	pre_run_buff_remaining_floors = maxi(0, int(checkpoint.get("pre_run_buff_remaining_floors", pre_run_buff_remaining_floors)))
	pre_run_buff_claimed = bool(checkpoint.get("pre_run_buff_claimed", pre_run_buff_claimed))
	base_run_deck_capacity = int(checkpoint.get("base_run_deck_capacity", base_run_deck_capacity))
	run_ad_deck_capacity_bonus = maxi(0, int(checkpoint.get("run_ad_deck_capacity_bonus", run_ad_deck_capacity_bonus)))
	deck_capacity_ad_uses = maxi(0, int(checkpoint.get("deck_capacity_ad_uses", deck_capacity_ad_uses)))
	combat_death_pending = false
	pending_post_combat = false
	last_combat_victory = false
	SignalBus.player_hp_changed.emit(hp, max_hp)
	SignalBus.gold_changed.emit(gold)
	SignalBus.deck_changed.emit()
	return true


func clear_combat_checkpoint() -> void:
	combat_checkpoint.clear()
	combat_death_pending = false


func _resolved_profile_deck_capacity() -> int:
	if ProfileState.base_run_deck_capacity >= 0:
		return ProfileState.base_run_deck_capacity
	var configured: Variant = GameData.meta_progression.get("base_run_deck_capacity", null)
	if configured == null or not (configured is int or configured is float):
		return -1
	return int(configured)


func _new_run_id() -> String:
	return "run:%d:%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]


func remove_card_at(index: int) -> bool:
	if index < 0 or index >= deck.size():
		return false
	deck.remove_at(index)
	SignalBus.deck_changed.emit()
	return true


## 永久移除服务：来源场景提供选中的原实例和费用；一次提交后再发库存信号。
## 防止扣费信号重入或列表变更导致删错同名牌；普通 add/remove API 保持兼容。
func can_remove_card() -> bool:
	return deck.size() > int(GameData.balance["card_removal"]["minimum_remaining"])


func try_remove_card(index: int, expected_entry: Dictionary, cost: int) -> bool:
	if _removing_card or not can_remove_card() or cost < 0 or gold < cost:
		return false
	if index < 0 or index >= deck.size() or not is_same(deck[index], expected_entry):
		return false
	_removing_card = true
	gold -= cost
	deck.remove_at(index)
	# 两个状态都已提交；所有监听者看到的都是一致结果。
	SignalBus.deck_changed.emit()
	if cost > 0:
		SignalBus.gold_changed.emit(gold)
	_removing_card = false
	return true


func upgrade_card_at(index: int) -> bool:
	if index < 0 or index >= deck.size():
		return false
	var entry := deck[index]
	var card: CardData = GameData.get_card(entry["id"])
	var current_level := int(entry.get("upgrade_level", 1 if bool(entry.get("upgraded", false)) else 0))
	if card == null or not card.has_upgrade() or current_level > 0 and not card.repeatable_upgrade:
		return false
	entry["upgraded"] = true
	entry["upgrade_level"] = current_level + 1
	deck[index] = entry
	SignalBus.deck_changed.emit()
	return true


# ---------- 遗物 ----------
func add_relic(relic_id: StringName) -> bool:
	if relic_ids.has(relic_id):
		return false
	relic_ids.append(relic_id)
	SignalBus.relic_gained.emit(relic_id)
	return true


func has_relic(relic_id: StringName) -> bool:
	return relic_ids.has(relic_id)


## 取所有匹配某 trigger 的遗物，供各系统在对应时机调用。
func relics_with_trigger(trigger: StringName) -> Array[RelicData]:
	var out: Array[RelicData] = []
	for rid in relic_ids:
		var r: RelicData = GameData.get_relic(rid)
		if r != null and r.trigger == trigger:
			out.append(r)
	return out


# ---------- 药水库存 ----------
func _potion_cap() -> int:
	return int(GameData.balance.get("potions", {}).get("max_carry", POTION_CAP))

## 获得一瓶药水；背包已满返回 false。
func add_potion(id: StringName) -> bool:
	if potions.size() >= _potion_cap():
		return false
	potions.append(id)
	SignalBus.deck_changed.emit()
	return true

## 消耗并移除第 index 瓶药水，返回其 id（越界返回空）。
func remove_potion_at(index: int) -> StringName:
	if index < 0 or index >= potions.size():
		return &""
	var id: StringName = potions[index]
	potions.remove_at(index)
	SignalBus.deck_changed.emit()
	return id

func has_potion_at(index: int) -> bool:
	return index >= 0 and index < potions.size()


# ---------- 附魔（卡牌第二定制层，单卡 ≤1） ----------
## 该卡能否贴上指定附魔：存在、未满、类型匹配、未重复。
func can_enchant_card_at(index: int, enchant_id: StringName) -> bool:
	if index < 0 or index >= deck.size():
		return false
	var entry: Dictionary = deck[index]
	if entry.get("enchants", []).size() >= 1:
		return false
	var ed: EnchantData = GameData.get_enchant(enchant_id)
	if ed == null:
		return false
	if entry.get("enchants", []).has(enchant_id):
		return false
	var cd: CardData = GameData.get_card(entry["id"])
	if cd == null or not ed.matches_card(cd):
		return false
	return true

## 为牌组第 index 张卡贴上附魔（永久生效）。成功返回 true。
func add_enchant_to_card_at(index: int, enchant_id: StringName) -> bool:
	if not can_enchant_card_at(index, enchant_id):
		return false
	var entry: Dictionary = deck[index]
	var list: Array = entry.get("enchants", [])
	list.append(enchant_id)
	entry["enchants"] = list
	deck[index] = entry
	SignalBus.deck_changed.emit()
	return true


# ---------- 层数 / 幕 ----------
func advance_floor(node_type: StringName) -> void:
	current_floor += 1
	current_node_type = node_type
	SignalBus.floor_entered.emit(current_floor, node_type)


## 当前幕地图
func current_map() -> Array:
	return act_maps[current_act] if current_act < act_maps.size() else []


## 当前幕配置（来自 GameData.act_configs）
func current_act_config() -> Dictionary:
	return GameData.act_configs[current_act] if current_act < GameData.act_configs.size() else {}


## 是否已是最后一幕（仅终幕 Boss 胜利才整局胜利）
func is_last_act() -> bool:
	return current_act >= act_maps.size() - 1


func total_floors() -> int:
	return int(current_act_config().get("floor_count", 10))


func is_boss_floor() -> bool:
	return current_floor >= int(current_act_config().get("boss_floor", total_floors() - 1))


# ---------- 存档（P4 落盘；P-A 升 v2 多幕） ----------
const SAVE_VERSION := 6
const SUPPORTED_SAVE_VERSIONS := [2, 3, 4, 5, 6]

## 将运行态序列化为可 JSON 化的 Dictionary。
## 所有 StringName 必须转 String，否则 JSON.stringify 会丢失类型。
func to_save_dict() -> Dictionary:
	var act_maps_data: Array = []
	for am in act_maps:
		var floor_arrs: Array = []
		for floor_nodes in am:
			var floor_arr: Array = []
			for node in floor_nodes:
				if node is MapNode:
					var eids: Array = []
					for e in node.enemy_ids:
						eids.append(String(e))
					floor_arr.append({
						"floor": node.floor,
						"index": node.index,
						"col": node.col,
						"type": String(node.type),
						"enemy_ids": eids,
						"links": node.links,
						"visited": node.visited,
					})
			floor_arrs.append(floor_arr)
		act_maps_data.append(floor_arrs)

	var deck_data: Array = []
	for c in deck:
		deck_data.append({"id": String(c["id"]), "upgraded": bool(c.get("upgraded", false)), "upgrade_level":int(c.get("upgrade_level", 1 if bool(c.get("upgraded", false)) else 0)), "enchants": c.get("enchants", [])})

	var potion_data: Array = []
	for p in potions:
		potion_data.append(String(p))

	var relic_data: Array = []
	for r in relic_ids:
		relic_data.append(String(r))

	var defeated_data: Array = []
	for d in defeated:
		defeated_data.append(String(d))

	return {
		"version": SAVE_VERSION,
		"deck": deck_data,
		"potions": potion_data,
		"relic_ids": relic_data,
		"max_hp": max_hp,
		"hp": hp,
		"gold": gold,
		"current_floor": current_floor,
		"current_node_type": String(current_node_type),
		"card_rare_offset": card_rare_offset,
		"defeated": defeated_data,
		"victory": victory,
		"is_active": is_active,
		"current_act": current_act,
		"act_cleared_flags": act_cleared_flags,
		"act_maps": act_maps_data,
		"run_id": run_id,
		"base_run_deck_capacity": base_run_deck_capacity,
		"run_ad_deck_capacity_bonus": run_ad_deck_capacity_bonus,
		"deck_capacity_ad_uses": deck_capacity_ad_uses,
		"pending_card_acquisition": pending_card_acquisition.duplicate(true),
		"shop_states": shop_states.duplicate(true),
		"ad_reward_transaction_ids": ad_reward_transaction_ids.duplicate(),
		"run_end_base_fireseed": run_end_base_fireseed,
		"run_end_ad_bonus_fireseed": run_end_ad_bonus_fireseed,
		"run_end_base_settled": run_end_base_settled,
		"pre_run_buff_offer_ids": _string_name_array_to_strings(pre_run_buff_offer_ids),
		"pre_run_buff_id": String(pre_run_buff_id),
		"pre_run_buff_remaining_floors": pre_run_buff_remaining_floors,
		"pre_run_buff_claimed": pre_run_buff_claimed,
		"pre_run_preparation_resolved": pre_run_preparation_resolved,
		"resolved_floor_keys": resolved_floor_keys.duplicate(),
		"combat_checkpoint": combat_checkpoint.duplicate(true),
		"combat_death_pending": combat_death_pending,
		"revive_used_count": revive_used_count,
	}


## 从存档 Dictionary 还原运行态，重建 MapNode 对象并广播信号。
## 接受 v2/v3/v4 并迁移到 v5；v1 旧单幕存档仍由 SaveManager 删除。
func from_save_dict(d: Dictionary) -> bool:
	var source_version := int(d.get("version", -1))
	if not SUPPORTED_SAVE_VERSIONS.has(source_version):
		push_error("[RunState] 不支持的存档版本：%d" % source_version)
		return false

	deck.clear()
	for c in d.get("deck", []):
		var loaded_id := StringName(String(c.get("id", "")))
		if GameData.get_card(loaded_id) == null:
			loaded_id = StringName(String(GameData.legacy_card_id_map.get(String(loaded_id), "")))
		if GameData.get_card(loaded_id) == null:
			continue
		var loaded_level := int(c.get("upgrade_level", 1 if bool(c.get("upgraded", false)) else 0))
		deck.append({"id":loaded_id,"upgraded":loaded_level > 0,"upgrade_level":loaded_level,"enchants":c.get("enchants", [])})
	if deck.is_empty():
		for starter_id in GameData.balance.get("starting_deck", []):
			deck.append({"id":StringName(starter_id),"upgraded":false,"upgrade_level":0,"enchants":[]})

	potions.clear()
	for p in d.get("potions", []):
		potions.append(StringName(p))

	relic_ids.clear()
	for r in d.get("relic_ids", []):
		relic_ids.append(StringName(r))

	max_hp = int(d.get("max_hp", 80))
	hp = int(d.get("hp", max_hp))
	gold = int(d.get("gold", 0))
	current_floor = int(d.get("current_floor", 0))
	current_node_type = StringName(d.get("current_node_type", ""))
	var pity: Dictionary = GameData.balance.get("card_rewards", {}).get("rare_pity", {})
	var minimum_offset := mini(
		int(pity.get("initial_offset", 0)),
		int(pity.get("rare_reset_offset", 0))
	)
	card_rare_offset = clampi(
		int(d.get("card_rare_offset", pity.get("initial_offset", 0))),
		minimum_offset,
		int(pity.get("max_offset", 0))
	)
	victory = bool(d.get("victory", false))
	is_active = bool(d.get("is_active", true))

	defeated.clear()
	for x in d.get("defeated", []):
		defeated.append(StringName(x))

	run_id = String(d.get("run_id", ""))
	if run_id.is_empty():
		run_id = _new_run_id()
	base_run_deck_capacity = int(d.get("base_run_deck_capacity", -1))
	run_ad_deck_capacity_bonus = maxi(0, int(d.get("run_ad_deck_capacity_bonus", 0)))
	deck_capacity_ad_uses = maxi(0, int(d.get("deck_capacity_ad_uses", 0)))
	pending_card_acquisition = d.get("pending_card_acquisition", {}).duplicate(true)
	shop_states = d.get("shop_states", {}).duplicate(true)
	if source_version < 6:
		# 旧商店/满库事务可能引用已删除卡牌；换池后重新生成，避免悬空引用。
		pending_card_acquisition.clear()
		shop_states.clear()
	ad_reward_transaction_ids.clear()
	for transaction_id in d.get("ad_reward_transaction_ids", []):
		var clean_id := String(transaction_id).strip_edges()
		if not clean_id.is_empty() and not ad_reward_transaction_ids.has(clean_id):
			ad_reward_transaction_ids.append(clean_id)
	run_end_base_fireseed = maxi(0, int(d.get("run_end_base_fireseed", 0)))
	run_end_ad_bonus_fireseed = maxi(0, int(d.get("run_end_ad_bonus_fireseed", 0)))
	run_end_base_settled = bool(d.get("run_end_base_settled", false))
	pre_run_buff_offer_ids.clear()
	for buff_id in d.get("pre_run_buff_offer_ids", []):
		var clean_buff_id := StringName(String(buff_id))
		if clean_buff_id != &"" and not pre_run_buff_offer_ids.has(clean_buff_id):
			pre_run_buff_offer_ids.append(clean_buff_id)
	pre_run_buff_id = StringName(String(d.get("pre_run_buff_id", "")))
	pre_run_buff_remaining_floors = maxi(0, int(d.get("pre_run_buff_remaining_floors", 0)))
	pre_run_buff_claimed = bool(d.get("pre_run_buff_claimed", false))
	pre_run_preparation_resolved = bool(d.get("pre_run_preparation_resolved", source_version < 4))
	resolved_floor_keys.clear()
	for floor_key in d.get("resolved_floor_keys", []):
		var clean_floor_key := String(floor_key).strip_edges()
		if not clean_floor_key.is_empty() and not resolved_floor_keys.has(clean_floor_key):
			resolved_floor_keys.append(clean_floor_key)
	combat_checkpoint = d.get("combat_checkpoint", {}).duplicate(true) if d.get("combat_checkpoint", {}) is Dictionary else {}
	if combat_checkpoint.has("deck"):
		var migrated_checkpoint_deck: Array = []
		for checkpoint_card in combat_checkpoint.get("deck", []):
			var checkpoint_id := StringName(String(checkpoint_card.get("id", "")))
			if GameData.get_card(checkpoint_id) == null:
				checkpoint_id = StringName(String(GameData.legacy_card_id_map.get(String(checkpoint_id), "")))
			if GameData.get_card(checkpoint_id) == null:
				continue
			var checkpoint_level := int(checkpoint_card.get("upgrade_level", 1 if bool(checkpoint_card.get("upgraded", false)) else 0))
			migrated_checkpoint_deck.append({
				"id":String(checkpoint_id), "upgraded":checkpoint_level > 0,
				"upgrade_level":checkpoint_level, "enchants":checkpoint_card.get("enchants", []).duplicate()
			})
		combat_checkpoint["deck"] = migrated_checkpoint_deck
	combat_death_pending = bool(d.get("combat_death_pending", false)) and not combat_checkpoint.is_empty()
	revive_used_count = maxi(0, int(d.get("revive_used_count", 0)))

	current_act = int(d.get("current_act", 0))
	act_cleared_flags.clear()
	for fl in d.get("act_cleared_flags", []):
		act_cleared_flags.append(bool(fl))

	act_maps.clear()
	for am in d.get("act_maps", []):
		var floor_arrs: Array = []
		for floor_nodes in am:
			var floor_arr: Array = []
			for nd in floor_nodes:
				var n := MapNode.new()
				n.floor = int(nd.get("floor", 0))
				n.index = int(nd.get("index", 0))
				n.col = int(nd.get("col", 0))
				n.type = StringName(nd.get("type", "combat"))
				n.enemy_ids = []
				for e in nd.get("enemy_ids", []):
					n.enemy_ids.append(StringName(e))
				n.links = []
				for l in nd.get("links", []):
					n.links.append(int(l))
				n.visited = bool(nd.get("visited", false))
				floor_arr.append(n)
			floor_arrs.append(floor_arr)
		act_maps.append(floor_arrs)

	pending_combat_enemy_ids.clear()
	pending_post_combat = false
	pending_post_reward = false
	pending_node_resolved = false
	pending_reward_data.clear()
	_record_deck_discoveries()
	SignalBus.player_hp_changed.emit(hp, max_hp)
	SignalBus.gold_changed.emit(gold)
	SignalBus.deck_changed.emit()
	SignalBus.map_generated.emit(current_map())
	return true


func _string_name_array_to_strings(values: Array) -> Array:
	var output: Array = []
	for value in values:
		output.append(String(value))
	return output
