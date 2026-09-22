extends Node
## BP-01..05 用户确认规则；真实控制器与正式演出路径回归。
var passed := 0
var failed := 0
var cc: CombatController

func _ready() -> void:
	await get_tree().process_frame
	ProfileManager.autosave_enabled = false
	_test_data_and_damage_floor()
	_test_cycles_growth_and_effects()
	_test_phase_transitions()
	_test_chi_output_cycles()
	_test_regeneration_and_power_cards()
	_test_death_and_reset()
	await _test_director_parity()
	await _test_ui()
	if OS.get_cmdline_user_args().has("--visual"):
		await _test_visual()
	if cc != null: cc.free()
	print("BOSS_PRESSURE_RESULT:%s %d PASS / %d FAIL" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func check(label: String, ok: bool) -> void:
	if ok: passed += 1
	else: failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func fresh(id: StringName) -> CombatUnit:
	if cc != null: cc.free()
	RunState.is_active = false
	RunState.start_new_run()
	RunState.current_act = 1 if id == &"kilnheart_ember" else 2
	RunState.relic_ids.clear()
	cc = CombatController.new()
	add_child(cc)
	cc.start_combat([id])
	# 耐受测试夹具，不修改产品数值。
	cc.player.max_hp = 10000
	cc.player.hp = 10000
	cc.hand.clear()
	return cc.enemies[0]

func step(e: CombatUnit) -> void:
	if cc.enemy_pre(e):
		cc._execute_enemy_intent(e)
		cc.enemy_post(e)

func wound_count() -> int:
	var count := 0
	for pile in [cc.hand, cc.draw_pile, cc.discard_pile, cc.exhaust_pile]:
		for entry in pile:
			if entry.id == &"wound" or entry.id == "wound": count += 1
	return count

func _test_data_and_damage_floor() -> void:
	for id in [&"kilnheart_ember", &"chi_the_first"]:
		var e := fresh(id)
		check("局内HP " + String(id), e.max_hp == (462 if id == &"kilnheart_ember" else 660))
		var expected: Array = [[18, 1], [14, 1], [12, 2], [14, 1], [52, 1]] if id == &"kilnheart_ember" else [[26, 1], [8, 4], [26, 1], [52, 1], [13, 3], [23, 1]]
		var references: Array = [[16, 1], [12, 1], [10, 2], [12, 1], [45, 1]] if id == &"kilnheart_ember" else [[20, 1], [6, 4], [20, 1], [40, 1], [10, 3], [18, 1]]
		var idx := 0
		for phase_idx in [0, 1]:
			for mv in e.data.phases[phase_idx].moves:
				if mv.intent != "attack": continue
				var scaled := cc._intent.scale_intent_damage(mv, &"boss")
				check("幕倍率与段数 " + String(mv.id), [int(scaled.value), int(scaled.times)] == expected[idx])
				check("不低于A0参考招式 " + String(mv.id), int(scaled.value) * int(scaled.times) >= int(references[idx][0]) * int(references[idx][1]))
				idx += 1
		check("确定性3阶段", e.data.ai == &"phased_cycle" and e.data.phases.size() == 3)
		check("Boss移除免费定时成长", not e.data.boss_rules.has("growth_every"))

func _test_cycles_growth_and_effects() -> void:
	var e := fresh(&"kilnheart_ember")
	var permanent := RunState.deck.duplicate(true)
	check("首招烬爪且无初始力量", e.intent.id == "claw" and e.get_status(&"heat") == 0)
	step(e)
	check("攻击后预告独立护炉，尚未成长", e.intent.id == "ward" and e.get_status(&"heat") == 0)
	var hp := cc.player.hp
	step(e)
	check("护炉不攻击且格挡保持15，不叠幕倍率", cc.player.hp == hp and e.block == 15)
	check("防御后预告灼面，无免费成长", e.intent.id == "scald_opening" and e.get_status(&"heat") == 0 and e.enemy_actions == 2)
	step(e)
	check("灼面施加两种2层减益", cc.player.get_status(&"damp") == 2 and cc.player.get_status(&"crazed") == 2)
	check("灼面仅塞2伤口", wound_count() == 2)
	check("污染不进入永久牌库", RunState.deck == permanent)
	check("攻击后预告独立蓄势且清旧盾", e.intent.id == "stoke" and e.block == 0)
	hp = cc.player.hp
	step(e)
	check("蓄势只加3力量，不攻击", e.get_status(&"heat") == 3 and cc.player.hp == hp)
	check("完整循环回到烬爪", e.intent.id == "claw")
	step(e)
	check("后续攻击不额外成长", e.get_status(&"heat") == 3)
	e.intent = cc._intent.scale_intent_damage(e.data.find_move(&"scald_opening"), &"boss")
	e.move_effects_resolved = false
	cc.player.statuses.clear()
	cc.player.block = 1000
	var before := wound_count()
	cc._execute_enemy_intent(e)
	cc._intent.apply_move_effects(e)
	check("附带效果不重复且格挡不能阻止污染", wound_count() == before + 2 and cc.player.get_status(&"damp") == 2)

func _test_phase_transitions() -> void:
	var e := fresh(&"kilnheart_ember")
	e.hp = 231
	e.add_status(&"heat", -3)
	e.add_status(&"damp", 2)
	e.add_status(&"crazed", 2)
	check("受伤不暗换已公布意图", e.intent.id == "claw")
	step(e)
	check("半血先预告强化，尚未加力量", e.intent.id == "phase_entry_1" and e.intent.intent == "buff" and e.get_status(&"heat") == -3)
	check("预告不会提前清除减益", e.has_status(&"damp") and e.has_status(&"crazed"))
	cc._roll_enemy_intent(e)
	check("重复选意图不能跳过强化回合", e.intent.id == "phase_entry_1" and e.get_status(&"heat") == -3)
	var hp := cc.player.hp
	step(e)
	check("强化实际占行动、净化后+6，随后预告处决", cc.player.hp == hp and e.intent.id == "execute_enraged" and e.get_status(&"heat") == 6)
	check("阶段清除虚弱与易伤", not e.has_status(&"damp") and not e.has_status(&"crazed"))
	check("半血处决实际18×2", cc.enemy_outgoing(e, int(e.intent.value)) == 18 and int(e.intent.times) == 2)
	e.hp = 115
	step(e)
	check("四分之一阶段先预告，不免费+6", e.phase_index == 2 and e.intent.id == "phase_entry_2" and e.get_status(&"heat") == 6)
	hp = cc.player.hp
	step(e)
	check("第二次强化不攻击，再+6并接处决", cc.player.hp == hp and e.intent.id == "execute_last" and e.get_status(&"heat") == 12)
	cc._roll_enemy_intent(e)
	check("重复选意图不重复加阶段力量", e.get_status(&"heat") == 12)
	e.heal(e.max_hp)
	cc._roll_enemy_intent(e)
	check("回血不倒退阶段", e.phase_index == 2)
	e = fresh(&"chi_the_first")
	e.hp = 165
	cc._roll_enemy_intent(e)
	check("跨两阈值先预告第一觉醒", e.phase_index == 1 and e.get_status(&"heat") == 0 and e.intent.id == "phase_entry_1")
	hp = cc.player.hp
	step(e)
	check("第一觉醒后接第二觉醒，各占行动", cc.player.hp == hp and e.phase_index == 2 and e.get_status(&"heat") == 3 and e.intent.id == "phase_entry_2")
	step(e)
	check("两次觉醒后才预告暗焰", cc.player.hp == hp and e.get_status(&"heat") == 6 and e.intent.id == "echo_last")
	step(e)
	check("觉醒完毕下一回合才造成爆发伤害", cc.player.hp == hp - 58)
	e = fresh(&"chi_the_first")
	e.hp = 329
	step(e)
	check("回复跨回半血仍兑现已触发阶段", e.hp == 339 and e.phase_index == 1 and e.intent.id == "phase_entry_1")
	step(e)
	check("回复不取消已预告觉醒", e.phase_index == 1 and e.get_status(&"heat") == 3 and e.intent.id == "echo_awakened")

func _test_chi_output_cycles() -> void:
	for powers in [0, 2]:
		var e := fresh(&"chi_the_first")
		for i in powers:
			cc.energy = 100
			cc.hand = [{"id":&"inflame", "upgraded":false}]
			cc.play_card(0)
		var hp := cc.player.hp
		for i in range(3): step(e)
		check("P1三行动均伤 " + str(powers), hp - cc.player.hp == (84 if powers == 0 else 108))
		for phase in [1, 2]:
			e.hp = 330 if phase == 1 else 165
			cc._roll_enemy_intent(e)
			hp = cc.player.hp
			step(e)
			check("窑主觉醒零伤害 P%d" % phase, cc.player.hp == hp)
			check("预告一次暗焰 P%d" % phase, String(e.intent.id).begins_with("echo_"))
			step(e)
			var expected_burst: int = (55 if phase == 1 else 58) + powers * 2
			check("一次暗焰实际伤害 P%d powers%d" % [phase,powers], hp - cc.player.hp == expected_burst)
			e.heal(e.max_hp)
			for cycle in range(3):
				hp = cc.player.hp
				check("重复循环从扑击开始", String(e.intent.id).begins_with("pounce_"))
				step(e)
				check("重复循环第二招灰浆", String(e.intent.id).begins_with("sludge_"))
				step(e)
				var expected_sum: int = (74 if phase == 1 else 86) + powers * 8
				check("后期均伤37/43或45/51且不重播暗焰", hp - cc.player.hp == expected_sum)
			check("回血不倒退阶段或重复觉醒", e.phase_index == phase and e.get_status(&"heat") == phase * 3 + powers * 2)

func _test_regeneration_and_power_cards() -> void:
	var e := fresh(&"chi_the_first")
	e.hp = 640
	cc.enemy_pre(e)
	check("行动开始回复10", e.hp == 650)
	cc.enemy_pre(e)
	cc.enemy_pre(e)
	check("回复不超过最大HP", e.hp == 660)
	cc.energy = 100
	cc.hand = [{"id":&"inflame", "upgraded":false}]
	check("能力牌实际打出", cc.play_card(0))
	check("能力牌反制+2力量", e.get_status(&"heat") == 2)
	cc.hand = [{"id":&"wound", "upgraded":false}]
	check("失败出牌不触发反制", not cc.play_card(0) and e.get_status(&"heat") == 2)
	cc.draw_pile = [{"id":&"inflame", "upgraded":false}]
	cc._play_top_draw_card_exhausted()
	check("自动打出能力牌也反制且不重复", e.get_status(&"heat") == 4)
	cc.hand = [{"id":&"defend", "upgraded":false}]
	cc.play_card(0)
	check("技能牌不触发能力反制", e.get_status(&"heat") == 4)
	e.hp = 160
	cc._roll_enemy_intent(e)
	cc.hand = [{"id":&"inflame", "upgraded":false}]
	cc.play_card(0)
	check("觉醒准备回合已停止能力反制，旧力量保留", e.get_status(&"heat") == 4)
	step(e)
	cc.draw_pile = [{"id":&"inflame", "upgraded":false}]
	cc._play_top_draw_card_exhausted()
	check("末阶段自动打出的能力也不反制", e.get_status(&"heat") == 7)
	step(e)
	for i in range(6): step(e)
	check("后期持续攻击不再定时涨力量", e.get_status(&"heat") == 10)

func _test_death_and_reset() -> void:
	var e := fresh(&"chi_the_first")
	e.hp = 1
	e.add_status(&"ashrot", 1)
	check("燃烧致死后不再生复活", not cc.enemy_pre(e) and e.hp == 0)
	e = fresh(&"chi_the_first")
	e.hp = 1
	e.intent = cc._intent.scale_intent_damage(e.data.find_move(&"soul"), &"boss")
	cc._temporary_thorns = 1
	var hp := cc.player.hp
	cc._execute_enemy_intent(e)
	check("多段被反伤击杀后停止后续命中", e.hp == 0 and cc.player.hp == hp - 8)
	e.setup(false, &"fixture", "fixture", 20)
	check("复用单位清理阶段与成长状态", e.phase_index == -1 and e.phase_move_index == -1 and e.reached_phase_index == 0 and e.enemy_actions == 0 and not e.move_effects_resolved)

func snapshot(e: CombatUnit) -> Array:
	return [e.get_status(&"heat"), e.enemy_actions, e.intent.id, e.block, cc.player.hp, cc.player.get_status(&"damp"), cc.player.get_status(&"crazed"), wound_count()]

func _test_director_parity() -> void:
	var e := fresh(&"kilnheart_ember")
	e.intent = cc._intent.scale_intent_damage(e.data.find_move(&"scald_opening"), &"boss")
	cc.end_player_turn()
	step(e)
	cc.enemy_phase_done()
	var direct := snapshot(e)
	e = fresh(&"kilnheart_ember")
	e.intent = cc._intent.scale_intent_damage(e.data.find_move(&"scald_opening"), &"boss")
	cc.end_player_turn()
	await BattleDirector.run_enemy_turn(cc, null, func(_e): return null)
	check("正式Director与直接结算一致（伤害/减益/塞牌/成长/下一意图）", snapshot(e) == direct)
	for move_id in [&"ward", &"stoke", &"phase_entry_1"]:
		e = fresh(&"kilnheart_ember")
		if move_id == &"phase_entry_1":
			e.hp = 231
			cc._roll_enemy_intent(e)
			e.add_status(&"heat", -3)
			e.add_status(&"damp", 2)
		else:
			e.intent = cc._intent.scale_intent_damage(e.data.find_move(move_id), &"boss")
		var before_hp := cc.player.hp
		cc.end_player_turn()
		step(e)
		cc.enemy_phase_done()
		direct = snapshot(e)
		check("准备回合零攻击 " + String(move_id), cc.player.hp == before_hp)
		e = fresh(&"kilnheart_ember")
		if move_id == &"phase_entry_1":
			e.hp = 231
			cc._roll_enemy_intent(e)
			e.add_status(&"heat", -3)
			e.add_status(&"damp", 2)
		else:
			e.intent = cc._intent.scale_intent_damage(e.data.find_move(move_id), &"boss")
		cc.end_player_turn()
		await BattleDirector.run_enemy_turn(cc, null, func(_e): return null)
		check("正式Director准备行动与直接结算一致 " + String(move_id), snapshot(e) == direct)
	e = fresh(&"chi_the_first")
	e.intent = cc._intent.scale_intent_damage(e.data.find_move(&"soul"), &"boss")
	e.hp = 1
	# 再生关闭仅用于隔离测试首击反伤；正式数据不修改。
	e.data = EnemyData.from_dict({"id":"fixture","boss_rules":{},"moves":[]})
	cc._temporary_thorns = 1
	var hp := cc.player.hp
	cc.end_player_turn()
	await BattleDirector.run_enemy_turn(cc, null, func(_e): return null)
	check("正式Director反伤击杀终止四连击", e.hp == 0 and cc.player.hp == hp - 8)

func _test_ui() -> void:
	var e := fresh(&"kilnheart_ember")
	e.intent = cc._intent.scale_intent_damage(e.data.find_move(&"scald_opening"), &"boss")
	var panel := load("res://scenes/combat/EnemyPanel.tscn").instantiate() as EnemyPanel
	add_child(panel)
	await get_tree().process_frame
	panel.build(e, 0, false, 1, cc)
	var bar := panel.get_node("Inner/IntentBar")
	check("复合意图显示攻击/虚弱/易伤/伤口，无免费成长", bar.get_child_count() == 4)
	check("敌人总览保留独立强化规则", panel.get_node("Inner/NameLabel").tooltip_text.contains("各占一回合"))
	check("阶段名称可见", panel.get_node("Inner/NameLabel").text.contains("阶段1"))
	panel.queue_free()
	e = fresh(&"chi_the_first")
	e.hp = 330
	cc._roll_enemy_intent(e)
	panel = load("res://scenes/combat/EnemyPanel.tscn").instantiate() as EnemyPanel
	add_child(panel)
	await get_tree().process_frame
	panel.build(e, 0, false, 1, cc)
	bar = panel.get_node("Inner/IntentBar")
	var labels: Array[String] = []
	for badge in bar.get_children(): labels.append(badge.get_meta("info_title", ""))
	check("觉醒意图显示净化与回复，不显示能力反制", "净化" in labels and "持续回复" in labels and not "能力反制" in labels)
	check("觉醒意图无攻击图标", not bar.get_children().any(func(badge): return badge.get_meta("intent_kind") == "attack"))
	panel.queue_free()

func _test_visual() -> void:
	cc.free()
	cc = null
	for id in [&"kilnheart_ember", &"chi_the_first"]:
		RunState.is_active = false
		RunState.start_new_run()
		RunState.current_act = 1 if id == &"kilnheart_ember" else 2
		var ui := load("res://scenes/combat/CombatPlay.tscn").instantiate() as CombatUI
		ui.pending_enemy_ids = [id]
		add_child(ui)
		await get_tree().process_frame
		await get_tree().process_frame
		var e := ui.controller.enemies[0]
		if id == &"kilnheart_ember":
			ui.controller._roll_enemy_intent(e)
		else:
			e.hp = 330
			ui.controller._roll_enemy_intent(e)
			ui.controller._roll_enemy_intent(e)
			ui.controller._roll_enemy_intent(e)
		ui._refresh_all()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "res://Temp/boss-pressure-%s.png" % id
		DirAccess.make_dir_recursive_absolute("res://Temp")
		check("真实战斗界面截图 " + String(id), get_viewport().get_texture().get_image().save_png(path) == OK)
		var panel: EnemyPanel = ui.unit_panels[e]
		var bar := panel.get_node("Inner/IntentBar") as Control
		var sprite := panel.get_node("Inner/SpriteRect") as Control
		check("复合意图未遮挡敌人立绘 " + String(id), bar.get_global_rect().end.y <= sprite.get_global_rect().position.y)
		ui.queue_free()
		await get_tree().process_frame
