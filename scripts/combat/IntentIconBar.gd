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
					next_value = controller.enemy_preview_outgoing(unit, next_value)
			entries.append(["attack" if next_kind == "aoe_debuff" else next_kind, _number(next_value, int(next.get("times", 1))), "下回合释放"])
	else:
		if kind in ["attack", "aoe_debuff"] and controller != null:
			value = controller.enemy_preview_outgoing(unit, value)
		entries.append(["attack" if kind == "aoe_debuff" else kind, "" if kind == "unknown" else _number(value, times), description])
		if kind == "aoe_debuff":
			entries.append(["debuff", "", "群体减益"])
	var gold := int(move.get("gold_steal", 0))
	if bool(move.get("cleanse", false)):
		entries.append(["buff", "净化", "本回合不攻击；清除自身减益及负力量，再进行强化"])
	if gold > 0:
		entries.append(["steal", str(gold), "抢夺 %d 金币" % gold])
	if unit.block_break_next != &"":
		entries.append(["interrupt", "", "打掉格挡可打断"])
	for effect in move.get("after_effects", []):
		match String(effect.get("kind", "")):
			"status":
				var status := GameData.get_status(StringName(effect.get("status", "")))
				var label: String = status.name if status != null else String(effect.get("status", ""))
				entries.append(["debuff", "%s%d" % [label, int(effect.get("value", 0))], "攻击后施加%s，格挡不能阻止" % label])
			"block":
				entries.append(["defend", str(int(effect.get("value", 0))), "攻击后获得格挡"])
			"add_card":
				var card := GameData.get_card(StringName(effect.get("card_id", "")))
				var label: String = card.name if card != null else String(effect.get("card_id", ""))
				entries.append(["debuff", "%s%d" % [label, int(effect.get("count", 0))], "攻击后加入本场%s牌堆" % String(effect.get("pile", "discard")).replace("discard", "弃")])
			"rally":
				entries.append(["buff", "全队+%d" % int(effect.strength), "所有存活敌人永久获得力量"])
				entries.append(["defend", "随从%d" % int(effect.escort_block), "存活随从获得格挡，保留至下个玩家回合"])
			"recruit":
				entries.append(["buff", "补兵", "补满编队；新随从下个敌方回合开始行动"])
			"self_destruct":
				entries.append(["debuff", "自毁", "本次攻击后死亡；提前击杀不会爆炸"])
	if move.has("if_missing"):
		entries.append(["buff", "缺员补兵", "缺员时本次不攻击，改为补兵；满员才攻击"])
	if unit.data != null:
		if unit.data.effective_stats:
			description += "\n" + unit.data.combat_hint
		var escort_rules: Dictionary = unit.data.escort_rules
		var leader_alive := controller != null and unit.leader_index >= 0 and unit.leader_index < controller.enemies.size() and controller.enemies[unit.leader_index].is_alive()
		if escort_rules.has("protect_leader_attack_mult") and leader_alive:
			entries.append(["defend", "护主%d%%" % roundi((1.0 - float(escort_rules.protect_leader_attack_mult)) * 100.0), "主怪攻击承伤减少；击杀护卫解除"])
		if escort_rules.has("react_card_type") and (escort_rules.get("react_target", "self") != "leader" or leader_alive):
			var card_type := "技能" if escort_rules.react_card_type == "skill" else "能力"
			entries.append(["buff", "%s+%d" % [card_type, int(escort_rules.react_strength)], unit.data.combat_hint])
		if unit.leader_index >= 0 and controller != null and unit.can_act_from_turn > controller.turn:
			entries.append(["charge", "下回合行动", "新补充随从本回合不行动"])
		if unit.leader_index >= 0 and String(move.get("id", "")) != "detonate":
			var following: Dictionary = unit.data.find_move(StringName(move.get("next", "")))
			if following.get("id", "") == "detonate":
				entries.append(["charge", "下次自爆", "本次行动后进入自爆意图；爆炸值与段数届时公开"])
	if unit.data != null and not unit.data.boss_rules.is_empty():
		var rules: Dictionary = unit.data.boss_rules
		var every := int(rules.get("growth_every", 0))
		if every > 0:
			entries.append(["buff", "蓄势%d/%d" % [unit.enemy_actions % every, every], "每行动%d次永久获得%d力量；下次成长还需%d次行动" % [every, int(rules.get("growth_strength", 0)), every - unit.enemy_actions % every]])
		var reactive: int = unit.data.power_response_strength(unit.phase_index)
		var regen := int(rules.get("regeneration", 0))
		if reactive > 0:
			entries.append(["buff", "反制%d·回复%d" % [reactive, regen], "每打出能力牌使Boss获得%d力量；每次行动前回复%d生命" % [reactive, regen]])
		elif regen > 0:
			entries.append(["buff", "回复%d" % regen, "每次行动前回复%d生命；能力牌反制已停止" % regen])
	if unit.data != null and not unit.data.effective_stats:
		description += "\n" + unit.data.combat_hint
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
