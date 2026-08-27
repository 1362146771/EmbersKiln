extends Node
## 事件系统数据驱动验证：确认 GameData 已从 events.json 加载事件表，
## 结构合法（标题 + ≥2 选项），效果键合法，random_event / get_event 可用。
## （事件 UI 已在整局集成测试中随 event 节点进入而间接验证）

var results: Array[String] = []
var pass_count := 0
var fail_count := 0

const ALLOWED_EFFECT_KEYS := ["gold", "heal", "lose_hp", "add_card", "add_relic", "remove_card"]


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
	check("事件数量≥5（策划要求 4~5 个）", GameData.events.size() >= 5,
		"count=%d" % GameData.events.size())

	var all_well := true
	for ev in GameData.events:
		var title: String = ev.get("title", "")
		var opts: Array = ev.get("options", [])
		if title == "" or opts.size() < 2:
			all_well = false
			results.append("  [事件结构] %s 不合法" % title)
			continue
		for opt in opts:
			for key in opt.get("effects", {}).keys():
				if not (String(key) in ALLOWED_EFFECT_KEYS):
					all_well = false
					results.append("  [效果键] %s 含未知键 %s" % [title, key])
	check("全部事件结构合法(标题+≥2选项+效果键合法)", all_well)

	var ev := GameData.random_event()
	check("random_event 返回有效事件", not ev.is_empty() and ev.get("title", "") != "",
		"title=%s" % ev.get("title", ""))
	check("get_event(0) 可索引", not GameData.get_event(0).is_empty())


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== 事件数据驱动验证 =====")
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("EVENTS_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
