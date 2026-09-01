extends Node
## 集成测试：一键打通到 Boss。
## 自动跑完整局（地图 → 战斗 → 奖励 → 节点内容 → Boss），
## 验证「可完整游玩一局的闭环」端到端成立。真实运行（headless）后用 stdout 判定。
##
## 判定：在有限次尝试内，能否从第一层自动推进到 Boss 层并击败 Boss。
## 自动战斗 AI：每回合优先补格挡扛过预期伤害，否则出攻击牌（瞄准最低血敌人），
## 再出其余牌；能量耗尽则结束回合。带回合上限与尝试次数上限，避免死循环。
##
## 注意：本测试只驱动「数据 + 核心逻辑」层（RunState / CombatController /
## RewardBuilder / MapGenerator），不依赖任何 UI 场景。UI 仍由人工真机验收。

const MAX_ATTEMPTS := 30
const MAX_COMBAT_TURNS := 60
const MAX_CARD_PLAYS_PER_TURN := 80

var results: Array[String] = []
var pass_count := 0
var fail_count := 0

# 成功尝试的关键指标（供报告）
var _attempts_used := 0
var _floors_cleared := 0
var _boss_defeated := false
var _final_hp := 0
var _deck_size := 0
var _gold := 0
var _relic_count := 0
var _total_all_floors := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	if not GameData.is_loaded:
		check("GameData 加载", false, "加载失败，无法运行集成测试")
		_print_report()
		return

	await run()
	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if detail != "" else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if detail != "" else ""])


func run() -> void:
	# ---------- 数据层不变量 ----------
	check("卡牌数据=48", GameData.cards.size() == 48, "cards=%d" % GameData.cards.size())
	check("敌人数据=21（新增首幕Boss匣母）", GameData.enemies.size() == 21, "enemies=%d" % GameData.enemies.size())
	check("遗物数据=11", GameData.relics.size() == 11, "relics=%d" % GameData.relics.size())
	check("状态数据=10（含活力/缓冲/衰朽/领袖气质）", GameData.statuses.size() == 10, "statuses=%d" % GameData.statuses.size())
	check("层数=floor_count", RunState.total_floors() == int(GameData.act_configs[0].get("floor_count", 15)), "floors=%d" % RunState.total_floors())

	# 全幕总层数（用于「通关时到达终幕 Boss 层」断言）
	var total_all := 0
	for a in GameData.act_configs:
		total_all += int(a.get("floor_count", 0))
	_total_all_floors = total_all

	# ---------- 整局自动打通 ----------
	var original_profile := ProfileState.to_save_dict()
	_prepare_fully_progressed_test_profile()
	var cc := CombatController.new()
	add_child(cc)

	var won := false
	for attempt in range(MAX_ATTEMPTS):
		_attempts_used = attempt + 1
		RunState.start_new_run()
		if await _run_floors(cc):
			won = true
			break
		# 失败（阵亡或卡死）：下一轮重新开局重试

	check("整局打通到 Boss（%d 次尝试内）" % _attempts_used,
		won, "attempts=%d boss_defeated=%s" % [_attempts_used, _boss_defeated])
	check("击败 Boss", _boss_defeated, "boss_defeated=%s" % _boss_defeated)
	check("通关时玩家存活", won and _final_hp > 0, "hp=%d" % _final_hp)
	check("通关时到达终幕 Boss 层", won and _floors_cleared >= _total_all_floors,
		"floors_cleared=%d/%d" % [_floors_cleared, _total_all_floors])
	check("奖励生效：牌组增长(>=起始10)", _deck_size >= 10, "deck=%d" % _deck_size)
	check("奖励生效：遗物≥2(精英/Boss)", _relic_count >= 2, "relics=%d" % _relic_count)

	cc.queue_free()
	ProfileState.from_save_dict(original_profile, false, false)
	SaveManager.delete_save()   # 清理可能残留的自动存档


## 整局闭环使用完整成长档案：新手档案的通关率属于平衡验证，不应阻断流程集成测试。
## 所有数值与解锁范围都从正式数据派生，测试本身不另写玩法数值。
func _prepare_fully_progressed_test_profile() -> void:
	ProfileState.reset_to_defaults(false)
	ProfileState.unlocked_card_ids.assign(GameData.cards.keys())
	ProfileState.unlocked_relic_ids.assign(GameData.relics.keys())
	ProfileState.unlocked_potion_ids.assign(GameData.potions.keys())
	ProfileState.unlocked_enchant_ids.assign(GameData.enchants.keys())
	ProfileState.unlocked_pre_run_buff_ids.assign(GameData.meta_pre_run_buffs.keys())

	var max_capacity := int(GameData.meta_progression.get("base_run_deck_capacity", -1))
	for project in GameData.meta_project_list():
		max_capacity = maxi(max_capacity, int(project.get("grants", {}).get("base_run_deck_capacity", -1)))
	ProfileState.base_run_deck_capacity = max_capacity

	for tier in GameData.meta_progression.get("run_start_bonus_tiers", []):
		var facility_id := String(tier.get("facility_id", ""))
		if facility_id.is_empty():
			continue
		ProfileState.facility_levels[facility_id] = maxi(
			int(ProfileState.facility_levels.get(facility_id, 0)),
			int(tier.get("required_level", 0))
		)


## 自动推进所有幕所有层；返回是否成功打通到最后一幕 Boss 且玩家存活。
func _run_floors(cc: CombatController) -> bool:
	_floors_cleared = 0
	_boss_defeated = false
	while RunState.current_act < RunState.act_maps.size():
		var floors: Array = RunState.current_map()
		var act_is_last: bool = RunState.is_last_act()
		for f in range(floors.size()):
			var row: Array = floors[f]
			var node: MapNode = row[0]  # 取本层首节点（确定性，足够验证闭环）
			var ntype: StringName = node.type
			RunState.advance_floor(ntype)

			if node.is_combat_like():
				cc.start_combat(node.enemy_ids)
				if not await _auto_battle(cc):
					_final_hp = RunState.hp
					_deck_size = RunState.deck.size()
					_relic_count = RunState.relic_ids.size()
					return false
				_grant_combat_rewards(ntype)
				if ntype == &"boss":
					_boss_defeated = true
			else:
				_handle_noncombat(ntype)

			_floors_cleared += 1
			if RunState.hp <= 0:
				_final_hp = RunState.hp
				return false

		if act_is_last:
			RunState.end_run(true)  # 击败终幕 Boss，整局胜利
			break
		else:
			RunState.advance_act()  # 进下一幕（按 transition_heal 回血）

	_final_hp = RunState.hp
	_deck_size = RunState.deck.size()
	_gold = RunState.gold
	_relic_count = RunState.relic_ids.size()
	return _boss_defeated and RunState.hp > 0


## 自动战斗：返回玩家是否存活且战斗结束（敌人清空）。
func _auto_battle(cc: CombatController) -> bool:
	var guard := 0
	var get_panel := func(_unit): return null
	while cc.phase != CombatController.Phase.ENDED and guard < MAX_COMBAT_TURNS:
		guard += 1
		var safety := 0
		while safety < MAX_CARD_PLAYS_PER_TURN:
			safety += 1
			if cc.phase != CombatController.Phase.PLAYER:
				break
			var idx := _choose_card(cc)
			if idx < 0:
				break
			var ti := _target_for(cc, idx)
			if not cc.play_card(idx, ti):
				break
		if cc.phase == CombatController.Phase.ENDED:
			break
		cc.end_player_turn()
		await BattleDirector.run_summon_turn(cc, null, get_panel, get_panel)
		await BattleDirector.run_enemy_turn(cc, null, get_panel)
	return cc.phase == CombatController.Phase.ENDED and cc.player.is_alive()


## 选牌启发式：预期受伤 > 当前格挡则优先出格挡牌；否则优先攻击牌（打最低血敌人）；再出其余牌。
func _choose_card(cc: CombatController) -> int:
	var incoming := _incoming_damage(cc)
	var block_needed := incoming > cc.player.block
	var best_block := -1
	var best_attack := -1
	var best_any := -1
	for i in range(cc.hand.size()):
		var entry: Dictionary = cc.hand[i]
		var cd: CardData = GameData.get_card(entry["id"])
		if cd == null or cc.energy < cd.cost:
			continue
		if best_any < 0:
			best_any = i
		var has_block := false
		for eff in cd.get_effects(entry["upgraded"]):
			if eff is Dictionary and String(eff.get("kind", "")) == "block":
				has_block = true
		if has_block and best_block < 0:
			best_block = i
		if cd.type == &"attack" and best_attack < 0:
			best_attack = i
	if block_needed and best_block >= 0:
		return best_block
	if best_attack >= 0:
		return best_attack
	if best_block >= 0:
		return best_block
	return best_any


func _target_for(cc: CombatController, idx: int) -> int:
	var cd: CardData = GameData.get_card(cc.hand[idx]["id"])
	if cd != null and cd.target == &"enemy":
		var best := -1
		var best_hp := 1000000
		for i in range(cc.enemies.size()):
			if cc.enemies[i].is_alive() and cc.enemies[i].hp < best_hp:
				best_hp = cc.enemies[i].hp
				best = i
		return best if best >= 0 else 0
	return -1


func _incoming_damage(cc: CombatController) -> int:
	var sum := 0
	for e in cc.enemies:
		if not e.is_alive():
			continue
		var it: Dictionary = e.intent
		var kind: String = String(it.get("intent", String(it.get("kind", ""))))
		if kind == "attack":
			sum += int(it.get("value", 0)) * int(it.get("times", 1))
	return sum


func _grant_combat_rewards(ntype: StringName) -> void:
	RunState.add_gold(RewardBuilder.roll_gold(ntype))
	var choices: Array = RewardBuilder.roll_card_choices(
		int(GameData.balance.get("rewards", {}).get("card_choice_count", 3)))
	if not choices.is_empty():
		# P-D 起难度实装：bot 优先拿攻击牌提升击杀效率，无攻击牌则拿第一张
		var pick: Dictionary = choices[0]
		for c in choices:
			var cd: CardData = GameData.get_card(StringName(c.get("id", "")))
			if cd != null and cd.type == &"attack":
				pick = c
				break
		RunState.add_card(pick["id"], false)
	if ntype == &"elite" or ntype == &"boss":
		var rid := RewardBuilder.roll_relic(ntype)
		if rid != &"":
			RunState.add_relic(rid)


func _handle_noncombat(ntype: StringName) -> void:
	match ntype:
		&"rest":
			# P-D 起多幕难度实装（Act2/3 ×1.15/×1.30）：bot 在休息点升级一张牌（拟真玩家行为），再回血
			var upgradable: Array = []
			for i in range(RunState.deck.size()):
				if not RunState.deck[i].get("upgraded", false):
					upgradable.append(i)
			if not upgradable.is_empty():
				RunState.upgrade_card_at(upgradable[randi_range(0, upgradable.size() - 1)])
			RunState.heal(int(RunState.max_hp * 0.3))
		&"treasure":
			var rid := RewardBuilder.roll_shop_relic()
			if rid != &"":
				RunState.add_relic(rid)
			var c := RewardBuilder.roll_single_card()
			if not c.is_empty():
				RunState.add_card(c["id"], false)
		&"shop":
			# 自动买第一张买得起的卡，强化牌组（取最低价位档）
			var costs: Array = GameData.balance.get("shop", {}).get("card_cost", [50])
			var price: int = int(costs[0]) if not costs.is_empty() else 50
			if RunState.gold >= price:
				var c := RewardBuilder.roll_single_card()
				if not c.is_empty() and RunState.spend_gold(price):
					RunState.add_card(c["id"], false)
		&"event":
			# 事件节点：集成测试取中性默认（不触发，保持确定）
			pass


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== 整局集成测试（一键打通到 Boss）=====")
	lines.append("尝试次数=%d  清空层数=%d/%d  Boss击败=%s  终局HP=%d  牌组=%d  金币=%d  遗物=%d" % [
		_attempts_used, _floors_cleared, _total_all_floors, _boss_defeated,
		_final_hp, _deck_size, _gold, _relic_count])
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("PLAYTHROUGH_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
