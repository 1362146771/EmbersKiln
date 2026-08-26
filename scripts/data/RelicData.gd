class_name RelicData
extends Resource
## 遗物定义。trigger 决定挂在哪个 SignalBus 事件上。

@export var id: StringName = &""
@export var name: String = ""
@export var rarity: StringName = &"common"     # starter / common / uncommon / rare
@export var trigger: StringName = &""
@export var effect: StringName = &""
@export var value: int = 0
@export var effect_flat: int = 0
@export var description: String = ""
@export var icon: String = ""


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
	return r


func is_starter() -> bool:
	return rarity == &"starter"
