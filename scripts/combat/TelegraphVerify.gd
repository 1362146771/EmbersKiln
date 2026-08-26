extends Node
## 蓄力/telegraph 意图机制确定性验证。
## 运行时向 GameData 注入一个仅含「蓄力→释放」招式的测试敌人，驱动回合验证：
## 1) 开局显示蓄力意图；2) 下一回合意图被强制为释放招式；3) 释放招式实际造成伤害。

var controller: CombatController
var test_enemy: EnemyData
var results: Array[String] = []
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()

	# 注入仅含 charge→release 的测试敌人（蓄力 chance 1.0 / 释放 0.0，保证确定性）
	test_enemy = EnemyData.from_dict({
		"id": "t_charger",
		"name": "测试蓄力者",
		"tier": "normal",
		"hp": 40,
		"ai": "weighted_random",
		"moves": [
			{"id": "t_charge", "intent": "charge", "value": 8, "next": "t_release", "chance": 1.0},
			{"id": "t_release", "intent": "attack", "value": 20, "chance": 0.0}
		]
	})
	GameData.enemies[StringName("t_charger")] = test_enemy

	controller = CombatController.new()
	add_child(controller)

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
	RunState.start_new_run()
	controller.start_combat(["t_charger"])

	check("开局敌人意图为蓄力(charge)",
		String(controller.enemies[0].intent.get("intent", "")) == "charge",
		"intent=%s" % controller.enemies[0].intent.get("intent", ""))

	var hp_after_charge_turn: int = controller.player.hp

	# 第 1 次结束回合：敌人执行蓄力（不输出），并锁定下回合释放招式
	controller.end_player_turn()
	var intent_after_charge: String = String(controller.enemies[0].intent.get("intent", ""))
	var val_after_charge: int = int(controller.enemies[0].intent.get("value", 0))
	check("蓄力后下一回合意图被强制为攻击(释放招式)",
		intent_after_charge == "attack", "intent=%s" % intent_after_charge)
	check("释放招式数值=20", val_after_charge == 20, "value=%d" % val_after_charge)
	check("蓄力回合玩家未受伤(决策窗口)",
		controller.player.hp == hp_after_charge_turn,
		"hp=%d" % controller.player.hp)

	# 第 2 次结束回合：敌人执行释放招式，玩家应受到伤害
	controller.end_player_turn()
	check("释放招式实际造成伤害",
		controller.player.hp < hp_after_charge_turn,
		"hp %d -> %d" % [hp_after_charge_turn, controller.player.hp])

	# 数据层自洽：find_move 能解析释放招式（UI 预告用）
	var rel := test_enemy.find_move(&"t_release")
	check("EnemyData.find_move 能解析释放招式", not rel.is_empty(), "rel=%s" % str(rel))


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== 蓄力/telegraph 意图机制验证 =====")
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("TELEGRAPH_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
