class_name EnchantData
extends Resource
## 附魔定义（只读运行时镜像）。数值全部来自 res://data/enchants.json，禁止在此硬编码。
## 附魔是卡牌的第二定制层，加法叠加于「升级」之上，进入长期牌组永久保留（单卡 ≤1）。

@export var id: StringName = &""
@export var name: String = ""
@export var rarity: StringName = &"common"      # common / uncommon / rare
@export var description: String = ""
@export var icon: String = ""

## restriction / mods / condition 保持 Dictionary：结构由 JSON 定义，结算管线按字段读取。
var restriction: Dictionary = {}   # { card_type: [attack/skill/power] }，空=任意
var mods: Dictionary = {}          # { damage_bonus / block_bonus / aoe_damage_bonus / draw_bonus / heal_bonus / extra_effects:[] }
var condition: Dictionary = {}     # { min_cost: int }


static func from_dict(d: Dictionary) -> EnchantData:
	var e := EnchantData.new()
	e.id = StringName(d.get("id", ""))
	e.name = d.get("name", "")
	e.rarity = StringName(d.get("rarity", "common"))
	e.description = d.get("description", "")
	e.icon = d.get("icon", "")
	e.restriction = d.get("restriction", {})
	e.mods = d.get("mods", {})
	e.condition = d.get("condition", {})
	return e


## 该附魔能否贴到这张卡（restriction.card_type 为空=任意卡型）。
func matches_card(cd: CardData) -> bool:
	var types: Array = restriction.get("card_type", [])
	if types.is_empty():
		return true
	return types.has(cd.type)


## 触发前置条件（如 min_cost）是否满足。不满足则该附魔本次打出不生效。
func meets_condition(card_cost: int) -> bool:
	var mc: int = int(condition.get("min_cost", 0))
	return card_cost >= mc
