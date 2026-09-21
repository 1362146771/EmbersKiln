class_name IntentRoller
extends RefCounted
## 敌人意图滚动与行动（P4 从 CombatController 拆出）。
## 通过 attach(ctrl) 持有战斗门面引用；跨子系统调用统一走 ctrl 转发，避免 preload 环路。
## 本文件零 preload：所有外部类型（CombatController / CombatUnit / EnemyData / EnemyAI / SignalBus / GameData 等）均为全局 class_name。

var ctrl: CombatController

func attach(controller: CombatController) -> void:
	ctrl = controller

# =====================================================================
# 敌人意图
# =====================================================================
## 为敌人滚动下一手意图（加权随机 / Boss 分阶段），并广播给 UI。
## 若上一回合处于蓄力（charge_next 非空），则跳过随机、直接强制打出释放招式。
func roll_enemy_intent(e: CombatUnit) -> void:
	var ed: EnemyData = e.data
	# 已预告的转阶段行动必须先执行，重复请求意图不能跳过准备回合。
	if bool(e.intent.get("phase_entry", false)) and not e.move_effects_resolved:
		return
	e.move_effects_resolved = false
	if ed != null and ed.ai == &"phased_cycle":
		roll_phase_cycle(e, ed)
		return
	if ed != null and ed.ai == &"scripted_cycle":
		var nx: StringName = ed.first_move if e.intent.is_empty() else StringName(e.intent.get("next", ""))
		# 当前意图可能已被破封分支替换，必须从替换后的 next 继续，不能随机选招。
		e.charge_next = &""
		e.intent = scale_intent_damage(ctrl._escorts.resolve_conditional_intent(e, ed.find_move(nx)), ed.tier, ed.effective_stats)
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
		e.intent = scale_intent_damage(forced, ed.tier if ed != null else &"", ed.effective_stats if ed != null else false)
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
	# 阶段切换检测（scripted_phases）：进入新阶段时触发 on_enter（如觉醒自身加力量）
	if ed.ai == &"scripted_phases" and not ed.phases.is_empty():
		var pidx := EnemyAI.phase_index_for(ed, ratio)
		if pidx > e.phase_index:
			apply_phase_on_enter(e, ed.phases[pidx])
		e.phase_index = pidx
	e.intent = scale_intent_damage(EnemyAI.choose_intent(ed, ratio), ed.tier, ed.effective_stats)
	SignalBus.enemy_intent_changed.emit(
		ctrl._index_of(e),
		StringName(e.intent.get("intent", "unknown")),
		int(e.intent.get("value", 0))
	)


## 确定性阶段循环。只在下一手意图公布时转阶段；回血不退阶段。
func roll_phase_cycle(e: CombatUnit, ed: EnemyData) -> void:
	if ed.phases.is_empty():
		e.intent = {}
		return
	var ratio := float(e.hp) / float(e.max_hp) if e.max_hp > 0 else 1.0
	e.reached_phase_index = maxi(e.reached_phase_index, EnemyAI.phase_index_for(ed, ratio))
	var next_phase := maxi(maxi(e.phase_index, e.reached_phase_index), EnemyAI.phase_index_for(ed, ratio))
	if next_phase > e.phase_index:
		for idx in range(e.phase_index + 1, next_phase + 1):
			var phase: Dictionary = ed.phases[idx]
			var entry: Dictionary = phase.get("entry_move", {})
			if not entry.is_empty():
				e.phase_index = idx
				e.phase_move_index = -1
				e.intent = scale_intent_damage(entry, ed.tier, ed.effective_stats).duplicate(true)
				e.intent["phase_entry"] = true
				SignalBus.enemy_intent_changed.emit(ctrl._index_of(e), StringName(e.intent.get("intent", "unknown")), int(e.intent.get("value", 0)))
				return
			if bool(phase.get("cleanse", false)):
				cleanse_debuffs(e)
			apply_phase_on_enter(e, phase)
		e.phase_index = next_phase
		e.phase_move_index = 0
	else:
		e.phase_move_index += 1
	var moves: Array = ed.phases[e.phase_index].get("moves", [])
	if moves.is_empty():
		e.intent = {}
		return
	e.phase_move_index %= moves.size()
	e.intent = scale_intent_damage(moves[e.phase_move_index], ed.tier, ed.effective_stats)
	SignalBus.enemy_intent_changed.emit(ctrl._index_of(e), StringName(e.intent.get("intent", "unknown")), int(e.intent.get("value", 0)))


func cleanse_debuffs(e: CombatUnit) -> void:
	for sid in e.status_ids():
		var sd := GameData.get_status(sid)
		var amount := e.get_status(sid)
		if (sd != null and sd.is_debuff()) or amount < 0:
			ctrl._apply_status(e, sid, -amount)


func before_enemy_action(e: CombatUnit) -> void:
	var ed := e.data as EnemyData
	if ed == null or not e.is_alive():
		return
	if ed.ai == &"phased_cycle":
		# 回复之前记录已跨过的阈值；不能靠本回合回血取消已触发的阶段。
		e.reached_phase_index = maxi(e.reached_phase_index, EnemyAI.phase_index_for(ed, float(e.hp) / float(e.max_hp)))
	var healing := int(ed.boss_rules.get("regeneration", 0))
	if healing > 0 and e.heal(healing) > 0:
		SignalBus.enemy_hp_changed.emit(ctrl._index_of(e), e.hp, e.max_hp)


func after_enemy_action(e: CombatUnit) -> void:
	var ed := e.data as EnemyData
	if ed == null or not e.is_alive():
		return
	e.enemy_actions += 1
	var interval := int(ed.boss_rules.get("growth_every", 0))
	if interval > 0 and e.enemy_actions % interval == 0:
		ctrl._apply_status(e, &"heat", int(ed.boss_rules.get("growth_strength", 0)))


func on_player_card_played(cd: CardData) -> void:
	ctrl._escorts.on_card_played(cd)
	if cd.type != &"power":
		return
	for e in ctrl.enemies:
		var ed := e.data as EnemyData
		if e.is_alive() and ed != null:
			var gain := ed.power_response_strength(e.phase_index)
			if gain > 0:
				ctrl._apply_status(e, &"heat", gain)


## 每个攻击行动末尾执行一次；图形演出与直接模拟共用此入口。
func apply_move_effects(e: CombatUnit) -> void:
	if e.move_effects_resolved or not e.is_alive() or not ctrl.player_alive():
		return
	e.move_effects_resolved = true
	for effect in e.intent.get("after_effects", []):
		if not e.is_alive(): break
		ctrl._escorts.apply_effect(e, effect)
		match String(effect.get("kind", "")):
			"status":
				var target := e if effect.get("target", "player") == "self" else ctrl.player
				ctrl._apply_status(target, StringName(effect.get("status", "")), int(effect.get("value", 0)))
			"block":
				e.add_block(int(effect.get("value", 0)))
			"add_card":
				ctrl._add_generated_card(StringName(effect.get("card_id", "")), String(effect.get("pile", "discard")), int(effect.get("count", 0)), bool(effect.get("shuffle", false)))


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
	e.intent = scale_intent_damage(replacement, ed.tier, ed.effective_stats)
	ctrl._log("%s 封匣破裂 → %s" % [e.unit_name, replacement.get("name", "泄压")])
	SignalBus.enemy_intent_changed.emit(ctrl._index_of(e), StringName(e.intent.get("intent", "unknown")), int(e.intent.get("value", 0)))

## 攻击按难度/幕倍率缩放；第一、三幕非 Boss 的攻击、主动格挡再吃约 30% 削弱。
## 注意：choose_intent 返回的是 EnemyData.moves 内部字典的引用，必须 duplicate 后再改。
func scale_intent_damage(intent: Dictionary, tier: StringName = &"", effective_stats: bool = false) -> Dictionary:
	if effective_stats or bool(intent.get("effective_stats", false)):
		return intent.duplicate(true)
	if intent.is_empty():
		return intent
	var kind: String = intent.get("intent", "")
	if kind != "attack" and kind != "aoe_debuff" and kind != "defend" and kind != "charge":
		return intent
	var out: Dictionary = intent.duplicate()
	if kind == "attack" or kind == "aoe_debuff":
		out["value"] = GameData.scaled_enemy_damage(int(intent.get("value", 0)), tier)
	else:
		out["value"] = GameData.scaled_enemy_defense(int(intent.get("value", 0)), tier)
	return out

## 阶段切换时触发该阶段的 on_enter（自增益类，如觉醒自身加 3 力量）。
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
	if bool(mv.get("cleanse", false)):
		cleanse_debuffs(e)
	match kind:
		"attack":
			for i in times:
				if not ctrl.player.is_alive() or not e.is_alive():
					break
				var dmg := ctrl._dmg.compute_outgoing(e, ctrl.player, value)
				ctrl.enemy_attack_hit(e, dmg)
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
	apply_move_effects(e)
	ctrl._log("敌人 %s 行动：%s" % [e.unit_name, kind])
