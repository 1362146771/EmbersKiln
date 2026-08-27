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

## 玩家持久 Power：kind(StringName) -> 数值
const POWER_START_TURN_BLOCK := &"power_start_turn_block"
const POWER_START_TURN_STRENGTH := &"power_start_turn_strength"
const POWER_END_TURN_AOE := &"power_end_turn_aoe"
const POWER_ON_ATTACK_STRENGTH := &"power_on_attack_strength"

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
		_intent.roll_enemy_intent(e)

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
	_status.process_turn_start_statuses(player)
	_status.apply_player_start_turn_powers()
	_apply_relics_combat_start()   # 遗物：开局（格挡/炽热/抽牌）— 必须在 block 清零之后
	if turn == 1:
		_apply_relics_first_turn()  # 遗物：第一回合额外能量

	# 抽牌
	var draw_n: int = int(GameData.player_config().get("draw_per_turn", 5))
	_draw_cards(draw_n)

	SignalBus.turn_started.emit(true)
	_log("玩家回合 %d 开始 — 能量 %d，手牌 %d" % [turn, energy, hand.size()])


func end_player_turn() -> void:
	if phase != Phase.PLAYER:
		return
	# 玩家格挡不清空 —— 保留到敌人阶段，先扛过敌人攻击，再在下个玩家回合开始清零。
	_status.apply_player_end_turn_powers()
	# 焦渴（thirst）：回合结束未打出攻击牌 → 下回合 -1 能量（读 thirst 先于衰减）
	if player.has_status(&"thirst") and not _attack_played_this_turn:
		_thirst_penalty_next = true
	_status.decay_statuses_at_turn_end(player)
	phase = Phase.ENEMY
	# 敌人回合的碰撞卡演出与"全部播完才进下一回合"由 BattleDirector.run_enemy_turn 异步编排，
	# CombatUI._on_end_turn 在调用本方法后触发它，本方法不再同步跑敌人阶段。
	SignalBus.turn_ended.emit(true)


## 敌方回合开始：清旧格挡 + 回合开始状态（ashrot 等可能致死 → _post_enemy_death）。
## 返回行动后是否仍存活。
func enemy_pre(e: CombatUnit) -> bool:
	e.block = 0
	_status.process_turn_start_statuses(e)
	return e.is_alive()


## 敌方回合结束：状态衰减 + 滚动下一手意图。
func enemy_post(e: CombatUnit) -> void:
	_status.decay_statuses_at_turn_end(e)
	_intent.roll_enemy_intent(e)


## 计算敌人 outgoing（含炽热加成等，不含格挡——格挡在 apply_damage 内结算）。
func enemy_outgoing(e: CombatUnit, base: int) -> int:
	return _dmg.compute_outgoing(e, player, base)


## 单次攻击命中结算（供碰撞卡撞击点回调）。
func enemy_attack_hit(e: CombatUnit, dmg: int) -> void:
	_dmg.enemy_attack_hit(e, dmg)


## AOE 伤害 + 对玩家施加 debuff（如釉裂）；友方随从同步受击。
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
			_status.apply_status(player, &"heat", int(powers[POWER_ON_ATTACK_STRENGTH]))
		_first_attack_done = true
		_attack_played_this_turn = true
		# 窑温·共鸣：每打出 1 张 attack 牌 +1 窑温
		kiln_heat += 1
		SignalBus.kiln_heat_changed.emit(kiln_heat, _kiln_threshold())
		_dmg.check_kiln_resonance()
		# 蓄焰（stoke）：攻击牌出手后 -1 层
		if player.has_status(&"stoke"):
			_status.apply_status(player, &"stoke", -1)

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
				# 设计命名 strength -> 状态「炽热 heat」
				if potion_apply: _apply_potion_status(source, &"heat", value)
				else: _status.apply_status(source, &"heat", value)
			"gain_dexterity":
				# 设计命名 dexterity -> 状态「塑形 temper」
				if potion_apply: _apply_potion_status(source, &"temper", value)
				else: _status.apply_status(source, &"temper", value)
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
			"exhaust":
				pass  # 消耗由 play_card 处理
			"power_start_turn_block", "power_start_turn_strength", "power_end_turn_aoe", "power_on_attack_strength":
				_register_power(StringName(kind), value)
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


func _register_power(kind: StringName, value: int) -> void:
	powers[kind] = int(powers.get(kind, 0)) + value


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


## 敌人按意图行动（转发到 IntentRoller）。被 P2Verify 直接调用。
func _execute_enemy_intent(e: CombatUnit) -> void:
	_intent.execute_enemy_intent(e)


## 敌人意图滚动（转发到 IntentRoller）。被 P3Verify 直接调用。
func _roll_enemy_intent(e: CombatUnit) -> void:
	_intent.roll_enemy_intent(e)


## 召唤随从（转发到 IntentRoller）。被 SummonVerify / SummonTurnVerify 直接调用。
func _summon_minion(mid: StringName, count: int) -> void:
	_intent.summon_minion(mid, count)


## 随从阶段（转发到 IntentRoller）。被 SummonVerify / SummonTurnVerify 直接调用。
func _summon_phase() -> void:
	_intent.summon_phase()


## 友方随从受击（转发到 IntentRoller）。被 SummonVerify 直接调用。
func _deal_to_ally(ally: CombatUnit, final_dmg: int) -> void:
	_intent.deal_to_ally(ally, final_dmg)


# =====================================================================
# 牌堆
# =====================================================================
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
