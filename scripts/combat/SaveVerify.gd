extends Node
## P4 存档读档验证：保存→变更→加载 全字段一致性，以及损坏/版本不匹配拒绝。
## 真跑（headless）后用 stdout 判定 SAVE_RESULT:PASS/FAIL。

const TEST_PATH := "user://save_verify_test.json"

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

	_test_roundtrip()
	_test_corrupt_rejected()
	_test_version_mismatch_rejected()
	_test_delete()

	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if detail != "" else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if detail != "" else ""])


# =====================================================================
# 4.1 存档读档往返一致性
# =====================================================================
func _test_roundtrip() -> void:
	if not RunState.start_new_run():
		check("开局用于存档验证", false, "start_new_run 失败")
		return

	# 制造有代表性的运行态（直接改字段，避免触发自动存档信号）
	RunState.hp = RunState.max_hp - 25
	RunState.gold = RunState.gold + 40
	RunState.current_floor = 3
	RunState.current_node_type = &"elite"
	if RunState.deck.size() > 0:
		RunState.deck[0]["upgraded"] = true
	if RunState.current_map().size() > 0 and RunState.current_map()[0].size() > 0:
		RunState.current_map()[0][0].visited = true

	# 快照前置状态
	var pre := {
		"max_hp": RunState.max_hp,
		"hp": RunState.hp,
		"gold": RunState.gold,
		"current_floor": RunState.current_floor,
		"current_node_type": String(RunState.current_node_type),
		"victory": RunState.victory,
		"is_active": RunState.is_active,
		"deck": _deck_sig(RunState.deck),
		"relic_ids": _str_arr(RunState.relic_ids),
		"defeated": _str_arr(RunState.defeated),
		"map": _map_sig(RunState.current_map()),
	}

	var saved := SaveManager.save_to_file(TEST_PATH)
	check("存档写入成功", saved, "")

	# 清空运行态
	RunState.is_active = false
	RunState.hp = 0
	RunState.max_hp = 0
	RunState.gold = 0
	RunState.current_floor = 0
	RunState.current_node_type = &""
	RunState.victory = false
	RunState.deck.clear()
	RunState.relic_ids.clear()
	RunState.defeated.clear()
	RunState.current_map().clear()

	# 读取并还原
	var d := SaveManager.load_from_file(TEST_PATH)
	check("读档解析成功", not d.is_empty(), "")
	if d.is_empty():
		return
	var restored := RunState.from_save_dict(d)
	check("from_save_dict 还原成功", restored, "")

	# 逐字段比对
	check("HP 一致", RunState.hp == pre["hp"], "%d vs %d" % [RunState.hp, pre["hp"]])
	check("max_hp 一致", RunState.max_hp == pre["max_hp"], "%d vs %d" % [RunState.max_hp, pre["max_hp"]])
	check("金币 一致", RunState.gold == pre["gold"], "%d vs %d" % [RunState.gold, pre["gold"]])
	check("当前层 一致", RunState.current_floor == pre["current_floor"], "%d vs %d" % [RunState.current_floor, pre["current_floor"]])
	check("当前层类型 一致", String(RunState.current_node_type) == pre["current_node_type"], "%s vs %s" % [RunState.current_node_type, pre["current_node_type"]])
	check("胜负标记 一致", RunState.victory == pre["victory"], "")
	check("is_active 一致", RunState.is_active == pre["is_active"], "")
	check("牌组 一致", _deck_sig(RunState.deck) == pre["deck"], "%s vs %s" % [_deck_sig(RunState.deck), pre["deck"]])
	check("遗物 一致", _str_arr(RunState.relic_ids) == pre["relic_ids"], "%s vs %s" % [_str_arr(RunState.relic_ids), pre["relic_ids"]])
	check("已击败 一致", _str_arr(RunState.defeated) == pre["defeated"], "")
	check("地图结构 一致", _map_sig(RunState.current_map()) == pre["map"], "%s vs %s" % [_map_sig(RunState.current_map()), pre["map"]])


# =====================================================================
# 4.2 损坏存档被拒绝
# =====================================================================
func _test_corrupt_rejected() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_line("{ this is not valid json ,,, }")
		f.close()
	var d := SaveManager.load_from_file(TEST_PATH)
	check("损坏 JSON 被拒绝（返回空）", d.is_empty(), "")
	var before_hp := RunState.hp
	var ok := RunState.from_save_dict(d)
	check("损坏数据 from_save_dict 返回 false", not ok, "")
	check("损坏数据未污染运行态", RunState.hp == before_hp, "")


# =====================================================================
# 4.3 版本不匹配被拒绝
# =====================================================================
func _test_version_mismatch_rejected() -> void:
	var bad := {"version": 999, "deck": []}
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_line(JSON.stringify(bad))
		f.close()
	var d := SaveManager.load_from_file(TEST_PATH)
	check("版本不匹配档案可解析", not d.is_empty(), "")
	var ok := RunState.from_save_dict(d)
	check("版本不匹配 from_save_dict 返回 false", not ok, "version=%d" % int(d.get("version", -1)))


# =====================================================================
# 4.4 删档
# =====================================================================
func _test_delete() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if f != null:
		f.store_line(JSON.stringify({"version": 1}))
		f.close()
	check("删档前文件存在", FileAccess.file_exists(TEST_PATH), "")
	# 复用 SaveManager 的 user:// 删除逻辑（TEST_PATH 同目录）
	var da := DirAccess.open("user://")
	if da != null:
		da.remove(TEST_PATH.get_file())
	check("删档后文件消失", not FileAccess.file_exists(TEST_PATH), "")
	# 清理真实存档位（防止 headless 残留干扰）
	SaveManager.delete_save()


# ---------- 序列化辅助 ----------
func _str_arr(a: Array) -> String:
	var out := PackedStringArray()
	for x in a:
		out.append(String(x))
	out.sort()
	return ",".join(out)


func _deck_sig(deck: Array) -> String:
	var parts := PackedStringArray()
	for c in deck:
		parts.append("%s:%s" % [String(c["id"]), "1" if bool(c.get("upgraded", false)) else "0"])
	parts.sort()
	return ";".join(parts)


func _map_sig(map: Array) -> String:
	var lines := PackedStringArray()
	for row in map:
		var nodes := PackedStringArray()
		for node in row:
			if node is MapNode:
				var eids: PackedStringArray = []
				for e in node.enemy_ids:
					eids.append(String(e))
				eids.sort()
				nodes.append("%d.%d.%s.[%s].l%s.%s" % [
					node.floor, node.index, String(node.type),
					",".join(eids), _links_str(node.links), "1" if node.visited else "0"])
		lines.append("[%s]" % ";".join(nodes))
	return "|".join(lines)


func _links_str(links: Array) -> String:
	var out := PackedStringArray()
	for l in links:
		out.append(str(int(l)))
	out.sort()
	return ",".join(out)


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== P4 存档读档验证 =====")
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("SAVE_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
