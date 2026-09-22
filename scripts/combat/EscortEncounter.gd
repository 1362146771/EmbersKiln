class_name EscortEncounter
extends RefCounted
## 固定精英编队：槽位、补兵、护卫与出牌反制。主怪死亡后随从继续战斗。
var ctrl: CombatController

func attach(controller: CombatController) -> void:
	ctrl = controller

func make_unit(ed: EnemyData) -> CombatUnit:
	var unit := CombatUnit.new()
	unit.setup(false, ed.id, ed.name, ed.base_hp if ed.effective_stats else GameData.scaled_enemy_hp(ed.base_hp), ed.sprite)
	unit.data = ed
	return unit

func setup_formation() -> void:
	# 地图和检查点只保存主怪ID；每次开战按配置还原相同固定编队。
	for leader in ctrl.enemies.duplicate():
		var ed := leader.data as EnemyData
		if ed == null or ed.escort_ids.is_empty(): continue
		var leader_slot := ctrl.enemies.find(leader)
		for id in ed.escort_ids:
			var escort := make_unit(GameData.get_enemy(StringName(id)))
			escort.leader_index = leader_slot
			ctrl.enemies.append(escort)

func missing_escorts(leader: CombatUnit) -> bool:
	var slot := ctrl.enemies.find(leader)
	for unit in ctrl.enemies:
		if unit.leader_index == slot and not unit.is_alive(): return true
	return false

func recruit(leader: CombatUnit) -> void:
	if not leader.is_alive(): return
	var slot := ctrl.enemies.find(leader)
	for index in ctrl.enemies.size():
		var old: CombatUnit = ctrl.enemies[index]
		if old.leader_index != slot or old.is_alive(): continue
		var unit := make_unit(old.data)
		unit.leader_index = slot
		unit.can_act_from_turn = ctrl.turn + 1
		ctrl.enemies[index] = unit
		SignalBus.sound_requested.emit(&"enemy_summon")
		ctrl._intent.roll_enemy_intent(unit)

func attack_multiplier(target: CombatUnit) -> float:
	var multiplier := 1.0
	var slot := ctrl.enemies.find(target)
	if slot < 0: return multiplier
	for unit in ctrl.enemies:
		if unit.is_alive() and unit.leader_index == slot:
			multiplier *= float(unit.data.escort_rules.get("protect_leader_attack_mult", 1.0))
	return multiplier

func announced_rally_strength(unit: CombatUnit) -> int:
	if unit.leader_index < 0: return 0
	var leader: CombatUnit = ctrl.enemies[unit.leader_index]
	if not leader.is_alive() or leader.move_effects_resolved: return 0
	var bonus := 0
	for effect in leader.intent.get("after_effects", []):
		if effect.get("kind", "") == "rally": bonus += int(effect.get("strength", 0))
	return bonus

func on_card_played(card: CardData) -> void:
	for unit in ctrl.enemies:
		if not unit.is_alive(): continue
		var rules: Dictionary = unit.data.escort_rules
		if String(card.type) != String(rules.get("react_card_type", "")): continue
		var target: CombatUnit = unit
		if rules.get("react_target", "self") == "leader":
			if unit.leader_index < 0: continue
			target = ctrl.enemies[unit.leader_index]
		if target.is_alive():
			ctrl._apply_status(target, &"heat", int(rules.get("react_strength", 0)))

func apply_effect(source: CombatUnit, effect: Dictionary) -> void:
	match String(effect.get("kind", "")):
		"rally":
			for unit in ctrl.enemies:
				if unit.is_alive():
					ctrl._apply_status(unit, &"heat", int(effect.get("strength", 0)))
					if unit.leader_index == ctrl.enemies.find(source):
						var amount := int(effect.get("escort_block", 0))
						unit.add_block(amount)
						# 盟友在其本次行动前发的盾不被自然清盾删除。
						if unit.last_action_turn != ctrl.turn: unit.pending_ally_block += amount
		"recruit":
			recruit(source)
		"self_destruct":
			source.hp = 0
			ctrl._post_enemy_death(source)

## 条件招始终显示「缺员补兵，否则攻击」。仅减轻威胁的分支会随死亡即时更新。
func resolve_conditional_intent(unit: CombatUnit, move: Dictionary) -> Dictionary:
	if not move.has("if_missing"): return move
	var result: Dictionary = move.duplicate(true)
	if missing_escorts(unit): result.merge(move.if_missing, true)
	return result

func refresh_conditional_intents() -> void:
	for unit in ctrl.enemies:
		if not unit.is_alive() or not unit.intent.has("if_missing"): continue
		var move: Dictionary = unit.data.find_move(StringName(unit.intent.id))
		unit.intent = resolve_conditional_intent(unit, move)
		SignalBus.enemy_intent_changed.emit(ctrl.enemies.find(unit), StringName(unit.intent.intent), int(unit.intent.get("value", 0)))
