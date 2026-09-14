extends Node
## 仅机制夹具：下列数值不是匣母平衡提案，绝不注入正式敌人目录。
## 请在隔离 APPDATA 下运行，避免测试的战斗信号影响用户存档。

var passed := 0
var failed := 0
var ctrl: CombatController
var boss: CombatUnit
var intent_events := 0


func _ready() -> void:
	var isolated := OS.get_environment("SAGGER_TEST_APPDATA").replace("\\", "/")
	if isolated.is_empty() or not OS.get_user_data_dir().begins_with(isolated + "/"):
		push_error("SaggerMatronVerify 必须由隔离 APPDATA 的测试命令运行")
		get_tree().quit(2)
		return
	print("SAGGER_USER_DATA=" + OS.get_user_data_dir())
	await get_tree().process_frame
	check("正式目录可加载", GameData.is_loaded)
	SignalBus.enemy_intent_changed.connect(_on_intent)
	_test_validation()
	_test_failed_break_cycle()
	_test_successful_break_cycle()
	_test_damage_routes()
	_test_ui_and_scaling()
	_test_legacy_and_reset()
	if ctrl != null:
		ctrl.free()
	print("SAGGER_RESULT:%s %d PASS / %d FAIL" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func fixture() -> Dictionary:
	return {
		"id": "verify_sagger", "name": "匣母机制夹具", "tier": "boss", "hp": 1000,
		"ai": "scripted_cycle", "first_move": "bar",
		"moves": [
			{"id": "bar", "name": "拦路", "intent": "attack", "value": 3, "next": "seal"},
			{"id": "seal", "name": "封匣", "intent": "charge", "value": 8, "next": "fire", "on_block_break": "vent"},
			{"id": "fire", "name": "开窑", "intent": "attack", "value": 9, "next": "cool"},
			{"id": "vent", "name": "泄压", "intent": "unknown", "next": "cool"},
			{"id": "cool", "name": "散热", "intent": "unknown", "next": "bar"}
		]
	}


func fresh() -> void:
	if ctrl != null:
		ctrl.free()
	RunState.is_active = false
	RunState.relic_ids.clear()
	RunState.potions.clear()
	ctrl = CombatController.new()
	add_child(ctrl)
	ctrl.player = CombatUnit.new()
	ctrl.player.setup(true, &"verify_player", "测试玩家", 1000)
	ctrl._combat_active = true
	ctrl.phase = CombatController.Phase.PLAYER
	var ed := EnemyData.from_dict(fixture())
	boss = CombatUnit.new()
	boss.setup(false, ed.id, ed.name, ed.base_hp)
	boss.data = ed
	ctrl.enemies.append(boss)
	ctrl._roll_enemy_intent(boss)
	intent_events = 0


func move_id() -> String:
	return boss.intent.get("id", "")


func step_enemy() -> void:
	if ctrl.enemy_pre(boss):
		ctrl.enemy_act(boss)
		ctrl.enemy_post(boss)


func seal() -> void:
	fresh()
	step_enemy()
	step_enemy()
	intent_events = 0


func _on_intent(_index: int, _kind: StringName, _value: int) -> void:
	intent_events += 1


func check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])


func _test_validation() -> void:
	check("循环夹具合法", EnemyData.from_dict(fixture()).cycle_validation_errors().is_empty())
	var d := fixture()
	d.first_move = "absent"
	check("拒绝缺失首招", not EnemyData.from_dict(d).cycle_validation_errors().is_empty())
	d = fixture()
	d.moves[2].next = "absent"
	check("拒绝缺失下一招", not EnemyData.from_dict(d).cycle_validation_errors().is_empty())
	d = fixture()
	d.moves[1].on_block_break = "absent"
	check("拒绝缺失破封分支", not EnemyData.from_dict(d).cycle_validation_errors().is_empty())
	d = fixture()
	d.moves[1].value = 0
	check("拒绝零格挡破封窗口", not EnemyData.from_dict(d).cycle_validation_errors().is_empty())
	d = fixture()
	d.moves[4].id = "bar"
	check("拒绝重复招式标识", not EnemyData.from_dict(d).cycle_validation_errors().is_empty())


func _test_failed_break_cycle() -> void:
	fresh()
	check("首招固定拦路", move_id() == "bar")
	var hp := ctrl.player.hp
	step_enemy()
	check("拦路伤害且转封匣", ctrl.player.hp == hp - GameData.scaled_enemy_damage(3) and move_id() == "seal")
	hp = ctrl.player.hp
	step_enemy()
	check("封匣无伤害并获得格挡", ctrl.player.hp == hp and boss.block == 8)
	check("封匣后明示喷火且窗口开启", move_id() == "fire" and boss.block_break_next == &"vent")
	ctrl._dmg.deal_to_unit(boss, 3)
	check("未破封仍然喷火", boss.block == 5 and move_id() == "fire" and intent_events == 2)
	ctrl.enemy_pre(boss)
	check("自然清盾不泄压", boss.block == 0 and boss.block_break_next == &"" and move_id() == "fire")
	ctrl.enemy_act(boss)
	ctrl.enemy_post(boss)
	check("未破封喷火实际命中并转散热", ctrl.player.hp == hp - GameData.scaled_enemy_damage(9) and move_id() == "cool")
	hp = ctrl.player.hp
	step_enemy()
	check("散热不攻击格挡回血并回拦路", ctrl.player.hp == hp and boss.block == 0 and boss.hp == boss.max_hp and move_id() == "bar")


func _test_successful_break_cycle() -> void:
	seal()
	var hp := ctrl.player.hp
	ctrl._dmg.deal_to_unit(boss, 8)
	check("恰好破封不掉血也能打断", boss.hp == boss.max_hp and boss.block == 0 and move_id() == "vent")
	check("即时广播换意图并清除蓄力", intent_events == 1 and boss.charge_next == &"" and boss.block_break_next == &"")
	ctrl._dmg.deal_to_unit(boss, 1)
	check("窗口内不重复泄压", intent_events == 1 and move_id() == "vent")
	step_enemy()
	check("泄压无伤害并进入散热", ctrl.player.hp == hp and move_id() == "cool")
	step_enemy()
	check("成功分支也完整经历散热", ctrl.player.hp == hp and move_id() == "bar")
	step_enemy()
	step_enemy()
	check("下一循环重新开启破封窗口", boss.block == 8 and boss.block_break_next == &"vent" and move_id() == "fire")
	ctrl._dmg.deal_to_unit(boss, 10)
	check("溢出正常扣血且再次可破封", boss.hp == boss.max_hp - 3 and move_id() == "vent")
	seal()
	ctrl._dmg.deal_to_unit(boss, 0)
	check("零伤害不破封", boss.block == 8 and move_id() == "fire" and intent_events == 0)
	seal()
	ctrl._dmg.deal_to_unit(boss, boss.hp + boss.block)
	check("死亡优先不进入泄压", not boss.is_alive() and not ctrl._combat_active and intent_events == 0)


func _test_damage_routes() -> void:
	seal()
	ctrl._resolve_effects([{"kind": "damage", "value": 4, "times": 3}], ctrl.player, boss)
	check("多段攻击只打断一次且后段继续伤害", move_id() == "vent" and intent_events == 1 and boss.hp == boss.max_hp - 4)
	seal()
	ctrl._dmg.deal_kiln_resonance(boss, 20)
	check("贯穿窑变不消耗封匣格挡", boss.block == 8 and move_id() == "fire" and intent_events == 0)
	boss.add_status(&"ashrot", 2)
	ctrl._status.process_turn_start_statuses(boss)
	check("燃烧绕盾不破封", boss.block == 8 and move_id() == "fire" and boss.hp == boss.max_hp - 22)
	seal()
	var ally := CombatUnit.new()
	ally.setup(false, &"verify_ally", "随从夹具", 10)
	ctrl.allies.append(ally)
	ctrl._intent.ally_attack_hit(ally, boss, 8)
	check("随从实际命中路径可以破封", move_id() == "vent" and intent_events == 1)
	var hp := ctrl.player.hp
	step_enemy()
	check("随从阶段破封后敌人不会喷火", ctrl.player.hp == hp and move_id() == "cool")
	seal()
	RunState.potions.append(&"kiln_fire_oil")
	check("范围伤害药水路径可以破封", ctrl.use_potion(0) and move_id() == "vent" and RunState.potions.is_empty())
	seal()
	RunState.potions.append(&"titan_anoint")
	check("单体伤害药水路径可以破封", ctrl.use_potion(0, 0) and move_id() == "vent")
	seal()
	var other := CombatUnit.new()
	other.setup(false, &"other", "其他敌人", 100)
	ctrl.enemies.append(other)
	ctrl._dmg.deal_to_unit(other, 8)
	check("攻击其他敌人不误触破封", boss.block == 8 and move_id() == "fire")


func _test_ui_and_scaling() -> void:
	seal()
	var panel: EnemyPanel = load("res://scenes/combat/EnemyPanel.tscn").instantiate()
	add_child(panel)
	panel.build(boss, 0, false, 1, ctrl)
	check("喷火和破封提示可见", panel.get_node("Inner/IntentBar").tooltip_text.contains("打掉格挡可打断"))
	check("剩余封匣格挡数值显示在盾上", panel.get_node("Inner/BlockShield/BlockText").text == "8")
	# 无需进入 CombatUI._ready；只验证已持有面板时的真实信号处理路径。
	var ui := CombatUI.new()
	ui.controller = ctrl
	ui.unit_panels[boss] = panel
	ui._casting = true
	var manager := EnemyViewManager.new()
	manager.attach(ui)
	SignalBus.enemy_intent_changed.connect(manager.on_eintent)
	BattleDirector.input_locked = true
	ctrl._dmg.deal_to_unit(boss, 8)
	var label: String = panel.get_node("Inner/IntentBar").tooltip_text
	check("动画锁定期间即时换提示无残留喷火", label == "泄压 · 不攻击" and ui._needs_refresh)
	SignalBus.enemy_intent_changed.disconnect(manager.on_eintent)
	BattleDirector.input_locked = false
	ui.free()
	panel.free()
	fresh()
	step_enemy()
	boss.add_status(&"heat", 2)
	var preview := EnemyPanel.format_scripted_intent(boss, ctrl)
	var expected := ctrl.enemy_outgoing(boss, GameData.scaled_enemy_damage(9))
	check("预告伤害包含真实敌方增益", preview.ends_with("喷火 %d" % expected))
	step_enemy()
	check("已滚动攻击意图显示真实伤害", EnemyPanel.format_scripted_intent(boss, ctrl).begins_with("开窑 %d" % expected))
	var ed := boss.data as EnemyData
	check("缩放不污染原始数据", int(ed.find_move(&"fire").value) == 9)
	var original_multiplier: Variant = GameData.balance.enemy_scaling.damage_multiplier
	GameData.balance.enemy_scaling.damage_multiplier = 1.5
	fresh()
	step_enemy()
	preview = EnemyPanel.format_scripted_intent(boss, ctrl)
	expected = GameData.scaled_enemy_damage(9)
	step_enemy()
	check("难度缩放前后预告一致且仅乘一次", preview.ends_with("喷火 %d" % expected) and int(boss.intent.value) == expected)
	GameData.balance.enemy_scaling.damage_multiplier = original_multiplier


func _test_legacy_and_reset() -> void:
	fresh()
	var legacy := EnemyData.from_dict({"id": "legacy", "ai": "weighted_random", "moves": [
		{"id": "charge", "intent": "charge", "value": 8, "next": "release", "chance": 1.0},
		{"id": "release", "intent": "attack", "value": 9, "chance": 0.0}
	]})
	boss.data = legacy
	boss.intent = legacy.find_move(&"charge")
	ctrl.enemy_act(boss)
	ctrl.enemy_post(boss)
	ctrl._dmg.deal_to_unit(boss, 8)
	check("旧蓄力怪破盾不会取消攻击", move_id() == "release" and boss.block_break_next == &"")
	var hp := ctrl.player.hp
	step_enemy()
	check("旧蓄力释放实际伤害", ctrl.player.hp == hp - GameData.scaled_enemy_damage(9))
	seal()
	boss.setup(false, &"reused", "复用单元", 1000)
	check("重置战斗单元清理破封和蓄力状态", boss.block_break_next == &"" and boss.charge_next == &"" and boss.intent.is_empty())
	fresh()
	step_enemy()
	var ed := boss.data as EnemyData
	boss.setup(false, &"reused", "复用单元", 1000)
	check("非攻击意图重置不污染数据", not ed.find_move(&"seal").is_empty())
