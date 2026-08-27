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

## 多幕地图容器：Array[act] -> Array[floor] -> Array[MapNode]
var act_maps: Array = []
var current_act: int = 0
var act_cleared_flags: Array = []      # Array[bool]，每幕是否已通关（Boss 已击败）

## 注：单张 `map` 兼容 getter 已在 P-B 移除；所有调用方改用 `current_map()`。

var victory: bool = false

## 本局已击败的敌人 id（用于奖励与统计）
var defeated: Array[StringName] = []

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
	max_hp = int(pc.get("max_hp", 80))
	hp = max_hp
	gold = 0
	current_floor = 0
	current_node_type = &""
	victory = false
	defeated.clear()
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
		deck.append({"id": StringName(cid), "upgraded": false, "enchants": []})

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
func add_card(card_id: StringName, upgraded: bool = false) -> void:
	deck.append({"id": card_id, "upgraded": upgraded, "enchants": []})
	SignalBus.deck_changed.emit()


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
	if card == null or not card.has_upgrade() or entry["upgraded"]:
		return false
	entry["upgraded"] = true
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
const SAVE_VERSION := 2

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
		deck_data.append({"id": String(c["id"]), "upgraded": bool(c.get("upgraded", false)), "enchants": c.get("enchants", [])})

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
		"defeated": defeated_data,
		"victory": victory,
		"is_active": is_active,
		"current_act": current_act,
		"act_cleared_flags": act_cleared_flags,
		"act_maps": act_maps_data,
	}


## 从存档 Dictionary 还原运行态，重建 MapNode 对象并广播信号。
## 仅接受 version == SAVE_VERSION（v1 旧单幕存档直接拒绝，由 SaveManager 删除）。
func from_save_dict(d: Dictionary) -> bool:
	if int(d.get("version", -1)) != SAVE_VERSION:
		push_error("[RunState] 存档版本不匹配 (期望 %d，实际 %d)" % [SAVE_VERSION, int(d.get("version", -1))])
		return false

	deck.clear()
	for c in d.get("deck", []):
		deck.append({"id": StringName(c["id"]), "upgraded": bool(c.get("upgraded", false)), "enchants": c.get("enchants", [])})

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
	victory = bool(d.get("victory", false))
	is_active = bool(d.get("is_active", true))

	defeated.clear()
	for x in d.get("defeated", []):
		defeated.append(StringName(x))

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

	SignalBus.player_hp_changed.emit(hp, max_hp)
	SignalBus.gold_changed.emit(gold)
	SignalBus.deck_changed.emit()
	SignalBus.map_generated.emit(current_map())
	return true
