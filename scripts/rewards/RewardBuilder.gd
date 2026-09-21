class_name RewardBuilder
extends RefCounted
## 战后奖励生成。所有数值取自 GameData.balance / 卡池 / 遗物表，禁止写死。

const CARD_RARITIES: Array[StringName] = [&"rare", &"uncommon", &"common"]


## 战斗卡牌奖励。source 对应 balance.card_rewards.sources：combat / elite / boss。
## 先抽稀有度，再在该稀有度池内等概率抽牌；同一组奖励不重复。
static func roll_card_choices(count: int, source: StringName = &"combat") -> Array:
	return _roll_card_choices(count, source, [])


## 商店刷新用：读取当前稀有补偿但不推进，并排除刷新前仍在售的卡牌。
static func roll_card_choices_excluding(
	count: int,
	excluded_ids: Array,
	source: StringName = &"shop"
) -> Array:
	return _roll_card_choices(count, source, excluded_ids)


static func _roll_card_choices(count: int, source: StringName, excluded_ids: Array) -> Array:
	var pool := _eligible_card_pool(excluded_ids)
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var rarity := _roll_available_rarity(source, pool)
		if rarity == &"":
			break
		var candidates := _cards_of_rarity(pool, rarity)
		if candidates.is_empty():
			break
		var cd: CardData = candidates[randi_range(0, candidates.size() - 1)]
		var upgraded := _roll_random_upgrade(source, cd)
		out.append(_card_reward_dict(cd, upgraded))
		pool.erase(cd)
		apply_rarity_result(rarity, source)
	return out


static func _eligible_card_pool(excluded_ids: Array = []) -> Array:
	var pool: Array = []
	for c in GameData.cards.values():
		if c.rarity in [&"starter", &"special"]:
			continue
		if excluded_ids.has(c.id) or excluded_ids.has(String(c.id)):
			continue
		if GameData.is_card_unlocked(c.id):
			pool.append(c)
	return pool


static func _cards_of_rarity(pool: Array, rarity: StringName) -> Array:
	var candidates: Array = []
	for card in pool:
		if card.rarity == rarity:
			candidates.append(card)
	return candidates


## 返回当前 source 在给定稀有补偿下的实际百分比。
## 负补偿会先压低稀有，越过 0 的部分继续压低精良；正补偿从普通转移给稀有。
static func rarity_probabilities(source: StringName, offset_override: Variant = null) -> Dictionary:
	var reward_cfg: Dictionary = GameData.balance.get("card_rewards", {})
	var scale := int(reward_cfg.get("probability_scale", 0))
	var source_cfg := _source_config(source)
	var forced := StringName(String(source_cfg.get("forced_rarity", "")))
	if forced != &"":
		var forced_result := {&"common": 0, &"uncommon": 0, &"rare": 0}
		forced_result[forced] = scale
		return forced_result

	var base: Dictionary = source_cfg.get("rarity_percent", {})
	var offset := 0
	if bool(source_cfg.get("uses_rare_pity", false)):
		offset = RunState.card_rare_offset if offset_override == null else int(offset_override)
	var rare_cutoff := clampi(int(base.get("rare", 0)) + offset, 0, scale)
	var uncommon_cutoff := clampi(
		int(base.get("rare", 0)) + int(base.get("uncommon", 0)) + offset,
		0,
		scale
	)
	return {
		&"rare": rare_cutoff,
		&"uncommon": uncommon_cutoff - rare_cutoff,
		&"common": scale - uncommon_cutoff,
	}


static func _roll_available_rarity(source: StringName, pool: Array) -> StringName:
	var probabilities := rarity_probabilities(source)
	var available_weights: Dictionary = {}
	var total := 0
	for rarity in CARD_RARITIES:
		if not _cards_of_rarity(pool, rarity).is_empty():
			var weight := int(probabilities.get(rarity, 0))
			available_weights[rarity] = weight
			total += weight
	if total > 0:
		var roll := randi_range(0, total - 1)
		for rarity in CARD_RARITIES:
			roll -= int(available_weights.get(rarity, 0))
			if roll < 0:
				return rarity

	# 局外锁定可能让强制稀有来源暂时没有对应卡；仅在这种情况下退到现有稀有度。
	var available: Array[StringName] = []
	for rarity in CARD_RARITIES:
		if not _cards_of_rarity(pool, rarity).is_empty():
			available.append(rarity)
	return available[randi_range(0, available.size() - 1)] if not available.is_empty() else &""


## 只有会推进补偿的来源才修改 RunState；商店只读取当前值。
static func apply_rarity_result(rarity: StringName, source: StringName) -> void:
	var source_cfg := _source_config(source)
	if not bool(source_cfg.get("updates_rare_pity", false)):
		return
	var pity: Dictionary = GameData.balance.get("card_rewards", {}).get("rare_pity", {})
	if rarity == &"common":
		RunState.card_rare_offset = mini(
			RunState.card_rare_offset + int(pity.get("common_increment", 0)),
			int(pity.get("max_offset", 0))
		)
	elif rarity == &"rare":
		RunState.card_rare_offset = int(pity.get("rare_reset_offset", 0))


static func random_upgrade_chance(source: StringName, rarity: StringName, act_index: int) -> float:
	var source_cfg := _source_config(source)
	if not bool(source_cfg.get("random_upgrade", false)) or rarity == &"rare":
		return 0.0
	var chances: Array = GameData.balance.get("card_rewards", {}).get("upgrade_chance_by_act", [])
	if chances.is_empty():
		return 0.0
	return float(chances[clampi(act_index, 0, chances.size() - 1)])


static func _roll_random_upgrade(source: StringName, card: CardData) -> bool:
	if card == null or not card.has_upgrade():
		return false
	var chance := random_upgrade_chance(source, card.rarity, RunState.current_act)
	return chance > 0.0 and randf() < chance


static func _card_reward_dict(card: CardData, upgraded: bool) -> Dictionary:
	return {
		"id": card.id,
		"name": card.name,
		"rarity": card.rarity,
		"cost": card.cost,
		"type": card.type,
		"desc": card.get_description(upgraded),
		"upgraded": upgraded,
	}


static func _source_config(source: StringName) -> Dictionary:
	var sources: Dictionary = GameData.balance.get("card_rewards", {}).get("sources", {})
	return sources.get(String(source), sources.get("misc", {}))


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


## 普通遗物：精英与终幕Boss自动发放；前两幕Boss由独立选择池替代。
static func roll_relic(tier: StringName) -> StringName:
	if tier == &"boss" and not RunState.is_last_act(): return &""
	if tier != &"elite" and tier != &"boss":
		return &""
	var owned := RunState.relic_ids
	var candidates: Array = []
	for r in GameData.relics.values():
		if r.rarity in [&"starter", &"boss", &"shop", &"special"]:
			continue
		if not GameData.is_relic_unlocked(r.id):
			continue
		if owned.has(r.id):
			continue
		candidates.append(r)
	if candidates.is_empty():
		return &""
	return candidates[randi_range(0, candidates.size() - 1)].id


## 单卡抽取：事件默认 misc；宝箱显式传 treasure，分别遵循对应来源配置。
static func roll_single_card(source: StringName = &"misc") -> Dictionary:
	var choices := _roll_card_choices(1, source, [])
	return choices[0] if not choices.is_empty() else {}


## 宝箱独立配置，不改变商店、战斗或事件的物品抽取规则。
static func roll_treasure_kind() -> StringName:
	return _weighted_key(GameData.balance.get("treasure", {}).get("reward_weights", {}))


static func _weighted_key(weights: Dictionary) -> StringName:
	var total := 0.0
	for value in weights.values():
		total += maxf(float(value), 0.0)
	if total <= 0.0:
		return &""
	var roll := randf() * total
	for key in weights:
		roll -= maxf(float(weights[key]), 0.0)
		if roll < 0.0:
			return StringName(key)
	return &""


static func _treasure_tier() -> Dictionary:
	var config: Dictionary = GameData.balance.get("treasure", {})
	var size := _weighted_key(config.get("chest_size_weights", {}))
	return config.get("chest_tiers", {}).get(String(size), {})


static func roll_treasure_gold() -> int:
	var band: Dictionary = _treasure_tier().get("gold", {})
	return randi_range(int(band.get("min", 0)), int(band.get("max", 0)))


static func roll_treasure_relic() -> StringName:
	var pool: Array = []
	for relic in GameData.relics.values():
		if relic.rarity in CARD_RARITIES and not RunState.relic_ids.has(relic.id) and GameData.is_relic_unlocked(relic.id):
			pool.append(relic)
	return _weighted_item(pool, _treasure_tier().get("relic_rarity_weights", {}))


static func roll_treasure_potion() -> StringName:
	if RunState.potions.size() >= int(GameData.balance.get("potions", {}).get("max_carry", 0)):
		return &""
	var pool: Array = []
	for potion in GameData.potions.values():
		if GameData.is_potion_unlocked(potion.id):
			pool.append(potion)
	return _weighted_item(pool, GameData.balance.get("treasure", {}).get("potion_rarity_weights", {}))


## 先按稀有度、后在该稀有度内等概率抽取。空稀有度移除并归一化。
static func _weighted_item(pool: Array, weights: Dictionary) -> StringName:
	if pool.is_empty():
		return &""
	var available := {}
	for item in pool:
		available[String(item.rarity)] = weights.get(String(item.rarity), 0)
	var rarity := _weighted_key(available)
	# 如低级箱对应池已完全耗尽，仅从仍有物品的稀有度中回退。
	var candidates: Array = []
	for item in pool:
		if rarity == &"" or item.rarity == rarity:
			candidates.append(item)
	return candidates[randi_range(0, candidates.size() - 1)].id


## 普通随机池：排除初始、首领与专属类别（商店/事件用）。
static func roll_shop_relic() -> StringName:
	var owned := RunState.relic_ids
	var candidates: Array = []
	for r in GameData.relics.values():
		if r.rarity in [&"starter", &"boss", &"shop", &"special"]:
			continue
		if not GameData.is_relic_unlocked(r.id):
			continue
		if owned.has(r.id):
			continue
		candidates.append(r)
	if candidates.is_empty():
		return &""
	return candidates[randi_range(0, candidates.size() - 1)].id


static func roll_shop_relic_excluding(excluded_ids: Array) -> StringName:
	var candidates: Array = []
	for r in GameData.relics.values():
		if r.rarity in [&"starter", &"boss", &"shop", &"special"] or RunState.relic_ids.has(r.id):
			continue
		if not GameData.is_relic_unlocked(r.id):
			continue
		if excluded_ids.has(r.id) or excluded_ids.has(String(r.id)):
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
	var ids: Array = []
	for potion_id in GameData.potions:
		if GameData.is_potion_unlocked(potion_id):
			ids.append(potion_id)
	if ids.is_empty():
		return &""
	return StringName(ids[randi_range(0, ids.size() - 1)])


## 随机一个对指定卡类型合法的附魔 id（restriction.card_type 含该类型或无限制）。无合法附魔返回 &""。
static func roll_enchant_for_card(card: CardData) -> StringName:
	if card == null:
		return &""
	var legal: Array = []
	for e in GameData.enchants.values():
		if GameData.is_enchant_unlocked(e.id) and e.matches_card(card):
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
		if not RunState.can_receive_run_enchant(entry):
			continue
		if roll_enchant_for_card(cd) != &"":
			return true
	return false



## Candidates are rolled once by MapUI and persisted with the reward transaction.
static func roll_boss_relic_choices() -> Array:
	var pool: Array = []
	if RunState.is_last_act(): return pool
	for relic in GameData.relics.values():
		if relic.rarity == &"boss" and not RunState.has_relic(relic.id) and GameData.is_relic_unlocked(relic.id):
			pool.append(String(relic.id))
	pool.shuffle()
	return pool.slice(0, int(GameData.balance.get("rewards", {}).get("boss_relic_choice_count", 0)))
