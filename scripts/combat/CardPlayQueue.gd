extends Node
## Input reservations keep instance identity; gameplay still resolves at impact.
var ui: CombatUI
var pending: Array[Dictionary] = []
var active: Dictionary = {}
var running := false
var returning := 0

func busy() -> bool:
	return running or not pending.is_empty() or returning > 0

func hand_index(entry: Dictionary) -> int:
	for i in ui.controller.hand.size():
		if is_same(ui.controller.hand[i], entry): return i
	return -1

func contains(entry: Dictionary) -> bool:
	if not active.is_empty() and is_same(active.entry, entry): return true
	for command in pending:
		if is_same(command.entry, entry): return true
	return false

func available_energy() -> int:
	var available: int = ui.controller.energy
	var commands: Array = [active] if not active.is_empty() else []
	commands.append_array(pending)
	for command in commands:
		if hand_index(command.entry) < 0: continue # Already paid at impact.
		var cost: int = ui.controller.card_cost(command.entry)
		available = maxi(0, available - cost) if cost >= 0 else 0
	return available

func can_submit(entry: Dictionary) -> bool:
	var index := hand_index(entry)
	if ui.combat_over or contains(entry) or not ui.controller.can_play_card(index): return false
	var reserved := 0
	var commands: Array = [active] if not active.is_empty() else []
	commands.append_array(pending)
	for command in commands:
		if hand_index(command.entry) >= 0: reserved += 1
	if not ui.controller.can_play_more_cards(reserved): return false
	var cost: int = ui.controller.card_cost(entry)
	return cost < 0 or cost <= available_energy()

func submit(entry: Dictionary, target_index: int, ghost: Control) -> bool:
	if not can_submit(entry): return false
	pending.append({"entry": entry, "target": target_index, "ghost": ghost})
	ghost.hide()
	if not running:
		running = true
		_drain.call_deferred()
	return true

func _drain() -> void:
	while not pending.is_empty() and not ui.combat_over:
		if not ui.controller.pending_card_choice.is_empty():
			await SignalBus.combat_card_choice_resolved
			await get_tree().process_frame
			continue
		active = pending.pop_front()
		var entry: Dictionary = active.entry
		var index := hand_index(entry)
		var target_index: int = active.target
		var cd: CardData = GameData.get_card(StringName(entry.id))
		var target: Control = ui.player_panel
		if target_index >= 0:
			if target_index >= ui.controller.enemies.size() or not ui.controller.enemies[target_index].is_alive():
				# Preserve explicit single-enemy targeting; AoE can use a surviving enemy.
				target_index = -1
				if cd.target == &"all_enemies":
					for i in ui.controller.enemies.size():
						if ui.controller.enemies[i].is_alive():
							target_index = i
							break
			if target_index >= 0: target = ui.unit_panels.get(ui.controller.enemies[target_index])
			else: target = null
		if ui.controller.can_play_card(index) and is_instance_valid(target):
			var ghost: Control = active.ghost
			ghost.show()
			await BattleDirector.play_card_cast(ghost, target, cd, index, target_index, ui.controller, _return_card)
		else:
			ui._log("排队出牌已取消：卡牌或目标已不可用")
		# Successful return owns its ghost; canceled casts have no return flight.
		if is_instance_valid(active.ghost) and not active.ghost.get_meta("returning", false):
			active.ghost.queue_free()
		active = {}
		ui._hand.refresh_hand()
	for command in pending:
		if is_instance_valid(command.ghost): command.ghost.queue_free()
	pending.clear()
	running = false
	ui._hand.refresh_hand()

func _return_card(ghost: Control, in_discard: bool, config: Dictionary) -> void:
	ghost.set_meta("returning", true)
	returning += 1
	await BattleDirector._finish_card_flight(ghost, in_discard, config)
	if is_instance_valid(ghost): ghost.queue_free()
	returning -= 1
