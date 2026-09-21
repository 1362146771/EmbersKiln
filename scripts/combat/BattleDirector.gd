extends Node
## BattleDirector —— 战斗演出序列器（autoload，不写 class_name，靠 project.godot 注册名全局调用）。
## 职责：编排玩家出牌与敌人回合节奏；敌人不生成飞牌或染色爆发贴图。
## 演出本身不碰数值结算，在行动时间点回调 controller 的薄方法结算伤害/状态。
##
## 关键约束（AGENTS/godot 踩坑）：本脚本不得写 class_name，否则与 autoload 单例名
## "BattleDirector" 冲突（Class X hides an autoload singleton）。

var input_locked := false        # 演出期间锁结束回合/药水；手牌通过队列继续接收输入
signal card_cast_started(entry: Dictionary, target_index: int, travel: float, ghost: Control)
signal card_cast_finished(ok: bool)
signal card_flight_started(entry: Dictionary, travel: float)

const CAST_TRAVEL := 0.18        # 出牌飞行时长（s）
const CAST_SETTLE := 0.14       # 撞击后等爆发/飘字冒头的缓冲（s）
const SELF_BEAT := 0.34         # 敌人防御/buff 等原有行动节拍（s）
const ENEMY_WINDUP := 0.34      # 沿用旧飞牌到达前等待时间，不再绘制飞牌
const ENEMY_RECOVERY := 0.16    # 沿用旧命中后等待时间，供受击反馈显示


## 包装一次出牌的 cast 演出：卡飞向目标 → 到达瞬间结算 → 现有命中反馈 → 缓冲后交还。
## ghost 由调用方持有；可提供独立收牌回调，攻击完成无需等待弃牌飞行。
func play_card_cast(ghost: Control, target_node: Control, cd: CardData, idx: int, target_index: int, controller, return_handler: Callable = Callable()) -> void:
	input_locked = true
	if not is_instance_valid(ghost) or not is_instance_valid(target_node) or not is_instance_valid(controller) or idx < 0 or idx >= controller.hand.size():
		input_locked = false
		card_cast_finished.emit(false)
		return
	var played_entry: Dictionary = controller.hand[idx]
	var config: Dictionary = GameData.vfx["card_presentation"]
	var attack_cast := cd.type == &"attack" and target_index >= 0
	var travel := float(config["strike_seconds"]) if attack_cast else CAST_TRAVEL
	var total_travel := travel
	if attack_cast:
		total_travel += float(config["pullback_seconds"]) + float(config["charge_seconds"])
	ghost.pivot_offset = ghost.size * 0.5
	card_cast_started.emit(played_entry.duplicate(true), target_index, total_travel, ghost)
	# Battle-local presentation requests a cut-in before flight and real damage.
	var prelude_seconds := float(ghost.get_meta("cast_prelude_seconds", 0.0))
	if prelude_seconds > 0.0:
		var prelude := create_tween()
		prelude.tween_interval(prelude_seconds)
		await prelude.finished
		if not is_instance_valid(ghost) or not is_instance_valid(target_node) or not is_instance_valid(controller):
			input_locked = false
			card_cast_finished.emit(false)
			return
		ghost.show()
	card_flight_started.emit(played_entry.duplicate(true), total_travel)
	var to_pos := target_node.get_global_rect().get_center() - ghost.size * 0.5
	if attack_cast:
		# Pull away from the target, hold tension, then accelerate into impact.
		var pullback := to_pos + Vector2.DOWN * ghost.size.y * float(config["pullback_card_heights"])
		var viewport_size := ghost.get_viewport_rect().size
		pullback = pullback.clamp(Vector2.ZERO, (viewport_size - ghost.size).max(Vector2.ZERO))
		var windup := create_tween()
		windup.tween_property(ghost, "global_position", pullback, float(config["pullback_seconds"])).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		windup.parallel().tween_property(ghost, "scale", Vector2.ONE, float(config["pullback_seconds"]))
		windup.tween_property(ghost, "scale", Vector2.ONE * float(config["charge_scale"]), float(config["charge_seconds"])).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await windup.finished
		if not is_instance_valid(ghost) or not is_instance_valid(target_node) or not is_instance_valid(controller):
			input_locked = false
			card_cast_finished.emit(false)
			return
		to_pos = target_node.get_global_rect().get_center() - ghost.size * 0.5
	var tw := create_tween()
	tw.tween_property(ghost, "global_position", to_pos, travel).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ghost, "scale", Vector2.ONE * float(config["impact_scale"]), travel)
	await tw.finished
	if not is_instance_valid(ghost) or not is_instance_valid(target_node) or not is_instance_valid(controller):
		input_locked = false
		card_cast_finished.emit(false)
		return
	idx = -1
	for i in controller.hand.size():
		if is_same(controller.hand[i], played_entry):
			idx = i
			break
	var ok: bool = controller.play_card(idx, target_index)
	card_cast_finished.emit(ok)
	var feedback_ref: WeakRef = ghost.get_meta("attack_feedback", null)
	var feedback: Node = feedback_ref.get_ref() if feedback_ref != null else null
	# The hit feedback already started in play_card; return the card alongside it.
	if ok and is_instance_valid(ghost) and is_instance_valid(controller):
		var in_discard: bool = controller.discard_pile.any(func(entry: Dictionary) -> bool: return is_same(entry, played_entry))
		if return_handler.is_valid():
			return_handler.call(ghost, in_discard, config)
		else:
			await _finish_card_flight(ghost, in_discard, config)
	# Wait only for any remaining hit/recovery work, never delay the return flight.
	if is_instance_valid(feedback) and feedback.playing_hits:
		await feedback.playback_finished
	var settle := create_tween()
	settle.tween_interval(CAST_SETTLE)
	await settle.finished
	input_locked = false


func _finish_card_flight(ghost: Control, in_discard: bool, config: Dictionary) -> void:
	var target_ref: WeakRef = ghost.get_meta("discard_target", null)
	var target: Control = target_ref.get_ref() if target_ref != null else null
	ghost.show() # An enchanted first hit may hide it; return it immediately.
	var duration := float(config["discard_seconds"])
	var tween := create_tween()
	if in_discard and is_instance_valid(target):
		var start := ghost.global_position
		var finish := target.get_global_rect().get_center() - ghost.size * 0.5
		var bend := (start + finish) * 0.5 + Vector2.UP * float(config["discard_arc_pixels"])
		tween.tween_method(func(weight: float):
			if is_instance_valid(ghost):
				ghost.global_position = start.lerp(bend, weight).lerp(bend.lerp(finish, weight), weight)
		, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(ghost, "rotation", TAU * float(config["discard_turns"]), duration)
	else:
		# Exhausted cards and powers leave the cycle, so do not fly into discard.
		tween.tween_property(ghost, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(ghost, "scale", Vector2.ONE * float(config["discard_scale"]), duration)
	await tween.finished
	if is_instance_valid(ghost): ghost.hide()


## 保留敌人逐击节奏与玩家受击反馈，不再创建、飞行或碎裂攻击卡。
func play_enemy_attack(player_panel: Control, on_impact: Callable = Callable()) -> void:
	var windup := create_tween()
	windup.tween_interval(ENEMY_WINDUP)
	await windup.finished
	if on_impact.is_valid(): on_impact.call()
	if is_instance_valid(player_panel):
		VFXSystem.screen_shake(6.0)
		VFXSystem.spawn_hit_shake(player_panel)
	var recovery := create_tween()
	recovery.tween_interval(ENEMY_RECOVERY)
	await recovery.finished


## 非攻击行动仅保留原有节拍与状态/格挡反馈。
func play_enemy_action(panel: Control, on_apply: Callable = Callable()) -> void:
	if panel == null:
		if on_apply.is_valid():
			on_apply.call()
		return
	var tw := create_tween()
	tw.tween_interval(SELF_BEAT)
	await tw.finished
	if on_apply.is_valid():
		on_apply.call()


## 敌人回合异步编排（P3 核心）：每个存活敌人均依次演出其意图，
## 全部播完后才调用 controller.enemy_phase_done() 开启下一玩家回合。
## player_panel：玩家面板 Control；enemy_panel_getter(e:CombatUnit)->Control 取敌方面板。
## 演出期间 input_locked=true，撞击点回调 controller 薄方法结算；任一敌人致死/玩家阵亡则提前收尾。
func run_enemy_turn(controller, player_panel: Control, enemy_panel_getter: Callable) -> void:
	# 防御性守卫：
	# 1) 已在演出中（input_locked）—— 防止同一结束回合被重复驱动（旧代码 end_player_turn
	#    若仍同步跑敌人阶段 + 新 _on_end_turn 又调本方法，会双跑敌人阶段 → “重复攻击”）。
	# 2) 仅在确实处于敌人阶段且战斗仍激活时才演出；phase 已回到 PLAYER 说明敌人阶段
	#    已被别处跑完，本方法应直接放弃，绝不二次攻击玩家。
	if input_locked:
		return
	if controller == null or not controller.combat_active():
		return
	if controller.phase != CombatController.Phase.ENEMY:
		return
	input_locked = true
	for e in controller.enemies.duplicate():
		if not is_instance_valid(e) or not e.is_alive():
			continue

		# 敌方回合开始：清格挡 + 回合开始状态（ashrot 等可能致死）
		var alive: bool = controller.enemy_pre(e)
		if not alive:
			if not controller.combat_active():
				break
			continue

		var mv: Dictionary = e.intent
		var kind: String = mv.get("intent", "unknown")
		var value: int = int(mv.get("value", 0))
		var times: int = int(mv.get("times", 1))
		var ep: Control = enemy_panel_getter.call(e) if enemy_panel_getter.is_valid() else null

		if kind == "attack":
			for i in times:
				if not controller.player_alive() or not e.is_alive():
					break
				var dmg: int = controller.enemy_outgoing(e, value)
				await play_enemy_attack(player_panel, func(): controller.enemy_attack_hit(e, dmg))
				if not controller.player_alive():
					controller.check_player_death()
					input_locked = false
					return
				if not controller.combat_active():
					input_locked = false
					return
		elif kind == "aoe_debuff":
			var dmg: int = controller.enemy_outgoing(e, value)
			await play_enemy_attack(player_panel, func(): controller.enemy_aoe_hit(e, dmg, mv))
			if not controller.player_alive():
				controller.check_player_death()
				input_locked = false
				return
			if not controller.combat_active():
				input_locked = false
				return
		else:
			# defend / buff / debuff / charge / unknown → 行动节拍后结算
			await play_enemy_action(ep, func(): controller.enemy_act(e))
			if not controller.combat_active():
				input_locked = false
				return

		if not controller.combat_active():
			input_locked = false
			return
		# 回合结束衰减 + 滚动下一手意图
		controller.enemy_post(e)

	if not controller.combat_active():
		input_locked = false
		return
	# 先解锁：enemy_phase_done 内部会 emit turn_started → 同步触发 _on_turn_started → refresh，
	# refresh 守卫检查 BattleDirector.input_locked，必须在此处先归 false 否则 UI 不更新。
	input_locked = false
	# 全部敌人演出完毕 → 开玩家回合（内部会 _check_combat_end）
	controller.enemy_phase_done()
