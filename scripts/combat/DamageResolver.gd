class_name DamageResolver
extends RefCounted
## 伤害 / 格挡 / 窑变 结算（P4 从 CombatController 拆出）。
## 通过 attach(ctrl) 持有战斗门面引用；跨子系统调用统一走 ctrl 转发，避免 preload 环路。
## 本文件零 preload：所有外部类型（CombatController / CombatUnit / SignalBus / GameData 等）均为全局 class_name。

var ctrl: CombatController

func attach(controller: CombatController) -> void:
	ctrl = controller

## 计算从 attacker 对 target 的最终伤害：含力量加成、虚弱削弱、易伤增伤。
func compute_outgoing(attacker: CombatUnit, target: CombatUnit, base: int, include_guard: bool = true) -> int:
	var dmg := base
	dmg += attacker.get_status(&"heat")
	if attacker.has_status(&"damp"):
		dmg = int(floor(dmg * 0.75))
	if target.has_status(&"crazed"):
		# 残酷的额外百分比加在易伤原有倍率上；加成值来自卡牌 JSON。
		dmg = int(floor(dmg * (1.5 + ctrl.vulnerable_bonus_damage_for(attacker))))
	# 巨像只处理攻击伤害路径，不影响直接失血与状态伤害。
	dmg = int(floor(dmg * ctrl.incoming_attack_multiplier_for(attacker, target)))
	if include_guard:
		dmg = int(floor(dmg * ctrl._escorts.attack_multiplier(target)))
	return maxi(0, dmg)

func deal_to_unit(unit: CombatUnit, final_dmg: int) -> void:
	var block_before := unit.block
	unit.apply_damage(final_dmg)
	if ctrl.enemies.has(unit):
		ctrl._intent.interrupt_on_block_break(unit, block_before)
	SignalBus.damage_dealt.emit(not unit.is_player, ctrl._index_of(unit), final_dmg)
	if unit.is_player:
		ctrl._sync_player_hp()
	else:
		SignalBus.enemy_hp_changed.emit(ctrl._index_of(unit), unit.hp, unit.max_hp)
		if not unit.is_alive():
			ctrl._post_enemy_death(unit)

func deal_to_player(final_dmg: int) -> void:
	var dmg := maxi(0, final_dmg)
	# 缓冲（glaze）：受到攻击时减伤等于层数，触发 1 次后 -1 层
	if ctrl.player.has_status(&"glaze"):
		dmg = maxi(0, dmg - ctrl.player.get_status(&"glaze"))
		ctrl._apply_status(ctrl.player, &"glaze", -1)
	ctrl.player.apply_damage(dmg)
	ctrl._sync_player_hp()
	SignalBus.damage_dealt.emit(false, -1, dmg)

## 窑变贯穿伤害：绕过格挡直接扣血。
func deal_kiln_resonance(unit: CombatUnit, dmg: int) -> void:
	unit.lose_hp_direct(dmg)
	SignalBus.enemy_hp_changed.emit(ctrl._index_of(unit), unit.hp, unit.max_hp)
	SignalBus.damage_dealt.emit(true, ctrl._index_of(unit), dmg)
	if not unit.is_alive():
		ctrl._post_enemy_death(unit)

func add_block(unit: CombatUnit, amount: int) -> void:
	var real := amount
	real += unit.get_status(&"temper")
	var before := unit.block
	unit.add_block(real)
	if unit.is_player:
		SignalBus.player_block_changed.emit(ctrl.player.block)
	if unit.is_player and unit.block > before:
		ctrl.on_player_block_gained()

## 单次攻击命中结算（供碰撞卡撞击点回调）。
func enemy_attack_hit(e: CombatUnit, dmg: int) -> void:
	deal_to_player(dmg)
	if ctrl._temporary_thorns > 0 and e.is_alive():
		deal_to_unit(e, ctrl._temporary_thorns)
	ctrl._tick_sherd_vest(e)   # 遗物：受击反伤（陶片背心）

## AOE 伤害 + 对玩家施加 debuff（如易伤）。
func enemy_aoe_hit(e: CombatUnit, dmg: int, mv: Dictionary) -> void:
	deal_to_player(dmg)
	ctrl._tick_sherd_vest(e)
	var sid := StringName(mv.get("status", ""))
	var sval := int(mv.get("status_value", 0))
	if sid != &"" and sval != 0:
		ctrl._apply_status(ctrl.player, sid, sval)

## 窑温·共鸣：累计满阈值时立即触发「窑变」——对所有敌人造成贯穿伤害并消耗阈值点窑温。
func check_kiln_resonance() -> void:
	while ctrl.kiln_heat >= ctrl._kiln_threshold():
		ctrl.kiln_heat -= ctrl._kiln_threshold()
		SignalBus.kiln_heat_changed.emit(ctrl.kiln_heat, ctrl._kiln_threshold())
		for e in ctrl.enemies:
			if e.is_alive():
				deal_kiln_resonance(e, ctrl._kiln_pierce())
		ctrl._check_combat_end()
