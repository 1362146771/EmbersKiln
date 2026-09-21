extends Node
## 正式 UI / 独立节点场景整合回归，仅允许在 runner 创建的独立副本运行。
const MENU := "res://scenes/main/MainMenu.tscn"
const MAP := "res://scenes/map/MapPlay.tscn"
const COMBAT := "res://scenes/combat/CombatPlay.tscn"
const REWARD := "res://scenes/rewards/RewardUI.tscn"
const TOWN := "res://scenes/town/Town.tscn"
var checks := 0
var failures := 0
var reveals: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_cmdline_user_args().has("--transition-verify"):
		return
	var path := ProjectSettings.globalize_path("res://").replace("\\", "/")
	if not path.contains("/Temp/transition-verify-") or not OS.get_user_data_dir().replace("\\", "/").begins_with(path):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	_run.call_deferred()

func _run() -> void:
	get_tree().create_timer(90.0, true, false, true).timeout.connect(func(): get_tree().quit(2))
	TransitionManager.scene_revealing.connect(func(scene): reveals.append(scene.scene_file_path))
	_check("主菜单保留正式入口", _at(MENU) and get_tree().current_scene.play_button != null)
	get_tree().current_scene._on_play()
	get_tree().current_scene._on_play()
	_check("菜单立即锁定且未提前开始首战", TransitionManager.is_transitioning and not RunState.is_active)
	await _wait_transition()
	_check("新玩家仍直接进入首战并保留检查点", _at(COMBAT) and RunState.has_combat_checkpoint() and ProfileState.first_battle_started)
	await _capture("01-formal-combat")
	var run_id := RunState.run_id
	PauseManager._open_pause()
	await _wait_transition()
	_check("正式暂停界面仍可打开图鉴", get_tree().paused and PauseManager._overlay.find_child("CompendiumButton", true, false) != null)
	PauseManager._on_save_to_menu()
	PauseManager._on_save_to_menu()
	await _wait_transition()
	_check("保存返回菜单且解除暂停", _at(MENU) and not get_tree().paused)
	get_tree().current_scene._on_play()
	await _wait_transition()
	_check("继续游戏恢复原战斗检查点", _at(COMBAT) and RunState.run_id == run_id and RunState.has_combat_checkpoint())
	await _win_and_reward()
	await _dismiss_continue()
	await _test_nodes()
	await _test_bosses()
	await _test_failures()
	await _test_shader_pixels()
	await _test_kiln_pixels()
	print("TRANSITION_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _win_and_reward() -> void:
	var battle := get_tree().current_scene
	var before := reveals.size()
	for enemy in battle.controller.enemies:
		enemy.hp = 0
	battle.controller._check_combat_end()
	battle._on_combat_end(true)
	_check("战后反馈等待期间立即锁定", TransitionManager.is_transitioning)
	await _wait_transition()
	_check("路由地图不揭幕，直接展示独立奖励场景", _at(REWARD) and reveals.size() == before + 1 and reveals.back() == REWARD)
	var reward := get_tree().current_scene
	_check("正式战利品总览与选牌页都保留", is_instance_valid(reward._overview) and reward.has_node("Dim/Center/MainPanel"))
	var overview: Control = reward._overview
	_check("键盘焦点交给总览", overview.is_ancestor_of(get_viewport().gui_get_focus_owner()))
	await _capture("02-reward-overview")
	overview._on_continue()
	overview._on_continue()
	await _wait_transition()
	_check("总览只关闭一次并恢复选牌", not is_instance_valid(reward._overview) and not reward._closing)
	var visible_cards := true
	for card in reward._entrance_cards:
		visible_cards = visible_cards and is_equal_approx(card.modulate.a, 1.0) and card.scale.is_equal_approx(Vector2.ONE)
	_check("正式卡面错峰入场后全部可见", visible_cards)
	await _capture("03-reward-cards")
	reward._on_skip()
	reward._on_skip()
	await _wait_transition()
	_check("奖励返回地图且标记消费一次", _at(MAP) and not RunState.pending_post_reward)

func _fresh_map() -> void:
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_enchant_review = false
	FormalUI.combat_reward_pending = false
	TransitionManager.change_scene_to_file(MAP)
	await _wait_transition()

func _test_nodes() -> void:
	for kind in [&"rest", &"shop", &"event", &"treasure", &"altar", &"combat", &"elite"]:
		await _fresh_map()
		RunState.hp = 30
		RunState.gold = 500
		RunState.relic_ids.clear()
		var map := get_tree().current_scene
		var node = RunState.current_map()[0][0]
		node.type = kind
		map.start_new_map()
		await get_tree().process_frame
		map._on_node_pressed(0, 0)
		map._on_node_pressed(0, 0)
		_check("节点提交延迟到全遮盖", not node.visited and TransitionManager.is_transitioning)
		await _check_node_pulse(map, 0, 0)
		await _wait_transition()
		_check("节点标记正确且材质已清理", node.visited and RunState.current_node_type == kind and TransitionManager._cover.material == null)
		if kind in [&"combat", &"elite"]:
			_check("普通和精英使用短颗粒效果", _at(COMBAT) and TransitionManager._effect == &"clay")
			await _win_and_reward()
		else:
			var ui := get_tree().current_scene
			_check("独立节点保留正式界面和交互", ui.can_interact() and ui.scene_file_path.begins_with("res://scenes/map/"))
			await _capture("04-node-" + String(kind))
			match kind:
				&"rest":
					ui._on_rest(8)
					ui._on_rest(8)
					_check("休息只回复一次", RunState.hp == 38)
				&"shop":
					var price: int = ui.card_stock[0].price
					ui._on_buy_card(0)
					ui._on_buy_card(0)
					_check("商店库存/购买逻辑保留且不重复扣费", RunState.gold == 500 - price)
					ui._finish()
				&"event":
					ui._on_choose({"gold": 7})
					ui._on_choose({"gold": 7})
					_check("事件只结算一次", RunState.gold == 507)
					ui._finish()
				&"treasure":
					ui._on_open()
					ui._on_open()
					await get_tree().create_timer(0.8).timeout
					_check("宝箱开启动画和奖励展示保留", ui._claimed and ui._reward_ready)
					ui._finish()
				&"altar":
					ui._finish()
			ui._finish()
			await _wait_transition()
			_check("独立节点退场后返回原地图", _at(MAP) and not RunState.pending_node_resolved)
		await _dismiss_continue()

func _dismiss_continue() -> void:
	var map := get_tree().current_scene
	var panel: Control = map._transition_panel
	_check("返回地图先展示原有确认页", is_instance_valid(panel))
	map._on_continue(panel)
	map._on_continue(panel)
	await _wait_transition()
	await get_tree().process_frame
	_check("确认页退场后焦点回到地图", map.map_area.is_ancestor_of(get_viewport().gui_get_focus_owner()))

func _test_bosses() -> void:
	await _fresh_map()
	var boss_max := 0
	var chapter_max := 0
	for act in RunState.act_maps.size():
		var map := get_tree().current_scene
		var floor_index := RunState.current_map().size() - 1
		RunState.current_map()[floor_index - 1][0].visited = true
		map.start_new_map()
		await get_tree().process_frame
		var start := Time.get_ticks_msec()
		map._on_node_pressed(floor_index, 0)
		_check("Boss 入口使用裂纹效果", TransitionManager._effect == &"boss")
		await _check_node_pulse(map, floor_index, 0)
		await get_tree().create_timer(0.15).timeout
		_check("Boss 音效正常播放", TransitionManager._sound.playing)
		await _capture("05-boss-cover")
		await _wait_transition()
		boss_max = maxi(boss_max, Time.get_ticks_msec() - start)
		_check("保留本幕实际 Boss", get_tree().current_scene.controller.enemies[0].id == StringName(RunState.current_act_config().boss_id))
		await _win_and_reward()
		map = get_tree().current_scene
		if act < RunState.act_maps.size() - 1:
			var hp := RunState.hp
			_check("Boss 领奖后只推进一幕并自动存档", RunState.current_act == act + 1 and int(SaveManager.load_from_file(SaveManager.runtime_save_path).current_act) == act + 1)
			var panel := map.get_node("ActTransition")
			await _capture("06-chapter-title")
			start = Time.get_ticks_msec()
			map._on_enter_act(panel)
			map._on_enter_act(panel)
			_check("跨幕使用窑门", TransitionManager._effect == &"chapter")
			await _wait_transition()
			chapter_max = maxi(chapter_max, Time.get_ticks_msec() - start)
			_check("跨幕不重复回血且正式地图已就绪", RunState.hp == hp and RunState.current_act == act + 1 and get_tree().current_scene.has_node("FormalBackground"))
		else:
			_check("终幕胜利不新开局且保留城镇结算入口", RunState.victory and not RunState.is_active and map.find_child("ReturnTownButton", true, false) != null)
	print("SPECIAL_TIMING: boss_max=%dms chapter_max=%dms" % [boss_max, chapter_max])
	get_tree().current_scene._on_return_town(null)
	await _wait_transition()
	_check("结算可返回原城镇系统", _at(TOWN) and not RunState.is_active)
	get_tree().current_scene._on_depart()
	get_tree().current_scene._on_depart()
	await _wait_transition()
	if not _at(MAP):
		get_tree().current_scene._on_skip()
		await get_tree().process_frame
		await _wait_transition()
	_check("城镇出发仍走原局前准备和地图", _at(MAP) and RunState.is_active)

func _test_failures() -> void:
	var original := get_tree().current_scene
	for effect in [&"fade", &"boss", &"chapter"]:
		TransitionManager.change_scene_to_file(MENU, func(): return FAILED, 0.0, effect)
		await _wait_transition()
		_check("准备失败恢复场景、声音和材质", original == get_tree().current_scene and not TransitionManager._sound.playing and TransitionManager._cover.material == null)
	PauseManager._open_pause()
	await _wait_transition()
	TransitionManager.change_scene_to_file(MENU, func(): return FAILED)
	await _wait_transition()
	_check("暂停中失败不会误解除暂停", get_tree().paused and PauseManager._open)
	PauseManager._on_resume()
	await _wait_transition()
	_check("失败后可以正常恢复", not get_tree().paused)
	var panel := Panel.new()
	TransitionManager.open_panel(original, panel)
	panel.free()
	await _wait_transition()
	_check("面板意外销毁仍能解锁", not TransitionManager._cover.visible)
	await _fresh_map()
	get_tree().current_scene._on_node_pressed(0, 0)
	await _wait_transition()
	var battle := get_tree().current_scene
	battle.controller.player.hp = 0
	battle.controller.check_player_death()
	if RunState.combat_death_pending:
		_check("保留原有复活提示", battle.find_child("EndRunButton", true, false) != null)
		battle._on_decline_revive()
	await _wait_transition()
	_check("死亡结算不提前创建新局", _at(MAP) and not RunState.is_active and get_tree().current_scene.find_child("ReturnTownButton", true, false) != null)

func _at(path: String) -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == path

func _check_node_pulse(map: Control, floor_index: int, index: int) -> void:
	var button: Control = map.map_area.get_node("MapNode_%d_%d" % [floor_index, index])
	var node = RunState.current_map()[floor_index][index]
	var smallest := 1.0
	var largest := 1.0
	var deferred_entry := true
	var deadline := Time.get_ticks_msec() + 2000
	while TransitionManager._ready_gate.is_valid() and not TransitionManager._ready_gate.call() and Time.get_ticks_msec() < deadline:
		smallest = minf(smallest, button.scale.x)
		largest = maxf(largest, button.scale.x)
		deferred_entry = deferred_entry and not node.visited and get_tree().current_scene == map
		await get_tree().process_frame
	_check("节点以中心缩小后放大回弹", smallest < 0.95 and largest > 1.02 and button.pivot_offset.is_equal_approx(button.size * 0.5))
	_check("回弹结束恢复原尺寸，期间不提前进入", button.scale.is_equal_approx(Vector2.ONE) and deferred_entry)

func _wait_transition() -> void:
	var deadline := Time.get_ticks_msec() + 8000
	while TransitionManager.is_transitioning and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.01, true, false, true).timeout
	_check("转场按时解锁", not TransitionManager.is_transitioning)

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func _capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://" + label + ".png")


func _test_shader_pixels() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(240, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color.WHITE
	background.size = Vector2(240, 400)
	viewport.add_child(background)
	var cover := ColorRect.new()
	cover.size = background.size
	var material := ShaderMaterial.new()
	material.shader = TransitionManager.CLAY_SHADER
	cover.material = material
	viewport.add_child(cover)
	for revealing in [false, true]:
		material.set_shader_parameter("revealing", revealing)
		for progress in [0.0, 0.5, 1.0]:
			material.set_shader_parameter("progress", progress)
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			var top := image.get_pixel(120, 30).r
			var bottom := image.get_pixel(120, 370).r
			if progress == 0.0:
				_check("Shader 全透明端点无残留", top > 0.98 and bottom > 0.98)
			elif progress == 1.0:
				var opaque := true
				for y in range(0, 400, 16):
					for x in range(0, 240, 16):
						opaque = opaque and image.get_pixel(x, y).r < 0.5
				_check("Shader 完全覆盖端点无透底孔洞", opaque)
			else:
				_check("Shader 擦除方向正确", (top > 0.9 and bottom < 0.5) if revealing else (top < 0.5 and bottom > 0.9))
				image.save_png("res://08-shader-%s.png" % ("reveal" if revealing else "cover"))
	viewport.queue_free()




func _test_kiln_pixels() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color.WHITE
	viewport.add_child(background)
	var cover := ColorRect.new()
	var material := ShaderMaterial.new()
	material.shader = TransitionManager.KILN_SHADER
	cover.material = material
	viewport.add_child(cover)
	for dimensions in [Vector2i(240, 400), Vector2i(400, 240)]:
		viewport.size = dimensions
		background.size = dimensions
		cover.size = dimensions
		for chapter in [false, true]:
			material.set_shader_parameter("chapter", chapter)
			for revealing in [false, true]:
				material.set_shader_parameter("revealing", revealing)
				for progress in [0.0, 0.5, 1.0]:
					material.set_shader_parameter("progress", progress)
					await RenderingServer.frame_post_draw
					var picture := viewport.get_texture().get_image()
					var white := 0
					var dark := 0
					var total := 0
					for y in range(0, dimensions.y, 8):
						for x in range(0, dimensions.x, 8):
							var value := picture.get_pixel(x, y).r
							total += 1
							white += int(value > 0.98)
							dark += int(value < 0.5)
					if progress == 0.0:
						_check("裂纹/窑门横竖屏透明端点无残留", white == total)
					elif progress == 1.0:
						_check("裂纹/窑门横竖屏覆盖端点无孔洞", dark == total)
					else:
						_check("裂纹/窑门中段同时存在遮盖和揭幕区域", white > total / 10 and dark > total / 10)
						picture.save_png("res://12-kiln-%s-%s-%s.png" % ["chapter" if chapter else "boss", "reveal" if revealing else "cover", dimensions.x])
	viewport.queue_free()
