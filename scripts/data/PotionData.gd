class_name PotionData
extends Resource
## 药水定义（只读运行时镜像）。数值全部来自 res://data/potions.json，禁止在此硬编码。

@export var id: StringName = &""
@export var name: String = ""
@export var rarity: StringName = &"common"      # common / uncommon / rare
@export var target: StringName = &"self"        # self / enemy / all_enemies
@export var combat_only: bool = true
@export var exhaust: bool = true
@export var description: String = ""
@export var icon: String = ""

## effects 保持 Dictionary 数组：结构由 JSON 定义，CombatController 按 kind 分派。
var effects: Array = []


static func from_dict(d: Dictionary) -> PotionData:
	var p := PotionData.new()
	p.id = StringName(d.get("id", ""))
	p.name = d.get("name", "")
	p.rarity = StringName(d.get("rarity", "common"))
	p.target = StringName(d.get("target", "self"))
	p.combat_only = bool(d.get("combat_only", true))
	p.exhaust = bool(d.get("exhaust", true))
	p.description = d.get("description", "")
	p.icon = d.get("icon", "")
	p.effects = d.get("effects", [])
	return p


## 是否为「持续型」药水（效果含施加状态者）。
## 即时型（heal / block / damage / draw / energy / aoe_damage）饮用即结算、无残留，
## 仅作效果分类；持续型也允许同类叠加、异类共存，不限制饮用。
func is_persistent() -> bool:
	for eff in effects:
		if not (eff is Dictionary):
			continue
		var k: String = eff.get("kind", "")
		if k == "apply_status" or k == "gain_strength" or k == "gain_dexterity" or k == "gain_kiln_heat":
			return true
	return false
