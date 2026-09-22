extends HFlowContainer
## 意图只读取当前已滚动招式；伤害预览调用战斗控制器，不改玩法。
const BADGE := preload("res://scenes/combat/IntentBadge.tscn")
const ICON_INFO := preload("res://scripts/ui/CombatIconInfo.gd")
const TITLES := {"attack":"攻击", "defend":"格挡", "buff":"强化", "debuff":"施加减益", "charge":"蓄力", "steal":"掠夺", "unknown":"特殊行动", "interrupt":"可打断"}
const SPECIAL_TITLES := {
	"backlash":"灰火反冲", "vent":"换气 · 反冲暂停", "growth":"蓄势成长", "guard":"护主",
	"skill_watch":"技能监视", "power_watch":"能力反制", "regeneration":"持续回复",
	"cleanse":"净化", "rally":"号令", "recruit":"补兵", "self_destruct":"自爆",
	"arrival":"新援待命", "wound_card":"塞入伤口", "dazed_card":"塞入晕眩",
	"breakable_charge":"破盾打断", "plunder":"掠夺"
}
const ICONS := {
	"attack": "Attack", "defend": "Defend", "buff": "Buff", "debuff": "Debuff",
	"charge": "Charge", "steal": "Steal", "unknown": "Unknown", "interrupt": "Interrupt"
}
## 专属机制只改变视图；触发条件与数值仍读取真实招式 / 敌人配置。
const SPECIAL_ICONS := {
	"backlash": "Backlash", "vent": "Vent", "growth": "Growth", "guard": "Guard",
	"skill_watch": "SkillWatch", "power_watch": "PowerWatch", "regeneration": "Regeneration",
	"cleanse": "Cleanse", "rally": "Rally", "recruit": "Recruit", "self_destruct": "SelfDestruct",
	"arrival": "Arrival", "wound_card": "WoundCard", "dazed_card": "DazedCard",
	"breakable_charge": "BreakableCharge", "plunder": "Plunder"
}
var _signature := ""

func set_unit(unit: CombatUnit, controller: CombatController, _description: String) -> void:
	var entries: Array = []
	var move: Dictionary = unit.intent
	var kind: String = move.get("intent", "unknown")
	var value := int(move.get("value", 0))
	var times := int(move.get("times", 1))
	if kind == "charge":
		entries.append(["charge", "", "本回合蓄力，下回合释放已预告的招式。"])
		if value > 0:
			entries.append(["defend", str(value), "本回合获得 %d 点格挡。" % value])
		if unit.data != null:
			var next: Dictionary = unit.data.find_move(StringName(move.get("next", "")))
			var next_kind: String = next.get("intent", "unknown")
			var next_value := int(next.get("value", 0))
			if next_kind in ["attack", "aoe_debuff"]:
				if not unit.data.effective_stats and not bool(next.get("effective_stats", false)):
					next_value = GameData.scaled_enemy_damage(next_value, unit.data.tier)
				next_value += DifficultyRules.attack_bonus(unit.data.tier, next)
				if controller != null:
					next_value = controller.enemy_preview_outgoing(unit, next_value)
			entries.append(["attack" if next_kind == "aoe_debuff" else next_kind, _number(next_value, int(next.get("times", 1))), "下回合释放：\n" + _move_description(next, next_value, int(next.get("times", 1)))])
	else:
		if kind in ["attack", "aoe_debuff"] and controller != null:
			value = controller.enemy_preview_outgoing(unit, value)
		var move_icon := _move_icon(move)
		# 号令 / 补兵在下方带真实效果说明，不额外显示空白或零值图标。
		if move_icon not in ["rally", "recruit"]:
			entries.append(["attack" if kind == "aoe_debuff" else kind, "" if kind == "unknown" else _number(value, times), _move_description(move, value, times), "", _move_title(move)])
		if kind == "aoe_debuff":
			entries.append(["debuff", "", "本次行动同时施加减益；各效果可分别查看。", "", "复合减益"])
	var gold := int(move.get("gold_steal", 0))
	if bool(move.get("cleanse", false)):
		entries.append(["buff", "", "本回合清除自身所有减益与负层数属性。\n已有的正面状态保留。", "cleanse"])
	if gold > 0:
		entries.append(["steal", str(gold), "本次攻击抢走至多 %d 金币。\n击败此敌人并赢得战斗后，找回实际被抢走的金币。" % gold, "plunder"])
	if unit.block_break_next != &"":
		entries.append(["interrupt", "", "以伤害打掉此敌人的全部格挡，即可打断正在准备的招式。\n回合切换时自然清空格挡不会触发。", "breakable_charge"])
	for effect in move.get("after_effects", []):
		match String(effect.get("kind", "")):
			"status":
				var status := GameData.get_status(StringName(effect.get("status", "")))
				var label: String = status.name if status != null else String(effect.get("status", ""))
				var to_self: bool = effect.get("target", "player") == "self"
				var amount := int(effect.get("value", 0))
				var body := "行动后，%s获得 %d 层%s。" % ["自身" if to_self else "玩家", amount, label]
				if not to_self: body += "格挡不能阻止施加。"
				if status != null: body += "\n" + status.effect
				entries.append(["buff" if to_self else "debuff", str(amount), body, "", label])
			"block":
				entries.append(["defend", str(int(effect.get("value", 0))), "攻击结束后，自身获得 %d 点格挡。" % int(effect.get("value", 0))])
			"add_card":
				var card := GameData.get_card(StringName(effect.get("card_id", "")))
				var label: String = card.name if card != null else String(effect.get("card_id", ""))
				var pile_name: String = {"discard":"弃牌堆", "draw":"抽牌堆", "hand":"手牌"}.get(String(effect.get("pile", "discard")), String(effect.get("pile", "discard")))
				entries.append(["debuff", str(int(effect.get("count", 0))), "行动后，将 %d 张%s加入玩家的%s。\n仅在本场战斗生效。" % [int(effect.get("count", 0)), label, pile_name], "dazed_card" if effect.get("card_id", "") == "dazed" else "wound_card"])
			"rally":
				entries.append(["buff", str(int(effect.strength)), "本次行动使所有存活敌人获得 %d 层力量。\n持续到本场战斗结束。" % int(effect.strength), "rally"])
				entries.append(["defend", str(int(effect.escort_block)), "本次行动使存活随从获得 %d 点格挡。\n保留至下个玩家回合。" % int(effect.escort_block), "", "随从格挡"])
			"recruit":
				entries.append(["buff", "", "本次行动补满编队中已阵亡的随从。\n新随从从下个敌方回合开始行动。", "recruit"])
			"self_destruct":
				entries.append(["debuff", "", "完成本次攻击后，此随从死亡。\n攻击可以格挡；提前击杀随从不会触发爆炸。", "self_destruct"])
	if move.has("if_missing") and not entries.any(func(entry): return entry.size() > 3 and entry[3] == "recruit"):
		entries.append(["buff", "", "若有随从阵亡，本次行动改为补兵，不攻击。\n编队满员时才执行攻击。", "recruit"])
	if unit.data != null:
		var escort_rules: Dictionary = unit.data.escort_rules
		var leader_alive := controller != null and unit.leader_index >= 0 and unit.leader_index < controller.enemies.size() and controller.enemies[unit.leader_index].is_alive()
		if escort_rules.has("protect_leader_attack_mult") and leader_alive:
			var reduction := roundi((1.0 - float(escort_rules.protect_leader_attack_mult)) * 100.0)
			entries.append(["defend", "%d%%" % reduction, "此护卫存活时，主怪受到的攻击伤害减少 %d%%。\n先减伤，再扣格挡；不影响直接伤害或失血。击杀护卫后解除。" % reduction, "guard"])
		if escort_rules.has("react_card_type") and (escort_rules.get("react_target", "self") != "leader" or leader_alive):
			var card_type := "技能" if escort_rules.react_card_type == "skill" else "能力"
			var target := "主怪" if escort_rules.get("react_target", "self") == "leader" else "此敌人"
			entries.append(["buff", str(int(escort_rules.react_strength)), "每当玩家实际打出一张%s牌，%s获得 %d 层力量，包括自动出牌。\n监视者死亡后停止触发，已获得的力量保留。" % [card_type, target, int(escort_rules.react_strength)], "skill_watch" if escort_rules.react_card_type == "skill" else "power_watch"])
		if unit.leader_index >= 0 and controller != null and unit.can_act_from_turn > controller.turn:
			entries.append(["charge", "", "此随从刚加入战斗，本回合不行动。\n从下个敌方回合开始行动。", "arrival"])
		if unit.leader_index >= 0 and String(move.get("id", "")) != "detonate":
			var following: Dictionary = unit.data.find_move(StringName(move.get("next", "")))
			if following.get("id", "") == "detonate":
				entries.append(["charge", "", "完成本次行动后，将准备自爆。\n下次意图公布爆炸伤害与段数；提前击杀不会爆炸。", "self_destruct"])
	if unit.data != null and not unit.data.boss_rules.is_empty():
		var rules: Dictionary = unit.data.boss_rules
		if rules.has("backlash_damage"):
			var remaining := maxi(0, int(rules.backlash_raw_cap) - unit.ash_backlash_used)
			var backlash_body := "每当玩家打出一张牌并完成结算，受到 %d 点反冲伤害，可以格挡。\n每回合最多造成 %d 点原始伤害，本回合还可造成 %d 点。\n换气期间暂停触发。" % [int(rules.backlash_damage), int(rules.backlash_raw_cap), remaining]
			entries.append(["debuff" if unit.ash_sealed else "buff", str(int(rules.backlash_damage)) if unit.ash_sealed else "", backlash_body if unit.ash_sealed else "当前未封焰，出牌不会触发灰火反冲。\n下次封焰生效后，恢复出牌反冲。", "backlash" if unit.ash_sealed else "vent"])
			if String(move.get("id", "")) == "seal" and controller != null:
				var amount := mini(int(rules.ash_cards_per_seal), maxi(0, int(rules.ash_live_cap) - controller._binder.live_ash(unit)))
				entries.append(["debuff", str(amount), "封焰生效后，将 %d 张晕眩加入玩家弃牌堆。\n此敌人生成的晕眩，在手牌、抽牌堆和弃牌堆中合计最多 %d 张。" % [amount, int(rules.ash_live_cap)], "dazed_card"])
		var every := int(rules.get("growth_every", 0))
		if every > 0:
			entries.append(["buff", "%d/%d" % [unit.enemy_actions % every, every], "每完成 %d 次行动，自身获得 %d 层力量，持续到战斗结束。\n当前进度 %d/%d；再行动 %d 次后触发。" % [every, int(rules.get("growth_strength", 0)), unit.enemy_actions % every, every, every - unit.enemy_actions % every], "growth"])
		var reactive: int = unit.data.power_response_strength(unit.phase_index)
		var regen := int(rules.get("regeneration", 0))
		if reactive > 0:
			entries.append(["buff", str(reactive), "每当玩家实际打出一张能力牌，此首领获得 %d 层力量，包括自动出牌。\n进入后续阶段后停止触发，已获得的力量保留。" % reactive, "power_watch"])
		if regen > 0:
			entries.append(["buff", str(regen), "每次行动前，自身回复 %d 点生命。\n回复不会超过最大生命，也不会退回先前阶段。" % regen, "regeneration"])
	# The bar itself has no catch-all tooltip; each badge owns only its effect.
	tooltip_text = ""
	var signature := JSON.stringify(entries)
	if signature == _signature:
		return
	_signature = signature
	while get_child_count() > entries.size():
		var child := get_child(get_child_count() - 1)
		remove_child(child)
		child.queue_free()
	for index in entries.size():
		var entry: Array = entries[index]
		var badge: Control
		if index < get_child_count():
			badge = get_child(index)
		else:
			badge = BADGE.instantiate()
			add_child(badge)
		badge.set_meta("intent_kind", entry[0])
		var special: String = entry[3] if entry.size() > 3 else ""
		badge.set_meta("special_effect", special)
		badge.get_node("Icon").texture = load("res://art/icons/enemy_special/ICO_Enemy_%s.png" % SPECIAL_ICONS[special]) if SPECIAL_ICONS.has(special) else load("res://art/icons/intent/ICO_Intent_%s.png" % ICONS.get(entry[0], "Unknown"))
		badge.get_node("Value").text = entry[1]
		badge.get_node("Value").visible = not String(entry[1]).is_empty()
		var title: String = entry[4] if entry.size() > 4 else SPECIAL_TITLES.get(special, TITLES.get(entry[0], "特殊行动"))
		ICON_INFO.configure(badge, title, entry[2], badge.get_node("Icon").texture)

func _number(value: int, times: int) -> String:
	return "%d×%d" % [value, times] if times > 1 else str(value)

func _move_icon(move: Dictionary) -> String:
	# 普通攻击 / 格挡 / 状态仍保留原图标；无伤害的特殊行动使用机制图。
	if bool(move.get("cleanse", false)):
		return "cleanse"
	if move.get("intent", "") not in ["buff", "unknown"] or move.has("status"):
		return ""
	for effect in move.get("after_effects", []):
		if effect.get("kind", "") in ["rally", "recruit"]:
			return String(effect.kind)
	return ""

func _move_title(move: Dictionary) -> String:
	var status := GameData.get_status(StringName(move.get("status", "")))
	return status.name if status != null else TITLES.get(move.get("intent", "unknown"), "特殊行动")

func _move_description(move: Dictionary, value: int, times: int) -> String:
	match String(move.get("intent", "unknown")):
		"attack", "aoe_debuff":
			return "本次行动攻击 %d 次，每次造成 %d 点伤害。\n伤害预览已计入当前攻击修正。" % [times, value]
		"defend": return "本次行动获得 %d 点格挡。" % value
		"buff", "debuff":
			var status := GameData.get_status(StringName(move.get("status", "")))
			if status != null:
				return "本次行动使%s获得 %d 层%s。\n%s" % ["自身" if move.get("intent") == "buff" else "玩家", value, status.name, status.effect]
	return "本次行动：%s。" % String(move.get("name", "特殊行动"))
