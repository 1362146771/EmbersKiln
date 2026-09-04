extends Node
## Autoload: GameData —— 静态配置层（StaticData）。
## 职责：从 res://data/*.json 加载全部设计数据，构建索引，做交叉引用校验。
## 铁律：任何系统取数值只能走 GameData，禁止在 .gd 里写死数值。

const DATA_DIR := "res://data/"

const FILES := {
	"cards": "cards.json",
	"enemies": "enemies.json",
	"statuses": "statuses.json",
	"relics": "relics.json",
	"map": "map.json",
	"balance": "balance.json",
	"events": "events.json",
	"potions": "potions.json",
	"enchants": "enchants.json",
	"minions": "minions.json",
	"meta_progression": "meta_progression.json",
	"ad_economy": "ad_economy.json",
}

var cards: Dictionary = {}      # StringName -> CardData
var enemies: Dictionary = {}    # StringName -> EnemyData
var statuses: Dictionary = {}   # StringName -> StatusData
var relics: Dictionary = {}     # StringName -> RelicData
var minions: Dictionary = {}      # StringName -> MinionData
var potions: Dictionary = {}     # StringName -> PotionData
var enchants: Dictionary = {}    # StringName -> EnchantData
var effect_kinds: Array = []     # cards.json 顶层 effect_kinds（用于交叉校验）
var card_taxonomy: Dictionary = {} # cards.json 顶层 taxonomy（类型/稀有度/机制中文名）
var map_config: Dictionary = {}
var act_configs: Array = []      # Array[Dictionary] —— 多幕配置（map.json 的 acts 数组）
var balance: Dictionary = {}
var events: Array = []          # Array[Dictionary] —— 事件表（标题/描述/选项/后果）
var formations: Array = []      # Array[Dictionary] —— 多敌编成表（见 map.json）
var meta_progression: Dictionary = {}
var meta_facilities: Dictionary = {} # StringName -> Dictionary
var meta_projects: Dictionary = {}   # StringName -> Dictionary
var meta_pre_run_buffs: Dictionary = {} # StringName -> Dictionary
var ad_economy: Dictionary = {}

var is_loaded: bool = false
var load_errors: Array[String] = []


func _ready() -> void:
	load_all()


func load_all() -> bool:
	load_errors.clear()
	cards.clear()
	enemies.clear()
	statuses.clear()
	relics.clear()
	minions.clear()
	potions.clear()
	enchants.clear()
	effect_kinds.clear()
	card_taxonomy.clear()
	events.clear()
	formations.clear()
	meta_progression.clear()
	meta_facilities.clear()
	meta_projects.clear()
	meta_pre_run_buffs.clear()
	ad_economy.clear()

	var raw := {}
	for key in FILES:
		var parsed = _read_json(DATA_DIR + FILES[key])
		if parsed == null:
			load_errors.append("无法解析: %s" % FILES[key])
			continue
		raw[key] = parsed

	if not load_errors.is_empty():
		is_loaded = false
		SignalBus.data_load_failed.emit(load_errors)
		push_error("[GameData] 数据加载失败: %s" % ", ".join(load_errors))
		return false

	for d in raw["statuses"].get("statuses", []):
		var s := StatusData.from_dict(d)
		statuses[s.id] = s
	for d in raw["cards"].get("cards", []):
		var c := CardData.from_dict(d)
		cards[c.id] = c
	for d in raw["enemies"].get("enemies", []):
		var e := EnemyData.from_dict(d)
		enemies[e.id] = e
	for d in raw["relics"].get("relics", []):
		var r := RelicData.from_dict(d)
		relics[r.id] = r
	for d in raw["minions"].get("minions", []):
		var m := MinionData.from_dict(d)
		minions[m.id] = m

	effect_kinds = raw["cards"].get("effect_kinds", [])
	card_taxonomy = raw["cards"].get("taxonomy", {})
	for d in raw["potions"].get("potions", []):
		var p := PotionData.from_dict(d)
		potions[p.id] = p
	for d in raw["enchants"].get("enchants", []):
		var e := EnchantData.from_dict(d)
		enchants[e.id] = e

	var map_raw: Dictionary = raw["map"]
	act_configs = map_raw.get("acts", [])
	if act_configs.is_empty():
		act_configs = [map_raw]
	map_config = act_configs[0]
	balance = raw["balance"]
	formations = map_raw.get("formations", [])
	meta_progression = raw["meta_progression"]
	ad_economy = raw["ad_economy"]
	for facility in meta_progression.get("facilities", []):
		if facility is Dictionary:
			var facility_id := StringName(String(facility.get("id", "")))
			if facility_id != &"":
				meta_facilities[facility_id] = facility
	for project in meta_progression.get("projects", []):
		if project is Dictionary:
			var project_id := StringName(String(project.get("id", "")))
			if project_id != &"":
				meta_projects[project_id] = project
	for buff in meta_progression.get("pre_run_buffs", []):
		if buff is Dictionary:
			var buff_id := StringName(String(buff.get("id", "")))
			if buff_id != &"":
				meta_pre_run_buffs[buff_id] = buff

	for ev in raw["events"].get("events", []):
		events.append(ev)

	_validate()
	_validate_meta_progression()
	_validate_ad_economy()

	if load_errors.is_empty():
		is_loaded = true
		SignalBus.data_loaded.emit()
	print("[GameData] 加载完成 — 卡牌 %d / 敌人 %d / 状态 %d / 遗物 %d / 随从 %d / 药水 %d / 附魔 %d" % [cards.size(), enemies.size(), statuses.size(), relics.size(), minions.size(), potions.size(), enchants.size()])
	return true

	is_loaded = false
	SignalBus.data_load_failed.emit(load_errors)
	for e in load_errors:
		push_error("[GameData] 校验失败: %s" % e)
	return false


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[GameData] 文件不存在: %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[GameData] 无法打开: %s" % path)
		return null
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("[GameData] JSON 语法错误 %s 第 %d 行: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## 交叉引用校验：卡牌/敌人引用的 status 必须存在；起始牌组必须有效。
func _validate() -> void:
	var valid_types: Dictionary = card_taxonomy.get("types", {})
	var valid_rarities: Dictionary = card_taxonomy.get("rarities", {})
	var valid_mechanics: Dictionary = card_taxonomy.get("mechanics", {})
	if valid_types.is_empty() or valid_rarities.is_empty() or valid_mechanics.is_empty():
		load_errors.append("cards.json 缺少完整 taxonomy（types / rarities / mechanics）")
	for cid in cards:
		var c: CardData = cards[cid]
		if not valid_types.has(String(c.type)):
			load_errors.append("卡牌 %s 含未知类型 %s" % [cid, c.type])
		if not valid_rarities.has(String(c.rarity)):
			load_errors.append("卡牌 %s 含未知稀有度 %s" % [cid, c.rarity])
		if c.mechanics.is_empty():
			load_errors.append("卡牌 %s 缺少 mechanics 分类" % cid)
		for mechanic in c.mechanics:
			if not valid_mechanics.has(String(mechanic)):
				load_errors.append("卡牌 %s 含未知机制标签 %s" % [cid, mechanic])
		for eff in c.effects + c.upgrade_effects:
			if eff is Dictionary and not effect_kinds.has(String(eff.get("kind", ""))):
				load_errors.append("卡牌 %s 含未知 effect_kind：%s" % [cid, eff.get("kind", "")])
			if eff is Dictionary and eff.has("status"):
				var sid := StringName(eff["status"])
				if not statuses.has(sid):
					load_errors.append("卡牌 %s 引用了不存在的状态 %s" % [cid, sid])
			if eff is Dictionary and eff.get("kind", "") == "summon" and eff.has("minion_id"):
				var mid := StringName(eff["minion_id"])
				if not minions.has(mid):
					load_errors.append("卡牌 %s 引用了不存在的随从 %s" % [cid, mid])

	for eid in enemies:
		var e: EnemyData = enemies[eid]
		for cycle_error in e.cycle_validation_errors():
			load_errors.append("敌人 %s 循环配置错误：%s" % [eid, cycle_error])
		for mv in e.moves:
			if mv is Dictionary and mv.has("status"):
				var sid := StringName(mv["status"])
				if not statuses.has(sid):
					load_errors.append("敌人 %s 引用了不存在的状态 %s" % [eid, sid])

	for cid in balance.get("starting_deck", []):
		if not cards.has(StringName(cid)):
			load_errors.append("起始牌组引用了不存在的卡牌 %s" % cid)
	_validate_card_reward_config()

	# 编成表校验：引用的敌人必须存在，且不超过单场上限
	var max_en := int(balance.get("enemy_scaling", {}).get("max_enemies_per_combat", 2))
	for fm in formations:
		if not (fm is Dictionary) or fm.get("id", "") == "":
			load_errors.append("编成表存在无效条目：%s" % str(fm))
			continue
		var fl: Array = fm.get("enemies", [])
		if fl.size() < 1 or fl.size() > max_en:
			load_errors.append("编成 %s 敌人数越界(%d，上限%d)" % [fm.get("id", ""), fl.size(), max_en])
		for eid in fl:
			if not enemies.has(StringName(eid)):
				load_errors.append("编成 %s 引用了不存在的敌人 %s" % [fm.get("id", ""), eid])

	if not enemies.values().any(func(e: EnemyData) -> bool: return e.is_boss()):
		load_errors.append("敌人表中没有 boss 层级的敌人")

	# 多幕配置校验（P-D）：enemy_pool 引用存在且层级匹配；boss_id 存在且为 boss
	for ac in act_configs:
		if not (ac is Dictionary):
			continue
		var act_no: Variant = ac.get("act", "?")
		var pool: Dictionary = ac.get("enemy_pool", {})
		for tier_key in pool:
			for eid in pool[tier_key]:
				var pe: EnemyData = enemies.get(StringName(eid))
				if pe == null:
					load_errors.append("幕 %s 敌池引用了不存在的敌人 %s" % [act_no, eid])
				elif pe.tier != StringName(tier_key):
					load_errors.append("幕 %s 敌池 %s 层级不符（期望 %s 实际 %s）" % [act_no, eid, tier_key, pe.tier])
		var bid := StringName(ac.get("boss_id", ""))
		if bid != &"":
			var bd: EnemyData = enemies.get(bid)
			if bd == null:
				load_errors.append("幕 %s boss_id 不存在：%s" % [act_no, bid])
			elif not bd.is_boss():
				load_errors.append("幕 %s boss_id %s 非 boss 层级" % [act_no, bid])

	# 事件表校验
	if events.is_empty():
		load_errors.append("事件表为空（events.json 缺失或格式错误）")
	var event_ids: Dictionary = {}
	for ev in events:
		if not (ev is Dictionary) or ev.get("title", "") == "":
			load_errors.append("事件缺少 title：%s" % str(ev))
			continue
		var event_id := StringName(String(ev.get("id", "")))
		if event_id == &"":
			load_errors.append("事件 %s 缺少 id" % ev.get("title", ""))
		elif event_ids.has(event_id):
			load_errors.append("事件 id 重复：%s" % event_id)
		else:
			event_ids[event_id] = true
		var event_acts = ev.get("acts", [])
		if not (event_acts is Array) or event_acts.is_empty():
			load_errors.append("事件 %s 缺少 acts" % ev.get("title", ""))
		else:
			for act_no in event_acts:
				if int(act_no) < 1 or int(act_no) > act_configs.size():
					load_errors.append("事件 %s 含无效幕号：%s" % [ev.get("title", ""), act_no])
		var opts = ev.get("options", [])
		if not (opts is Array) or opts.size() < 2:
			load_errors.append("事件 %s 选项不足 2 个" % ev.get("title", ""))

	# 药水表校验：effect_kind 合法、apply_status 引用的状态存在
	for pid in potions:
		var p: PotionData = potions[pid]
		for eff in p.effects:
			if not (eff is Dictionary):
				continue
			var k: String = eff.get("kind", "")
			if not effect_kinds.has(k):
				load_errors.append("药水 %s 含未知 effect_kind：%s" % [pid, k])
			if k == "apply_status" and eff.has("status"):
				var sid := StringName(eff["status"])
				if not statuses.has(sid):
					load_errors.append("药水 %s 引用了不存在的状态 %s" % [pid, sid])

	# 附魔表校验：restriction.card_type 合法、extra_effects 的 kind 合法且引用的状态存在
	for eid in enchants:
		var e: EnchantData = enchants[eid]
		for t in e.restriction.get("card_type", []):
			if not (t in [&"attack", &"skill", &"power"]):
				load_errors.append("附魔 %s 含非法卡类型 %s" % [eid, t])
		for ex in e.mods.get("extra_effects", []):
			if not (ex is Dictionary):
				continue
			var k: String = ex.get("kind", "")
			if not effect_kinds.has(k):
				load_errors.append("附魔 %s extra_effects 含未知 kind：%s" % [eid, k])
			if k == "apply_status" and ex.has("status"):
				var sid := StringName(ex["status"])
				if not statuses.has(sid):
					load_errors.append("附魔 %s 引用了不存在的状态 %s" % [eid, sid])


func _validate_card_reward_config() -> void:
	var reward_cfg: Variant = balance.get("card_rewards", null)
	if not reward_cfg is Dictionary:
		load_errors.append("balance.card_rewards 缺失或格式无效")
		return
	var scale := int(reward_cfg.get("probability_scale", 0))
	if scale <= 0:
		load_errors.append("card_rewards.probability_scale 必须大于 0")
		return
	var sources: Variant = reward_cfg.get("sources", null)
	if not sources is Dictionary:
		load_errors.append("card_rewards.sources 缺失或格式无效")
		return
	for source_id in ["combat", "elite", "boss", "shop", "misc"]:
		var source_cfg: Variant = sources.get(source_id, null)
		if not source_cfg is Dictionary:
			load_errors.append("card_rewards.sources.%s 缺失或格式无效" % source_id)
			continue
		var rarity_percent: Variant = source_cfg.get("rarity_percent", null)
		if not rarity_percent is Dictionary:
			load_errors.append("卡牌来源 %s 缺少 rarity_percent" % source_id)
			continue
		var total := 0
		for rarity_id in ["common", "uncommon", "rare"]:
			var value := int(rarity_percent.get(rarity_id, -1))
			if value < 0:
				load_errors.append("卡牌来源 %s 的 %s 概率无效" % [source_id, rarity_id])
			total += maxi(value, 0)
		if total != scale:
			load_errors.append("卡牌来源 %s 稀有度概率总和 %d，应为 %d" % [source_id, total, scale])
		for flag in ["uses_rare_pity", "updates_rare_pity", "random_upgrade"]:
			if not source_cfg.has(flag) or not source_cfg[flag] is bool:
				load_errors.append("卡牌来源 %s 缺少布尔字段 %s" % [source_id, flag])
		var forced := String(source_cfg.get("forced_rarity", ""))
		if not forced.is_empty() and not forced in ["common", "uncommon", "rare"]:
			load_errors.append("卡牌来源 %s 的 forced_rarity 无效：%s" % [source_id, forced])

	var pity: Variant = reward_cfg.get("rare_pity", null)
	if not pity is Dictionary:
		load_errors.append("card_rewards.rare_pity 缺失或格式无效")
	else:
		for field in ["initial_offset", "common_increment", "rare_reset_offset", "max_offset"]:
			if not pity.has(field) or not pity[field] is float and not pity[field] is int:
				load_errors.append("card_rewards.rare_pity.%s 缺失或不是数字" % field)
		if int(pity.get("common_increment", 0)) <= 0:
			load_errors.append("rare_pity.common_increment 必须大于 0")
		if int(pity.get("initial_offset", 0)) > int(pity.get("max_offset", 0)):
			load_errors.append("rare_pity.initial_offset 不得大于 max_offset")
		if int(pity.get("rare_reset_offset", 0)) > int(pity.get("max_offset", 0)):
			load_errors.append("rare_pity.rare_reset_offset 不得大于 max_offset")

	var upgrade_chances: Variant = reward_cfg.get("upgrade_chance_by_act", null)
	if not upgrade_chances is Array or upgrade_chances.size() < act_configs.size():
		load_errors.append("card_rewards.upgrade_chance_by_act 必须覆盖全部幕")
	else:
		for chance in upgrade_chances:
			if not chance is float and not chance is int or float(chance) < 0.0 or float(chance) > 1.0:
				load_errors.append("card_rewards.upgrade_chance_by_act 含无效概率：%s" % chance)


## 局外成长允许 Pending 数值以 null 留在配置中；null 项目不会开放建造。
func _validate_meta_progression() -> void:
	if int(meta_progression.get("version", -1)) != 1:
		load_errors.append("meta_progression.json 版本无效")
	if String(meta_progression.get("currency_id", "")) != "fireseed":
		load_errors.append("局外货币必须为 fireseed")
	if not meta_progression.get("facilities", null) is Array:
		load_errors.append("局外设施表格式无效")
		return
	if not meta_progression.get("projects", null) is Array:
		load_errors.append("局外项目表格式无效")
		return
	if not meta_progression.get("pre_run_buffs", null) is Array:
		load_errors.append("局前 Buff 表格式无效")
		return

	var facility_ids: Dictionary = {}
	for facility in meta_progression.get("facilities", []):
		if not facility is Dictionary:
			load_errors.append("局外设施含非法条目")
			continue
		var facility_id := String(facility.get("id", "")).strip_edges()
		if facility_id.is_empty() or facility_ids.has(facility_id):
			load_errors.append("局外设施 id 缺失或重复：%s" % facility_id)
			continue
		facility_ids[facility_id] = true

	var workshop: Variant = meta_progression.get("workshop", {})
	if not workshop is Dictionary:
		load_errors.append("工坊配置格式无效")
	else:
		_validate_nullable_nonnegative_number(workshop.get("queue_capacity", null), "workshop.queue_capacity", false)
	_validate_nullable_nonnegative_number(meta_progression.get("base_run_deck_capacity", null), "base_run_deck_capacity", false)
	var run_end_rewards: Variant = meta_progression.get("run_end_rewards", {})
	if not run_end_rewards is Dictionary:
		load_errors.append("局终火种配置格式无效")
	else:
		for field in ["floor_index_offset", "per_floor", "per_defeated_enemy", "victory_bonus", "base_cap"]:
			_validate_nullable_nonnegative_number(run_end_rewards.get(field, null), "run_end_rewards.%s" % field)

	var bonus_tiers: Variant = meta_progression.get("run_start_bonus_tiers", [])
	if not bonus_tiers is Array:
		load_errors.append("run_start_bonus_tiers 格式无效")
	else:
		var seen_bonus_tiers: Dictionary = {}
		for tier in bonus_tiers:
			if not tier is Dictionary:
				load_errors.append("新局加成档位含非法条目")
				continue
			var tier_facility := String(tier.get("facility_id", "")).strip_edges()
			var required_level: Variant = tier.get("required_level", null)
			if not facility_ids.has(tier_facility):
				load_errors.append("新局加成档位引用未知设施：%s" % tier_facility)
			if required_level == null or not (required_level is int or required_level is float) or int(required_level) <= 0:
				load_errors.append("新局加成档位等级无效：%s" % tier_facility)
				continue
			var tier_key := "%s:%d" % [tier_facility, int(required_level)]
			if seen_bonus_tiers.has(tier_key):
				load_errors.append("新局加成档位重复：%s" % tier_key)
			seen_bonus_tiers[tier_key] = true
			for field in ["max_hp_bonus", "starting_gold_bonus"]:
				_validate_nullable_nonnegative_number(tier.get(field, null), "%s.%s" % [tier_key, field])

	var initial_unlocks: Variant = meta_progression.get("initial_unlocks", {})
	if not initial_unlocks is Dictionary:
		load_errors.append("initial_unlocks 格式无效")
	else:
		var initial_indexes := {
			"card_ids": cards,
			"relic_ids": relics,
			"potion_ids": potions,
			"enchant_ids": enchants,
		}
		for field in initial_indexes:
			var values: Variant = initial_unlocks.get(field, [])
			if not values is Array:
				load_errors.append("initial_unlocks.%s 格式无效" % field)
				continue
			var seen_ids: Dictionary = {}
			for value in values:
				var content_id := StringName(String(value))
				if not initial_indexes[field].has(content_id):
					load_errors.append("initial_unlocks.%s 引用未知内容 %s" % [field, value])
				if seen_ids.has(String(content_id)):
					load_errors.append("initial_unlocks.%s 含重复内容 %s" % [field, value])
				seen_ids[String(content_id)] = true

	var project_ids: Dictionary = {}
	for project in meta_progression.get("projects", []):
		if not project is Dictionary:
			load_errors.append("工坊项目含非法条目")
			continue
		var project_id := String(project.get("id", "")).strip_edges()
		if project_id.is_empty() or project_ids.has(project_id):
			load_errors.append("工坊项目 id 缺失或重复：%s" % project_id)
			continue
		project_ids[project_id] = true
		var facility_id := String(project.get("facility_id", "")).strip_edges()
		if not facility_ids.has(facility_id):
			load_errors.append("工坊项目 %s 引用了不存在的设施 %s" % [project_id, facility_id])
		_validate_nullable_nonnegative_number(project.get("fireseed_cost", null), "%s.fireseed_cost" % project_id)
		_validate_nullable_nonnegative_number(project.get("duration_seconds", null), "%s.duration_seconds" % project_id)
		if project.has("grants") and not project["grants"] is Dictionary:
			load_errors.append("工坊项目 %s grants 格式无效" % project_id)
		elif project.has("grants"):
			_validate_meta_project_grants(project_id, project["grants"], facility_ids)

	for project in meta_progression.get("projects", []):
		if not project is Dictionary:
			continue
		var project_id := String(project.get("id", ""))
		for prerequisite in project.get("prerequisite_project_ids", []):
			if not project_ids.has(String(prerequisite)):
				load_errors.append("工坊项目 %s 前置不存在：%s" % [project_id, prerequisite])

	var buff_ids: Dictionary = {}
	for buff in meta_progression.get("pre_run_buffs", []):
		if not buff is Dictionary:
			load_errors.append("局前 Buff 含非法条目")
			continue
		var buff_id := String(buff.get("id", "")).strip_edges()
		if buff_id.is_empty() or buff_ids.has(buff_id):
			load_errors.append("局前 Buff id 缺失或重复：%s" % buff_id)
			continue
		buff_ids[buff_id] = true
		if String(buff.get("name", "")).strip_edges().is_empty():
			load_errors.append("局前 Buff %s 缺少名称" % buff_id)
		var effects: Variant = buff.get("effects", null)
		if not effects is Array or effects.is_empty():
			load_errors.append("局前 Buff %s effects 为空或格式无效" % buff_id)
			continue
		for effect in effects:
			if not effect is Dictionary or String(effect.get("kind", "")) != "combat_start_block":
				load_errors.append("局前 Buff %s 含未支持的效果模板" % buff_id)
				continue
			_validate_nullable_nonnegative_number(effect.get("value", null), "%s.effects.value" % buff_id)


func _validate_nullable_nonnegative_number(value: Variant, field: String, require_positive: bool = true) -> void:
	if value == null:
		return
	if not (value is int or value is float):
		load_errors.append("局外数值字段类型无效：%s" % field)
		return
	if (require_positive and float(value) < 0.0) or (not require_positive and float(value) <= 0.0):
		load_errors.append("局外数值字段范围无效：%s" % field)


func _validate_meta_project_grants(project_id: String, grants: Dictionary, facility_ids: Dictionary) -> void:
	var facility_grants: Variant = grants.get("facility_levels", {})
	if not facility_grants is Dictionary:
		load_errors.append("工坊项目 %s facility_levels 格式无效" % project_id)
	else:
		for facility_id in facility_grants:
			var level: Variant = facility_grants[facility_id]
			if not facility_ids.has(String(facility_id)):
				load_errors.append("工坊项目 %s 奖励引用未知设施 %s" % [project_id, facility_id])
			if not (level is int or level is float) or int(level) < 0:
				load_errors.append("工坊项目 %s 设施等级奖励无效" % project_id)

	var content_indexes := {
		"unlocked_card_ids": cards,
		"unlocked_relic_ids": relics,
		"unlocked_potion_ids": potions,
		"unlocked_enchant_ids": enchants,
	}
	for field in content_indexes:
		var values: Variant = grants.get(field, [])
		if not values is Array:
			load_errors.append("工坊项目 %s 的 %s 格式无效" % [project_id, field])
			continue
		for value in values:
			if not content_indexes[field].has(StringName(String(value))):
				load_errors.append("工坊项目 %s 的 %s 引用未知内容 %s" % [project_id, field, value])

	for field in ["unlocked_pre_run_buff_ids", "unlocked_loadout_ids"]:
		var values: Variant = grants.get(field, [])
		if not values is Array:
			load_errors.append("工坊项目 %s 的 %s 格式无效" % [project_id, field])
			continue
		for value in values:
			if String(value).strip_edges().is_empty():
				load_errors.append("工坊项目 %s 的 %s 含空 id" % [project_id, field])

	var stage: Variant = grants.get("town_visual_stage", null)
	if stage != null and (not (stage is int or stage is float) or int(stage) < 0):
		load_errors.append("工坊项目 %s 镇貌阶段奖励无效" % project_id)
	_validate_nullable_nonnegative_number(grants.get("base_run_deck_capacity", null), "%s.grants.base_run_deck_capacity" % project_id, false)


func _validate_ad_economy() -> void:
	if int(ad_economy.get("version", -1)) != 1:
		load_errors.append("ad_economy.json 版本无效")
	var placements: Variant = ad_economy.get("placements", null)
	if not placements is Dictionary:
		load_errors.append("广告位配置格式无效")
		return
	var required_ids := [
		"death_revive",
		"pre_run_buff",
		"shop_refresh",
		"run_end_currency",
		"workshop_speedup",
		"deck_capacity_expand",
	]
	for placement_id in required_ids:
		if not placements.has(placement_id) or not placements[placement_id] is Dictionary:
			load_errors.append("缺少广告位配置：%s" % placement_id)
			continue
		var config: Dictionary = placements[placement_id]
		if not config.get("enabled", null) is bool:
			load_errors.append("广告位 %s enabled 类型无效" % placement_id)
	if placements.has("death_revive"):
		_validate_confirmed_ad_number(placements["death_revive"].get("max_per_run", null), "death_revive.max_per_run", false)
	if placements.has("pre_run_buff"):
		_validate_confirmed_ad_number(placements["pre_run_buff"].get("duration_floors", null), "pre_run_buff.duration_floors", false)
		_validate_nullable_nonnegative_number(placements["pre_run_buff"].get("choice_count", null), "pre_run_buff.choice_count")
		var configured_buff_ids: Variant = placements["pre_run_buff"].get("buff_ids", [])
		if not configured_buff_ids is Array:
			load_errors.append("pre_run_buff.buff_ids 格式无效")
		else:
			for buff_id in configured_buff_ids:
				if not meta_pre_run_buffs.has(StringName(String(buff_id))):
					load_errors.append("pre_run_buff 引用了不存在的 Buff：%s" % buff_id)
	if placements.has("shop_refresh"):
		_validate_confirmed_ad_number(placements["shop_refresh"].get("max_per_shop", null), "shop_refresh.max_per_shop", false)
	if placements.has("run_end_currency"):
		_validate_positive_number(placements["run_end_currency"].get("bonus_multiplier", null), "run_end_currency.bonus_multiplier")
		_validate_confirmed_ad_number(placements["run_end_currency"].get("bonus_cap", null), "run_end_currency.bonus_cap", false)
		if not String(placements["run_end_currency"].get("rounding", "")) in ["floor", "round", "ceil"]:
			load_errors.append("run_end_currency.rounding 无效")
	if placements.has("workshop_speedup"):
		for field in ["seconds_reduced", "max_per_project", "max_per_day"]:
			_validate_confirmed_ad_number(placements["workshop_speedup"].get(field, null), "workshop_speedup.%s" % field, false)
	if placements.has("deck_capacity_expand"):
		for field in ["slots_per_view", "max_per_run"]:
			_validate_confirmed_ad_number(placements["deck_capacity_expand"].get(field, null), "deck_capacity_expand.%s" % field, false)


func _validate_confirmed_ad_number(value: Variant, field: String, allow_zero: bool) -> void:
	if not (value is int or value is float):
		load_errors.append("已确认广告数值缺失或类型无效：%s" % field)
		return
	if (allow_zero and int(value) < 0) or (not allow_zero and int(value) <= 0):
		load_errors.append("已确认广告数值范围无效：%s" % field)


func _validate_positive_number(value: Variant, field: String) -> void:
	if not (value is int or value is float) or float(value) <= 0.0:
		load_errors.append("已确认数值缺失或范围无效：%s" % field)


# ---------- 查询接口 ----------
func get_card(id: StringName) -> CardData:
	return cards.get(id)


func get_enemy(id: StringName) -> EnemyData:
	return enemies.get(id)


func get_status(id: StringName) -> StatusData:
	return statuses.get(id)


func get_relic(id: StringName) -> RelicData:
	return relics.get(id)


func get_minion(id: StringName) -> MinionData:
	return minions.get(id)


func get_potion(id: StringName) -> PotionData:
	return potions.get(id)


func get_enchant(id: StringName) -> EnchantData:
	return enchants.get(id)


func get_meta_facility(id: StringName) -> Dictionary:
	return meta_facilities.get(id, {})


func get_meta_project(id: StringName) -> Dictionary:
	return meta_projects.get(id, {})


func get_pre_run_buff(id: StringName) -> Dictionary:
	return meta_pre_run_buffs.get(id, {})


func meta_facility_list() -> Array:
	return meta_progression.get("facilities", [])


func meta_project_list() -> Array:
	return meta_progression.get("projects", [])


func pre_run_buff_list() -> Array:
	return meta_progression.get("pre_run_buffs", [])


func ad_placement_config(id: StringName) -> Dictionary:
	return ad_economy.get("placements", {}).get(String(id), {})


func is_card_unlocked(id: StringName) -> bool:
	return _is_meta_content_unlocked("card_ids", id, ProfileState.unlocked_card_ids)


func card_taxonomy_name(group: StringName, id: StringName) -> String:
	var entries: Dictionary = card_taxonomy.get(String(group), {})
	return String(entries.get(String(id), String(id)))


func is_relic_unlocked(id: StringName) -> bool:
	return _is_meta_content_unlocked("relic_ids", id, ProfileState.unlocked_relic_ids)


func is_potion_unlocked(id: StringName) -> bool:
	return _is_meta_content_unlocked("potion_ids", id, ProfileState.unlocked_potion_ids)


func is_enchant_unlocked(id: StringName) -> bool:
	return _is_meta_content_unlocked("enchant_ids", id, ProfileState.unlocked_enchant_ids)


func profile_run_start_bonuses() -> Dictionary:
	var resolved := {"max_hp_bonus": 0, "starting_gold_bonus": 0}
	var best_levels: Dictionary = {}
	var best_tiers: Dictionary = {}
	for raw_tier in meta_progression.get("run_start_bonus_tiers", []):
		if not raw_tier is Dictionary:
			continue
		var facility_id := String(raw_tier.get("facility_id", ""))
		var required_level := int(raw_tier.get("required_level", 0))
		var profile_level := int(ProfileState.facility_levels.get(facility_id, 0))
		if required_level <= 0 or profile_level < required_level or required_level <= int(best_levels.get(facility_id, 0)):
			continue
		best_levels[facility_id] = required_level
		best_tiers[facility_id] = raw_tier
	for tier in best_tiers.values():
		resolved["max_hp_bonus"] += int(tier.get("max_hp_bonus", 0))
		resolved["starting_gold_bonus"] += int(tier.get("starting_gold_bonus", 0))
	return resolved


func _is_meta_content_unlocked(config_field: String, id: StringName, profile_unlocks: Array[StringName]) -> bool:
	if id == &"":
		return false
	var initial_unlocks: Variant = meta_progression.get("initial_unlocks", null)
	# 旧配置没有解锁表时保持原有“全部开放”行为，避免测试或旧内容表被意外清空。
	if not initial_unlocks is Dictionary or not initial_unlocks.has(config_field):
		return true
	if profile_unlocks.has(id):
		return true
	for raw_id in initial_unlocks.get(config_field, []):
		if StringName(String(raw_id)) == id:
			return true
	# 数据版本更新后，已完成项目可能新增奖励内容；按当前项目 grants 动态回填资格，
	# 避免老存档因项目不可重复领取而永久错过新卡/遗物/药水/附魔。
	var grant_field := "unlocked_" + config_field
	for completed_id in ProfileState.completed_project_ids:
		var project: Dictionary = meta_projects.get(completed_id, {})
		var grants: Dictionary = project.get("grants", {})
		for raw_id in grants.get(grant_field, []):
			if StringName(String(raw_id)) == id:
				return true
	return false


# ---------- 图标 ----------
## 由 icon id 解析药水 / 附魔 / 遗物资源路径。
func icon_path(icon_id: String) -> String:
	if icon_id == "":
		return ""
	if icon_id.begins_with("ICO_Potion_"):
		return "res://art/icons/potion/" + icon_id + ".png"
	if icon_id.begins_with("ICO_Enchant_"):
		return "res://art/icons/enchant/" + icon_id + ".png"
	if icon_id.begins_with("ICO_Relic_"):
		return "res://art/icons/relic/" + icon_id + ".png"
	return ""


## 加载图标纹理；失败/缺失返回 null，调用方自行处理占位。
func icon_texture(icon_id: String) -> Texture2D:
	var p := icon_path(icon_id)
	if p == "" or not ResourceLoader.exists(p):
		return null
	var tex = load(p)
	if tex is Texture2D:
		return tex as Texture2D
	return null


## 构建一个已配置好的图标 TextureRect（PX×PX，保持透明与比例）。texture 为空时返回无纹理空框。
func icon_rect(icon_id: String, px: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = icon_texture(icon_id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tr


# ---------- 事件 ----------
func get_event(index: int) -> Dictionary:
	if index >= 0 and index < events.size():
		return events[index]
	return {}


func events_for_act(act_number: int) -> Array:
	var pool: Array = []
	for event_data in events:
		var event_acts = event_data.get("acts", [])
		if event_acts is Array:
			for configured_act in event_acts:
				if int(configured_act) == act_number:
					pool.append(event_data)
					break
	return pool


func random_event(act_number: int = -1) -> Dictionary:
	var resolved_act := act_number if act_number > 0 else RunState.current_act + 1
	var pool := events_for_act(resolved_act)
	if pool.is_empty():
		return {}
	return pool[randi_range(0, pool.size() - 1)]


func get_cards_by_rarity(rarity: StringName) -> Array[CardData]:
	var out: Array[CardData] = []
	for c in cards.values():
		if c.rarity == rarity:
			out.append(c)
	return out


func get_enemies_by_tier(tier: StringName) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for e in enemies.values():
		if e.tier == tier:
			out.append(e)
	return out


## 多敌编成表：返回在指定层（含 min/max 区间）可用的编成列表（按 weight 加权）。
## P-D：带 acts 字段的编成仅在对应幕可用（缺省=全幕可用，向后兼容）。
## 注意：JSON 数字解析为 float，acts 匹配必须数值比较（Array.has 对 int/float 不宽容）。
## act<=0 表示未指定幕（旧调用方），跳过幕过滤。
func get_formations_for_floor(floor: int, act: int = 0) -> Array:
	var out: Array = []
	for fm in formations:
		if not (fm is Dictionary):
			continue
		if act > 0:
			var acts: Array = fm.get("acts", [])
			if not acts.is_empty():
				var in_act := false
				for a in acts:
					if int(a) == act:
						in_act = true
						break
				if not in_act:
					continue
		var lo: int = int(fm.get("min_floor", 0))
		var hi: int = int(fm.get("max_floor", 999))
		if floor >= lo and floor <= hi:
			out.append(fm)
	return out


# ---------- 难度系数（全局 balance.enemy_scaling × 当前幕 act mult，P-D） ----------
func scaled_enemy_hp(base_hp: int) -> int:
	var m: float = balance.get("enemy_scaling", {}).get("hp_multiplier", 1.0)
	return maxi(1, int(round(base_hp * m * _current_act_mult("act_hp_mult"))))


func scaled_enemy_damage(base_damage: int) -> int:
	var m: float = balance.get("enemy_scaling", {}).get("damage_multiplier", 1.0)
	return maxi(0, int(round(base_damage * m * _current_act_mult("act_dmg_mult"))))


## 当前幕局部乘子（P-D 幕缩放）：仅活跃局中生效，否则恒 1.0（无局/编辑器测试不受影响）。
func _current_act_mult(key: String) -> float:
	if RunState == null or not RunState.is_active:
		return 1.0
	var cfg: Dictionary = RunState.current_act_config()
	return float(cfg.get(key, 1.0))


func max_enemies_per_combat() -> int:
	return int(balance.get("enemy_scaling", {}).get("max_enemies_per_combat", 2))


func player_config() -> Dictionary:
	return balance.get("player", {})
