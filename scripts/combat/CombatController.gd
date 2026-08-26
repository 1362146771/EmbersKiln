class_name CombatController
extends Node
## 战斗状态机（战斗核心）。主持单场战斗：抽/手/弃/耗牌堆、能量、回合循环、
## 卡牌效果结算、伤害/格挡/状态、敌人意图与行动、胜负判定。
## 铁律：所有数值取自 GameData / balance，禁止在脚本里写死。
## UI 不直接访问此类的内部字段，只通过 TurnManager 与 SignalBus 交互。

enum Phase { NONE, PLAYER, ENEMY, ENDED }

## 玩家持久 Power：kind(StringName) -> 数值
const POWER_START_TURN_BLOCK := &"power_start_turn_block"
const POWER_START_TURN_STRENGTH := &"power_start_turn_strength"
const POWER_END_TURN_AOE := &"power_end_turn_aoe"
const POWER_ON_ATTACK_STRENGTH := &"power_on_attack_strength"

## 窑温·共鸣（P2 新机制）

var player: CombatUnit
var enemies: Array[CombatUnit] = []
var allies: Array[CombatUnit] = []   # 友方随从（召唤物）

var draw_pile: Array = []      # [{id:StringName, upgraded:bool}]
var hand: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []

var energy: int = 0
var max_energy: int = 0
var turn: int = 0
var phase: int = Phase.NONE

var powers: Dictionary = {}    # StringName -> int（仅玩家持有）

## 窑温·共鸣：本场累计的窑温值（0 起，出 attack 牌 +1，满阈值触发窑变）
var kiln_heat: int = 0

## 焦渴（thirst）判定辅助：本回合是否打出过攻击牌；下回合是否扣能量
var _attack_played_this_turn: bool = false
var _thirst_penalty_next: bool = false

var _combat_active: bool = false

## 本场首张攻击牌是否已打出（劈薪斧遗物用）
var _first_attack_done: bool = false
## 当前由「持续型药水」施加的残留状态（§1.5 规则 2：新持续型顶旧持续型）
var _active_potion_statuses: Array = []


func _ready() -> void:
	# 由上层场景显式调用 start_combat，这里不自动开局。
	pass


# =====================================================================
# 战斗生命周期
# =====================================================================
func start_combat(enemy_ids: Array) -> void:
	if not GameData.is_loaded:
		push_error("[CombatController] GameData 未就绪")
		return
	if not RunState.is_active:
		RunState.start_new_run()

	# 玩家单元
	player = CombatUnit.new()
	player.setup(true, &"player", "炭之郎", RunState.max_hp, "res://art/player/SPR_Player_Tannaro_Idle.png")
	player.hp = RunState.hp

	# 敌人单元（难度系数在构造时施加）
	enemies.clear()
	allies.clear()
	for eid in enemy_ids:
		var ed: EnemyData = GameData.get_enemy(StringName(eid))
		if ed == null:
			push_error("[CombatController] 未知敌人: %s" % eid)
			continue
		var u := CombatUnit.new()
		u.setup(false, ed.id, ed.name, GameData.scaled_enemy_hp(ed.base_hp), ed.sprite)
		u.data = ed
		enemies.append(u)

	# 牌堆
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	for entry in RunState.deck:
		draw_pile.append({"id": entry["id"], "upgraded": entry["upgraded"], "enchants": entry.get("enchants", [])})
	_shuffle(draw_pile)

	# 能量
	var pc: Dictionary = GameData.player_config()
	max_energy = int(pc.get("energy_per_turn", 3))

	powers.clear()
	turn = 0
	_first_attack_done = false
	kiln_heat = 0
	_attack_played_this_turn = false
	_thirst_penalty_next = false
	phase = Phase.PLAYER
	_combat_active = true

	# 敌人初始意图
	for e in enemies:
		_roll_enemy_intent(e)

	SignalBus.combat_started.emit(enemy_ids)
	_start_player_turn()


func _start_player_turn() -> void:
	if not _combat_active:
		return
	turn += 1
	phase = Phase.PLAYER
	energy = max_energy

	# 焦渴（thirst）：上回合空过 → 本回合能量 -1
	if _thirst_penalty_next:
		energy = maxi(0, energy - 1)
		_thirst_penalty_next = false
		SignalBus.energy_changed.emit(energy, max_energy)

	_attack_played_this_turn = false

	# 回合开始：清理旧格挡 → 状态触发 → 玩家 Power
	player.block = 0
	_process_turn_start_statuses(player)
	_apply_player_start_turn_powers()
	_apply_relics_combat_start()   # 遗物：开局（格挡/炽热/抽牌）— 必须在 block 清零之后
	if turn == 1:
		_apply_relics_first_turn()  # 遗物：第一回合额外能量

	# 抽牌
	var draw_n: int = int(GameData.player_config().get("draw_per_turn", 5))
	_draw_cards(draw_n)

	# 注意：随从阶段不再在此同步执行。召唤物改为「玩家结束回合后、敌人回合前」
	# 由 BattleDirector.run_summon_turn 异步演出（带动画/VFX），与敌人回合范式一致。

	SignalBus.turn_started.emit(true)
	_log("玩家回合 %d 开始 — 能量 %d，手牌 %d" % [turn, energy, hand.size()])


func end_player_turn() -> void:
	if phase != Phase.PLAYER:
		return
	# 注意：玩家格挡不清空 —— 必须保留到敌人阶段，先扛过敌人攻击，
	# 再在下个玩家回合开始（_start_player_turn）时清零。
	_apply_player_end_turn_powers()
	# 焦渴（thirst）：回合结束未打出攻击牌 → 下回合 -1 能量（读 thirst 先于衰减）
	if player.has_status(&"thirst") and not _attack_played_this_turn:
		_thirst_penalty_next = true
	_decay_statuses_at_turn_end(player)
	phase = Phase.ENEMY
	# 玩家回合结束信号（UI 可据此切换状态）；敌人回合的碰撞卡演出与
	# "全部播完才进下一回合"由 BattleDirector.run_enemy_turn 异步编排，
	# CombatUI._on_end_turn 在调用本方法后触发它，本方法不再同步跑敌人阶段。
	SignalBus.turn_ended.emit(true)


## （P3 起废弃）原同步敌人阶段已拆为 BattleDirector.run_enemy_turn + 上述薄包装。
## 保留 _run_enemy_phase_async 名称作为历史占位已删除；逻辑全部在 Director 内。


func _execute_enemy_intent(e: CombatUnit) -> void:
	var mv: Dictionary = e.intent
	if mv.is_empty():
		return
	var kind: String = mv.get("intent", "unknown")
	var value: int = int(mv.get("value", 0))
	var times: int = int(mv.get("times", 1))

	match kind:
		"attack":
			for i in times:
				if not player.is_alive():
					break
				var dmg := _compute_outgoing(e, player, value)
				enemy_attack_hit(e, dmg)
		"defend":
			e.add_block(value)
		"buff":
			var sid := StringName(mv.get("status", ""))
			if sid != &"":
				_apply_status(e, sid, value)
		"debuff":
			var sid := StringName(mv.get("status", ""))
			if sid != &"":
				_apply_status(player, sid, value)
		"charge":
			# 蓄力：本回合不造成输出，给玩家一回合决策窗口。
			# 可选 value=自身格挡（蓄势防御）；下回合通过 next 强制释放招式。
			var brace: int = int(mv.get("value", 0))
			if brace > 0:
				e.add_block(brace)
			var nx := StringName(mv.get("next", ""))
			if nx != &"":
				e.charge_next = nx
			_log("敌人 %s 蓄力（下回合释放 %s）" % [e.unit_name, nx])
		"unknown":
			pass
		"aoe_debuff":
			var dmg := _compute_outgoing(e, player, value)
			enemy_aoe_hit(e, dmg, mv)
	_log("敌人 %s 行动：%s" % [e.unit_name, kind])


# =====================================================================
# P3 薄包装（供 BattleDirector.run_enemy_turn 异步驱动；逻辑与上方 _execute_enemy_intent 共用，不重复实现）
# =====================================================================
## 敌方回合开始：清旧格挡 + 回合开始状态（ashrot 等可能致死 → _post_enemy_death）。
## 返回行动后是否仍存活。
func enemy_pre(e: CombatUnit) -> bool:
	e.block = 0
	_process_turn_start_statuses(e)
	return e.is_alive()


## 敌方回合结束：状态衰减 + 滚动下一手意图。
func enemy_post(e: CombatUnit) -> void:
	_decay_statuses_at_turn_end(e)
	_roll_enemy_intent(e)


## 计算敌人 outgoing（含炽热加成等，不含格挡——格挡在 apply_damage 内结算）。
func enemy_outgoing(e: CombatUnit, base: int) -> int:
	return _compute_outgoing(e, player, base)


## 单次攻击命中结算（供碰撞卡撞击点回调）。
func enemy_attack_hit(e: CombatUnit, dmg: int) -> void:
	_deal_to_player(dmg)
	_tick_sherd_vest(e)   # 遗物：受击反伤（陶片背心）


## AOE 伤害 + 对玩家施加 debuff（如釉裂）；友方随从同步受击（Q2）。
func enemy_aoe_hit(e: CombatUnit, dmg: int, mv: Dictionary) -> void:
	_deal_to_player(dmg)
	_tick_sherd_vest(e)
	for a in allies:
		if a.is_alive():
			var ad := _compute_outgoing(e, a, int(mv.get("value", 0)))
			_deal_to_ally(a, ad)
	var sid := StringName(mv.get("status", ""))
	var sval := int(mv.get("status_value", 0))
	if sid != &"" and sval != 0:
		_apply_status(player, sid, sval)


## 非攻击意图（防御/buff/debuff/charge/unknown）整体结算（自身出牌演出后回调）。
func enemy_act(e: CombatUnit) -> void:
	_execute_enemy_intent(e)


## 敌人全灭/玩家阵亡判定 + 开启下一玩家回合。由 Director 在全部敌方演出完毕后调用。
func enemy_phase_done() -> void:
	SignalBus.turn_ended.emit(false)
	_check_combat_end()
	if _combat_active:
		_start_player_turn()


func combat_active() -> bool:
	return _combat_active


func player_alive() -> bool:
	return player != null and player.is_alive()


## 玩家在敌人攻击中阵亡时显式触发失败流程（_deal_to_player 不自行判定死亡）。
func check_player_death() -> void:
	if not player.is_alive():
		_on_player_death()


## 为敌人滚动下一手意图（加权随机 / Boss 分阶段），并广播给 UI。
## 若上一回合处于蓄力（charge_next 非空），则跳过随机、直接强制打出释放招式。
func _roll_enemy_intent(e: CombatUnit) -> void:
	var ed: EnemyData = e.data
	if e.charge_next != &"":
		var forced: Dictionary = {}
		if ed != null:
			forced = ed.find_move(e.charge_next)
		e.charge_next = &""   # 消费掉，只强制一次
		if forced.is_empty() and ed != null:
			# 释放招式不存在时回退到正常选择（不卡死）
			forced = EnemyAI.choose_intent(ed, float(e.hp) / float(e.max_hp) if e.max_hp > 0 else 1.0)
		e.intent = _scale_intent_damage(forced)
		SignalBus.enemy_intent_changed.emit(
			_index_of(e),
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
			_apply_phase_on_enter(e, ed.phases[pidx])
		e.phase_index = pidx
	e.intent = _scale_intent_damage(EnemyAI.choose_intent(ed, ratio))
	SignalBus.enemy_intent_changed.emit(
		_index_of(e),
		StringName(e.intent.get("intent", "unknown")),
		int(e.intent.get("value", 0))
	)


## 伤害类意图（attack / aoe_debuff）按难度系数 × 当前幕 act_dmg_mult 缩放（P-D 接线）。
## 注意：choose_intent 返回的是 EnemyData.moves 内部字典的引用，必须 duplicate 后再改，
## 否则每次重抽都会在基础数据上重复累乘。
func _scale_intent_damage(intent: Dictionary) -> Dictionary:
	if intent.is_empty():
		return intent
	var kind: String = intent.get("intent", "")
	if kind != "attack" and kind != "aoe_debuff":
		return intent
	var out: Dictionary = intent.duplicate()
	out["value"] = GameData.scaled_enemy_damage(int(intent.get("value", 0)))
	return out


## 阶段切换时触发该阶段的 on_enter（自增益类，如觉醒自身加 3 炽热）。
## 数据驱动：阶段条目可含 on_enter: [{status, value}, ...]，作用于敌人自身。
func _apply_phase_on_enter(e: CombatUnit, phase: Dictionary) -> void:
	for buff in phase.get("on_enter", []):
		if not (buff is Dictionary):
			continue
		var sid := StringName(buff.get("status", ""))
		if sid != &"":
			_apply_status(e, sid, int(buff.get("value", 0)))
	_log("敌人 %s 进入新阶段，触发 on_enter" % e.unit_name)


# =====================================================================
# 随从 / 召唤（Summon System，见 SUMMON_SYSTEM_DESIGN.md）
# =====================================================================
func _index_of_ally(a: CombatUnit) -> int:
	return allies.find(a)


## 随从 / 召唤（异步演出薄包装，供 BattleDirector.run_summon_turn 驱动；
## 与敌人 enemy_pre/enemy_attack_hit/enemy_post 范式一致，不重复实现）
## ---------------------------------------------------------------------

## 友方回合开始：清旧格挡 + 回合开始状态（ashrot 等可能致死 → _post_ally_death）。
## 返回行动后是否仍存活；存活则提亮面板（ally_action_start），死亡则不提亮。
func ally_pre(a: CombatUnit) -> bool:
	a.block = 0
	_process_turn_start_statuses(a, _post_ally_death)
	if not a.is_alive():
		return false
	SignalBus.ally_action_start.emit(_index_of_ally(a))
	return true


## 友方攻击 outgoing（含指挥加成、炽热/防潮/釉裂等，不含格挡）。
func ally_outgoing(a: CombatUnit, target: CombatUnit, base: int) -> int:
	var dmg := _compute_outgoing(a, target, base)
	var cmd: int = player.get_status(&"command") if player.has_status(&"command") else 0
	return dmg + cmd


## 单次攻击命中结算（供光弹撞击点回调）。目标已亡则改打首个存活敌人。
func ally_attack_hit(a: CombatUnit, target: CombatUnit, dmg: int) -> void:
	if target == null or not target.is_alive():
		target = _first_alive_enemy()
	if target == null:
		return
	_deal_to_unit(target, dmg)


## 非攻击意图（防御/buff/debuff/unknown）整体结算（自身出牌演出后回调）。
func ally_act(a: CombatUnit) -> void:
	_execute_minion_non_attack(a)


## 友方行动结束：状态衰减 + 寿命-1/到期消失 + 滚动下一意图。
func ally_post(a: CombatUnit) -> void:
	_decay_statuses_at_turn_end(a)
	a.lifetime -= 1
	SignalBus.ally_lifetime_changed.emit(_index_of_ally(a), a.lifetime)
	if a.lifetime <= 0:
		_post_ally_death(a)
	else:
		_roll_minion_intent(a)
	SignalBus.ally_action_end.emit(_index_of_ally(a))


## 召唤随从：受上场上限约束；满场则广播 summon_rejected 并停止。
func _summon_minion(mid: StringName, count: int) -> void:
	var md: MinionData = GameData.get_minion(mid)
	if md == null:
		push_warning("[Combat] 未知随从: %s" % mid)
		return
	var cap: int = int(GameData.balance.get("summon", {}).get("max_summons", 3))
	for n in count:
		if allies.size() >= cap:
			SignalBus.summon_rejected.emit(cap)
			_log("召唤栏已满（上限 %d），无法继续召唤" % cap)
			break
		var a := CombatUnit.new()
		a.setup(false, md.id, md.name, md.hp, md.sprite)
		a.block = md.block
		a.lifetime = md.lifetime
		a.data = md
		a.move_cursor = 0
		allies.append(a)
		_roll_minion_intent(a)
		SignalBus.ally_hp_changed.emit(_index_of_ally(a), a.hp, a.max_hp)
		SignalBus.ally_block_changed.emit(_index_of_ally(a), a.block)
		_log("召唤随从 %s（%d/%d）" % [md.name, allies.size(), cap])
	SignalBus.allies_changed.emit()


## 随从阶段：清旧格挡 → turn_start 状态 → 行动 → 寿命-1/到期消失。
func _summon_phase() -> void:
	if not _combat_active:
		return
	for a in allies.duplicate():
		if not is_instance_valid(a):
			continue
		a.block = 0
		_process_turn_start_statuses(a, _post_ally_death)
		if not a.is_alive():
			continue
		_execute_minion_intent(a)
		if not _combat_active:
			return
		_decay_statuses_at_turn_end(a)
		a.lifetime -= 1
		SignalBus.ally_lifetime_changed.emit(_index_of_ally(a), a.lifetime)
		if a.lifetime <= 0:
			_post_ally_death(a)


## 随从按意图行动（attack/defend/buff/debuff）。指挥(command) 给攻击/格挡加成。
## 攻击走 Director 撞击点（异步演出用 ally_outgoing），此处攻击循环供同步测试路径复用同一逻辑。
func _execute_minion_intent(a: CombatUnit) -> void:
	var mv: Dictionary = a.intent
	if mv.is_empty():
		return
	SignalBus.ally_action_start.emit(_index_of_ally(a))
	var kind: String = mv.get("intent", "unknown")
	var value: int = int(mv.get("value", 0))
	var times: int = int(mv.get("times", 1))
	match kind:
		"attack":
			for i in times:
				var tgt: CombatUnit = _first_alive_enemy()
				if tgt == null:
					break
				var dmg := ally_outgoing(a, tgt, value)
				_deal_to_unit(tgt, dmg)
		"defend", "buff", "debuff", "unknown":
			_execute_minion_non_attack(a)
	_roll_minion_intent(a)   # 滚动下一意图（fixed：循环 moves）
	SignalBus.ally_action_end.emit(_index_of_ally(a))


## 随从非攻击意图结算（defend/buff/debuff/unknown）。攻击意图由 Director 撞击点驱动，不走这里。
## 与 _execute_minion_intent 共用，避免逻辑重复（同步测试路径与异步演出路径一致）。
func _execute_minion_non_attack(a: CombatUnit) -> void:
	var mv: Dictionary = a.intent
	if mv.is_empty():
		return
	var kind: String = mv.get("intent", "unknown")
	var value: int = int(mv.get("value", 0))
	var cmd: int = player.get_status(&"command") if player.has_status(&"command") else 0
	match kind:
		"defend":
			_add_block(a, value + cmd)
		"buff":
			var sid := StringName(mv.get("status", ""))
			if sid != &"":
				_apply_status(a, sid, value)
		"debuff":
			var sid := StringName(mv.get("status", ""))
			if sid != &"":
				_apply_status(player, sid, value)
		"unknown":
			pass


## 随从意图：fixed AI 循环 moves（复用敌人意图 schema，随从无难度缩放）。
## 软约束：随从单次攻击不超过上限（防数据溢出，SM-03）。
func _roll_minion_intent(a: CombatUnit) -> void:
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
	SignalBus.ally_intent_changed.emit(_index_of_ally(a), StringName(mv.get("intent", "unknown")), int(mv.get("value", 0)))


## 友方随从受击（AoE 敌人用）：扣血 → 广播 → 死亡清理。
func _deal_to_ally(a: CombatUnit, final_dmg: int) -> void:
	a.apply_damage(final_dmg)
	SignalBus.ally_hp_changed.emit(_index_of_ally(a), a.hp, a.max_hp)
	if not a.is_alive():
		_post_ally_death(a)


func _post_ally_death(a: CombatUnit) -> void:
	# 注意：随从死亡/到期都走这里。寿命到期时 HP 仍 > 0（is_alive 为真），
	# 故不能按 is_alive 判定，只能按"是否还在友方列表"防重复移除。
	if not allies.has(a):
		return
	var idx: int = _index_of_ally(a)
	SignalBus.ally_died.emit(idx)
	allies.erase(a)
	_log("随从 %s 消失" % a.unit_name)


# =====================================================================
# 出牌
# =====================================================================
func play_card(hand_index: int, target_index: int = -1) -> bool:
	if phase != Phase.PLAYER:
		return false
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card: Dictionary = hand[hand_index]
	var cd: CardData = GameData.get_card(card["id"])
	if cd == null:
		return false
	if energy < cd.cost:
		return false

	energy -= cd.cost

	# 选目标
	var primary: CombatUnit = null
	match cd.target:
		&"enemy":
			if target_index >= 0 and target_index < enemies.size() and enemies[target_index].is_alive():
				primary = enemies[target_index]
			else:
				primary = _first_alive_enemy()
		&"self":
			primary = player
		&"all_enemies":
			primary = null
		&"none":
			primary = player

	var effects: Array = cd.get_effects(card["upgraded"])
	# 附魔结算（升级覆盖 → 附魔加法 → 状态结算）：先叠附魔加成，再走既有结算
	effects = _apply_enchant_mods(effects, cd, card.get("enchants", []))
	# 遗物：本场第一张攻击牌额外伤害（劈薪斧）
	if cd.type == &"attack":
		effects = _apply_first_attack_bonus(effects)
	_resolve_effects(effects, player, primary)

	# Power：每次打出攻击牌获得炽热
	if cd.type == &"attack":
		if powers.has(POWER_ON_ATTACK_STRENGTH):
			_apply_status(player, &"heat", int(powers[POWER_ON_ATTACK_STRENGTH]))
		_first_attack_done = true
		_attack_played_this_turn = true
		# 窑温·共鸣：每打出 1 张 attack 牌 +1 窑温
		kiln_heat += 1
		SignalBus.kiln_heat_changed.emit(kiln_heat, _kiln_threshold())
		_check_kiln_resonance()
		# 蓄焰（stoke）：攻击牌出手后 -1 层
		if player.has_status(&"stoke"):
			_apply_status(player, &"stoke", -1)

	# 卡牌离手
	hand.remove_at(hand_index)
	if cd.exhaust:
		exhaust_pile.append(card)
	else:
		discard_pile.append(card)

	SignalBus.card_played.emit(cd.id, target_index)
	_log("出牌：%s（耗能 %d，剩余能量 %d）" % [cd.name, cd.cost, energy])
	_check_combat_end()
	return true


# =====================================================================
# 效果结算（14 种 effect_kind 分派）
# =====================================================================
func _resolve_effects(effects: Array, source: CombatUnit, primary: CombatUnit, potion_apply: bool = false) -> void:
	for eff in effects:
		if not (eff is Dictionary):
			continue
		var kind: String = eff.get("kind", "")
		var value: int = int(eff.get("value", 0))
		var times: int = int(eff.get("times", 1))
		match kind:
			"damage":
				for i in times:
					if primary == null or not primary.is_alive():
						break
					var dmg := _compute_outgoing(source, primary, value)
					if source.is_player and source.has_status(&"stoke"):
						dmg += source.get_status(&"stoke")
					_deal_to_unit(primary, dmg)
					_tick_heat_siphon(source)
			"aoe_damage":
				for e in enemies:
					if not e.is_alive():
						continue
					for i in times:
						if not e.is_alive():
							break
						var dmg := _compute_outgoing(source, e, value)
						if source.is_player and source.has_status(&"stoke"):
							dmg += source.get_status(&"stoke")
						_deal_to_unit(e, dmg)
						_tick_heat_siphon(source)
			"block":
				_add_block(source, value)
			"draw":
				_draw_cards(value)
			"energy":
				energy += value
				SignalBus.energy_changed.emit(energy, max_energy)
			"heal":
				source.heal(value)
				if source.is_player:
					_sync_player_hp()
			"gain_strength":
				# 设计命名 strength -> 状态「炽热 heat」
				if potion_apply: _apply_potion_status(source, &"heat", value)
				else: _apply_status(source, &"heat", value)
			"gain_dexterity":
				# 设计命名 dexterity -> 状态「塑形 temper」
				if potion_apply: _apply_potion_status(source, &"temper", value)
				else: _apply_status(source, &"temper", value)
			"apply_status":
				var tgt_name: String = String(eff.get("target", "enemy"))
				var sid: StringName = StringName(eff.get("status", ""))
				if tgt_name == "all_enemies":
					for e in enemies:
						if e.is_alive():
							if potion_apply: _apply_potion_status(e, sid, value)
							else: _apply_status(e, sid, value)
				else:
					var tgt: CombatUnit = _resolve_status_target(tgt_name, primary)
					if tgt != null:
						if potion_apply: _apply_potion_status(tgt, sid, value)
						else: _apply_status(tgt, sid, value)
			"exhaust":
				pass  # 消耗由 play_card 处理
			"power_start_turn_block", "power_start_turn_strength", "power_end_turn_aoe", "power_on_attack_strength":
				_register_power(StringName(kind), value)
			"gain_kiln_heat":
				# 窑温联动：直接积累窑温，可能立即触发窑变
				kiln_heat += value
				SignalBus.kiln_heat_changed.emit(kiln_heat, _kiln_threshold())
				_check_kiln_resonance()
			"summon":
				var mid: StringName = StringName(eff.get("minion_id", ""))
				var cnt: int = int(eff.get("count", 1))
				_summon_minion(mid, cnt)
			_:
				push_warning("[CombatController] 未识别的 effect_kind: %s" % kind)

func _resolve_status_target(target: Variant, primary: CombatUnit) -> CombatUnit:
	var t: String = String(target)
	match t:
		"self":
			return player
		"enemy":
			return primary if primary != null else _first_alive_enemy()
		_:
			return primary


func _register_power(kind: StringName, value: int) -> void:
	powers[kind] = int(powers.get(kind, 0)) + value


# =====================================================================
# 附魔结算（卡牌第二定制层）与药水使用
# =====================================================================

## 将一张卡的附魔修正叠加到其效果序列（加法，不触碰状态/力量结算）。
## 顺序：升级覆盖已在此前 get_effects 完成；此处仅做「附魔加法」。
## 深拷贝避免改到 CardData 静态数据。
func _apply_enchant_mods(effects: Array, cd: CardData, enchants: Array) -> Array:
	if enchants.is_empty():
		return effects
	var out: Array = effects.duplicate(true)
	for eid in enchants:
		var ed: EnchantData = GameData.get_enchant(StringName(eid))
		if ed == null:
			continue
		if not ed.matches_card(cd):
			continue
		if not ed.meets_condition(cd.cost):
			continue
		var m: Dictionary = ed.mods
		var db: int = int(m.get("damage_bonus", 0))
		var bb: int = int(m.get("block_bonus", 0))
		var ab: int = int(m.get("aoe_damage_bonus", 0))
		var dab: int = int(m.get("draw_bonus", 0))
		var hb: int = int(m.get("heal_bonus", 0))
		if db != 0 or bb != 0 or ab != 0 or dab != 0 or hb != 0:
			for eff in out:
				if not (eff is Dictionary):
					continue
				var k: String = eff.get("kind", "")
				if k == "damage" and db != 0:
					eff["value"] = int(eff.get("value", 0)) + db
				elif k == "aoe_damage" and ab != 0:
					eff["value"] = int(eff.get("value", 0)) + ab
				elif k == "block" and bb != 0:
					eff["value"] = int(eff.get("value", 0)) + bb
				elif k == "draw" and dab != 0:
					eff["value"] = int(eff.get("value", 0)) + dab
				elif k == "heal" and hb != 0:
					eff["value"] = int(eff.get("value", 0)) + hb
		var extra: Array = m.get("extra_effects", [])
		for ex in extra:
			if ex is Dictionary:
				out.append(ex.duplicate())
	return out


## 使用携带格中的第 slot_index 瓶药水（战斗中、Free Action、消耗）。
## 规则：不耗能量、不打断出牌、不触发焦渴；用后 exhaust 移除。
## §1.5 互斥：持续型药水先清除上一瓶持续型残留，再施加本次（新顶旧）。
func use_potion(slot_index: int, target_index: int = -1) -> bool:
	if phase != Phase.PLAYER or not _combat_active:
		return false
	if slot_index < 0 or slot_index >= RunState.potions.size():
		return false
	var pid: StringName = RunState.potions[slot_index]
	var pd: PotionData = GameData.get_potion(pid)
	if pd == null:
		return false

	var primary: CombatUnit = null
	match pd.target:
		&"enemy":
			if target_index >= 0 and target_index < enemies.size() and enemies[target_index].is_alive():
				primary = enemies[target_index]
			else:
				primary = _first_alive_enemy()
		&"self":
			primary = player
		&"all_enemies":
			primary = null

	if pd.is_persistent():
		_clear_active_potion_statuses()

	_resolve_effects(pd.effects.duplicate(), player, primary, true)

	RunState.remove_potion_at(slot_index)
	_log("使用药水：%s" % pd.name)
	_check_combat_end()
	return true


## 施加「由持续型药水」带来的状态，并记录以便规则 2 顶替。
## 规则 1（同类型不重复生效）：目标已带该状态（无论来源）则不叠加、不记录。
func _apply_potion_status(unit: CombatUnit, status_id: StringName, amount: int) -> void:
	if unit == null or status_id == &"":
		return
	if unit.get_status(status_id) > 0:
		return
	_apply_status(unit, status_id, amount)
	_active_potion_statuses.append({"unit": unit, "status_id": status_id})


## 规则 2：清除上一瓶持续型药水施加的全部残留状态（新的顶旧的）。
func _clear_active_potion_statuses() -> void:
	for rec in _active_potion_statuses:
		var u: Variant = rec.get("unit")
		var sid: StringName = rec.get("status_id", &"")
		if u != null and is_instance_valid(u) and sid != &"":
			var cu: CombatUnit = u as CombatUnit
			var cur: int = cu.get_status(sid)
			if cur > 0:
				cu.add_status(sid, -cur)
	_active_potion_statuses.clear()


# =====================================================================
# 伤害 / 格挡 / 状态
# =====================================================================
## 计算从 attacker 对 target 的最终伤害：含炽热加成、防潮削弱、釉裂易伤。
func _compute_outgoing(attacker: CombatUnit, target: CombatUnit, base: int) -> int:
	var dmg := base
	if attacker.has_status(&"heat"):
		dmg += attacker.get_status(&"heat")
	if attacker.has_status(&"damp"):
		dmg = int(floor(dmg * 0.75))
	if target.has_status(&"crazed"):
		dmg = int(floor(dmg * 1.5))
	return maxi(0, dmg)


func _deal_to_unit(unit: CombatUnit, final_dmg: int) -> void:
	unit.apply_damage(final_dmg)
	SignalBus.damage_dealt.emit(not unit.is_player, _index_of(unit), final_dmg)
	if unit.is_player:
		_sync_player_hp()
	else:
		SignalBus.enemy_hp_changed.emit(_index_of(unit), unit.hp, unit.max_hp)
		if not unit.is_alive():
			_post_enemy_death(unit)


func _deal_to_player(final_dmg: int) -> void:
	var dmg := maxi(0, final_dmg)
	# 釉光（glaze）：受到攻击时减伤等于层数，触发 1 次后 -1 层
	if player.has_status(&"glaze"):
		dmg = maxi(0, dmg - player.get_status(&"glaze"))
		_apply_status(player, &"glaze", -1)
	player.apply_damage(dmg)
	_sync_player_hp()
	SignalBus.damage_dealt.emit(false, -1, dmg)


## 窑温·共鸣：累计满 _kiln_threshold() 时立即触发「窑变」——
## 对所有敌人造成 _kiln_pierce() 点贯穿伤害（无视格挡），并消耗阈值点窑温。
## 用 while 而非 if，避免极端情况下一次超出多倍阈值时只触发一次。
func _kiln_threshold() -> int:
	return int(GameData.balance.get("kiln_temperature", {}).get("threshold", 5))

func _kiln_pierce() -> int:
	return int(GameData.balance.get("kiln_temperature", {}).get("pierce_damage", 5))

func _check_kiln_resonance() -> void:
	while kiln_heat >= _kiln_threshold():
		kiln_heat -= _kiln_threshold()
		SignalBus.kiln_heat_changed.emit(kiln_heat, _kiln_threshold())
		for e in enemies:
			if e.is_alive():
				_deal_kiln_resonance(e, _kiln_pierce())
		_check_combat_end()


## 窑变贯穿伤害：绕过格挡直接扣血。
func _deal_kiln_resonance(unit: CombatUnit, dmg: int) -> void:
	unit.lose_hp_direct(dmg)
	SignalBus.enemy_hp_changed.emit(_index_of(unit), unit.hp, unit.max_hp)
	SignalBus.damage_dealt.emit(true, _index_of(unit), dmg)
	if not unit.is_alive():
		_post_enemy_death(unit)


func _add_block(unit: CombatUnit, amount: int) -> void:
	var real := amount
	if unit.has_status(&"temper"):
		real += unit.get_status(&"temper")
	unit.add_block(real)
	if unit.is_player:
		SignalBus.player_block_changed.emit(player.block)
	else:
		SignalBus.ally_block_changed.emit(_index_of_ally(unit), unit.block)


func _apply_status(unit: CombatUnit, status_id: StringName, amount: int) -> void:
	if status_id == &"":
		return
	if allies.has(unit):
		unit.add_status(status_id, amount)
		SignalBus.ally_status_applied.emit(_index_of_ally(unit), status_id, unit.get_status(status_id))
		return
	unit.add_status(status_id, amount)
	if unit.is_player:
		SignalBus.status_applied.emit(true, -1, status_id, unit.get_status(status_id))
	else:
		SignalBus.status_applied.emit(false, _index_of(unit), status_id, unit.get_status(status_id))


# =====================================================================
# 牌堆
# =====================================================================
func _draw_cards(n: int) -> void:
	var hand_max: int = int(GameData.player_config().get("hand_max", 10))
	for i in n:
		if hand.size() >= hand_max:
			break
		if draw_pile.is_empty():
			_reshuffle_discard()
		if draw_pile.is_empty():
			break
		var card: Dictionary = draw_pile.pop_front()
		hand.append(card)
		SignalBus.card_drawn.emit(card["id"])


func _reshuffle_discard() -> void:
	for c in discard_pile:
		draw_pile.append(c)
	discard_pile.clear()
	_shuffle(draw_pile)


func _shuffle(arr: Array) -> void:
	var n := arr.size()
	for i in range(n - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# =====================================================================
# 回合开始/结束 状态结算
# =====================================================================
func _process_turn_start_statuses(unit: CombatUnit, on_death: Callable = Callable()) -> void:
	for sid in unit.status_ids():
		var sd: StatusData = GameData.get_status(sid)
		if sd == null or sd.trigger != &"turn_start":
			continue
		if sid == &"ashrot":
			unit.lose_hp_direct(unit.get_status(sid))
			if unit.is_player:
				_sync_player_hp()
			else:
				SignalBus.enemy_hp_changed.emit(_index_of(unit), unit.hp, unit.max_hp)
		elif sid == &"anneal":
			unit.heal(unit.get_status(sid))
			if unit.is_player:
				_sync_player_hp()
			else:
				SignalBus.enemy_hp_changed.emit(_index_of(unit), unit.hp, unit.max_hp)
		unit.add_status(sid, -1)  # 触发型：层数 -1
		if not unit.is_alive():
			if unit.is_player:
				_sync_player_hp()
				_on_player_death()
			elif on_death.is_valid():
				on_death.call(unit)
			else:
				_post_enemy_death(unit)


func _decay_statuses_at_turn_end(unit: CombatUnit) -> void:
	for sid in unit.status_ids():
		var sd: StatusData = GameData.get_status(sid)
		if sd == null or not sd.decay or sd.trigger == &"turn_start":
			continue
		unit.add_status(sid, -sd.decay_per_turn)


func _apply_player_start_turn_powers() -> void:
	if powers.has(POWER_START_TURN_BLOCK):
		_add_block(player, int(powers[POWER_START_TURN_BLOCK]))
	if powers.has(POWER_START_TURN_STRENGTH):
		_apply_status(player, &"heat", int(powers[POWER_START_TURN_STRENGTH]))


func _apply_player_end_turn_powers() -> void:
	if powers.has(POWER_END_TURN_AOE):
		for e in enemies:
			if not e.is_alive():
				continue
			var dmg := int(powers[POWER_END_TURN_AOE])
			_deal_to_unit(e, dmg)


# =====================================================================
# 胜负
# =====================================================================
func _check_combat_end() -> void:
	if not _combat_active:
		return
	if not player.is_alive():
		_on_player_death()
		return
	var any_alive := false
	for e in enemies:
		if e.is_alive():
			any_alive = true
			break
	if not any_alive:
		_combat_active = false
		phase = Phase.ENDED
		_apply_relics_after_combat()  # 遗物：战后（余温炭回血）
		SignalBus.combat_ended.emit(true)
		_log("战斗胜利！")


func _on_player_death() -> void:
	if not _combat_active:
		return
	_combat_active = false
	phase = Phase.ENDED
	_sync_player_hp()
	SignalBus.combat_ended.emit(false)
	RunState.end_run(false)
	_log("玩家阵亡，战斗失败。")


func _post_enemy_death(e: CombatUnit) -> void:
	if e.is_alive():
		return
	SignalBus.unit_died.emit(false, _index_of(e))
	RunState.defeated.append(e.id)
	_log("敌人 %s 被击败" % e.unit_name)
	_check_combat_end()


# =====================================================================
# 遗物钩子（接入 RunState 持有的遗物，按 trigger 触发）
# =====================================================================
func _apply_relics_combat_start() -> void:
	for r in RunState.relics_with_trigger(&"combat_start"):
		match r.id:
			&"bellows_glove":
				_apply_status(player, &"heat", int(r.value))
			&"keeper_apron":
				_draw_cards(int(r.value))
			&"hearth_totem":
				_add_block(player, int(r.value))
			&"kilnmark":
				_summon_minion(&"emberhound", int(r.value))


func _apply_relics_first_turn() -> void:
	for r in RunState.relics_with_trigger(&"combat_start_first_turn"):
		if r.id == &"draft_flue":
			energy += int(r.value)
			SignalBus.energy_changed.emit(energy, max_energy)


## 本场第一张攻击牌：劈薪斧 +value 伤害（仅作用于首个伤害效果）。
func _apply_first_attack_bonus(effects: Array) -> Array:
	if _first_attack_done:
		return effects
	var bonus := 0
	for r in RunState.relics_with_trigger(&"first_attack_each_combat"):
		if r.id == &"firewood_axe":
			bonus += int(r.value)
	if bonus <= 0:
		return effects
	var out: Array = effects.duplicate()
	for eff in out:
		if eff is Dictionary:
			var k := String(eff.get("kind", ""))
			if k == "damage" or k == "aoe_damage":
				eff["value"] = int(eff.get("value", 0)) + bonus
				break
	return out


## 每次玩家造成攻击伤害后回血（汲热钳）。
func _tick_heat_siphon(source: CombatUnit) -> void:
	if not source.is_player:
		return
	for r in RunState.relics_with_trigger(&"on_attack_damage"):
		if r.id == &"heat_siphon":
			source.heal(int(r.effect_flat))
			_sync_player_hp()


## 玩家受攻击时反伤攻击者（陶片背心）。
func _tick_sherd_vest(attacker: CombatUnit) -> void:
	for r in RunState.relics_with_trigger(&"on_hit"):
		if r.id == &"sherd_vest" and attacker.is_alive():
			_deal_to_unit(attacker, int(r.value))


func _apply_relics_after_combat() -> void:
	for r in RunState.relics_with_trigger(&"after_combat"):
		if r.id == &"emberheart":
			RunState.heal(int(r.value))


# =====================================================================
# 工具
# =====================================================================
func _first_alive_enemy() -> CombatUnit:
	for e in enemies:
		if e.is_alive():
			return e
	return null


## 首个存活敌人（公开包装，供 BattleDirector.run_summon_turn 取攻击目标）。
func first_alive_enemy() -> CombatUnit:
	return _first_alive_enemy()


func _index_of(unit: CombatUnit) -> int:
	if unit.is_player:
		return -1
	return enemies.find(unit)


func _sync_player_hp() -> void:
	RunState.hp = player.hp
	SignalBus.player_hp_changed.emit(player.hp, player.max_hp)


func _log(msg: String) -> void:
	print("[Combat] " + msg)
