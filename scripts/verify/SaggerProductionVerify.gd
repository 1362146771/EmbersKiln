extends Node
## 正式数据/存档/真实战斗UI接入验证；测试断言数值来自已批准的XM台账。
## -- --visual 时用实际渲染后截图；必须隔离APPDATA，不能操作用户正在玩的局。

var passed := 0
var failed := 0
var visual := false
var ed: EnemyData
var ui: CombatUI


func _ready() -> void:
	var isolated := OS.get_environment("SAGGER_TEST_APPDATA").replace("\\", "/")
	if isolated.is_empty() or not OS.get_user_data_dir().begins_with(isolated + "/"):
		push_error("必须隔离APPDATA后运行生产接入测试")
		get_tree().quit(2)
		return
	visual = OS.get_cmdline_user_args().has("--visual")
	# 验证驱动常驻root，实际Combat/Reward/Map按产品路径切场景。
	get_tree().current_scene = null
	await get_tree().process_frame
	check("正式目录加载", GameData.is_loaded)
	ed = GameData.get_enemy(&"sagger_matron")
	if ed == null:
		check("匣母数据存在", false)
		_finish()
		return
	_test_data_and_saves()
	await _test_map_hint()
	await _test_combat()
	_finish()


func check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])


func _finish() -> void:
	print("SAGGER_PRODUCTION_RESULT:%s %d PASS / %d FAIL" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _test_data_and_saves() -> void:
	check("内容规模21敌人3Boss", GameData.enemies.size() == 21 and GameData.get_enemies_by_tier(&"boss").size() == 3)
	check("确认基础生命160", ed.base_hp == 160)
	check("确认伤害12/格挡14/喷火20", ed.find_move(&"bar").value == 12 and ed.find_move(&"seal").value == 14 and ed.find_move(&"fire").value == 20)
	check("固定循环链接合法", ed.ai == &"scripted_cycle" and ed.cycle_validation_errors().is_empty())
	check("图鉴和提示已接入数据", not ed.description.is_empty() and not ed.combat_hint.is_empty())
	check("生产sprite可加载", ed.sprite_texture() != null)
	if ed.sprite_texture() != null:
		var sprite_image := ed.sprite_texture().get_image()
		check("生产sprite保持批准原图尺寸", sprite_image.get_size() == Vector2i(1254, 1254))
		check("生产sprite具有真实抗锯齿alpha", sprite_image.detect_alpha() == Image.ALPHA_BLEND)
		var background_clear := true
		for point in [Vector2i(0, 0), Vector2i(1253, 0), Vector2i(0, 1253), Vector2i(1253, 1253), Vector2i(946, 1019), Vector2i(823, 214)]:
			background_clear = background_clear and is_zero_approx(sprite_image.get_pixelv(point).a)
		check("四角脚间与把手空隙全透明", background_clear)
		var subject_opaque := true
		for point in [Vector2i(329, 633), Vector2i(283, 947), Vector2i(532, 203), Vector2i(814, 215), Vector2i(745, 1090), Vector2i(1175, 799)]:
			subject_opaque = subject_opaque and is_equal_approx(sprite_image.get_pixelv(point).a, 1.0)
		check("眼光胸腔陶瓷边脚爪尾部保持不透明", subject_opaque)
	RunState.start_new_run()
	var expected := [&"sagger_matron", &"kilnheart_ember", &"chi_the_first"]
	for act in expected.size():
		var boss: MapNode = RunState.act_maps[act][-1][0]
		check("新局第%d幕Boss正确" % (act + 1), boss.enemy_ids == [expected[act]] and boss.type == &"boss")
		check("第%d幕层数保持15" % (act + 1), RunState.act_maps[act].size() == 15)
	var fresh_save := RunState.to_save_dict()
	var old_save: Dictionary = fresh_save.duplicate(true)
	old_save.act_maps[0][-1][0].enemy_ids = ["chi_the_first"]
	check("旧版双窑主局可读", RunState.from_save_dict(old_save))
	check("旧局首幕Boss不被静默迁移", RunState.act_maps[0][-1][0].enemy_ids == [&"chi_the_first"])
	check("旧局再次保存仍保留原Boss", RunState.to_save_dict().act_maps[0][-1][0].enemy_ids == ["chi_the_first"])
	check("新匣母局序列化可还原", RunState.from_save_dict(fresh_save) and RunState.act_maps[0][-1][0].enemy_ids == [&"sagger_matron"])
	check("旧Boss数值未变", GameData.get_enemy(&"chi_the_first").base_hp == 150 and GameData.get_enemy(&"kilnheart_ember").base_hp == 165)


func _test_map_hint() -> void:
	RunState.start_new_run()
	var map_ui = load("res://scenes/map/MapPlay.tscn").instantiate()
	add_child(map_ui)
	await get_tree().process_frame
	await get_tree().process_frame
	var hint: Label = map_ui.map_area.get_node_or_null("BossCombatHint")
	check("地图机制提示无需悬停", hint != null and hint.text == ed.combat_hint and hint.visible)
	if visual:
		map_ui.map_scroller.scroll_vertical = 0
		await snapshot("map")
	map_ui.queue_free()
	await get_tree().process_frame


func _test_combat() -> void:
	RunState.start_new_run()
	RunState.current_node_type = &"boss"
	RunState.pending_combat_enemy_ids = RunState.act_maps[0][-1][0].enemy_ids.duplicate()
	ui = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	get_tree().root.add_child(ui)
	get_tree().current_scene = ui
	await get_tree().process_frame
	await get_tree().process_frame
	var c := ui.controller
	var boss := c.enemies[0]
	check("真实CombatPlay加载匣母且生命160", boss.id == ed.id and boss.hp == 160)
	check("开局意图为拦路12", boss.intent.id == "bar" and boss.intent.value == 12)
	check("敌人面板使用生产贴图", ui.unit_panels[boss].get_node("Inner/SpriteRect").texture == ed.sprite_texture())
	await snapshot("bar")
	var player_hp := c.player.hp
	await end_turn()
	check("拦路实际命中12且转封匣", c.player.hp == player_hp - 12 and boss.intent.id == "seal")
	await snapshot("seal")
	await end_turn()
	check("封匣获得14格挡且预告喷火20", boss.block == 14 and boss.intent.id == "fire" and boss.intent.value == 20)
	await snapshot("fire")
	# 设置已存在的重劈手牌用于精确破盾，不改变正式卡牌/敌人数据。
	c.hand = [{"id": &"heavy_slash", "upgraded": false}]
	c.energy = GameData.get_card(&"heavy_slash").cost
	check("真实重劈卡可用", c.play_card(0, 0))
	check("重劈恰好破封不扣Boss生命", boss.block == 0 and boss.hp == 160 and boss.intent.id == "vent")
	check("已显示意图即时变泄压", ui.unit_panels[boss].get_node("Inner/IntentLabel").text == "泄压 · 不攻击")
	await snapshot("vent")
	player_hp = c.player.hp
	await end_turn()
	check("真实Director执行泄压无伤害", c.player.hp == player_hp and boss.intent.id == "cool")
	await snapshot("cool")
	await end_turn()
	check("散热无伤害后恢复拦路", c.player.hp == player_hp and boss.intent.id == "bar")
	await end_turn()
	await end_turn()
	player_hp = c.player.hp
	# 未破盾分支：实际窑壁卡给12格挡，喷火20，预计扣血8。
	c.hand = [{"id": &"iron_wall", "upgraded": false}]
	c.energy = GameData.get_card(&"iron_wall").cost
	check("真实窑壁卡可用", c.play_card(0, 0))
	await end_turn()
	check("未破封喷火正确被格挡减伤", c.player.hp == player_hp - 8 and boss.intent.id == "cool")
	# 不跳过战斗结束：测试打出足够伤害并检查真实UI回程标记。
	c._dmg.deal_to_unit(boss, boss.hp + boss.block)
	check("匣母死亡结束战斗", not c.combat_active() and not boss.is_alive())
	check("战果回程标记写入", RunState.pending_post_combat and RunState.last_combat_victory)
	check("首幕Boss胜利不提前整局结束", RunState.is_active and not RunState.victory)
	# 等产品代码完成Combat→Map→Reward回程。
	await get_tree().create_timer(VFXSystem.DEATH_DUR + 0.6).timeout
	var reward := get_tree().current_scene
	check("Boss战后实际进入奖励界面", reward != null and reward.scene_file_path == "res://scenes/rewards/RewardUI.tscn")
	if reward != null and reward.has_method("_finish"):
		reward._finish()
		await get_tree().scene_changed
		await get_tree().process_frame
	check("首幕奖励完成进入第二幕", RunState.current_act == 1 and RunState.is_active and RunState.act_cleared_flags[0])


func end_turn() -> void:
	var c := ui.controller
	c.end_player_turn()
	var enemy_getter := func(e: CombatUnit) -> Control: return ui.unit_panels.get(e)
	var ally_getter := func(a: CombatUnit) -> Control: return ui.ally_panels.get(a)
	await BattleDirector.run_summon_turn(c, ui.player_panel, enemy_getter, ally_getter)
	await BattleDirector.run_enemy_turn(c, ui.player_panel, enemy_getter)
	await get_tree().process_frame


func snapshot(tag: String) -> void:
	if not visual:
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://Temp/sagger-verify/production_%s.png" % tag
	check("实际渲染截图 " + tag, get_viewport().get_texture().get_image().save_png(path) == OK)
