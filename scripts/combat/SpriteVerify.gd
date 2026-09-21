extends Node
## SpriteVerify（headless）：验证敌人 sprite 数据驱动接入 UI
##  - 所有带 sprite 字段的敌人，sprite_texture() 返回非 null 纹理（资源可加载）
##  - EnemyPanel（可视化子场景）在 sprite 存在时生成 TextureRect 子节点
##  - Boss 窑心·烬 sprite 可加载（地图节点 icon 来源）
## 输出 SPRITE_RESULT:PASS / FAIL

var results: Array[String] = []
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	if not RunState.is_active:
		RunState.start_new_run()

	run()
	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] " + name)
	else:
		fail_count += 1
		results.append("[FAIL] " + name + "  " + detail)


func run() -> void:
	# 1) 所有带 sprite 的敌人资源应可加载
	var with_sprite := 0
	var loaded_ok := 0
	var missing: Array[String] = []
	for eid in GameData.enemies.keys():
		var ed: EnemyData = GameData.get_enemy(eid)
		if ed == null or ed.sprite.is_empty():
			continue
		with_sprite += 1
		var tex := ed.sprite_texture()
		if tex != null:
			loaded_ok += 1
		else:
			missing.append(String(eid))
	check("敌人 sprite 资源全部可加载", missing.is_empty(),
		"缺失纹理的敌人=%s" % str(missing))
	check("存在带 sprite 的敌人（>0）", with_sprite > 0, "with_sprite=%d" % with_sprite)
	print("[info] 带 sprite 敌人=%d，加载成功=%d" % [with_sprite, loaded_ok])

	# 2) EnemyPanel（可视化子场景）在 sprite 存在时生成 TextureRect
	var controller := CombatController.new()
	add_child(controller)
	controller.start_combat(["slagbeast", "claylump"])  # 多敌（含新敌 slagbeast + 原生 claylump）
	var e0: CombatUnit = controller.enemies[0]
	var ep_scene = preload("res://scenes/combat/EnemyPanel.tscn")
	var ep = ep_scene.instantiate()
	add_child(ep)
	ep.build(e0, 0, false, controller.enemies.size())
	var has_tex := false
	for c in ep.get_node("Inner").get_children():
		if c is TextureRect:
			has_tex = true
	check("EnemyPanel 为带头像敌人生成 TextureRect", has_tex,
		"enemy0=%s" % e0.unit_name)

	# 3) Boss 窑心·烬 sprite 可加载（地图节点 icon 来源）
	var ed2: EnemyData = GameData.get_enemy(StringName("kilnheart_ember"))
	check("Boss 窑心·烬 sprite 可加载（地图图标来源）",
		ed2 != null and ed2.sprite_texture() != null, "ed2=%s" % (ed2.name if ed2 else "null"))

	# 4) CardView（可视化子场景）build_visual 填充 Body 文本（取真实手牌，经 GameData.get_card 转 CardData）
	var cd5 = null
	if controller.hand.size() > 0:
		var h0: Dictionary = controller.hand[0]
		cd5 = GameData.get_card(StringName(h0["id"]))
	var cv_scene = preload("res://scenes/combat/CardView.tscn")
	var cv = cv_scene.instantiate()
	add_child(cv)
	if cd5 != null:
		cv.build_visual(cd5, 0, [])
	check("CardView 加载并 build_visual 成功（Body 含卡名）",
		cd5 != null and cv.get_node("Body").text.contains(cd5.name),
		"cd=%s" % (cd5.name if cd5 else "null"))


func _print_report() -> void:
	for r in results:
		print(r)
	var verdict := "PASS" if fail_count == 0 else "FAIL"
	print("SPRITE_RESULT:%s  (%d 项通过, %d 项失败)" % [verdict, pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)
