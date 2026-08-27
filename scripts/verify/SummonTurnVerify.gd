extends Node
## SummonTurnVerify：验证「玩家结束回合 → 召唤物异步演出（攻击/防御 + VFX）→ 敌人回合」链路。
## 覆盖：run_summon_turn 对敌人造成随从攻击伤害、防御随从加格挡、寿命递减、
##       指挥加成、行动信号、空场无操作、友色光弹 VFX 飞行+撞击回调+自动释放。
## 输出 SUMMON_TURN_RESULT:PASS / FAIL。通过 run_and_verify 指定该 scene 运行。

var results: Array[String] = []
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	if not RunState.is_active:
		RunState.start_new_run()
	await run()
	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] " + name)
	else:
		fail_count += 1
		results.append("[FAIL] " + name + "  " + detail)


## 统计当前存活且意图为 attack 的友方数量（用于稳健断言，避免持有遗物的入场召唤干扰）。
func _attackers(ctrl: CombatController) -> int:
	var n := 0
	for a in ctrl.allies:
		if a.is_alive() and String(a.intent.get("intent", "")) == "attack":
			n += 1
	return n


func run() -> void:
	var ctrl := CombatController.new()
	add_child(ctrl)
	ctrl.start_combat(["claylump"])

	# 召唤窑犬（attack 5，寿命 3）+ 釉卫（defend 5，寿命 3）
	ctrl._summon_minion(&"emberhound", 1)
	ctrl._summon_minion(&"glazeward", 1)
	var hound: CombatUnit = null
	var guard: CombatUnit = null
	for a in ctrl.allies:
		if a.id == &"emberhound":
			hound = a
		elif a.id == &"glazeward":
			guard = a
	check("窑犬与釉卫均已登场", hound != null and guard != null)
	var attackers := _attackers(ctrl)

	ctrl.end_player_turn()
	check("结束回合后 phase=ENEMY", ctrl.phase == CombatController.Phase.ENEMY, "phase=%d" % ctrl.phase)

	var enemy_getter := func(_e): return null
	var ally_getter := func(_a): return null
	var ehp_before: int = ctrl.enemies[0].hp

	await BattleDirector.run_summon_turn(ctrl, null, enemy_getter, ally_getter)

	var dealt: int = ehp_before - ctrl.enemies[0].hp
	check("召唤阶段：攻击随从造成 5/个 伤害", dealt == 5 * attackers, "dealt=%d attackers=%d" % [dealt, attackers])
	check("窑犬寿命 3→2", hound.lifetime == 2, "life=%d" % hound.lifetime)
	check("釉卫防御加格挡 5", guard.block == 5, "block=%d" % guard.block)
	check("召唤阶段结束后未锁输入", BattleDirector.input_locked == false)
	check("召唤阶段结束后战斗仍激活", ctrl.combat_active())

	# 指挥加成：玩家加 command 后，攻击随从伤害 +command、防御随从格挡 +command
	ctrl.player.add_status(&"command", 2)
	var ehp2: int = ctrl.enemies[0].hp
	await BattleDirector.run_summon_turn(ctrl, null, enemy_getter, ally_getter)
	var dealt2: int = ehp2 - ctrl.enemies[0].hp
	check("指挥+2：攻击随从伤害 5+2=7/个", dealt2 == 7 * attackers, "dealt2=%d" % dealt2)
	# 防御随从每回合先清格挡再置为 value+command（ally_pre 清格挡），故 = 5+2 = 7
	check("指挥+2：釉卫格挡 5+2=7", guard.block == 7, "block=%d" % guard.block)
	check("窑犬寿命 2→1", hound.lifetime == 1, "life=%d" % hound.lifetime)

	# 寿命到期清场：连推到寿命耗尽
	while ctrl.allies.size() > 0 and ctrl.combat_active():
		await BattleDirector.run_summon_turn(ctrl, null, enemy_getter, ally_getter)
	check("寿命到期后友方清场", ctrl.allies.size() == 0, "allies=%d" % ctrl.allies.size())

	# 空场无操作且不崩溃、解锁
	ctrl.end_player_turn()
	await BattleDirector.run_summon_turn(ctrl, null, enemy_getter, ally_getter)
	check("空场召唤阶段不崩溃且解锁", BattleDirector.input_locked == false)

	ctrl.queue_free()

	# 光弹 VFX：用真实 Control 面板验证飞行 + 撞击回调 + 自动释放
	var from := Control.new()
	var to := Control.new()
	add_child(from); add_child(to)
	from.global_position = Vector2(100, 100)
	to.global_position = Vector2(500, 500)
	var hit_flag := {"hit": false}
	await VFXSystem.spawn_summon_strike(from, to, func(): hit_flag.hit = true)
	check("spawn_summon_strike 撞击点回调触发", hit_flag.hit)
	await get_tree().create_timer(0.3).timeout
	check("spawn_summon_strike 演出后自动释放（无残留子节点）", from.get_child_count() == 0, "children=%d" % from.get_child_count())
	from.queue_free(); to.queue_free()


func _print_report() -> void:
	for r in results:
		print(r)
	var verdict := "PASS" if fail_count == 0 else "FAIL"
	print("SUMMON_TURN_RESULT:%s  (%d 项通过, %d 项失败)" % [verdict, pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)
