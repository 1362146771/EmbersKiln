extends Node
## 多幕扩展验证套件（P-A~P-E 全层）：3 幕生成 / advance_act 推进与幕间回血 /
## 幕间继承与状态重置 / act_changed 自动存档 / 幕缩放与敌池隔离 / 各幕 Boss /
## 终幕 end_run / v2 多幕存档全字段往返 / v1 旧档拒绝。
## 真跑（headless）后判定 ACT_RESULT:PASS/FAIL。

const TEST_PATH := "user://act_verify_test.json"

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

	_test_generation()
	_test_advance_and_heal()
	_test_inheritance_and_state()
	_test_act_changed_saves()
	_test_act_scaling_and_pools()
	_test_last_act_ends_run()
	_test_v2_roundtrip()
	_test_v1_rejected()
	SaveManager.delete_save()

	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if detail != "" else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if detail != "" else ""])


func _test_generation() -> void:
	RunState.start_new_run()
	check("开局生成 3 幕", RunState.act_maps.size() == 3, "acts=%d" % RunState.act_maps.size())
	check("开局 current_act=0", RunState.current_act == 0, "cur=%d" % RunState.current_act)
	check("Act1 层数=floor_count", RunState.current_map().size() == int(GameData.act_configs[0].get("floor_count", 15)), "floors=%d" % RunState.current_map().size())
	check("开局非终幕", not RunState.is_last_act(), "")
	check("每幕 floor_count 正确",
		RunState.act_maps[0].size() == int(GameData.act_configs[0].get("floor_count", 15)) and RunState.act_maps[1].size() == int(GameData.act_configs[1].get("floor_count", 15)) and RunState.act_maps[2].size() == int(GameData.act_configs[2].get("floor_count", 15)),
		"%d/%d/%d" % [RunState.act_maps[0].size(), RunState.act_maps[1].size(), RunState.act_maps[2].size()])
	check("每幕末层为 Boss",
		RunState.act_maps[0][-1][0].type == &"boss" and RunState.act_maps[1][-1][0].type == &"boss" and RunState.act_maps[2][-1][0].type == &"boss",
		"")


func _test_advance_and_heal() -> void:
	RunState.start_new_run()
	var mh: int = RunState.max_hp
	# 模拟 Act1 受创后进入 Act2：应回 30%
	RunState.hp = mh - 30
	RunState.advance_act()
	check("advance_act -> current_act=1", RunState.current_act == 1, "cur=%d" % RunState.current_act)
	check("Act1 标记通关", RunState.act_cleared_flags[0] == true, "")
	check("Act2 层数=floor_count", RunState.current_map().size() == int(GameData.act_configs[1].get("floor_count", 15)), "floors=%d" % RunState.current_map().size())
	var expect2: int = mini(mh, (mh - 30) + int(round(mh * 0.30)))
	check("Act2 进场回血 30%%", RunState.hp == expect2, "hp=%d expect=%d" % [RunState.hp, expect2])

	# 进入 Act3：应回 20%
	RunState.hp = mh - 50
	RunState.advance_act()
	check("advance_act -> current_act=2", RunState.current_act == 2, "cur=%d" % RunState.current_act)
	check("Act3 层数=floor_count", RunState.current_map().size() == int(GameData.act_configs[2].get("floor_count", 15)), "floors=%d" % RunState.current_map().size())
	var expect3: int = mini(mh, (mh - 50) + int(round(mh * 0.20)))
	check("Act3 进场回血 20%%", RunState.hp == expect3, "hp=%d expect=%d" % [RunState.hp, expect3])


## P-E：幕间继承一致 + 层数重置 + 非终幕推进不结束整局（设计稿 §7.1/7.3/7.4）。
func _test_inheritance_and_state() -> void:
	RunState.start_new_run()
	# 构造一些局内进度：加一张牌、一个遗物、一些金币，再跨幕
	RunState.add_card(&"strike", true)
	var pre_deck: int = RunState.deck.size()
	var pre_gold: int = RunState.gold + 77
	RunState.gold = pre_gold
	var pre_relics: int = RunState.relic_ids.size()
	RunState.current_floor = 5
	RunState.current_node_type = &"elite"

	RunState.advance_act()   # 非终幕推进
	check("幕间继承：牌组不变", RunState.deck.size() == pre_deck, "%d vs %d" % [RunState.deck.size(), pre_deck])
	check("幕间继承：金币不变", RunState.gold == pre_gold, "%d vs %d" % [RunState.gold, pre_gold])
	check("幕间继承：遗物不变", RunState.relic_ids.size() == pre_relics, "%d vs %d" % [RunState.relic_ids.size(), pre_relics])
	check("幕间层数重置 current_floor=0", RunState.current_floor == 0, "floor=%d" % RunState.current_floor)
	check("幕间节点类型清空", RunState.current_node_type == &"", "type=%s" % RunState.current_node_type)
	check("非终幕推进：整局仍在进行", RunState.is_active and not RunState.victory,
		"active=%s vic=%s" % [RunState.is_active, RunState.victory])


## P-C：advance_act 经由 SignalBus.act_changed 自动存档。
## 验证：开局瞬间不应误存（act_changed(0) 时 is_active 尚未 true）；
## 进入新幕后存档存在且 current_act/HP 与幕间回血后一致。
func _test_act_changed_saves() -> void:
	SaveManager.delete_save()
	check("P-C 起点无存档", not SaveManager.has_save(), "")

	RunState.start_new_run()   # 触发 act_changed(0)，但 is_active 尚未 true
	check("开局瞬间未误存档(act_changed(0))", not SaveManager.has_save(), "")

	RunState.hp = RunState.max_hp - 40
	RunState.advance_act()      # 非终幕 -> act_changed(1) -> SaveManager 自动存档
	check("advance_act 触发自动存档", SaveManager.has_save(), "")

	var d := SaveManager.load_from_file(SaveManager.SAVE_PATH)
	check("自动存档 current_act=1", int(d.get("current_act", -1)) == 1, "act=%d" % int(d.get("current_act", -1)))
	var expect_hp: int = mini(RunState.max_hp, (RunState.max_hp - 40) + int(round(RunState.max_hp * 0.30)))
	check("自动存档 HP=幕间回血后", int(d.get("hp", -1)) == expect_hp,
		"saved_hp=%d expect=%d" % [int(d.get("hp", -1)), expect_hp])


## P-D：幕缩放系数生效 + 敌池隔离 + 各幕 Boss 指定 + 新敌加载。
func _test_act_scaling_and_pools() -> void:
	# 新敌人加载（9 个：6 普通 + 2 精英 + 1 Boss）
	var new_ids: Array = [&"kilnwarden", &"cindermoth", &"meltgolem", &"kiln_captain",
		&"cinderfiend", &"magmawhelp", &"coalseer", &"ember_eater", &"kilnheart_ember"]
	var loaded := true
	for nid in new_ids:
		if GameData.get_enemy(nid) == null:
			loaded = false
	check("P-D 新敌人全部加载(9)", loaded, "")

	RunState.start_new_run()
	# Act1：乘子 1.0，缩放=基础
	check("Act1 HP 缩放=基础", GameData.scaled_enemy_hp(100) == 100, "scaled=%d" % GameData.scaled_enemy_hp(100))
	check("Act1 伤害缩放=基础", GameData.scaled_enemy_damage(10) == 10, "scaled=%d" % GameData.scaled_enemy_damage(10))
	_check_pool_isolation(0)
	check("Act1 Boss=封窑兽·匣母", _act_boss_id(0) == "sagger_matron", "boss=%s" % _act_boss_id(0))

	RunState.advance_act()   # → Act2（×1.15）
	check("Act2 HP 缩放×1.15", GameData.scaled_enemy_hp(100) == 115, "scaled=%d" % GameData.scaled_enemy_hp(100))
	check("Act2 伤害缩放×1.15", GameData.scaled_enemy_damage(20) == 23, "scaled=%d" % GameData.scaled_enemy_damage(20))
	_check_pool_isolation(1)
	check("Act2 Boss=窑心·烬", _act_boss_id(1) == "kilnheart_ember", "boss=%s" % _act_boss_id(1))

	RunState.advance_act()   # → Act3（×1.30）
	check("Act3 HP 缩放×1.30", GameData.scaled_enemy_hp(100) == 130, "scaled=%d" % GameData.scaled_enemy_hp(100))
	check("Act3 伤害缩放×1.30", GameData.scaled_enemy_damage(10) == 13, "scaled=%d" % GameData.scaled_enemy_damage(10))
	_check_pool_isolation(2)
	check("Act3 Boss=窑主·熾", _act_boss_id(2) == "chi_the_first", "boss=%s" % _act_boss_id(2))


## 校验指定幕地图内所有 combat/elite 节点的敌人都落在该幕 enemy_pool 内。
func _check_pool_isolation(act_idx: int) -> void:
	var cfg: Dictionary = GameData.act_configs[act_idx]
	var pool: Dictionary = cfg.get("enemy_pool", {})
	var normal_pool: Array = pool.get("normal", [])
	var elite_pool: Array = pool.get("elite", [])
	var ok := true
	for row in RunState.act_maps[act_idx]:
		for node in row:
			if node.type == &"combat":
				for eid in node.enemy_ids:
					if not normal_pool.has(String(eid)):
						ok = false
			elif node.type == &"elite":
				for eid in node.enemy_ids:
					if not elite_pool.has(String(eid)):
						ok = false
	check("Act%d 敌池隔离" % (act_idx + 1), ok, "")


## 取指定幕末层（Boss 层）首节点的敌人 id（String）。
func _act_boss_id(act_idx: int) -> String:
	var boss_row: Array = RunState.act_maps[act_idx][-1]
	if boss_row.is_empty() or boss_row[0].enemy_ids.is_empty():
		return ""
	return String(boss_row[0].enemy_ids[0])


func _test_last_act_ends_run() -> void:
	RunState.start_new_run()
	RunState.advance_act()   # -> act1
	RunState.advance_act()   # -> act2 (last)
	check("进入终幕前为终幕", RunState.is_last_act(), "")
	RunState.advance_act()   # act2 是最后一幕 -> end_run(true)
	check("终幕 advance_act 触发 end_run", not RunState.is_active and RunState.victory, "active=%s vic=%s" % [RunState.is_active, RunState.victory])


func _test_v2_roundtrip() -> void:
	RunState.start_new_run()
	RunState.hp = RunState.max_hp - 17
	RunState.gold += 33
	RunState.current_floor = 4
	RunState.current_node_type = &"elite"
	RunState.advance_act()   # 进 Act2，current_act=1
	var pre_act: int = RunState.current_act
	var pre_maps: int = RunState.act_maps.size()
	var pre_hp: int = RunState.hp

	var saved := SaveManager.save_to_file(TEST_PATH)
	check("v2 存档写入成功", saved, "")

	# 破坏内存
	RunState.is_active = false
	RunState.act_maps.clear()
	RunState.current_act = 0
	RunState.hp = 0

	var d := SaveManager.load_from_file(TEST_PATH)
	check("v2 读档可解析", not d.is_empty(), "")
	check("v2 含 act_maps 字段", d.has("act_maps") and d.has("current_act"), "")
	var ok := RunState.from_save_dict(d)
	check("v2 from_save_dict 还原成功", ok, "")
	check("v2 current_act 一致", RunState.current_act == pre_act, "%d vs %d" % [RunState.current_act, pre_act])
	check("v2 act_maps 幕数一致", RunState.act_maps.size() == pre_maps, "%d vs %d" % [RunState.act_maps.size(), pre_maps])
	check("v2 各幕层数一致",
		RunState.act_maps[0].size() == int(GameData.act_configs[0].get("floor_count", 15)) and RunState.act_maps[1].size() == int(GameData.act_configs[1].get("floor_count", 15)) and RunState.act_maps[2].size() == int(GameData.act_configs[2].get("floor_count", 15)),
		"%d/%d/%d" % [RunState.act_maps[0].size(), RunState.act_maps[1].size(), RunState.act_maps[2].size()])
	check("v2 HP 一致", RunState.hp == pre_hp, "%d vs %d" % [RunState.hp, pre_hp])


func _test_v1_rejected() -> void:
	var bad := {"version": 1, "deck": []}
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_line(JSON.stringify(bad))
		f.close()
	var d := SaveManager.load_from_file(TEST_PATH)
	check("v1 档案可解析", not d.is_empty(), "")
	var ok := RunState.from_save_dict(d)
	check("v1 from_save_dict 返回 false（拒绝）", not ok, "version=%d" % int(d.get("version", -1)))


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== 多幕扩展验证（P-A~P-E 全层）=====")
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("ACT_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
