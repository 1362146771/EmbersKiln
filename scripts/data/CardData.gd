class_name CardData
extends Resource
## 卡牌数据（只读运行时镜像）。数值全部来自 res://data/cards.json，禁止在此硬编码。

@export var id: StringName = &""
@export var name: String = ""
@export var type: StringName = &"attack"        # attack / skill / power
@export var cost: int = 1
@export var rarity: StringName = &"common"      # starter / common / uncommon / rare / special
@export var target: StringName = &"enemy"       # enemy / self / all_enemies / none
@export var exhaust: bool = false
@export var ethereal: bool = false
@export var innate: bool = false
@export var playable: bool = true
@export var repeatable_upgrade: bool = false
@export var description: String = ""
@export var upgrade_description: String = ""
@export var art: String = ""
@export var build_tags: Array[StringName] = []
@export var mechanics: Array[StringName] = []
@export var tags: Array[StringName] = []
var cost_rule: Dictionary = {}
var play_condition: Dictionary = {}
var end_turn_effects: Array = []
var on_exhaust_effects: Array = []
var upgrade_data: Dictionary = {}

## effects / upgrade_effects 保持 Dictionary 数组：结构由 JSON 定义，
## CombatController 按 kind 分派。新增效果类型只需改 JSON + 分派表，不改此类。
var effects: Array = []
var upgrade_effects: Array = []


static func from_dict(d: Dictionary) -> CardData:
	var c := CardData.new()
	c.id = StringName(d.get("id", ""))
	c.name = d.get("name", "")
	c.type = StringName(d.get("type", "attack"))
	c.cost = int(d.get("cost", 1))
	c.rarity = StringName(d.get("rarity", "common"))
	c.target = StringName(d.get("target", "enemy"))
	c.exhaust = bool(d.get("exhaust", false))
	c.ethereal = bool(d.get("ethereal", false))
	c.innate = bool(d.get("innate", false))
	c.playable = bool(d.get("playable", true))
	c.repeatable_upgrade = bool(d.get("repeatable_upgrade", false))
	c.description = d.get("description", "")
	c.upgrade_description = d.get("upgrade_description", "")
	c.art = d.get("art", "")
	for t in d.get("build", []):
		c.build_tags.append(StringName(t))
	for mechanic in d.get("mechanics", []):
		c.mechanics.append(StringName(mechanic))
	for tag in d.get("tags", []):
		c.tags.append(StringName(tag))
	c.effects = d.get("effects", [])
	c.cost_rule = d.get("cost_rule", {}).duplicate(true)
	c.play_condition = d.get("play_condition", {}).duplicate(true)
	c.end_turn_effects = d.get("end_turn_effects", []).duplicate(true)
	c.on_exhaust_effects = d.get("on_exhaust_effects", []).duplicate(true)
	c.upgrade_data = d.get("upgrade", {}).duplicate(true)
	c.upgrade_description = String(c.upgrade_data.get("description", c.upgrade_description))
	c.upgrade_effects = c.upgrade_data.get("effects", [])
	return c


## 升级后取用的效果表；无升级数据时回退到基础效果。
func get_effects(upgrade_state: Variant) -> Array:
	var level := upgrade_level_from(upgrade_state)
	if level <= 0:
		return effects
	if repeatable_upgrade:
		var resolved := effects.duplicate(true)
		var first_increment := int(upgrade_data.get("first_damage_increment", 0))
		var increment_growth := int(upgrade_data.get("damage_increment_growth", 0))
		var total_increment := level * first_increment + int(level * (level - 1) / 2.0) * increment_growth
		for effect in resolved:
			if effect is Dictionary and String(effect.get("kind", "")) in ["damage", "aoe_damage"]:
				effect["value"] = int(effect.get("value", 0)) + total_increment
				break
		return resolved
	if not upgrade_effects.is_empty():
		return upgrade_effects
	return effects


func get_description(upgrade_state: Variant) -> String:
	var level := upgrade_level_from(upgrade_state)
	if level <= 0:
		return description
	if repeatable_upgrade:
		var resolved_effects := get_effects(level)
		for effect in resolved_effects:
			if effect is Dictionary and String(effect.get("kind", "")) == "damage":
				return "造成 %d 点伤害。可被重复升级。" % int(effect.get("value", 0))
	if upgrade_description != "":
		return upgrade_description
	return description


func has_upgrade() -> bool:
	return repeatable_upgrade or not upgrade_effects.is_empty() or upgrade_data.has("cost") or upgrade_data.has("innate") or upgrade_data.has("exhaust")


func upgrade_level_from(upgrade_state: Variant) -> int:
	if upgrade_state is bool:
		return 1 if upgrade_state else 0
	return maxi(0, int(upgrade_state))


func resolved_cost(upgrade_state: Variant) -> int:
	if upgrade_level_from(upgrade_state) > 0 and upgrade_data.has("cost"):
		return int(upgrade_data["cost"])
	return cost


func is_innate(upgrade_state: Variant) -> bool:
	return innate or (upgrade_level_from(upgrade_state) > 0 and bool(upgrade_data.get("innate", false)))


func is_ethereal(upgrade_state: Variant) -> bool:
	if upgrade_level_from(upgrade_state) > 0 and upgrade_data.has("ethereal"):
		return bool(upgrade_data["ethereal"])
	return ethereal


func exhausts_on_play(upgrade_state: Variant) -> bool:
	if upgrade_level_from(upgrade_state) > 0 and upgrade_data.has("exhaust"):
		return bool(upgrade_data["exhaust"])
	return exhaust


func get_on_exhaust_effects(upgrade_state: Variant) -> Array:
	if upgrade_level_from(upgrade_state) > 0 and upgrade_data.has("on_exhaust_effects"):
		return upgrade_data["on_exhaust_effects"]
	return on_exhaust_effects
