extends Node
## 地图自动定位专项。隔离自动存档，仅改变测试进程内存，不改变地图配置。

const MapScene := preload("res://scenes/map/MapPlay.tscn")
var passed := 0
var failed := 0
var visual := false
var completed := false


func _ready() -> void:
	for sig in [SignalBus.combat_ended, SignalBus.floor_entered, SignalBus.act_changed, SignalBus.run_ended]:
		for connection in sig.get_connections():
			if connection.callable.get_object() == SaveManager:
				sig.disconnect(connection.callable)
	visual = OS.get_cmdline_user_args().has("--visual")
	await frames()
	await verify()
	check("all map focus scenarios completed", completed)
	print("MAP_PLAYER_FOCUS_RESULT:%s PASS=%d FAIL=%d" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func check(title: String, ok: bool) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", title])


func frames(count: int = 5) -> void:
	for i in count:
		await get_tree().process_frame


func choose_path(floor_index: int) -> void:
	var map := RunState.current_map()
	for row in map:
		for node in row:
			node.visited = false
	var index := 0
	for floor in range(floor_index + 1):
		var node: MapNode = map[floor][index]
		node.visited = true
		RunState.current_node_type = node.type
		if not node.links.is_empty():
			index = node.links[0]
	RunState.current_floor = maxi(0, floor_index)


func focused(ui: Control) -> bool:
	var scroll: ScrollContainer = ui.map_area.get_parent()
	var floor: int = clampi(RunState.current_floor, 0, ui.chosen.size() - 1)
	var index: int = maxi(0, ui.chosen[floor])
	var point: Vector2 = ui.node_pos["%d_%d" % [floor, index]]
	var bar := scroll.get_v_scroll_bar()
	var expected: int = roundi(clampf(point.y - bar.page * 0.5, 0.0, maxf(0.0, bar.max_value - bar.page)))
	return absi(scroll.scroll_vertical - expected) <= 1


func close_map(ui: Control) -> void:
	ui.queue_free()
	await frames()


func verify() -> void:
	RunState.start_new_run()
	var ui = MapScene.instantiate()
	add_child(ui)
	await frames()
	check("new run opens at starting floor, not Boss", focused(ui) and ui.map_area.get_parent().scroll_vertical > 0)
	if visual:
		await capture("new_run")
	await close_map(ui)
	for act in RunState.act_maps.size():
		RunState.current_act = act
		var floors := RunState.current_map().size()
		for floor in [0, floors / 2, floors - 1]:
			choose_path(int(floor))
			var state_before := RunState.to_save_dict()
			ui = MapScene.instantiate()
			add_child(ui)
			await frames()
			check("Act%d floor%d centers player with boundary clamp" % [act + 1, floor], focused(ui))
			check("focus is presentation only", RunState.to_save_dict() == state_before)
			await close_map(ui)
	RunState.start_new_run()
	choose_path(RunState.current_map().size() / 2)
	var save := RunState.to_save_dict()
	RunState.current_floor = 0
	check("resume fixture reloads", RunState.from_save_dict(save))
	ui = MapScene.instantiate()
	add_child(ui)
	await frames()
	check("resumed run focuses saved player floor", focused(ui))
	if visual:
		await capture("middle")
	var scroll: ScrollContainer = ui.map_area.get_parent()
	scroll.scroll_vertical = 0
	await frames(12)
	check("manual scrolling is not continuously overridden", scroll.scroll_vertical == 0)
	ui.start_new_map()
	await frames()
	check("rebuilding current map focuses player again", focused(ui))
	await close_map(ui)
	# 非战斗回程与奖励回程的真实 _ready 分支，点击继续后仍定位正确。
	for mode in ["node", "reward"]:
		RunState.pending_node_resolved = mode == "node"
		RunState.pending_post_reward = mode == "reward"
		RunState.current_node_type = &"combat" if mode == "reward" else &"shop"
		ui = MapScene.instantiate()
		add_child(ui)
		await frames()
		check(mode + " return focuses beneath continue panel", focused(ui))
		var overlay: Control = ui.get_child(ui.get_child_count() - 1)
		ui._on_continue(overlay)
		await frames()
		check(mode + " continue reveals player position", focused(ui))
		if visual and mode == "reward":
			await capture("reward_return")
		await close_map(ui)
	# 奖励回程时先重建旧幕再 advance_act；进入新幕后不能应用旧幕的延迟定位。
	RunState.current_act = 0
	choose_path(RunState.current_map().size() - 1)
	RunState.current_node_type = &"boss"
	RunState.pending_post_reward = true
	ui = MapScene.instantiate()
	add_child(ui)
	check("boss reward advances act", RunState.current_act == 1 and RunState.current_floor == 0)
	var transition: Control = ui.get_child(ui.get_child_count() - 1)
	ui._on_enter_act(transition)
	await frames()
	check("entering next act focuses new starting floor", focused(ui) and ui.map_area.get_parent().scroll_vertical > 0)
	if visual:
		await capture("next_act")
	# 同一帧连续重建，以最后一次状态为准。
	choose_path(RunState.current_map().size() - 1)
	ui.start_new_map()
	choose_path(0)
	ui.start_new_map()
	await frames()
	check("rapid rebuild uses newest player position", focused(ui))
	await close_map(ui)
	# 地图短于可视区时，滚动值保持零，不使用负数。
	var original: Array = RunState.act_maps[RunState.current_act]
	RunState.act_maps[RunState.current_act] = original.slice(0, 2)
	choose_path(0)
	ui = MapScene.instantiate()
	add_child(ui)
	await frames()
	check("short map clamps scroll to zero", ui.map_area.get_parent().scroll_vertical == 0)
	await close_map(ui)
	RunState.act_maps[RunState.current_act] = original
	# 创建后立刻移出树，延迟任务不得访问已离树场景。
	ui = MapScene.instantiate()
	add_child(ui)
	remove_child(ui)
	await frames()
	ui.free()
	check("leaving before deferred focus is safe", true)
	await verify_combat_return()
	completed = true


func verify_combat_return() -> void:
	RunState.start_new_run()
	choose_path(RunState.current_map().size() / 2)
	RunState.current_node_type = &"combat"
	RunState.pending_combat_enemy_ids = ["claylump"]
	var tree := get_tree()
	var combat = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	tree.root.add_child(combat)
	tree.current_scene = combat
	combat._on_combat_end(true)
	await tree.scene_changed
	# MapPlay 战后回程会立即转奖励页，期间的延迟定位必须安全退出。
	if tree.current_scene.scene_file_path == "res://scenes/map/MapPlay.tscn":
		await tree.scene_changed
	var reward := tree.current_scene
	check("combat return reaches reward scene", reward.scene_file_path == "res://scenes/rewards/RewardUI.tscn")
	reward._on_skip()
	await tree.scene_changed
	var ui := tree.current_scene
	await frames()
	check("actual combat reward return centers player", focused(ui))
	ui._on_continue(ui.get_child(ui.get_child_count() - 1))
	await frames()
	check("actual continue keeps player centered", focused(ui))
	if visual:
		await capture("combat_return")
	tree.current_scene = self
	tree.root.remove_child(ui)
	ui.queue_free()
	await frames()


func capture(title: String) -> void:
	await RenderingServer.frame_post_draw
	check("capture " + title, get_viewport().get_texture().get_image().save_png("res://logs/map_player_focus_" + title + ".png") == OK)
