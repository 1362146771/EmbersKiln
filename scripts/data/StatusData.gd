class_name StatusData
extends Resource
## 状态（Buff / Debuff）定义。v2 命名：炽热/塑形/釉裂/受潮/灰蚀/回火。

@export var id: StringName = &""
@export var name: String = ""
@export var type: StringName = &"buff"        # buff / debuff
@export var stacks: bool = true
@export var decay: bool = false
@export var decay_per_turn: int = 0
@export var trigger: StringName = &""          # turn_start / turn_end / 空
@export var applies_to: StringName = &"player_and_enemy"
@export var effect: String = ""
@export var icon: String = ""


static func from_dict(d: Dictionary) -> StatusData:
	var s := StatusData.new()
	s.id = StringName(d.get("id", ""))
	s.name = d.get("name", "")
	s.type = StringName(d.get("type", "buff"))
	s.stacks = bool(d.get("stacks", true))
	s.decay = bool(d.get("decay", false))
	s.decay_per_turn = int(d.get("decay_per_turn", 0))
	s.trigger = StringName(d.get("trigger", ""))
	s.applies_to = StringName(d.get("applies_to", "player_and_enemy"))
	s.effect = d.get("effect", "")
	s.icon = d.get("icon", "")
	return s


func is_debuff() -> bool:
	return type == &"debuff"
