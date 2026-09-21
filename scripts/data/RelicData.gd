class_name RelicData
extends Resource
## 遗物定义。trigger 决定挂在哪个 SignalBus 事件上。

@export var id: StringName = &""
@export var name: String = ""
@export var rarity: StringName = &"common"     # common / uncommon / rare / boss；starter 仅为历史保留分类，不自动发放
@export var trigger: StringName = &""
@export var effect: StringName = &""
@export var value: int = 0
@export var effect_flat: int = 0
@export var description: String = ""
@export var icon: String = ""
@export var energy_bonus: int = 0
@export var drawback: StringName = &""
@export var drawback_value: int = 0
@export var drawback_card: StringName = &""


static func from_dict(d: Dictionary) -> RelicData:
	var r := RelicData.new()
	r.id = StringName(d.get("id", ""))
	r.name = d.get("name", "")
	r.rarity = StringName(d.get("rarity", "common"))
	r.trigger = StringName(d.get("trigger", ""))
	r.effect = StringName(d.get("effect", ""))
	r.value = int(d.get("value", 0))
	r.effect_flat = int(d.get("effect_flat", 0))
	r.description = d.get("description", "")
	r.icon = d.get("icon", "")
	r.energy_bonus = int(d.get("energy_bonus", 0))
	r.drawback = StringName(d.get("drawback", ""))
	r.drawback_value = int(d.get("drawback_value", 0))
	r.drawback_card = StringName(d.get("drawback_card", ""))
	return r
