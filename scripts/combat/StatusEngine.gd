class_name StatusEngine
extends RefCounted
## 状态 / 回合开始-结束结算 / 玩家 Power（P4 从 CombatController 拆出）。
## 通过 attach(ctrl) 持有战斗门面引用；跨子系统调用统一走 ctrl 转发，避免 preload 环路。
## 本文件零 preload：所有外部类型（CombatController / CombatUnit / StatusData / SignalBus / GameData 等）均为全局 class_name。

var ctrl: CombatController

func attach(controller: CombatController) -> void:
	ctrl = controller

func apply_status(unit: CombatUnit, status_id: StringName, amount: int) -> void:
	if status_id == &"":
		return
	unit.add_status(status_id, amount)
	if unit.is_player:
		SignalBus.status_applied.emit(true, -1, status_id, unit.get_status(status_id))
	else:
		SignalBus.status_applied.emit(false, ctrl._index_of(unit), status_id, unit.get_status(status_id))

func process_turn_start_statuses(unit: CombatUnit, on_death: Callable = Callable()) -> void:
	for sid in unit.status_ids():
		var sd: StatusData = GameData.get_status(sid)
		if sd == null or sd.trigger != &"turn_start":
			continue
		if sid == &"ashrot":
			unit.lose_hp_direct(unit.get_status(sid))
			if unit.is_player:
				ctrl._sync_player_hp()
			else:
				SignalBus.enemy_hp_changed.emit(ctrl._index_of(unit), unit.hp, unit.max_hp)
		elif sid == &"anneal":
			unit.heal(unit.get_status(sid))
			if unit.is_player:
				ctrl._sync_player_hp()
			else:
				SignalBus.enemy_hp_changed.emit(ctrl._index_of(unit), unit.hp, unit.max_hp)
		unit.add_status(sid, -1)  # 触发型：层数 -1
		if not unit.is_alive():
			if unit.is_player:
				ctrl._sync_player_hp()
				ctrl._on_player_death()
			elif on_death.is_valid():
				on_death.call(unit)
			else:
				ctrl._post_enemy_death(unit)

func decay_statuses_at_turn_end(unit: CombatUnit) -> void:
	for sid in unit.status_ids():
		var sd: StatusData = GameData.get_status(sid)
		if sd == null or not sd.decay or sd.trigger == &"turn_start":
			continue
		unit.add_status(sid, -sd.decay_per_turn)

func apply_player_start_turn_powers() -> void:
	if ctrl.powers.has(CombatController.POWER_START_TURN_ENERGY):
		ctrl.energy += int(ctrl.powers[CombatController.POWER_START_TURN_ENERGY])
		SignalBus.energy_changed.emit(ctrl.energy, ctrl.max_energy)
	if ctrl.powers.has(CombatController.POWER_START_TURN_HP_DRAW):
		var start_power: Dictionary = ctrl.powers[CombatController.POWER_START_TURN_HP_DRAW]
		ctrl._lose_player_hp(int(start_power.get("self_hp", 0)), true)
		ctrl._draw_cards(int(start_power.get("draw", 0)))
	if ctrl.powers.has(CombatController.POWER_START_TURN_BLOCK):
		ctrl._dmg.add_block(ctrl.player, int(ctrl.powers[CombatController.POWER_START_TURN_BLOCK]))
	if ctrl.powers.has(CombatController.POWER_START_TURN_STRENGTH):
		apply_status(ctrl.player, &"heat", int(ctrl.powers[CombatController.POWER_START_TURN_STRENGTH]))

func apply_player_end_turn_powers() -> void:
	if ctrl.powers.has(CombatController.POWER_END_TURN_SELF_HP_AOE):
		var end_power: Dictionary = ctrl.powers[CombatController.POWER_END_TURN_SELF_HP_AOE]
		ctrl._lose_player_hp(int(end_power.get("self_hp", 0)), true)
		ctrl._deal_direct_aoe(int(end_power.get("damage", 0)))
	if ctrl.powers.has(CombatController.POWER_END_TURN_BLOCK):
		ctrl._dmg.add_block(ctrl.player, int(ctrl.powers[CombatController.POWER_END_TURN_BLOCK]))
	if ctrl.powers.has(CombatController.POWER_END_TURN_AOE):
		for e in ctrl.enemies:
			if not e.is_alive():
				continue
			var dmg := int(ctrl.powers[CombatController.POWER_END_TURN_AOE])
			ctrl._dmg.deal_to_unit(e, dmg)
