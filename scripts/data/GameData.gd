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
}

var cards: Dictionary = {}      # StringName -> CardData
var enemies: Dictionary = {}    # StringName -> EnemyData
var statuses: Dictionary = {}   # StringName -> StatusData
var relics: Dictionary = {}     # StringName -> RelicData
var minions: Dictionary = {}      # StringName -> MinionData
var potions: Dictionary = {}     # StringName -> PotionData
var enchants: Dictionary = {}    # StringName -> EnchantData
var effect_kinds: Array = []     # cards.json 顶层 effect_kinds（用于交叉校验）
var map_config: Dictionary = {}
var act_configs: Array = []      # Array[Dictionary] —— 多幕配置（map.json 的 acts 数组）
var balance: Dictionary = {}
var events: Array = []          # Array[Dictionary] —— 事件表（标题/描述/选项/后果）
var formations: Array = []      # Array[Dictionary] —— 多敌编成表（见 map.json）

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
	events.clear()
	formations.clear()

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

	for ev in raw["events"].get("events", []):
		events.append(ev)

	_validate()

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
	for cid in cards:
		var c: CardData = cards[cid]
		for eff in c.effects + c.upgrade_effects:
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
	for ev in events:
		if not (ev is Dictionary) or ev.get("title", "") == "":
			load_errors.append("事件缺少 title：%s" % str(ev))
			continue
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


func random_event() -> Dictionary:
	if events.is_empty():
		return {}
	return events[randi_range(0, events.size() - 1)]


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
