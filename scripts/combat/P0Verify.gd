extends Node2D
## P0 集成验证：不依赖点击，直接构建奖励界面与多敌战斗 UI 并断言正确性。
## 覆盖 RelicTest 未触及的纯构建路径（奖励生成逻辑、RewardUI 构建、多敌 CombatUI 构建）。

const RewardUIScript := preload("res://scripts/rewards/RewardUI.gd")
const CombatUIScript := preload("res://scripts/combat/CombatUI.gd")

var pc := 0
var fc := 0


func _ready() -> void:
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/p0_verify_save.json"
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	check("新局: 遗物库存为空", RunState.relic_ids.is_empty())
	verify_reward_builder()
	verify_reward_ui()
	await verify_multi_enemy_ui()
	await verify_scene_relic_bar()
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
	rw.queue_free()


func verify_multi_enemy_ui() -> void:
	var cu = CombatUIScript.new()
	cu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	await verify_relic_bar(cu, ".new()")
	cu.queue_free()
	await get_tree().process_frame


func verify_scene_relic_bar() -> void:
	# 前一路径积累的遗物模拟读档 / 从地图继承库存，不依赖再次获得信号。
	var before := SignalBus.relic_gained.get_connections().size()
	var cu = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(cu)
	await get_tree().process_frame
	await verify_relic_bar(cu, ".tscn")
	cu.queue_free()
	await get_tree().process_frame
	check("遗物栏: 离开战斗断开库存信号", SignalBus.relic_gained.get_connections().size() == before)


func verify_relic_bar(cu: CombatUI, path: String) -> void:
	var bar = cu.relic_bar
	var expected_slots := RunState.relic_ids.size()  # 空库存不创建占位。
	check("遗物栏 %s: 初始库存一致" % path, bar != null and bar.slots.get_child_count() == expected_slots)
	if bar == null:
		return
	if RunState.relic_ids.is_empty():
		check("遗物栏 %s: 新局无边框与占位" % path, bar.get_theme_stylebox("panel") is StyleBoxEmpty and bar.slots.get_child_count() == 0 and not bar.has_node("Row/Caption"))
		RunState.add_relic(&"hearth_totem")
	var first: Button = bar.slots.get_child(0)
	var displayed: RelicData = GameData.get_relic(StringName(first.get_meta("relic_id")))
	check("遗物栏 %s: 名称与说明来自数据" % path, first.tooltip_text == "%s\n%s" % [displayed.name, displayed.description])
	var hp := RunState.hp
	var energy := cu.controller.energy
	first.pressed.emit()
	check("遗物栏 %s: 点击打开正确说明" % path, bar.details.visible and bar.detail_name.text == displayed.name and bar.detail_description.text == displayed.description)
	bar.close_button.pressed.emit()
	check("遗物栏 %s: 关闭且不改变战斗资源" % path, not bar.details.visible and RunState.hp == hp and cu.controller.energy == energy)
	for rid in GameData.relics:
		RunState.add_relic(rid)
	check("遗物栏 %s: 获得后实时刷新" % path, bar.slots.get_child_count() == RunState.relic_ids.size())
	RunState.add_relic(&"emberheart")
	check("遗物栏 %s: 重复获得不增槽" % path, bar.slots.get_child_count() == GameData.relics.size())
	# 使用现行遗物临时模拟缺图，验证占位路径不依赖退役内容。
	var fixture: RelicData = GameData.get_relic(RunState.relic_ids.back())
	var original_icon := fixture.icon
	fixture.icon = "ICO_Relic_MissingForVerify"
	bar.refresh()
	var missing: Button = bar.slots.get_node(String(fixture.id))
	check("遗物栏 %s: 缺图显示名称占位" % path, missing.text.replace("\n", "") == fixture.name)
	missing.pressed.emit()
	check("遗物栏 %s: 缺图仍可查看完整说明" % path, bar.details.visible and not bar.detail_icon.visible and bar.detail_description.text == fixture.description)
	fixture.icon = original_icon
	bar.hide_details()
	await get_tree().process_frame
	await get_tree().process_frame
	check("遗物栏 %s: 多遗物滚动且不撑宽" % path, bar.slots.size.x > bar.scroll.size.x and bar.size.x < get_viewport_rect().size.x)
	bar.scroll.ensure_control_visible(missing)
	await get_tree().process_frame
	check("遗物栏 %s: 可滚动到最后一个遗物" % path, bar.scroll.scroll_horizontal > 0 and bar.scroll.get_global_rect().intersects(missing.get_global_rect()))
	var potions: Control = cu.get_node("Safe/Layout/PotionBar")
	check("遗物栏 %s: 顶部药水右侧且不被透明敌人面板覆盖" % path,
		bar.global_position.x >= potions.get_global_rect().end.x
		and bar.global_position.y >= 0 and bar.global_position.y <= 8
		and bar.get_global_rect().end.y <= 100
		and bar.get_parent().get_index() > cu.enemy_area.get_index()
		and get_viewport_rect().encloses(bar.get_global_rect()))
	var saved: Array[StringName] = RunState.relic_ids.duplicate()
	RunState.relic_ids.clear()
	bar.refresh()
	check("遗物栏 %s: 空库存无占位与残留" % path, bar.slots.get_child_count() == 0)
	RunState.relic_ids.assign(saved)
	bar.refresh()


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
	await preload("res://scripts/verify/CombatRegressionSupport.gd").finish(get_tree(), 0 if fc == 0 else 1)
