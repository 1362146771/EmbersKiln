extends Node
## 三幕 Boss 徽记、布局边界与真实点击进入战斗的集成检查。
var failed := 0

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--visual"):
		get_tree().root.size = Vector2i(1080, 1920)
	await frames()
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/boss_map_verify_save.json"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/map/bosses/manifest.json"))
	for act in 3:
		RunState.start_new_run()
		RunState.pre_run_preparation_resolved = true
		RunState.current_act = act
		var rows := RunState.current_map()
		var index := 0
		for floor in range(rows.size() - 1):
			var node: MapNode = rows[floor][index]
			node.visited = true
			index = node.links[0]
		RunState.current_floor = rows.size() - 2
		var boss: MapNode = rows.back()[0]
		var ui = load("res://scenes/map/MapPlay.tscn").instantiate()
		get_tree().root.add_child(ui)
		get_tree().current_scene = ui
		await frames()
		ui.map_scroller.scroll_vertical = 0
		await frames()
		check(not ui.map_scroller.get_v_scroll_bar().visible, "map scrollbar is hidden")
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = get_viewport().get_final_transform() * Vector2(250, 650)
		Input.parse_input_event(wheel)
		await frames()
		check(ui.map_scroller.scroll_vertical > 0, "hidden scrollbar preserves wheel scrolling")
		wheel.pressed = false
		Input.parse_input_event(wheel)
		# 等滚轮平滑滚动结束，再校准首领点击位置。
		await get_tree().create_timer(0.5).timeout
		ui.map_scroller.scroll_vertical = 0
		await frames()
		var button: Button = ui.map_area.get_node("MapNode_%d_0" % (rows.size() - 1))
		var art: TextureRect = button.get_node("BossEmblem")
		var expected := "res://art/map/bosses/" + String(manifest.images[act].file)
		check(art.texture.resource_path == expected, "Act%d correct emblem" % (act + 1))
		var legend_icon: TextureRect = ui.get_node("MapLegend").find_child("boss", true, false).get_node("Heading/Icon")
		check(legend_icon.texture == art.texture, "legend uses current act boss emblem")
		check(art.texture.get_image().get_pixel(0, 0).a == 0.0, "transparent background")
		check(button.position.y >= 0 and is_equal_approx(button.size.x, button.size.y), "uncropped square boss node")
		check(art.mouse_filter == Control.MOUSE_FILTER_IGNORE and not button.disabled, "reachable boss accepts input")
		if OS.get_cmdline_user_args().has("--visual"):
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png("res://Temp/boss_map_act%d.png" % (act + 1)) == OK, "capture map")
		var center := get_viewport().get_final_transform() * button.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = center
		Input.parse_input_event(motion)
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = center
			click.pressed = pressed
			Input.parse_input_event(click)
			await frames(2)
		await frames()
		check(get_tree().current_scene.scene_file_path == "res://scenes/combat/CombatPlay.tscn", "boss click enters combat")
		check(RunState.pending_combat_enemy_ids == boss.enemy_ids, "boss click retains encounter identity")
		var current := get_tree().current_scene
		get_tree().current_scene = self
		current.queue_free()
		await frames()
	print("BOSS_MAP_EMBLEM_RESULT FAIL=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)

func frames(count: int = 8) -> void:
	for i in count:
		await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])
