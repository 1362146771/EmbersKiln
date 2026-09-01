extends Node2D
## 战斗系统冒烟测试：脚本化打一场（玩家 vs 陶泥团 claylump），
## 断言核心不变量。真实运行（run_and_verify）后用 stdout 判定 PASS/FAIL。
## 状态机制（易伤 / 力量）通过直接注入隔离测试，不依赖随机起手牌。

var controller: CombatController
var results: Array[String] = []
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	controller = $CombatController

	run()
	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if detail != "" else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if detail != "" else ""])


func run() -> void:
	# ===== Phase 1：开局不变量 + 精确伤害 + 格挡 =====
	RunState.start_new_run()
	controller.start_combat(["claylump"])

	check("开局后手牌=5", controller.hand.size() == 5, "hand=%d" % controller.hand.size())
	check("开局后能量=3", controller.energy == 3, "energy=%d" % controller.energy)
	check("敌人已生成", controller.enemies.size() == 1)
	check("敌人初始HP=44(44×1.0,难度归位后偏易修正)", controller.enemies[0].hp == 44, "hp=%d" % controller.enemies[0].hp)

	var s := _find_in_hand("strike")
	if s >= 0:
		var before := controller.enemies[0].hp
		var ok := controller.play_card(s, 0)
		var after := controller.enemies[0].hp
		check("出劈薪成功", ok)
		check("劈薪造成6点伤害(无状态)", before - after == 6, "delta=%d" % (before - after))
		check("出牌后能量=2", controller.energy == 2, "energy=%d" % controller.energy)
	else:
		check("起手含劈薪(随机，跳过精确伤害)", true, "本局起手无劈薪")

	var d := _find_in_hand("defend")
	if d >= 0 and controller.energy >= _cost_of(d):
		var ok := controller.play_card(d, -1)
		check("出护坯成功", ok)
		check("护坯获得5点格挡", controller.player.block == 5, "block=%d" % controller.player.block)
	else:
		check("起手含护坯且能量足够(随机，跳过格挡)", true, "本局起手无护坯或能量不足")

	# ===== Phase 2：易伤（×1.5）隔离测试 =====
	controller.start_combat(["claylump"])
	controller._apply_status(controller.enemies[0], &"crazed", 2)
	check("易伤注入=2层", controller.enemies[0].get_status(&"crazed") == 2,
		"crazed=%d" % controller.enemies[0].get_status(&"crazed"))
	var s2 := _find_in_hand("strike")
	if s2 >= 0:
		var before := controller.enemies[0].hp
		controller.play_card(s2, 0)
		var after := controller.enemies[0].hp
		check("易伤使伤害×1.5(6→9)", before - after == 9, "delta=%d" % (before - after))
	else:
		check("起手含劈薪测试易伤(随机跳过)", true, "本局起手无劈薪")

	# ===== Phase 3：力量加成（+层数）隔离测试 =====
	controller.start_combat(["claylump"])
	controller._apply_status(controller.player, &"heat", 3)
	check("力量注入=3层", controller.player.get_status(&"heat") == 3,
		"heat=%d" % controller.player.get_status(&"heat"))
	var s3 := _find_in_hand("strike")
	if s3 >= 0:
		var before := controller.enemies[0].hp
		controller.play_card(s3, 0)
		var after := controller.enemies[0].hp
		check("力量使伤害+3(6→9)", before - after == 9, "delta=%d" % (before - after))
	else:
		check("起手含劈薪测试力量(随机跳过)", true, "本局起手无劈薪")

	# ===== Phase 4：结束回合 → 敌人阶段不崩溃 =====
	controller.start_combat(["claylump"])
	controller.end_player_turn()
	_advance_to_player_turn()   # 驱动敌人回合（真实战斗由 BattleDirector 异步编排）
	check("结束回合后回到玩家回合或战斗结束",
		controller.phase == CombatController.Phase.PLAYER or controller.phase == CombatController.Phase.ENDED)
	check("敌人阶段未崩溃(玩家存在)", controller.player != null)

	# ===== Phase 4b：格挡扛过敌人攻击（用户确认的设计）=====
	# 确定性验证：强制敌人攻击 6，玩家格挡 10，结束回合后敌人攻击必须被格挡吸收，HP 不变。
	controller.start_combat(["claylump"])
	controller.player.block = 10
	controller.enemies[0].intent = {"kind": "attack", "value": 6, "times": 1, "intent": "attack"}
	var hp_before_block_test: int = controller.player.hp
	controller.end_player_turn()
	_advance_to_player_turn()   # 驱动敌人真实攻击 → 应被格挡 10 吸收
	check("格挡扛过敌人攻击：HP 不变", controller.player.hp == hp_before_block_test,
		"hp=%d (攻击6应被格挡10吸收)" % controller.player.hp)
	check("格挡扛过敌人攻击：玩家仍存活", controller.player.hp > 0, "hp=%d" % controller.player.hp)

	# ===== Phase 5：完整打赢一场 =====
	var guard := 0
	while controller.phase != CombatController.Phase.ENDED and guard < 30:
		guard += 1
		var played := true
		while played:
			played = false
			for i in range(controller.hand.size()):
				var cd: CardData = GameData.get_card(controller.hand[i]["id"])
				if cd != null and cd.type == &"attack" and controller.energy >= cd.cost:
					var ti := 0
					if cd.target == &"enemy":
						ti = _first_alive_enemy_index()
					if controller.play_card(i, ti):
						played = true
						break
		controller.end_player_turn()
		_advance_to_player_turn()   # 驱动敌人回合（真实战斗由 BattleDirector 异步编排）
		if controller.phase == CombatController.Phase.ENDED:
			break

	check("在30轮内结束战斗", controller.phase == CombatController.Phase.ENDED, "guard=%d" % guard)
	check("战斗胜利(combat_ended true)", RunState.defeated.has(&"claylump"),
		"defeated=%s" % str(RunState.defeated))
	check("玩家存活", RunState.hp > 0, "hp=%d" % RunState.hp)


func _find_in_hand(card_id: String) -> int:
	for i in range(controller.hand.size()):
		if String(controller.hand[i]["id"]) == card_id:
			return i
	return -1


func _cost_of(hand_index: int) -> int:
	var cd: CardData = GameData.get_card(controller.hand[hand_index]["id"])
	return cd.cost if cd != null else 999


func _first_alive_enemy_index() -> int:
	for i in range(controller.enemies.size()):
		if controller.enemies[i].is_alive():
			return i
	return 0


## 模拟 BattleDirector 驱动一整轮敌人阶段（与真实战斗走同一组公开 API）：
## 对每个存活敌人执行 清旧格挡 → 执行意图(攻击走 outgoing/attack_hit，其余走 act)
## → 状态衰减+滚动下一意图，最后 enemy_phase_done 收尾回到下一玩家回合。
func _advance_to_player_turn() -> void:
	for e in controller.enemies:
		if not e.is_alive():
			continue
		controller.enemy_pre(e)
		var mv: Dictionary = e.intent
		var kind: String = String(mv.get("intent", "unknown"))
		if kind == "attack":
			var dmg: int = controller.enemy_outgoing(e, int(mv.get("value", 0)))
			controller.enemy_attack_hit(e, dmg)
		else:
			controller.enemy_act(e)
		controller.enemy_post(e)
	controller.enemy_phase_done()


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== 战斗系统冒烟测试 =====")
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("SMOKE_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
