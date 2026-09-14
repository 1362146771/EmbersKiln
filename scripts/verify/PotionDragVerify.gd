extends Node
## 输入回归 fixture；断开自动存档，不写玩家存档。
var failed := 0
var ui: CombatUI
var gesture: Node

func check(label: String, ok: bool) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failed += 1

func frames() -> void:
	for i in 4:
		await get_tree().process_frame

func _ready() -> void:
	for sig in [SignalBus.combat_ended, SignalBus.floor_entered, SignalBus.act_changed, SignalBus.run_ended]:
		for connection in sig.get_connections():
			if connection.callable.get_object() == SaveManager:
				sig.disconnect(connection.callable)
	RunState.start_new_run()
	RunState.pending_combat_enemy_ids = ["claylump", "claylump"]
	ui = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await frames()
	gesture = ui.get_node("PotionInteraction")
	ui._refresh_all()
	await frames()
	for source in [ui.potion_icons[0], ui.potion_slots[0]]:
		await stock(&"tinder_oil")
		press(source)
		gesture.release_pointer(source.get_global_rect().get_center())
		check("icon/name click opens details without consumption", ui.get_node("PotionDetails").visible and RunState.potions.size() == 1)
		ui.get_node("PotionDetails").hide()
		await frames()
	await stock(&"tinder_oil")
	var energy: int = ui.controller.energy
	press(ui.potion_icons[0])
	gesture.move_pointer(Vector2(710, 900))
	gesture.release_pointer(Vector2(710, 900))
	check("empty drop cancels", RunState.potions.size() == 1 and not ui._drag_active and ui.controller.energy == energy)
	var enemy: Control = ui.unit_panels[ui.controller.enemies[1]]
	var enemy_pos := enemy.get_global_rect().get_center()
	press(ui.potion_icons[0])
	gesture.move_pointer(enemy_pos)
	check("self potion rejects enemy highlight", ui.drop_layer._hover_index == -3)
	gesture.release_pointer(enemy_pos)
	check("wrong target retains potion", RunState.potions.size() == 1)
	var player_pos := ui.player_sprite.get_global_rect().get_center()
	press(ui.potion_slots[0])
	gesture.move_pointer(player_pos)
	check("legal player hover", ui.drop_layer._hover_index == -1 and ui._drag_active)
	await capture("player")
	gesture.release_pointer(player_pos)
	check("self potion applies once", RunState.potions.is_empty() and ui.controller.energy == energy + 1 and not ui._drag_active)
	await stock(&"craze_dust")
	press(ui.potion_icons[0], true)
	var move := InputEventScreenDrag.new()
	move.index = 2
	move.position = enemy_pos
	gesture._input(move)
	check("touch enemy hover", ui.drop_layer._hover_index == 1)
	await capture("enemy")
	var release := InputEventScreenTouch.new()
	release.index = 2
	release.position = enemy_pos
	release.pressed = false
	gesture._input(release)
	check("touch uses chosen enemy only", RunState.potions.is_empty() and ui.controller.enemies[1].get_status(&"crazed") > 0 and ui.controller.enemies[0].get_status(&"crazed") == 0)
	await stock(&"mud_bolt")
	press(ui.potion_icons[0])
	gesture.move_pointer(enemy_pos)
	gesture.release_pointer(enemy_pos)
	check("aoe affects both enemies", RunState.potions.is_empty() and ui.controller.enemies[0].get_status(&"damp") > 0 and ui.controller.enemies[1].get_status(&"damp") > 0)
	await stock(&"tinder_oil")
	press(ui.potion_icons[0])
	gesture.move_pointer(player_pos)
	ui.controller.phase = CombatController.Phase.ENEMY
	gesture.release_pointer(player_pos)
	check("phase lock cancels without consumption", RunState.potions.size() == 1 and not ui._drag_active)
	ui.controller.phase = CombatController.Phase.PLAYER
	press(ui.potion_icons[0])
	gesture.move_pointer(player_pos)
	gesture.cancel()
	check("cancel clears visuals", not ui.drop_layer.arrow_visible and ui.drop_layer._hover_index == -3 and gesture.ghost == null and RunState.potions.size() == 1)
	await stock(&"tinder_oil")
	var origin: Vector2 = ui.potion_icons[0].get_global_rect().get_center()
	await mouse_button(origin, true)
	await mouse_button(origin, false)
	check("viewport click opens details only", ui.get_node("PotionDetails").visible and RunState.potions.size() == 1)
	ui.get_node("PotionDetails").hide()
	await frames()
	await mouse_button(origin, true)
	var motion := InputEventMouseMotion.new()
	motion.position = player_pos
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion, true)
	await frames()
	check("viewport drag activates player hover", ui._drag_active and ui.drop_layer._hover_index == -1)
	await mouse_button(player_pos, false)
	check("viewport release uses potion", RunState.potions.is_empty() and not ui._drag_active)
	ui.queue_free()
	await frames()
	print("POTION_DRAG_RESULT: %s" % ["PASS" if failed == 0 else "FAIL"])
	get_tree().quit(0 if failed == 0 else 1)

func stock(id: StringName) -> void:
	RunState.potions = [id]
	ui._refresh_all()
	await frames()

func press(source: Control, touch := false) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenTouch.new()
		event.index = 2
	else:
		event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = source.size * 0.5
	source.gui_input.emit(event)

func mouse_button(pos: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = pos
	get_viewport().push_input(event, true)
	await frames()

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	await frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/potion_drag_%s.png" % label)
