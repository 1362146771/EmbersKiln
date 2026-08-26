extends Node2D
## P0 集成验证：不依赖点击，直接构建奖励界面与多敌战斗 UI 并断言正确性。
## 覆盖 RelicTest 未触及的纯构建路径（奖励生成逻辑、RewardUI 构建、多敌 CombatUI 构建）。

const RewardUIScript := preload("res://scripts/rewards/RewardUI.gd")
const CombatUIScript := preload("res://scripts/combat/CombatUI.gd")

var pc := 0
var fc := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	RunState.start_new_run()
	verify_reward_builder()
	verify_reward_ui()
	await verify_multi_enemy_ui()
	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pc += 1
		print("[PASS] %s%s" % [name, (" — " + detail) if detail != "" else ""])
	else:
		fc += 1
		print("[FAIL] %s%s" % [name, (" — " + detail) if detail != "" else ""])


func verify_reward_builder() -> void:
	var cards := RewardBuilder.roll_card_choices(3)
	check("奖励: 三选一卡牌=3", cards.size() == 3, "n=%d" % cards.size())
	var ok := true
	for c in cards:
		if not c.has("id") or not c.has("name") or not c.has("desc"):
			ok = false
	check("奖励: 卡牌字段完整", ok)

	var g := RewardBuilder.roll_gold(&"combat")
	check("奖励: 普通金币在[10,20]", g >= 10 and g <= 20, "gold=%d" % g)

	var r := RewardBuilder.roll_relic(&"elite")
	if r != &"":
		check("奖励: 精英遗物有效", GameData.get_relic(r) != null, "relic=%s" % r)
	else:
		check("奖励: 精英遗物有效", true, "（无可给遗物，跳过）")


func verify_reward_ui() -> void:
	var cards := RewardBuilder.roll_card_choices(3)
	var data := {"tier": &"elite", "gold": 30, "relic_id": &"emberheart", "cards": cards}
	var rw = RewardUIScript.new()
	rw.setup(data, _noop)
	add_child(rw)  # 触发 _ready -> _build_main
	check(" RewardUI: 构建出子节点", rw.get_child_count() > 0, "children=%d" % rw.get_child_count())
	# 应含“战利品”标题
	var found := false
	for c in rw.get_children():
		found = _find_label_text(c, "战  利  品") or found
	check(" RewardUI: 含「战利品」标题", found)


func verify_multi_enemy_ui() -> void:
	var cu = CombatUIScript.new()
	cu.pending_enemy_ids = ["claylump", "sootling"]
	add_child(cu)  # _ready -> start_combat -> _refresh_enemy
	check("多敌UI: 生成 2 个敌人", cu.controller.enemies.size() == 2, "n=%d" % cu.controller.enemies.size())
	# 等一帧让 queue_free 的旧面板真正移除，再统计当前面板数
	await get_tree().process_frame
	var area: HBoxContainer = cu.enemy_area
	if area != null:
		check("多敌UI: 敌人区渲染 2 面板", area.get_child_count() == 2, "panels=%d" % area.get_child_count())
	else:
		check("多敌UI: 敌人区渲染 2 面板", false, "enemy_area 缺失")


func _noop() -> void:
	pass


func _find_label_text(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text == needle:
		return true
	for c in node.get_children():
		if _find_label_text(c, needle):
			return true
	return false


func _print_report() -> void:
	print("[P0Verify] PASS=%d FAIL=%d" % [pc, fc])
	print("[P0Verify] RESULT=" + ("PASS" if fc == 0 else "FAIL"))
