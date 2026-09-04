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
@export var description: String = ""
@export var upgrade_description: String = ""
@export var art: String = ""
@export var build_tags: Array[StringName] = []
@export var mechanics: Array[StringName] = []

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
	c.description = d.get("description", "")
	c.upgrade_description = d.get("upgrade_description", "")
	c.art = d.get("art", "")
	for t in d.get("build", []):
		c.build_tags.append(StringName(t))
	for mechanic in d.get("mechanics", []):
		c.mechanics.append(StringName(mechanic))
	c.effects = d.get("effects", [])
	var up: Dictionary = d.get("upgrade", {})
	c.upgrade_effects = up.get("effects", [])
	return c


## 升级后取用的效果表；无升级数据时回退到基础效果。
func get_effects(upgraded: bool) -> Array:
	if upgraded and not upgrade_effects.is_empty():
		return upgrade_effects
	return effects


func get_description(upgraded: bool) -> String:
	if upgraded and upgrade_description != "":
		return upgrade_description
	return description


func has_upgrade() -> bool:
	return not upgrade_effects.is_empty()
