class_name AshenBinder
extends RefCounted
## 状态按战斗单元持有；读档/复燃沿用全项目的开战检查点，重新开始同场战斗。
var ctrl: CombatController
var pending_cards := 0
signal backlash_resolved(enemy: CombatUnit, absorbed: bool)

func attach(controller: CombatController) -> void:
	ctrl = controller

func reset() -> void:
	pending_cards = 0

func start_turn() -> void:
	for enemy in ctrl.enemies:
		enemy.ash_backlash_used = 0
		_refresh(enemy)

func apply_move(enemy: CombatUnit) -> void:
	if enemy.data == null or not enemy.data.boss_rules.has("backlash_damage"): return
	var move: String = enemy.intent.get("id", "")
	var rules: Dictionary = enemy.data.boss_rules
	if move == "seal":
		enemy.ash_sealed = true
		var amount := mini(int(rules.ash_cards_per_seal), maxi(0, int(rules.ash_live_cap) - live_ash(enemy)))
		for i in amount:
			ctrl.discard_pile.append({"id":&"dazed", "upgraded":false,"upgrade_level":0,"enchants":[],"enchant_active":false,"ash_source":String(enemy.id)})
	elif move == "vent":
		enemy.ash_sealed = false
	_refresh(enemy)

func live_ash(enemy: CombatUnit) -> int:
	var count := 0
	for pile in [ctrl.hand, ctrl.draw_pile, ctrl.discard_pile]:
		for card in pile:
			if String(card.get("ash_source", "")) == String(enemy.id): count += 1
	return count

func card_finished() -> void:
	pending_cards += 1
	flush()

func flush() -> void:
	if not ctrl.pending_card_choice.is_empty(): return
	while pending_cards > 0:
		pending_cards -= 1
		if not ctrl.player_alive():
			pending_cards = 0
			return
		for enemy in ctrl.enemies:
			if not enemy.is_alive() or not enemy.ash_sealed: continue
			var rules: Dictionary = enemy.data.boss_rules
			var amount := mini(int(rules.backlash_damage), maxi(0, int(rules.backlash_raw_cap) - enemy.ash_backlash_used))
			if amount <= 0: continue
			enemy.ash_backlash_used += amount
			var hp_before := ctrl.player.hp
			ctrl._dmg.deal_to_player(amount)
			backlash_resolved.emit(enemy, ctrl.player.hp == hp_before)
			SignalBus.sound_requested.emit(&"ashen_backlash")
			_refresh(enemy)
			ctrl.check_player_death()
			if not ctrl.player_alive(): break

func _refresh(enemy: CombatUnit) -> void:
	if enemy.data != null and enemy.data.boss_rules.has("backlash_damage"):
		SignalBus.enemy_intent_changed.emit(ctrl._index_of(enemy), StringName(enemy.intent.get("intent", "unknown")), int(enemy.intent.get("value", 0)))
