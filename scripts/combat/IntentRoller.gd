class_name IntentRoller
extends RefCounted
## 敌人 & 随从意图滚动与行动、召唤系统（P4 从 CombatController 拆出）。
## 通过 attach(ctrl) 持有战斗门面引用；跨子系统调用统一走 ctrl 转发，避免 preload 环路。
## 本文件零 preload：所有外部类型（CombatController / CombatUnit / EnemyData / MinionData / EnemyAI / SignalBus / GameData 等）均为全局 class_name。

var ctrl: CombatController

func attach(controller: CombatController) -> void:
	ctrl = controller

## 友方索引：随从在 allies 中的位置（供 SignalBus 广播）。
func index_of_ally(a: CombatUnit) -> int:
	return ctrl.allies.find(a)

# =====================================================================
# 敌人意图
# =====================================================================
## 为敌人滚动下一手意图（加权随机 / Boss 分阶段），并广播给 UI。
## 若上一回合处于蓄力（charge_next 非空），则跳过随机、直接强制打出释放招式。
func roll_enemy_intent(e: CombatUnit) -> void:
	var ed: EnemyData = e.data
	if ed != null and ed.ai == &"scripted_cycle":
		var nx: StringName = ed.first_move if e.intent.is_empty() else StringName(e.intent.get("next", ""))
		# 当前意图可能已被破封分支替换，必须从替换后的 next 继续，不能随机选招。
		e.charge_next = &""
		e.intent = scale_intent_damage(ed.find_move(nx))
		SignalBus.enemy_intent_changed.emit(ctrl._index_of(e), StringName(e.intent.get("intent", "unknown")), int(e.intent.get("value", 0)))
		return
	if e.charge_next != &"":
		var forced: Dictionary = {}
		if ed != null:
			forced = ed.find_move(e.charge_next)
		e.charge_next = &""   # 消费掉，只强制一次
		if forced.is_empty() and ed != null:
			# 释放招式不存在时回退到正常选择（不卡死）
			forced = EnemyAI.choose_intent(ed, float(e.hp) / float(e.max_hp) if e.max_hp > 0 else 1.0)
		e.intent = scale_intent_damage(forced)
		SignalBus.enemy_intent_changed.emit(
			ctrl._index_of(e),
			StringName(e.intent.get("intent", "unknown")),
			int(e.intent.get("value", 0))
		)
		return
	if ed == null:
		e.intent = {}
		return
	var ratio: float = float(e.hp) / float(e.max_hp) if e.max_hp > 0 else 1.0
	# 阶段切换检测（scripted_phases）：进入新阶段时触发 on_enter（如觉醒自身加炽热）
	if ed.ai == &"scripted_phases" and not ed.phases.is_empty():
		var pidx := EnemyAI.phase_index_for(ed, ratio)
		if pidx > e.phase_index:
			apply_phase_on_enter(e, ed.phases[pidx])
		e.phase_index = pidx
	e.intent = scale_intent_damage(EnemyAI.choose_intent(ed, ratio))
	SignalBus.enemy_intent_changed.emit(
		ctrl._index_of(e),
		StringName(e.intent.get("intent", "unknown")),
		int(e.intent.get("value", 0))
	)


## 只从 DamageResolver 的真实扣盾路径调用；死亡与自然清盾不换意图。
func interrupt_on_block_break(e: CombatUnit, block_before: int) -> void:
	if not e.is_alive() or block_before <= 0 or e.block > 0 or e.block_break_next == &"":
		return
	var ed := e.data as EnemyData
	if ed == null:
		return
	var replacement := ed.find_move(e.block_break_next)
	if replacement.is_empty():
		return
	e.block_break_next = &""
	e.charge_next = &""
	e.intent = scale_intent_damage(replacement)
	ctrl._log("%s 封匣破裂 → %s" % [e.unit_name, replacement.get("name", "泄压")])
	SignalBus.enemy_intent_changed.emit(ctrl._index_of(e), StringName(e.intent.get("intent", "unknown")), int(e.intent.get("value", 0)))

## 伤害类意图（attack / aoe_debuff）按难度系数 × 当前幕 act_dmg_mult 缩放（P-D 接线）。
## 注意：choose_intent 返回的是 EnemyData.moves 内部字典的引用，必须 duplicate 后再改。
func scale_intent_damage(intent: Dictionary) -> Dictionary:
	if intent.is_empty():
		return intent
	var kind: String = intent.get("intent", "")
	if kind != "attack" and kind != "aoe_debuff":
		return intent
	var out: Dictionary = intent.duplicate()
	out["value"] = GameData.scaled_enemy_damage(int(intent.get("value", 0)))
	return out

## 阶段切换时触发该阶段的 on_enter（自增益类，如觉醒自身加 3 炽热）。
func apply_phase_on_enter(e: CombatUnit, phase: Dictionary) -> void:
	for buff in phase.get("on_enter", []):
		if not (buff is Dictionary):
			continue
		var sid := StringName(buff.get("status", ""))
		if sid != &"":
			ctrl._apply_status(e, sid, int(buff.get("value", 0)))
	ctrl._log("敌人 %s 进入新阶段，触发 on_enter" % e.unit_name)

## 敌人按意图行动（attack/defend/buff/debuff/charge/aoe_debuff/unknown）。
func execute_enemy_intent(e: CombatUnit) -> void:
	var mv: Dictionary = e.intent
	if mv.is_empty():
		return
	var kind: String = mv.get("intent", "unknown")
	var value: int = int(mv.get("value", 0))
	var times: int = int(mv.get("times", 1))
	match kind:
		"attack":
			for i in times:
				if not ctrl.player.is_alive():
					break
				var dmg := ctrl._dmg.compute_outgoing(e, ctrl.player, value)
				ctrl._dmg.enemy_attack_hit(e, dmg)
		"defend":
			e.add_block(value)
		"buff":
			var sid := StringName(mv.get("status", ""))
			if sid != &"":
				ctrl._apply_status(e, sid, value)
		"debuff":
			var sid := StringName(mv.get("status", ""))
			if sid != &"":
				ctrl._apply_status(ctrl.player, sid, value)
		"charge":
			var brace: int = int(mv.get("value", 0))
			e.block_break_next = &""
			if brace > 0:
				e.add_block(brace)
				e.block_break_next = StringName(mv.get("on_block_break", ""))
			var nx := StringName(mv.get("next", ""))
			if nx != &"":
				e.charge_next = nx
			ctrl._log("敌人 %s 蓄力（下回合释放 %s）" % [e.unit_name, nx])
		"unknown":
			pass
		"aoe_debuff":
			var dmg := ctrl._dmg.compute_outgoing(e, ctrl.player, value)
			ctrl._dmg.enemy_aoe_hit(e, dmg, mv)
	ctrl._log("敌人 %s 行动：%s" % [e.unit_name, kind])

# =====================================================================
# 随从 / 召唤（Summon System）
# =====================================================================
## 召唤随从：受上场上限约束；满场则广播 summon_rejected 并停止。
func summon_minion(mid: StringName, count: int) -> void:
	var md: MinionData = GameData.get_minion(mid)
	if md == null:
		push_warning("[Combat] 未知随从: %s" % mid)
		return
	var cap: int = int(GameData.balance.get("summon", {}).get("max_summons", 3))
	for n in count:
		if ctrl.allies.size() >= cap:
			SignalBus.summon_rejected.emit(cap)
			ctrl._log("召唤栏已满（上限 %d），无法继续召唤" % cap)
			break
		var a := CombatUnit.new()
		a.setup(false, md.id, md.name, md.hp, md.sprite)
		a.block = md.block
		a.lifetime = md.lifetime
		a.data = md
		a.move_cursor = 0
		ctrl.allies.append(a)
		roll_minion_intent(a)
		SignalBus.ally_hp_changed.emit(index_of_ally(a), a.hp, a.max_hp)
		SignalBus.ally_block_changed.emit(index_of_ally(a), a.block)
		ctrl._log("召唤随从 %s（%d/%d）" % [md.name, ctrl.allies.size(), cap])
	SignalBus.allies_changed.emit()

## 随从阶段：清旧格挡 → turn_start 状态 → 行动 → 寿命-1/到期消失。
func summon_phase() -> void:
	if not ctrl._combat_active:
		return
	for a in ctrl.allies.duplicate():
		if not is_instance_valid(a):
			continue
		a.block = 0
		ctrl._status.process_turn_start_statuses(a, post_ally_death)
		if not a.is_alive():
			continue
		execute_minion_intent(a)
		if not ctrl._combat_active:
			return
		ctrl._status.decay_statuses_at_turn_end(a)
		a.lifetime -= 1
		SignalBus.ally_lifetime_changed.emit(index_of_ally(a), a.lifetime)
		if a.lifetime <= 0:
			post_ally_death(a)

## 随从按意图行动（attack/defend/buff/debuff）。指挥(command) 给攻击/格挡加成。
func execute_minion_intent(a: CombatUnit) -> void:
	var mv: Dictionary = a.intent
	if mv.is_empty():
		return
	SignalBus.ally_action_start.emit(index_of_ally(a))
	var kind: String = mv.get("intent", "unknown")
	var value: int = int(mv.get("value", 0))
	var times: int = int(mv.get("times", 1))
	match kind:
		"attack":
			for i in times:
				var tgt: CombatUnit = ctrl.first_alive_enemy()
				if tgt == null:
					break
				var dmg := ally_outgoing(a, tgt, value)
				ctrl._dmg.deal_to_unit(tgt, dmg)
		"defend", "buff", "debuff", "unknown":
			execute_minion_non_attack(a)
	roll_minion_intent(a)   # 滚动下一意图（fixed：循环 moves）
	SignalBus.ally_action_end.emit(index_of_ally(a))

## 随从非攻击意图结算（defend/buff/debuff/unknown）。
func execute_minion_non_attack(a: CombatUnit) -> void:
	var mv: Dictionary = a.intent
	if mv.is_empty():
		return
	var kind: String = mv.get("intent", "unknown")
	var value: int = int(mv.get("value", 0))
	var cmd: int = ctrl.player.get_status(&"command") if ctrl.player.has_status(&"command") else 0
	match kind:
		"defend":
			ctrl._dmg.add_block(a, value + cmd)
		"buff":
			var sid := StringName(mv.get("status", ""))
			if sid != &"":
				ctrl._apply_status(a, sid, value)
		"debuff":
			var sid := StringName(mv.get("status", ""))
			if sid != &"":
				ctrl._apply_status(ctrl.player, sid, value)
		"unknown":
			pass

## 随从意图：fixed AI 循环 moves（复用敌人意图 schema，随从无难度缩放）。
func roll_minion_intent(a: CombatUnit) -> void:
	var md: MinionData = a.data as MinionData
	if md == null or md.moves.is_empty():
		a.intent = {}
		return
	var atk_cap: int = int(GameData.balance.get("summon", {}).get("max_minion_attack", 7))
	var idx: int = int(a.move_cursor) % md.moves.size()
	var mv: Dictionary = md.moves[idx].duplicate()
	if String(mv.get("intent", "")) == "attack":
		mv["value"] = mini(int(mv.get("value", 0)), atk_cap)
	a.intent = mv
	a.move_cursor = (idx + 1) % md.moves.size()
	SignalBus.ally_intent_changed.emit(index_of_ally(a), StringName(mv.get("intent", "unknown")), int(mv.get("value", 0)))

## 友方随从受击（AoE 敌人用）：扣血 → 广播 → 死亡清理。
func deal_to_ally(a: CombatUnit, final_dmg: int) -> void:
	a.apply_damage(final_dmg)
	SignalBus.ally_hp_changed.emit(index_of_ally(a), a.hp, a.max_hp)
	if not a.is_alive():
		post_ally_death(a)

func post_ally_death(a: CombatUnit) -> void:
	# 寿命到期时 HP 仍 > 0（is_alive 为真），故不能按 is_alive 判定，只能按"是否还在友方列表"防重复移除。
	if not ctrl.allies.has(a):
		return
	var idx: int = index_of_ally(a)
	SignalBus.ally_died.emit(idx)
	ctrl.allies.erase(a)
	ctrl._log("随从 %s 消失" % a.unit_name)

# =====================================================================
# 随从 / 召唤（异步演出薄包装，供 BattleDirector.run_summon_turn 驱动）
# =====================================================================
## 友方回合开始：清旧格挡 + 回合开始状态（ashrot 等可能致死 → post_ally_death）。
func ally_pre(a: CombatUnit) -> bool:
	a.block = 0
	ctrl._status.process_turn_start_statuses(a, post_ally_death)
	if not a.is_alive():
		return false
	SignalBus.ally_action_start.emit(index_of_ally(a))
	return true

## 友方攻击 outgoing（含指挥加成、炽热/防潮/釉裂等，不含格挡）。
func ally_outgoing(a: CombatUnit, target: CombatUnit, base: int) -> int:
	var dmg := ctrl._dmg.compute_outgoing(a, target, base)
	var cmd: int = ctrl.player.get_status(&"command") if ctrl.player.has_status(&"command") else 0
	return dmg + cmd

## 单次攻击命中结算（供光弹撞击点回调）。目标已亡则改打首个存活敌人。
func ally_attack_hit(a: CombatUnit, target: CombatUnit, dmg: int) -> void:
	if target == null or not target.is_alive():
		target = ctrl.first_alive_enemy()
	if target == null:
		return
	ctrl._dmg.deal_to_unit(target, dmg)

## 非攻击意图整体结算（自身出牌演出后回调）。
func ally_act(a: CombatUnit) -> void:
	execute_minion_non_attack(a)

## 友方行动结束：状态衰减 + 寿命-1/到期消失 + 滚动下一意图。
func ally_post(a: CombatUnit) -> void:
	ctrl._status.decay_statuses_at_turn_end(a)
	a.lifetime -= 1
	SignalBus.ally_lifetime_changed.emit(index_of_ally(a), a.lifetime)
	if a.lifetime <= 0:
		post_ally_death(a)
	else:
		roll_minion_intent(a)
	SignalBus.ally_action_end.emit(index_of_ally(a))
