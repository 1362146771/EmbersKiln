extends Node
## BattleDirector —— 战斗演出序列器（autoload，不写 class_name，靠 project.godot 注册名全局调用）。
## 职责：把"出牌 cast 演出"与"敌人回合碰撞卡演出"从此处用 await 编排；演出本身
## 不碰数值结算，仅在"撞击点"回调 controller 的薄方法来结算伤害/状态。
##
## 关键约束（AGENTS/godot 踩坑）：本脚本不得写 class_name，否则与 autoload 单例名
## "BattleDirector" 冲突（Class X hides an autoload singleton）。

var input_locked := false        # 演出期间锁输入（拖拽/结束回合/药水在此被忽略）

const CAST_TRAVEL := 0.18        # 出牌飞行时长（s）
const CAST_SETTLE := 0.14       # 撞击后等爆发/飘字冒头的缓冲（s）
const SELF_BEAT := 0.34         # 敌人自身出牌（防御/buff 等）演出时长（s）


## 包装一次出牌的 cast 演出：卡飞向目标 → 到达瞬间结算 → 元素爆发 → 缓冲后交还。
## ghost 由 CombatUI 创建/持有，本方法只负责飞行+到达结算+爆发，并在结束时解锁。
func play_card_cast(ghost: Control, target_node: Control, cd: CardData, idx: int, target_index: int, controller) -> void:
	input_locked = true
	var to_pos := target_node.get_global_rect().get_center() - ghost.size * 0.5
	var tw := create_tween()
	tw.tween_property(ghost, "global_position", to_pos, CAST_TRAVEL).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ghost, "scale", Vector2(0.65, 0.65), CAST_TRAVEL)
	await tw.finished
	var ok: bool = controller.play_card(idx, target_index)
	if ok:
		VFXSystem.spawn_cast_burst(target_node, cd.type == &"attack")
	var settle := create_tween()
	settle.tween_interval(CAST_SETTLE)
	await settle.finished
	input_locked = false


## 敌人攻击"碰撞卡"演出（await 飞行+撞击+碎裂；撞击点 on_impact 由 Director 结算伤害）。
func play_strike_card(enemy_panel: Control, player_panel: Control, intent: Dictionary, on_impact: Callable = Callable()) -> void:
	await VFXSystem.spawn_strike_card(enemy_panel, player_panel, intent, on_impact)


## 敌人非攻击意图（防御/buff/debuff/charge 等）的"自身出牌"演出：
## 在敌方面板播元素爆发，稍候回调 on_apply 结算状态/格挡。
func play_self_card(panel: Control, is_buff: bool, on_apply: Callable = Callable()) -> void:
	if panel == null:
		if on_apply.is_valid():
			on_apply.call()
		return
	VFXSystem.spawn_cast_burst(panel, is_buff)
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
	for e in controller.enemies:
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
				if not controller.player_alive():
					break
				var dmg: int = controller.enemy_outgoing(e, value)
				await play_strike_card(ep, player_panel, mv, func(): controller.enemy_attack_hit(e, dmg))
				if not controller.player_alive():
					controller.check_player_death()
					input_locked = false
					return
				if not controller.combat_active():
					input_locked = false
					return
		elif kind == "aoe_debuff":
			var dmg: int = controller.enemy_outgoing(e, value)
			await play_strike_card(ep, player_panel, mv, func(): controller.enemy_aoe_hit(e, dmg, mv))
			if not controller.player_alive():
				controller.check_player_death()
				input_locked = false
				return
			if not controller.combat_active():
				input_locked = false
				return
		else:
			# defend / buff / debuff / charge / unknown → 自身出牌演出后结算
			var is_buff: bool = (kind == "buff" or kind == "charge")
			await play_self_card(ep, is_buff, func(): controller.enemy_act(e))
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


## 友方（随从）回合异步编排：玩家结束回合后、敌人回合前依次演出每个随从意图。
## 攻击意图：友色光弹从随从面板飞向敌方面板，撞击点回调 controller.ally_attack_hit 结算（含领袖气质加成）。
## 非攻击意图（defend/buff/debuff）：随从面板自身爆发，稍候回调 controller.ally_act 结算（复用 play_self_card）。
## 演出期间 input_locked=true；随从致死（turn_start 状态/寿命到期）/ 全灭 / 战斗结束则提前收尾。
## ally_panel_getter(a:CombatUnit)->Control 取随从面板；enemy_panel_getter(e:CombatUnit)->Control 取敌方面板。
## 与 run_enemy_turn 对称：本方法播完后 input_locked 归 false，调用方再驱动 run_enemy_turn。
func run_summon_turn(controller, player_panel: Control, enemy_panel_getter: Callable, ally_panel_getter: Callable) -> void:
	# 防御性守卫：与 run_enemy_turn 同构
	if input_locked:
		return
	if controller == null or not controller.combat_active():
		return
	if controller.phase != CombatController.Phase.ENEMY:
		return
	input_locked = true
	for a in controller.allies.duplicate():
		if not is_instance_valid(a) or not a.is_alive():
			continue

		# 随从回合开始：清格挡 + 回合开始状态（ashrot 等可能致死）
		var alive: bool = controller.ally_pre(a)
		if not alive:
			if not controller.combat_active():
				break
			continue

		var mv: Dictionary = a.intent
		var kind: String = mv.get("intent", "unknown")
		var value: int = int(mv.get("value", 0))
		var times: int = int(mv.get("times", 1))
		var ap: Control = ally_panel_getter.call(a) if ally_panel_getter.is_valid() else null

		if kind == "attack":
			for i in times:
				if not controller.combat_active():
					break
				var tgt = controller.first_alive_enemy()
				if tgt == null:
					break
				var ep: Control = enemy_panel_getter.call(tgt) if enemy_panel_getter.is_valid() else null
				var dmg: int = controller.ally_outgoing(a, tgt, value)
				await VFXSystem.spawn_summon_strike(ap, ep, func(): controller.ally_attack_hit(a, tgt, dmg))
				if not controller.combat_active():
					input_locked = false
					return
		else:
			# defend / buff / debuff / unknown → 自身出牌演出后结算
			var is_buff: bool = (kind == "buff")
			await play_self_card(ap, is_buff, func(): controller.ally_act(a))
			if not controller.combat_active():
				input_locked = false
				return

		controller.ally_post(a)
		if not controller.combat_active():
			input_locked = false
			return

	# 全部随从演出完毕 → 解锁，交由调用方驱动敌人回合
	input_locked = false
