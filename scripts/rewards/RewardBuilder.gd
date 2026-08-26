class_name RewardBuilder
extends RefCounted
## 战后奖励生成。所有数值取自 GameData.balance / 卡池 / 遗物表，禁止写死。

## 按稀有度权重抽取 count 张可选卡牌（排除 starter / special）。
static func roll_card_choices(count: int) -> Array:
	var pool: Array = []
	for c in GameData.cards.values():
		if c.rarity == &"starter" or c.rarity == &"special":
			continue
		pool.append(c)
	var weights: Dictionary = GameData.balance.get("card_pool_weights", {})
	var out: Array = []
	var guard := 0
	while out.size() < count and guard < count * 20:
		guard += 1
		var cd := _weighted_card(pool, weights)
		if cd == null:
			break
		# 允许重复出现（玩家可选到同名卡），去重仅防同一次三选一重复
		var dup := false
		for existing in out:
			if existing["id"] == cd.id:
				dup = true
				break
		if dup:
			continue
		out.append({
			"id": cd.id,
			"name": cd.name,
			"rarity": cd.rarity,
			"cost": cd.cost,
			"type": cd.type,
			"desc": cd.get_description(false),
		})
	return out


static func _weighted_card(pool: Array, weights: Dictionary) -> CardData:
	if pool.is_empty():
		return null
	var total := 0.0
	for c in pool:
		total += float(weights.get(String(c.rarity), 0.0))
	if total <= 0.0:
		return pool[randi_range(0, pool.size() - 1)]
	var r := randf() * total
	for c in pool:
		r -= float(weights.get(String(c.rarity), 0.0))
		if r <= 0.0:
			return c
	return pool[pool.size() - 1]


## 金币：按 tier 取区间随机值。外部用 RunState.add_gold 发放（已含炭票袋加成）。
static func roll_gold(tier: StringName) -> int:
	var tbl: Dictionary = GameData.balance.get("rewards", {})
	var key := "combat_gold"
	if tier == &"elite":
		key = "elite_gold"
	elif tier == &"boss":
		key = "boss_gold"
	var rng: Dictionary = tbl.get(key, {"min": 10, "max": 20})
	return randi_range(int(rng.get("min", 10)), int(rng.get("max", 20)))


## 遗物：elite/boss 随机给一个未拥有的非 starter 遗物；其余 tier 不给。
static func roll_relic(tier: StringName) -> StringName:
	if tier != &"elite" and tier != &"boss":
		return &""
	var owned := RunState.relic_ids
	var candidates: Array = []
	for r in GameData.relics.values():
		if r.rarity == &"starter":
			continue
		if owned.has(r.id):
			continue
		candidates.append(r)
	if candidates.is_empty():
		return &""
	return candidates[randi_range(0, candidates.size() - 1)].id


## 单张随机卡（商店/宝箱用），返回 dict（含 id/name/rarity/cost/type/desc）。
static func roll_single_card() -> Dictionary:
	var pool: Array = []
	for c in GameData.cards.values():
		if c.rarity == &"starter" or c.rarity == &"special":
			continue
		pool.append(c)
	var weights: Dictionary = GameData.balance.get("card_pool_weights", {})
	var cd: CardData = _weighted_card(pool, weights)
	if cd == null:
		return {}
	return {
		"id": cd.id,
		"name": cd.name,
		"rarity": cd.rarity,
		"cost": cd.cost,
		"type": cd.type,
		"desc": cd.get_description(false),
	}


## 随机一个未拥有的非 starter 遗物（商店/宝箱/事件用）。
static func roll_shop_relic() -> StringName:
	var owned := RunState.relic_ids
	var candidates: Array = []
	for r in GameData.relics.values():
		if r.rarity == &"starter":
			continue
		if owned.has(r.id):
			continue
		candidates.append(r)
	if candidates.is_empty():
		return &""
	return candidates[randi_range(0, candidates.size() - 1)].id


## 药水：按 tier 掉落概率（combat_normal/elite/boss），背包未满才掉落；force=true 忽略概率必抽（事件/宝箱用）。
static func roll_potion(tier: StringName, force: bool = false) -> StringName:
	var drop_tbl: Dictionary = GameData.balance.get("potions", {}).get("drop", {})
	var key := "combat_normal"
	if tier == &"elite":
		key = "combat_elite"
	elif tier == &"boss":
		key = "combat_boss"
	var chance: float = float(drop_tbl.get(key, 0.0))
	if not force and randf() >= chance:
		return &""
	var cap: int = int(GameData.balance.get("potions", {}).get("max_carry", 3))
	if RunState.potions.size() >= cap:
		return &""
	var ids: Array = GameData.potions.keys()
	if ids.is_empty():
		return &""
	return StringName(ids[randi_range(0, ids.size() - 1)])


## 随机一个对指定卡类型合法的附魔 id（restriction.card_type 含该类型或无限制）。无合法附魔返回 &""。
static func roll_enchant_for_card(card: CardData) -> StringName:
	if card == null:
		return &""
	var legal: Array = []
	for e in GameData.enchants.values():
		if e.matches_card(card):
			legal.append(e.id)
	if legal.is_empty():
		return &""
	return StringName(legal[randi_range(0, legal.size() - 1)])


## 牌组是否存在至少一张可附魔（未附魔且能匹配某附魔）的卡。
static func can_any_card_enchant() -> bool:
	for i in RunState.deck.size():
		var entry: Dictionary = RunState.deck[i]
		var cd: CardData = GameData.get_card(StringName(entry["id"]))
		if cd == null:
			continue
		if not entry.get("enchants", []).is_empty():
			continue
		if roll_enchant_for_card(cd) != &"":
			return true
	return false

