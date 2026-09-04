extends Node
## 事件系统数据驱动验证：确认 GameData 已从 events.json 加载事件表，
## 结构合法（标题 + ≥2 选项），效果键合法，random_event / get_event 可用。
## （事件 UI 已在整局集成测试中随 event 节点进入而间接验证）

var results: Array[String] = []
var pass_count := 0
var fail_count := 0

const ALLOWED_EFFECT_KEYS := ["gold", "heal", "lose_hp", "add_card", "add_relic", "remove_card", "add_potion", "add_enchant"]


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
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
	check("GameData 已加载事件表", GameData.is_loaded and not GameData.events.is_empty(),
		"events=%d" % GameData.events.size())
	check("事件数量=15（扩充目标）", GameData.events.size() == 15,
		"count=%d" % GameData.events.size())

	var all_well := true
	var ids: Dictionary = {}
	for ev in GameData.events:
		var event_id: String = ev.get("id", "")
		var title: String = ev.get("title", "")
		var description: String = ev.get("desc", "")
		var acts: Array = ev.get("acts", [])
		var opts: Array = ev.get("options", [])
		if event_id == "" or ids.has(event_id) or title == "" or description == "" or acts.is_empty() or opts.size() < 2:
			all_well = false
			results.append("  [事件结构] %s 不合法" % title)
			continue
		ids[event_id] = true
		for act_no in acts:
			if int(act_no) < 1 or int(act_no) > 3:
				all_well = false
				results.append("  [幕号] %s 含无效幕号 %s" % [title, act_no])
		for opt in opts:
			for key in opt.get("effects", {}).keys():
				if not (String(key) in ALLOWED_EFFECT_KEYS):
					all_well = false
					results.append("  [效果键] %s 含未知键 %s" % [title, key])
	check("全部事件结构合法(id/标题/正文/幕池/≥2选项/效果键)", all_well)

	var pools_well := true
	for act_number in range(1, 4):
		var pool := GameData.events_for_act(act_number)
		if pool.size() != 7:
			pools_well = false
			results.append("  [幕池] 第%d幕事件数=%d，期望 7" % [act_number, pool.size()])
		for event_data in pool:
			var declared_for_act := false
			for configured_act in event_data.get("acts", []):
				if int(configured_act) == act_number:
					declared_for_act = true
					break
			if not declared_for_act:
				pools_well = false
	check("三幕事件池各含 7 个候选事件", pools_well)

	var random_well := true
	for act_number in range(1, 4):
		var act_pool := GameData.events_for_act(act_number)
		for _sample in 50:
			var ev := GameData.random_event(act_number)
			if ev.is_empty() or not act_pool.has(ev):
				random_well = false
				break
	check("random_event 始终遵守分幕事件池", random_well)
	check("get_event(0) 可索引", not GameData.get_event(0).is_empty())


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== 事件数据驱动验证 =====")
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("EVENTS_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
