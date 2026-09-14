extends HFlowContainer
## 意图只读取当前已滚动招式；伤害预览调用战斗控制器，不改玩法。
const BADGE := preload("res://scenes/combat/IntentBadge.tscn")
const ICONS := {
	"attack": "Attack", "defend": "Defend", "buff": "Buff", "debuff": "Debuff",
	"charge": "Charge", "steal": "Steal", "unknown": "Unknown", "interrupt": "Interrupt"
}
var _signature := ""

func set_unit(unit: CombatUnit, controller: CombatController, description: String) -> void:
	var entries: Array = []
	var move: Dictionary = unit.intent
	var kind: String = move.get("intent", "unknown")
	var value := int(move.get("value", 0))
	var times := int(move.get("times", 1))
	if kind == "charge":
		entries.append(["charge", "", "蓄力：下回合释放"])
		if value > 0:
			entries.append(["defend", str(value), "本回合获得格挡"])
		if unit.data != null:
			var next: Dictionary = unit.data.find_move(StringName(move.get("next", "")))
			var next_kind: String = next.get("intent", "unknown")
			var next_value := int(next.get("value", 0))
			if next_kind in ["attack", "aoe_debuff"]:
				next_value = GameData.scaled_enemy_damage(next_value, unit.data.tier)
				if controller != null:
					next_value = controller.enemy_outgoing(unit, next_value)
			entries.append(["attack" if next_kind == "aoe_debuff" else next_kind, _number(next_value, int(next.get("times", 1))), "下回合释放"])
	else:
		if kind in ["attack", "aoe_debuff"] and controller != null:
			value = controller.enemy_outgoing(unit, value)
		entries.append(["attack" if kind == "aoe_debuff" else kind, "" if kind == "unknown" else _number(value, times), description])
		if kind == "aoe_debuff":
			entries.append(["debuff", "", "群体减益"])
	var gold := int(move.get("gold_steal", 0))
	if gold > 0:
		entries.append(["steal", str(gold), "抢夺 %d 金币" % gold])
	if unit.block_break_next != &"":
		entries.append(["interrupt", "", "打掉格挡可打断"])
	tooltip_text = description
	var signature := JSON.stringify(entries)
	if signature == _signature:
		return
	_signature = signature
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for entry in entries:
		var badge := BADGE.instantiate()
		badge.set_meta("intent_kind", entry[0])
		badge.tooltip_text = entry[2] + "\n" + description
		badge.get_node("Icon").texture = load("res://art/icons/intent/ICO_Intent_%s.png" % ICONS.get(entry[0], "Unknown"))
		badge.get_node("Value").text = entry[1]
		badge.get_node("Value").visible = not String(entry[1]).is_empty()
		add_child(badge)

func _number(value: int, times: int) -> String:
	return "%d×%d" % [value, times] if times > 1 else str(value)
