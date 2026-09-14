class_name CombatController
extends Node
## 战斗状态机（战斗核心）门面。主持单场战斗：抽/手/弃/耗牌堆、能量、回合循环、
## 卡牌效果结算、伤害/格挡/状态、敌人意图与行动、胜负判定。
## 铁律：所有数值取自 GameData / balance，禁止在脚本里写死。
## UI 不直接访问内部字段，只通过 TurnManager 与 SignalBus 交互。
##
## P4 拆分：重逻辑下放到三个助手类（均 class_name + RefCounted，经 attach(ctrl) 持有门面，
## 跨子系统调用统一走 ctrl 转发，避免 preload 环路）：
##   - DamageResolver  : 伤害/格挡/窑变结算
##   - StatusEngine    : 状态/回合始末结算/玩家 Power
##   - IntentRoller    : 敌人&随从意图滚动与行动、召唤系统
## 本文件保留编排骨架、公开 API（被 BattleDirector / CombatUI / 各 verify 直接调用）与状态字段。

enum Phase { NONE, PLAYER, ENEMY, ENDED }

## Presentation-only receipt: actual energy paid and unique direct attack targets.
signal attack_feedback(paid_energy: int, target_indices: Array[int])

## 玩家持久 Power：kind(StringName) -> 数值
const POWER_START_TURN_BLOCK := &"power_start_turn_block"
const POWER_START_TURN_STRENGTH := &"power_start_turn_strength"
const POWER_END_TURN_AOE := &"power_end_turn_aoe"
const POWER_ON_ATTACK_STRENGTH := &"power_on_attack_strength"
const POWER_ON_SUMMON_COMMAND := &"power_on_summon_command"
const POWER_RETAIN_BLOCK := &"power_retain_block"
const POWER_VULNERABLE_BONUS_DAMAGE := &"power_vulnerable_bonus_damage"
const POWER_START_TURN_ENERGY := &"power_start_turn_energy"
const POWER_START_TURN_HP_DRAW := &"power_start_turn_hp_draw"
const POWER_SKILL_ZERO_EXHAUST := &"power_skill_cost_zero_exhaust"
const POWER_ON_EXHAUST_DRAW := &"power_on_exhaust_draw"
const POWER_ON_EXHAUST_BLOCK := &"power_on_exhaust_block"
const POWER_ON_DRAW_STATUS := &"power_on_draw_status"
const POWER_ON_DRAW_STATUS_AOE := &"power_on_draw_status_aoe"
const POWER_END_TURN_SELF_HP_AOE := &"power_end_turn_self_hp_aoe"
const POWER_END_TURN_BLOCK := &"power_end_turn_block"
const POWER_ON_BLOCK_DAMAGE := &"power_on_block_damage"
const POWER_ON_CARD_HP_LOSS_STRENGTH := &"power_on_card_hp_loss_strength"

var player: CombatUnit
var enemies: Array[CombatUnit] = []
var allies: Array[CombatUnit] = []   # 友方随从（召唤物）

var draw_pile: Array = []      # [{id:StringName, upgraded:bool}]
var hand: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []
var removed_pile: Array = []    # 已生效能力牌；不计作消耗，不能被发掘取回

var energy: int = 0
var max_energy: int = 0
var turn: int = 0
var phase: int = Phase.NONE

var powers: Dictionary = {}    # StringName -> int/bool（仅玩家持有）
## 巨像：本回合内，来自易伤敌人的攻击伤害倍率；数值由卡牌 JSON 写入。
var _vulnerable_enemy_damage_multiplier: float = 1.0

## 窑温·共鸣：本场累计的窑温值（0 起，出 attack 牌 +1，满阈值触发窑变）
var kiln_heat: int = 0

## 衰朽（thirst）判定辅助：本回合是否打出过攻击牌；下回合是否扣能量
var _attack_played_this_turn: bool = false
var _thirst_penalty_next: bool = false

var _combat_active: bool = false

## 本场首张攻击牌是否已打出（劈薪斧遗物用）
var _first_attack_done: bool = false
## 当前由「持续型药水」施加的残留状态（§1.5 规则 2：新持续型顶旧持续型）
var _active_potion_statuses: Array = []
var _card_hp_loss_count := 0
var _no_draw_this_turn := false
var _temporary_strength := 0
var _temporary_thorns := 0
var _temporary_attack_block := 0
var _double_tap_charges := 0
var _resolving_block_trigger := false
var pending_card_choice: Dictionary = {}

## 助手类实例（P4 拆分，经 attach 持有本门面引用）
var _dmg: DamageResolver
var _status: StatusEngine
var _intent: IntentRoller


func _ready() -> void:
	_init_helpers()


## 惰性初始化助手类；start_combat 也会调用，覆盖 .new() 路径下 _ready 不触发的情况。
func _init_helpers() -> void:
	if _dmg != null:
		return
	_dmg = DamageResolver.new()
	_status = StatusEngine.new()
	_intent = IntentRoller.new()
	_dmg.attach(self)
	_status.attach(self)
	_intent.attach(self)


# =====================================================================
# 战斗生命周期
# =====================================================================
func start_combat(enemy_ids: Array) -> void:
	_init_helpers()
	if not GameData.is_loaded:
		push_error("[CombatController] GameData 未就绪")
		return
	if not RunState.is_active:
		RunState.start_new_run()
	if RunState.has_combat_checkpoint():
		seed(RunState.combat_seed())

	# 玩家单元
	player = CombatUnit.new()
	player.setup(true, &"player", "炭之郎", RunState.max_hp, "res://art/player/SPR_Player_Tannaro.png")
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
	removed_pile.clear()
	for entry in RunState.deck:
		draw_pile.append(entry.duplicate(true))
	_shuffle(draw_pile)
	# 固有牌必须进入初始手牌；把它们稳定移到抽牌堆前端。
	var innate_cards: Array = []
	var other_cards: Array = []
	for entry in draw_pile:
		var innate_data: CardData = GameData.get_card(StringName(entry.get("id", "")))
		if innate_data != null and innate_data.is_innate(_card_upgrade_state(entry)):
			innate_cards.append(entry)
		else:
			other_cards.append(entry)
	draw_pile = innate_cards + other_cards

	# 能量
	var pc: Dictionary = GameData.player_config()
	max_energy = int(pc.get("energy_per_turn", 3))

	powers.clear()
	_vulnerable_enemy_damage_multiplier = 1.0
	turn = 0
	_first_attack_done = false
	kiln_heat = 0
	_attack_played_this_turn = false
	_thirst_penalty_next = false
	_card_hp_loss_count = 0
	_no_draw_this_turn = false
	_temporary_strength = 0
	_temporary_thorns = 0
	_temporary_attack_block = 0
	_double_tap_charges = 0
	pending_card_choice.clear()
	phase = Phase.PLAYER
	_combat_active = true

	# 敌人初始意图
	for e in enemies:
		_intent.roll_enemy_intent(e)

	SignalBus.combat_started.emit(enemy_ids)
	if RunState.combat_death_pending:
		player.hp = 0
		phase = Phase.ENDED
		_combat_active = false
		_sync_player_hp()
		SignalBus.unit_died.emit(true, -1)
		SignalBus.combat_death_pending.emit()
		return
	_start_player_turn()


func _start_player_turn() -> void:
	if not _combat_active:
		return
	turn += 1
	phase = Phase.PLAYER
	energy = max_energy
	# 巨像持续覆盖紧随玩家回合之后的敌方阶段，在下个玩家回合开始时失效。
	_vulnerable_enemy_damage_multiplier = 1.0

	# 衰朽（thirst）：上回合空过 → 本回合能量 -1
	if _thirst_penalty_next:
		energy = maxi(0, energy - 1)
		_thirst_penalty_next = false
		SignalBus.energy_changed.emit(energy, max_energy)

	_attack_played_this_turn = false
	_no_draw_this_turn = false
	_temporary_thorns = 0
	_temporary_attack_block = 0
	_double_tap_charges = 0

	# 回合开始：默认清理旧格挡；固釉不坠只阻止这一自然清盾。
	if not powers.has(POWER_RETAIN_BLOCK):
		player.block = 0
		SignalBus.player_block_changed.emit(player.block)
	_status.process_turn_start_statuses(player)
	_status.apply_player_start_turn_powers()
	if turn == 1:
		_apply_relics_combat_start()  # 战斗开始遗物仅首回合触发，且必须在 block 清零之后
		_apply_relics_first_turn()  # 遗物：第一回合额外能量
		PreRunBuffSystem.apply_combat_start(self)

	# 抽牌
	var draw_n: int = int(GameData.player_config().get("draw_per_turn", 5))
	_draw_cards(draw_n)

	SignalBus.turn_started.emit(true)
	_log("玩家回合 %d 开始 — 能量 %d，手牌 %d" % [turn, energy, hand.size()])


func end_player_turn() -> void:
	if not _combat_active or phase != Phase.PLAYER or not pending_card_choice.is_empty():
		return
	# 先锁定玩家输入，再按杀戮尖塔式顺序结算回合末手牌：
	# 回合末效果 -> 虚无牌消耗 -> 其余牌弃置。由消耗触发而抽到的牌也会被本轮弃置。
	phase = Phase.ENEMY
	var remaining_hand := hand.duplicate()
	var cards_to_discard: Array = []
	hand.clear()
	for card in remaining_hand:
		var cd: CardData = GameData.get_card(StringName(card.get("id", "")))
		if cd != null and not cd.end_turn_effects.is_empty():
			_resolve_effects(cd.end_turn_effects, player, player)
		if not _combat_active:
			return
		if cd != null and cd.is_ethereal(_card_upgrade_state(card)):
			_exhaust_card(card)
		else:
			cards_to_discard.append(card)
	# 普通未打出牌要等全部虚无/回合末效果结算完再入弃牌堆；这样消耗触发的抽牌
	# 不会把同一批尚在结算的手牌提前洗回。
	for card in cards_to_discard:
		_discard_at_turn_end(card)
	# 消耗触发抽到的牌也在本次回合结束时弃置，但不再次结算回合结束效果。
	var end_turn_draws := hand.duplicate()
	hand.clear()
	for drawn_card in end_turn_draws:
		_discard_at_turn_end(drawn_card)
	# 玩家格挡不清空 —— 保留到敌人阶段，先扛过敌人攻击，再在下个玩家回合开始清零。
	_status.apply_player_end_turn_powers()
	if not _combat_active:
		return
	if _temporary_strength != 0:
		_status.apply_status(player, &"heat", -_temporary_strength)
		_temporary_strength = 0
	# 衰朽（thirst）：回合结束未打出攻击牌 → 下回合 -1 能量（读 thirst 先于衰减）
	if player.has_status(&"thirst") and not _attack_played_this_turn:
		_thirst_penalty_next = true
	_status.decay_statuses_at_turn_end(player)
	# 敌人回合的碰撞卡演出与"全部播完才进下一回合"由 BattleDirector.run_enemy_turn 异步编排，
	# CombatUI._on_end_turn 在调用本方法后触发它，本方法不再同步跑敌人阶段。
	SignalBus.turn_ended.emit(true)


## 敌方回合开始：清旧格挡 + 回合开始状态（燃烧 ashrot 等可能致死 → _post_enemy_death）。
## 返回行动后是否仍存活。
func enemy_pre(e: CombatUnit) -> bool:
	# 随从已在此前行动，破封窗口到此关闭；自然清盾不得取消尚未被打断的喷火。
	e.block_break_next = &""
	e.gold_steal_resolved = false
	e.block = 0
	_status.process_turn_start_statuses(e)
	return e.is_alive()


## 敌方回合结束：状态衰减 + 滚动下一手意图。
func enemy_post(e: CombatUnit) -> void:
	_status.decay_statuses_at_turn_end(e)
	_intent.roll_enemy_intent(e)


## 计算敌人 outgoing（含力量加成等，不含格挡——格挡在 apply_damage 内结算）。
func enemy_outgoing(e: CombatUnit, base: int) -> int:
	return _dmg.compute_outgoing(e, player, base)


## 单次攻击命中结算（供碰撞卡撞击点回调）。
func enemy_attack_hit(e: CombatUnit, dmg: int) -> void:
	if not e.gold_steal_resolved:
		e.gold_steal_resolved = true
		enemy_attack_done(e, e.intent)
	_dmg.enemy_attack_hit(e, dmg)


## 一次攻击意图全部命中后结算其附带偷金；多段攻击也只结算一次。
func enemy_attack_done(e: CombatUnit, mv: Dictionary) -> void:
	var requested := int(mv.get("gold_steal", 0))
	if requested <= 0:
		return
	var lost := RunState.lose_gold(requested)
	if lost <= 0:
		_log("敌人 %s 试图抢钱，但玩家没有金币" % e.unit_name)
		return
	e.stolen_gold += lost
	_log("敌人 %s 抢走 %d 金币" % [e.unit_name, lost])


## AOE 伤害 + 对玩家施加 debuff（如易伤）；友方随从同步受击。
func enemy_aoe_hit(e: CombatUnit, dmg: int, mv: Dictionary) -> void:
	_dmg.enemy_aoe_hit(e, dmg, mv)


## 非攻击意图（防御/buff/debuff/charge/unknown）整体结算（自身出牌演出后回调）。
func enemy_act(e: CombatUnit) -> void:
	_intent.execute_enemy_intent(e)


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


# =====================================================================
# 出牌
# =====================================================================
func play_card(hand_index: int, target_index: int = -1) -> bool:
	if phase != Phase.PLAYER or not pending_card_choice.is_empty():
		return false
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card: Dictionary = hand[hand_index]
	var cd: CardData = GameData.get_card(card["id"])
	if cd == null:
		return false
	if not cd.playable or not _card_condition_met(cd, hand_index):
		return false
	var paid_cost := card_cost(card, cd)
	if paid_cost >= 0 and energy < paid_cost:
		return false

	var x_spent := energy if paid_cost < 0 else 0
	energy = 0 if paid_cost < 0 else energy - paid_cost
	SignalBus.energy_changed.emit(energy, max_energy)

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

	var effects: Array = cd.get_effects(_card_upgrade_state(card))
	var combat_damage_bonus := int(card.get("combat_damage_bonus", 0))
	if combat_damage_bonus != 0:
		for effect in effects:
			if effect is Dictionary and String(effect.get("kind", "")) == "damage":
				effect["value"] = int(effect.get("value", 0)) + combat_damage_bonus
				break
	# 附魔结算（升级覆盖 → 附魔加法 → 状态结算）：先叠附魔加成，再走既有结算
	effects = _apply_enchant_mods(effects, cd, card.get("enchants", []))
	# 遗物：本场第一张攻击牌额外伤害（劈薪斧）
	if cd.type == &"attack":
		effects = _apply_first_attack_bonus(effects)
	# 先离手，选择类效果看到的手牌不包含正在打出的牌。
	hand.remove_at(hand_index)
	card["_x_spent"] = x_spent
	card["_active_card_id"] = cd.id
	var repeats := 2 if cd.type == &"attack" and _double_tap_charges > 0 else 1
	if repeats == 2:
		_double_tap_charges -= 1
	var struck_targets: Array[int] = []
	var collect_hit := func(_source: bool, index: int, _amount: int) -> void:
		if index >= 0 and not struck_targets.has(index):
			struck_targets.append(index)
	if cd.type == &"attack":
		SignalBus.damage_dealt.connect(collect_hit)
	for repeat_index in repeats:
		_resolve_effects(effects, player, primary, false, card)
	if cd.type == &"attack":
		SignalBus.damage_dealt.disconnect(collect_hit)

	# Power：每次打出攻击牌获得力量
	if cd.type == &"attack":
		if _temporary_attack_block > 0:
			_dmg.add_block(player, _temporary_attack_block)
		if powers.has(POWER_ON_ATTACK_STRENGTH):
			_status.apply_status(player, &"heat", int(powers[POWER_ON_ATTACK_STRENGTH]))
		_first_attack_done = true
		_attack_played_this_turn = true
		# 窑温·共鸣：每打出 1 张 attack 牌 +1 窑温
		kiln_heat += 1
		SignalBus.kiln_heat_changed.emit(kiln_heat, _kiln_threshold())
		_dmg.check_kiln_resonance()
		# 活力（stoke）：攻击牌出手后 -1 层
		if player.has_status(&"stoke"):
			_status.apply_status(player, &"stoke", -1)

	# 能力牌建立本场持续效果后离开抽弃循环；同名副本仍可分别打出。
	if cd.type == &"power":
		card.erase("temporary_cost")
		card.erase("_x_spent")
		card.erase("_active_card_id")
		removed_pile.append(card)
	elif cd.exhausts_on_play(_card_upgrade_state(card)) or powers.has(POWER_SKILL_ZERO_EXHAUST) and cd.type == &"skill":
		_exhaust_card(card)
	else:
		card.erase("temporary_cost")
		card.erase("_x_spent")
		card.erase("_active_card_id")
		discard_pile.append(card)

	SignalBus.card_played.emit(cd.id, target_index)
	if cd.type == &"attack":
		attack_feedback.emit(x_spent if paid_cost < 0 else paid_cost, struck_targets)
	_log("出牌：%s（耗能 %s，剩余能量 %d）" % [cd.name, "X=%d" % x_spent if paid_cost < 0 else str(paid_cost), energy])
	_check_combat_end()
	return true


# =====================================================================
# 效果结算（14 种 effect_kind 分派）
# =====================================================================
func _resolve_effects(effects: Array, source: CombatUnit, primary: CombatUnit, potion_apply: bool = false, active_card: Dictionary = {}) -> void:
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
					var dmg := _dmg.compute_outgoing(source, primary, value)
					if source.is_player and source.has_status(&"stoke"):
						dmg += source.get_status(&"stoke")
					_dmg.deal_to_unit(primary, dmg)
					_tick_heat_siphon(source)
			"aoe_damage":
				for e in enemies:
					if not e.is_alive():
						continue
					for i in times:
						if not e.is_alive():
							break
						var dmg := _dmg.compute_outgoing(source, e, value)
						if source.is_player and source.has_status(&"stoke"):
							dmg += source.get_status(&"stoke")
						_dmg.deal_to_unit(e, dmg)
						_tick_heat_siphon(source)
			"scaled_damage":
				if primary != null and primary.is_alive():
					var base: int = int(eff.get("value", eff.get("base", 0)))
					var per: int = int(eff.get("per_card", eff.get("per", 0)))
					var count := _count_cards_with_tag(StringName(eff.get("tag", "")), active_card) if eff.has("tag") else _scaled_damage_count(String(eff.get("source", "")), primary, eff)
					var scaled: int = base + count * per
					var dmg := _dmg.compute_outgoing(source, primary, scaled)
					if source.is_player and source.has_status(&"stoke"):
						dmg += source.get_status(&"stoke")
					_dmg.deal_to_unit(primary, dmg)
					_tick_heat_siphon(source)
			"strength_scaled_damage":
				if primary != null and primary.is_alive():
					var strength := source.get_status(&"heat")
					var adjusted_base := value + strength * (int(eff.get("strength_multiplier", 1)) - 1)
					_deal_attack_value(source, primary, adjusted_base)
			"random_enemy_damage":
				for hit in times:
					var living := enemies.filter(func(enemy: CombatUnit) -> bool: return enemy.is_alive())
					if living.is_empty():
						break
					_deal_attack_value(source, living[randi() % living.size()], value)
			"x_aoe_damage":
				var x_times := int(active_card.get("_x_spent", 0))
				for hit in x_times:
					_resolve_effects([{"kind":"aoe_damage","value":value}], source, primary, potion_apply, active_card)
			"damage_from_block":
				if primary != null and primary.is_alive():
					_deal_attack_value(source, primary, source.block + int(eff.get("flat_bonus", 0)))
			"fatal_damage":
				if primary != null and primary.is_alive():
					_deal_attack_value(source, primary, value)
					if not primary.is_alive():
						RunState.increase_max_hp(int(eff.get("max_hp", 0)))
						player.max_hp = RunState.max_hp
						player.hp = RunState.hp
			"heal_unblocked_aoe":
				var healed := 0
				for enemy in enemies:
					if enemy.is_alive():
						var before_hp := enemy.hp
						_deal_attack_value(source, enemy, value)
						healed += before_hp - enemy.hp
				player.heal(healed)
				_sync_player_hp()
			"block":
				_dmg.add_block(source, value)
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
				# strength 效果映射至状态「力量」（内部 id heat）
				if potion_apply: _apply_potion_status(source, &"heat", value)
				else: _status.apply_status(source, &"heat", value)
			"gain_dexterity":
				# dexterity 效果映射至状态「敏捷」（内部 id temper）
				if potion_apply: _apply_potion_status(source, &"temper", value)
				else: _status.apply_status(source, &"temper", value)
			"temporary_strength":
				_status.apply_status(player, &"heat", value)
				_temporary_strength += value
			"reduce_enemy_strength":
				if primary != null:
					_status.apply_status(primary, &"heat", -value)
			"double_strength":
				var current_strength := player.get_status(&"heat")
				if current_strength != 0:
					_status.apply_status(player, &"heat", current_strength)
			"lose_hp":
				_lose_player_hp(value, bool(eff.get("from_card", false)))
			"apply_status":
				var tgt_name: String = String(eff.get("target", "enemy"))
				var sid: StringName = StringName(eff.get("status", ""))
				if tgt_name == "all_enemies":
					for e in enemies:
						if e.is_alive():
							if potion_apply: _apply_potion_status(e, sid, value)
							else: _status.apply_status(e, sid, value)
				else:
					var tgt: CombatUnit = _resolve_status_target(tgt_name, primary)
					if tgt != null:
						if potion_apply: _apply_potion_status(tgt, sid, value)
						else: _status.apply_status(tgt, sid, value)
			"clear_status":
				var clear_target: CombatUnit = _resolve_status_target(eff.get("target", "enemy"), primary)
				var clear_id := StringName(eff.get("status", ""))
				if clear_target != null and clear_id != &"":
					var clear_current: int = clear_target.get_status(clear_id)
					if clear_current > 0:
						_status.apply_status(clear_target, clear_id, -clear_current)
			"multiply_status":
				var multiply_target: CombatUnit = _resolve_status_target(eff.get("target", "enemy"), primary)
				var multiply_id := StringName(eff.get("status", ""))
				var multiplier: int = int(eff.get("multiplier", 0))
				if multiply_target != null and multiply_id != &"" and multiplier > 1:
					var multiply_current: int = multiply_target.get_status(multiply_id)
					if multiply_current > 0:
						_status.apply_status(multiply_target, multiply_id, multiply_current * (multiplier - 1))
			"exhaust":
				_handle_hand_choice(eff, active_card)
			"upgrade_hand", "exhaust_hand_and_draw", "copy_hand_card", "return_discard_to_draw_top", "recover_exhausted_card", "topdeck_hand":
				_handle_hand_choice(eff, active_card)
			"copy_self_to_discard":
				var copy := active_card.duplicate(true)
				copy.erase("_x_spent")
				copy.erase("_active_card_id")
				discard_pile.append(copy)
			"double_block":
				_dmg.add_block(player, player.block)
			"set_no_draw":
				_no_draw_this_turn = true
			"temporary_thorns":
				_temporary_thorns += value
			"double_next_attacks":
				_double_tap_charges += value
			"conditional_target_status":
				if primary != null and primary.get_status(StringName(eff.get("status", ""))) > 0:
					_resolve_effects(eff.get("effects", []), source, primary, potion_apply, active_card)
			"conditional_enemy_intent_strength":
				if primary != null and String(primary.intent.get("intent", "")) in ["attack", "attack_debuff", "aoe"]:
					_status.apply_status(player, &"heat", value)
			"add_card":
				_add_generated_card(StringName(eff.get("card_id", "")), String(eff.get("pile", "discard")), int(eff.get("count", 1)), bool(eff.get("shuffle", false)))
			"random_attack_to_hand":
				_add_random_attack_to_hand(int(eff.get("temporary_cost", 0)))
			"play_top_draw_exhaust":
				_play_top_draw_card_exhausted()
			"exhaust_non_attack_hand":
				var exhausted_count := _exhaust_non_attack_hand()
				if eff.has("block_per_card"):
					_dmg.add_block(player, exhausted_count * int(eff.get("block_per_card", 0)))
			"exhaust_hand_damage":
				var exhausted_cards := hand.size()
				while not hand.is_empty():
					_exhaust_card(hand.pop_back())
				for hit in exhausted_cards:
					if primary == null or not primary.is_alive():
						break
					_deal_attack_value(source, primary, value)
			"increment_card_damage":
				active_card["combat_damage_bonus"] = int(active_card.get("combat_damage_bonus", 0)) + value
			"power_start_turn_block", "power_start_turn_strength", "power_end_turn_aoe", "power_on_attack_strength", "power_on_summon_command", "power_start_turn_energy", "power_on_exhaust_draw", "power_on_exhaust_block", "power_on_draw_status", "power_on_draw_status_aoe", "power_end_turn_block", "power_on_block_damage", "power_on_card_hp_loss_strength":
				_register_power(StringName(kind), value)
			"power_start_turn_hp_draw", "power_end_turn_self_hp_aoe":
				_register_structured_power(StringName(kind), eff)
			"power_skill_cost_zero_exhaust":
				powers[POWER_SKILL_ZERO_EXHAUST] = true
			"power_on_attack_block":
				_temporary_attack_block += value
			"power_retain_block":
				powers[POWER_RETAIN_BLOCK] = true
			"vulnerable_enemy_damage_multiplier":
				_vulnerable_enemy_damage_multiplier = minf(
					_vulnerable_enemy_damage_multiplier, float(eff.get("value", 1.0)))
			"power_vulnerable_bonus_damage":
				_register_float_power(POWER_VULNERABLE_BONUS_DAMAGE, float(eff.get("value", 0.0)))
			"gain_kiln_heat":
				# 窑温联动：直接积累窑温，可能立即触发窑变
				kiln_heat += value
				SignalBus.kiln_heat_changed.emit(kiln_heat, _kiln_threshold())
				_dmg.check_kiln_resonance()
			"summon":
				var mid: StringName = StringName(eff.get("minion_id", ""))
				var cnt: int = int(eff.get("count", 1))
				_intent.summon_minion(mid, cnt)
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


func _scaled_damage_count(source_name: String, primary: CombatUnit, eff: Dictionary) -> int:
	match source_name:
		"ally_count":
			return allies.size()
		"target_status":
			return primary.get_status(StringName(eff.get("status", ""))) if primary != null else 0
		"player_block":
			return player.block if player != null else 0
		"exhaust_pile_count":
			return exhaust_pile.size()
		_:
			push_warning("[CombatController] 未识别的 scaled_damage source: %s" % source_name)
			return 0


func _register_power(kind: StringName, value: int) -> void:
	powers[kind] = int(powers.get(kind, 0)) + value


func _register_float_power(kind: StringName, value: float) -> void:
	powers[kind] = float(powers.get(kind, 0.0)) + value


func _register_structured_power(kind: StringName, effect: Dictionary) -> void:
	var current: Dictionary = powers.get(kind, {}).duplicate(true)
	for key in effect:
		if key != "kind":
			current[key] = int(current.get(key, 0)) + int(effect[key])
	powers[kind] = current


func _card_upgrade_state(card: Dictionary) -> int:
	return maxi(maxi(int(card.get("upgrade_level", 0)), 1 if bool(card.get("upgraded", false)) else 0), int(card.get("combat_upgrade_level", 0)))


func card_cost(card: Dictionary, cd: CardData = null) -> int:
	var data := cd if cd != null else GameData.get_card(StringName(card.get("id", "")))
	if data == null:
		return 99
	if card.has("temporary_cost"):
		return int(card["temporary_cost"])
	if powers.has(POWER_SKILL_ZERO_EXHAUST) and data.type == &"skill":
		return 0
	var result := data.resolved_cost(_card_upgrade_state(card))
	if String(data.cost_rule.get("kind", "")) == "card_hp_loss_count":
		result = maxi(int(data.cost_rule.get("minimum", 0)), result - _card_hp_loss_count)
	return result


func can_play_card(hand_index: int) -> bool:
	if phase != Phase.PLAYER or not pending_card_choice.is_empty() or hand_index < 0 or hand_index >= hand.size():
		return false
	var data: CardData = GameData.get_card(StringName(hand[hand_index].get("id", "")))
	if data == null or not data.playable or not _card_condition_met(data, hand_index):
		return false
	var resolved := card_cost(hand[hand_index], data)
	return resolved < 0 or energy >= resolved


func _card_condition_met(cd: CardData, hand_index: int) -> bool:
	if String(cd.play_condition.get("kind", "")) != "all_other_cards_attack":
		return true
	for index in hand.size():
		if index == hand_index:
			continue
		var other := GameData.get_card(StringName(hand[index].get("id", "")))
		if other == null or other.type != &"attack":
			return false
	return true


func _deal_attack_value(source: CombatUnit, target: CombatUnit, base: int) -> void:
	if target == null or not target.is_alive():
		return
	var damage := _dmg.compute_outgoing(source, target, base)
	if source.is_player and source.has_status(&"stoke"):
		damage += source.get_status(&"stoke")
	_dmg.deal_to_unit(target, damage)
	_tick_heat_siphon(source)


func _deal_direct_aoe(amount: int) -> void:
	for enemy in enemies:
		if enemy.is_alive():
			_dmg.deal_to_unit(enemy, maxi(0, amount))


func _lose_player_hp(amount: int, from_card: bool) -> void:
	var lost := player.lose_hp_direct(amount)
	_sync_player_hp()
	if from_card and lost > 0:
		_card_hp_loss_count += 1
		if powers.has(POWER_ON_CARD_HP_LOSS_STRENGTH):
			_status.apply_status(player, &"heat", int(powers[POWER_ON_CARD_HP_LOSS_STRENGTH]))
	if not player.is_alive():
		_on_player_death()


func _count_cards_with_tag(tag: StringName, active_card: Dictionary = {}) -> int:
	if tag == &"":
		return 0
	var count := 0
	var piles := [draw_pile, hand, discard_pile, exhaust_pile, removed_pile]
	for pile in piles:
		for entry in pile:
			var data: CardData = GameData.get_card(StringName(entry.get("id", "")))
			if data != null and data.tags.has(tag):
				count += 1
	if not active_card.is_empty():
		var active_data: CardData = GameData.get_card(StringName(active_card.get("id", "")))
		if active_data != null and active_data.tags.has(tag):
			count += 1
	return count


func _add_generated_card(card_id: StringName, pile_name: String, count: int, shuffle_after: bool) -> void:
	if GameData.get_card(card_id) == null:
		return
	var target_pile: Array = discard_pile
	match pile_name:
		"draw": target_pile = draw_pile
		"hand": target_pile = hand
	for index in maxi(0, count):
		if target_pile == hand and hand.size() >= int(GameData.player_config().get("hand_max", 10)):
			discard_pile.append({"id":card_id,"upgraded":false,"upgrade_level":0,"enchants":[]})
		else:
			target_pile.append({"id":card_id,"upgraded":false,"upgrade_level":0,"enchants":[]})
	if shuffle_after and target_pile == draw_pile:
		_shuffle(draw_pile)


func _add_random_attack_to_hand(temporary_cost: int) -> void:
	var pool: Array = []
	for data in GameData.cards.values():
		if data is CardData and data.type == &"attack" and data.rarity != &"special":
			pool.append(data)
	if pool.is_empty():
		return
	var picked: CardData = pool[randi() % pool.size()]
	var entry := {"id":picked.id,"upgraded":false,"upgrade_level":0,"enchants":[],"temporary_cost":temporary_cost}
	if hand.size() < int(GameData.player_config().get("hand_max", 10)):
		hand.append(entry)
	else:
		discard_pile.append(entry)


func _play_top_draw_card_exhausted() -> void:
	if draw_pile.is_empty():
		_reshuffle_discard()
	if draw_pile.is_empty():
		return
	var entry: Dictionary = draw_pile.pop_front()
	var data: CardData = GameData.get_card(StringName(entry.get("id", "")))
	if data != null and data.playable:
		entry["temporary_cost"] = 0
		hand.append(entry)
		var first_enemy := _first_alive_enemy()
		var played := play_card(hand.size() - 1, _index_of(first_enemy) if first_enemy != null else -1)
		if played:
			var discard_index := discard_pile.find(entry)
			if discard_index >= 0:
				_exhaust_card(discard_pile.pop_at(discard_index))
			return
	_exhaust_card(entry)


func _exhaust_non_attack_hand() -> int:
	var count := 0
	for index in range(hand.size() - 1, -1, -1):
		var data: CardData = GameData.get_card(StringName(hand[index].get("id", "")))
		if data == null or data.type != &"attack":
			var entry: Dictionary = hand.pop_at(index)
			_exhaust_card(entry)
			count += 1
	return count


func _exhaust_card(card: Dictionary) -> void:
	card.erase("temporary_cost")
	card.erase("_x_spent")
	card.erase("_active_card_id")
	exhaust_pile.append(card)
	var data: CardData = GameData.get_card(StringName(card.get("id", "")))
	if data != null:
		_resolve_effects(data.get_on_exhaust_effects(_card_upgrade_state(card)), player, player, false, card)
		SignalBus.card_exhausted.emit(data.id)
	if powers.has(POWER_ON_EXHAUST_BLOCK):
		_dmg.add_block(player, int(powers[POWER_ON_EXHAUST_BLOCK]))
	if powers.has(POWER_ON_EXHAUST_DRAW):
		_draw_cards(int(powers[POWER_ON_EXHAUST_DRAW]))


func _handle_hand_choice(effect: Dictionary, active_card: Dictionary) -> void:
	var kind := String(effect.get("kind", ""))
	if kind == "upgrade_hand" and bool(effect.get("all", false)):
		for entry in hand:
			_upgrade_combat_card(entry)
		return
	var source_pile: Array = hand
	if kind == "return_discard_to_draw_top":
		source_pile = discard_pile
	elif kind == "recover_exhausted_card":
		source_pile = exhaust_pile
	var candidates: Array = []
	for entry in source_pile:
		var data: CardData = GameData.get_card(StringName(entry.get("id", "")))
		if data == null:
			continue
		if kind == "copy_hand_card" and not String(data.type) in effect.get("types", []):
			continue
		if kind == "recover_exhausted_card" and bool(effect.get("exclude_self", false)) and data.id == StringName(active_card.get("_active_card_id", "")):
			continue
		candidates.append(entry)
	if candidates.is_empty():
		return
	if kind == "exhaust" and not bool(effect.get("choose", false)):
		_apply_card_choice(kind, candidates[randi() % candidates.size()], effect)
		return
	pending_card_choice = {"kind":kind,"effect":effect.duplicate(true),"candidates":candidates}
	var snapshots: Array = []
	for entry in candidates:
		snapshots.append(entry.duplicate(true))
	SignalBus.combat_card_choice_requested.emit(_choice_title(kind), snapshots)


func resolve_card_choice(candidate_index: int) -> bool:
	if pending_card_choice.is_empty():
		return false
	var candidates: Array = pending_card_choice.get("candidates", [])
	if candidate_index < 0 or candidate_index >= candidates.size():
		return false
	var kind := String(pending_card_choice.get("kind", ""))
	var effect: Dictionary = pending_card_choice.get("effect", {})
	var selected: Dictionary = candidates[candidate_index]
	pending_card_choice.clear()
	_apply_card_choice(kind, selected, effect)
	SignalBus.combat_card_choice_resolved.emit()
	return true


func _apply_card_choice(kind: String, selected: Dictionary, effect: Dictionary) -> void:
	match kind:
		"upgrade_hand":
			_upgrade_combat_card(selected)
		"exhaust", "exhaust_hand_and_draw":
			var index := hand.find(selected)
			if index >= 0:
				_exhaust_card(hand.pop_at(index))
				if kind == "exhaust_hand_and_draw":
					_draw_cards(int(effect.get("draw", 0)))
		"copy_hand_card":
			for copy_index in int(effect.get("count", 1)):
				if hand.size() >= int(GameData.player_config().get("hand_max", 10)):
					break
				hand.append(selected.duplicate(true))
		"return_discard_to_draw_top":
			var discard_index := discard_pile.find(selected)
			if discard_index >= 0:
				draw_pile.push_front(discard_pile.pop_at(discard_index))
		"recover_exhausted_card":
			var exhaust_index := exhaust_pile.find(selected)
			if exhaust_index >= 0:
				hand.append(exhaust_pile.pop_at(exhaust_index))
		"topdeck_hand":
			var hand_index := hand.find(selected)
			if hand_index >= 0:
				draw_pile.push_front(hand.pop_at(hand_index))


func _upgrade_combat_card(card: Dictionary) -> void:
	var data: CardData = GameData.get_card(StringName(card.get("id", "")))
	if data == null or not data.has_upgrade():
		return
	var current := _card_upgrade_state(card)
	card["combat_upgrade_level"] = current + 1 if data.repeatable_upgrade else maxi(1, current)


func _choice_title(kind: String) -> String:
	match kind:
		"upgrade_hand": return "选择一张手牌升级"
		"exhaust", "exhaust_hand_and_draw": return "选择一张手牌消耗"
		"copy_hand_card": return "选择一张牌复制"
		"return_discard_to_draw_top": return "选择一张弃牌置顶"
		"recover_exhausted_card": return "选择一张消耗牌回手"
		"topdeck_hand": return "选择一张手牌置顶"
		_: return "选择一张牌"


## 残酷：只为玩家阵营（玩家与随从）提供易伤承伤倍率的额外加成。
func vulnerable_bonus_damage_for(attacker: CombatUnit) -> float:
	if attacker == player or allies.has(attacker):
		return float(powers.get(POWER_VULNERABLE_BONUS_DAMAGE, 0.0))
	return 0.0


## 巨像：只降低带有易伤的敌人对玩家造成的攻击伤害。
func incoming_attack_multiplier_for(attacker: CombatUnit, target: CombatUnit) -> float:
	if target == player and enemies.has(attacker) and attacker.has_status(&"crazed"):
		return _vulnerable_enemy_damage_multiplier
	return 1.0


func on_player_block_gained() -> void:
	if _resolving_block_trigger or not powers.has(POWER_ON_BLOCK_DAMAGE):
		return
	var living := enemies.filter(func(enemy: CombatUnit) -> bool: return enemy.is_alive())
	if living.is_empty():
		return
	_resolving_block_trigger = true
	_dmg.deal_to_unit(living[randi() % living.size()], int(powers[POWER_ON_BLOCK_DAMAGE]))
	_resolving_block_trigger = false


# =====================================================================
# 附魔结算（卡牌第二定制层）与药水使用
# =====================================================================
## 将一张卡的附魔修正叠加到其效果序列（加法，不触碰状态/力量结算）。
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
				if db != 0:
					_add_flat_damage_bonus(eff, db)
				if ab != 0 and k in ["aoe_damage", "x_aoe_damage", "heal_unblocked_aoe"]:
					eff["value"] = int(eff.get("value", 0)) + ab
				if k == "block" and bb != 0:
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


## 为任意攻击伤害效果增加固定值；返回该效果是否属于伤害效果。
## 特殊攻击也必须经过这条兼容层，避免重构卡池后绕过既有附魔与遗物。
func _add_flat_damage_bonus(effect: Dictionary, bonus: int) -> bool:
	var kind := String(effect.get("kind", ""))
	match kind:
		"damage", "aoe_damage", "strength_scaled_damage", "random_enemy_damage", "x_aoe_damage", "fatal_damage", "heal_unblocked_aoe", "exhaust_hand_damage":
			effect["value"] = int(effect.get("value", 0)) + bonus
			return true
		"scaled_damage":
			if effect.has("value"):
				effect["value"] = int(effect.get("value", 0)) + bonus
			else:
				effect["base"] = int(effect.get("base", 0)) + bonus
			return true
		"damage_from_block":
			effect["flat_bonus"] = int(effect.get("flat_bonus", 0)) + bonus
			return true
	return false


## 使用携带格中的第 slot_index 瓶药水（战斗中、Free Action、消耗）。
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
func _apply_potion_status(unit: CombatUnit, status_id: StringName, amount: int) -> void:
	if unit == null or status_id == &"":
		return
	if unit.get_status(status_id) > 0:
		return
	_status.apply_status(unit, status_id, amount)
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
# 公开转发（供外部直接调用：verify 调 _apply_status / _execute_enemy_intent）
# =====================================================================
## 状态施加（转发到 StatusEngine）。被 verify 直接调用，故保留在门面。
func _apply_status(unit: CombatUnit, status_id: StringName, amount: int) -> void:
	_status.apply_status(unit, status_id, amount)


## 局前 Buff 的战斗开始格挡入口；具体数值只来自 Buff 配置。
func grant_pre_run_combat_start_block(amount: int) -> void:
	if amount > 0 and player != null and player.is_alive():
		_dmg.add_block(player, amount)


## 敌人按意图行动（转发到 IntentRoller）。被 P2Verify 直接调用。
func _execute_enemy_intent(e: CombatUnit) -> void:
	_intent.execute_enemy_intent(e)


## 敌人意图滚动（转发到 IntentRoller）。被 P3Verify 直接调用。
func _roll_enemy_intent(e: CombatUnit) -> void:
	_intent.roll_enemy_intent(e)


## 召唤随从（转发到 IntentRoller）。被 SummonVerify / SummonTurnVerify 直接调用。
func _summon_minion(mid: StringName, count: int) -> void:
	_intent.summon_minion(mid, count)


## 成功召唤进入场上后触发群窑共鸣；被上限拒绝的召唤不会调用此钩子。
func _on_minion_summoned() -> void:
	if powers.has(POWER_ON_SUMMON_COMMAND):
		_status.apply_status(player, &"command", int(powers[POWER_ON_SUMMON_COMMAND]))


## 随从阶段（转发到 IntentRoller）。被 SummonVerify / SummonTurnVerify 直接调用。
func _summon_phase() -> void:
	_intent.summon_phase()


## 友方随从受击（转发到 IntentRoller）。被 SummonVerify 直接调用。
func _deal_to_ally(ally: CombatUnit, final_dmg: int) -> void:
	_intent.deal_to_ally(ally, final_dmg)


# =====================================================================
# 牌堆
# =====================================================================
## 回合结束弃置会清除只在当前回合/当前结算有效的字段；战斗内永久成长字段继续保留。
func _discard_at_turn_end(card: Dictionary) -> void:
	card.erase("temporary_cost")
	card.erase("_x_spent")
	card.erase("_active_card_id")
	discard_pile.append(card)
	SignalBus.card_discarded.emit(StringName(card.get("id", "")))


## 手动弃牌不是出牌：仅移动原条目，不耗能、不结算效果、不补牌。
## 没有回合次数限制；升级、附魔及其他实例字段随条目保留。
func discard_card(hand_index: int) -> bool:
	if not _combat_active or phase != Phase.PLAYER or not player_alive():
		return false
	if hand_index < 0 or hand_index >= hand.size():
		return false
	var card: Dictionary = hand[hand_index]
	hand.remove_at(hand_index)
	discard_pile.append(card)
	SignalBus.card_discarded.emit(StringName(card["id"]))
	var cd: CardData = GameData.get_card(StringName(card["id"]))
	_log("弃牌：%s" % (cd.name if cd != null else String(card["id"])))
	return true


func _draw_cards(n: int) -> void:
	if _no_draw_this_turn:
		return
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
		var data: CardData = GameData.get_card(StringName(card.get("id", "")))
		if data != null and data.type == &"status":
			if powers.has(POWER_ON_DRAW_STATUS_AOE):
				_deal_direct_aoe(int(powers[POWER_ON_DRAW_STATUS_AOE]))
			if powers.has(POWER_ON_DRAW_STATUS):
				_draw_cards(int(powers[POWER_ON_DRAW_STATUS]))


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
# 窑温·共鸣（阈值/贯穿值从 balance 读取；结算逻辑在 DamageResolver）
# =====================================================================
func _kiln_threshold() -> int:
	return int(GameData.balance.get("kiln_temperature", {}).get("threshold", 5))

func _kiln_pierce() -> int:
	return int(GameData.balance.get("kiln_temperature", {}).get("pierce_damage", 5))


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
		_refund_stolen_gold_from_defeated_enemies()
		_apply_relics_after_combat()  # 遗物：战后（余温炭回血）
		RunState.clear_combat_checkpoint()
		SignalBus.combat_ended.emit(true)
		_log("战斗胜利！")


func _refund_stolen_gold_from_defeated_enemies() -> void:
	var refund := 0
	for e in enemies:
		if not e.is_alive():
			refund += e.stolen_gold
			e.stolen_gold = 0
	if refund <= 0:
		return
	RunState.restore_lost_gold(refund)
	_log("从被击败的抢劫者身上找回 %d 金币" % refund)


func _on_player_death() -> void:
	if not _combat_active:
		return
	_combat_active = false
	phase = Phase.ENDED
	_sync_player_hp()
	SignalBus.unit_died.emit(true, -1)
	if CombatReviveSystem.begin_death_decision():
		_log("玩家阵亡，等待复燃选择。")
		return
	finalize_player_death()


func finalize_player_death() -> void:
	if not RunState.is_active:
		return
	_combat_active = false
	phase = Phase.ENDED
	RunState.clear_combat_checkpoint()
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
				_status.apply_status(player, &"heat", int(r.value))
			&"keeper_apron":
				_draw_cards(int(r.value))
			&"hearth_totem":
				_dmg.add_block(player, int(r.value))
			&"kilnmark":
				_intent.summon_minion(&"emberhound", int(r.value))


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
	var out: Array = effects.duplicate(true)
	for eff in out:
		if eff is Dictionary and _add_flat_damage_bonus(eff, bonus):
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
			_dmg.deal_to_unit(attacker, int(r.value))


func _apply_relics_after_combat() -> void:
	for r in RunState.relics_with_trigger(&"after_combat"):
		if r.id == &"emberheart":
			RunState.heal(int(r.value))


# =====================================================================
# 随从 / 召唤（异步演出薄包装，供 BattleDirector.run_summon_turn 驱动）
# =====================================================================
func ally_pre(a: CombatUnit) -> bool:
	return _intent.ally_pre(a)

func ally_outgoing(a: CombatUnit, target: CombatUnit, base: int) -> int:
	return _intent.ally_outgoing(a, target, base)

func ally_attack_hit(a: CombatUnit, target: CombatUnit, dmg: int) -> void:
	_intent.ally_attack_hit(a, target, dmg)

func ally_act(a: CombatUnit) -> void:
	_intent.ally_act(a)

func ally_post(a: CombatUnit) -> void:
	_intent.ally_post(a)


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
