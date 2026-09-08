extends Node
## P3 内容扩展验证：卡池深化 / 多敌编成表 / Boss 三阶段觉醒。
## 全部确定性断言，真实运行（headless）后用 stdout 判定 P3_RESULT。

var results: Array[String] = []
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	if not GameData.is_loaded:
		check("GameData 加载", false, "加载失败")
		_print_report()
		return

	_test_card_pool()
	_test_boss_phase3()
	_test_formations()

	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if detail != "" else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if detail != "" else ""])


# =====================================================================
# 4.1 卡池深化
# =====================================================================
func _test_card_pool() -> void:
	check("卡池=75 张职业牌 + 3 张生成状态牌", GameData.cards.size() == 78, "cards=%d" % GameData.cards.size())

	var new_ids := ["anger", "flame_barrier", "shockwave", "immolate",
		"corruption", "demon_form", "barricade", "reaper"]
	for cid in new_ids:
		check("新卡存在: %s" % cid, GameData.get_card(StringName(cid)) != null, "")

	# 每系至少补到 1 张高稀有度终端卡
	check("力量终端熔身存在", GameData.get_card(&"demon_form") != null)
	check("格挡终端固釉不坠存在", GameData.get_card(&"barricade") != null)
	check("控制牌震荡波存在", GameData.get_card(&"shockwave") != null)
	check("状态牌联动燔祭存在", GameData.get_card(&"immolate") != null)

	# gain_kiln_heat effect 真实生效：累计窑温并触发窑变（贯穿伤害）
	_run_kiln_heat_effect()


# 直接用战斗核心 _resolve_effects 验证 gain_kiln_heat（免抽牌随机）。
func _run_kiln_heat_effect() -> void:
	var cc := CombatController.new()
	add_child(cc)
	RunState.start_new_run()
	RunState.hp = 80
	cc.start_combat([StringName("claylump")])   # 单弱敌即可验证窑变
	var before_hp: int = cc.enemies[0].hp
	# 一次性 +5 窑温 -> 触发一次窑变（贯穿 5，无视格挡）
	cc._resolve_effects([{"kind": "gain_kiln_heat", "value": 5}], cc.player, null)
	check("gain_kiln_heat 触发窑变：敌人受 5 贯穿", cc.enemies[0].hp == before_hp - 5,
		"enemy_hp %d -> %d" % [before_hp, cc.enemies[0].hp])
	check("gain_kiln_heat 窑变后窑温归零", cc.kiln_heat == 0, "heat=%d" % cc.kiln_heat)
	cc.queue_free()


# =====================================================================
# 4.3 Boss 三阶段觉醒
# =====================================================================
func _test_boss_phase3() -> void:
	var cc := CombatController.new()
	add_child(cc)
	RunState.start_new_run()
	RunState.hp = 80
	cc.start_combat([StringName("chi_the_first")])

	var boss: CombatUnit = cc.enemies[0]
	check("Boss 初始阶段=0", boss.phase_index == 0, "phase_index=%d" % boss.phase_index)

	# 模拟被打到 25% 以下（scaled hp 150，25%≈37）
	var scaled_hp: int = GameData.scaled_enemy_hp(150)
	boss.hp = int(floor(scaled_hp * 0.24))
	# 清掉战斗开局可能抽到的蓄力(charge_next)，避免强制释放招式掩盖阶段计算
	boss.charge_next = &""
	cc._roll_enemy_intent(boss)

	check("进入觉醒阶段(on_enter 自身+3力量)", boss.has_status(&"heat") and boss.get_status(&"heat") >= 3,
		"heat=%d" % boss.get_status(&"heat"))
	check("觉醒阶段意图=aoe_debuff", String(boss.intent.get("intent", "")) == "aoe_debuff",
		"intent=%s" % str(boss.intent.get("intent", "")))

	var p_hp_before: int = boss.hp   # not used; track player
	var player_hp_before: int = cc.player.hp
	cc._execute_enemy_intent(boss)
	var expected := 6 + boss.get_status(&"heat")   # AOE6 + 自身力量加成
	check("觉醒 AOE 命中玩家（含力量加成=%d）" % expected,
		cc.player.hp == player_hp_before - expected,
		"player %d -> %d" % [player_hp_before, cc.player.hp])
	check("觉醒施加玩家 2 层易伤", cc.player.has_status(&"crazed") and cc.player.get_status(&"crazed") >= 2,
		"crazed=%d" % cc.player.get_status(&"crazed"))

	cc.queue_free()


# =====================================================================
# 4.2 多敌编成表落地
# =====================================================================
func _test_formations() -> void:
	check("编成表=9 组（P-D 新增按幕编成 F/G/H/I）", GameData.formations.size() == 9, "formations=%d" % GameData.formations.size())

	# 每组敌人必须存在
	for fm in GameData.formations:
		var ok := true
		for eid in fm.get("enemies", []):
			if GameData.get_enemy(StringName(eid)) == null:
				ok = false
		check("编成 %s 敌人引用有效" % fm.get("id", ""), ok, "")

	# 层门控：D（灰颂者+陶泥团）仅在 floor>=5
	var early := GameData.get_formations_for_floor(0)
	var late := GameData.get_formations_for_floor(7)
	check("教学层不含 D 编成", not _has_formation(early, "D"), "")
	check("后期层含 D 编成", _has_formation(late, "D"), "")

	# 编成抽选器返回的 id 必须命中某编成
	var picked := MapGenerator._weighted_formation(GameData.get_formations_for_floor(7))
	var valid := false
	for fm in GameData.get_formations_for_floor(7):
		if _same_ids(picked, fm.get("enemies", [])):
			valid = true
			break
	check("编成抽选返回合法编成", valid, "picked=%s" % str(picked))

	# 真实地图生成：所有多敌（≥2）战斗节点的敌人组合必须恰好匹配某编成（无随机野怪对）
	var bad := 0
	for i in 200:
		var floors: Array = MapGenerator.generate(GameData.map_config)
		for row in floors:
			for node in row:
				if node is MapNode and node.type == &"combat" and node.enemy_ids.size() >= 2:
					if not _matches_some_formation(node.enemy_ids):
						bad += 1
	check("200 张地图：多敌战斗节点均命中编成", bad == 0, "bad=%d" % bad)


func _has_formation(list: Array, fid: String) -> bool:
	for fm in list:
		if fm.get("id", "") == fid:
			return true
	return false


func _same_ids(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	# 不依赖排序（StringName 与 String 数组 sort 顺序可能不一致），改为成员包含比较
	for x in a:
		var found := false
		for y in b:
			if String(x) == String(y):
				found = true
				break
		if not found:
			return false
	return true


func _matches_some_formation(ids: Array) -> bool:
	for fm in GameData.formations:
		if _same_ids(ids, fm.get("enemies", [])):
			return true
	return false


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== P3 内容扩展验证（卡池/编成/Boss三阶段）=====")
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("P3_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
