extends Node
var ui: CombatUI
var checks := 0
var failures := 0
var starts := 0
var impacts := 0
var overlapped := false
var self_cast_bursts := 0
var _last_cast_id := &""
var _skill_captured := false

func capture_skill() -> void:
	_skill_captured = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/skill_cast_without_burst.png")

class ScriptErrors extends Logger:
	var messages: PackedStringArray = []
	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _notify: bool, error_type: int, _backtraces: Array) -> void:
		if error_type == ERROR_TYPE_SCRIPT:
			messages.append("%s:%d %s %s" % [file, line, code, rationale])

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func prepare(entries: Array, energy: int) -> void:
	ui.controller.hand = entries
	ui.controller.energy = energy
	ui.controller.kiln_heat = 0
	ui._refresh_all()
	await get_tree().process_frame

func submit_first(target := 0, gui_release := false) -> Control:
	var view: CardView = ui.hand_container.get_child(0)
	# Exercise CardView's actual press/move/release handlers, including code after signals.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = view.size * 0.5
	view._on_gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = view.get_global_transform_with_canvas() * press.position + Vector2.UP * 50.0
	view._input(motion)
	var ghost: Control = ui._ghost
	if target == 999:
		ui._targeting.cast_card(view, target) # Deliberately invalid queued target.
	else:
		var target_node: Control = ui.player_panel if target < 0 else ui.unit_panels[ui.controller.enemies[target]]
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = target_node.get_global_transform_with_canvas() * (target_node.size * 0.5)
		if gui_release:
			release.position = view.get_global_transform_with_canvas().affine_inverse() * release.position
			view._on_gui_input(release)
		else:
			view._input(release)
	return ghost

func drain() -> void:
	while ui._play_queue.busy(): await get_tree().process_frame

func _ready() -> void:
	var script_errors := ScriptErrors.new()
	OS.add_logger(script_errors)
	get_tree().create_timer(45.0).timeout.connect(func(): get_tree().quit(2))
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/card_queue_save.json"
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_combat_enemy_ids = [&"claylump"]
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	get_tree().node_added.connect(func(child: Node):
		if child is TextureRect and child.texture != null and child.texture.resource_path in ["res://art/vfx/ART_CAST_BURST.png", "res://art/vfx/ART_STRIKE_CARD.png"]:
			self_cast_bursts += 1
	)
	ui.controller.enemies[0].hp = 500
	ui.controller.enemies[0].max_hp = 500
	BattleDirector.card_cast_started.connect(func(_e, _t, _s, _g):
		_last_cast_id = StringName(_e.id)
		starts += 1
		if ui._play_queue.returning > 0: overlapped = true
	)
	BattleDirector.card_cast_finished.connect(func(ok):
		if ok: impacts += 1
		if ok and _last_cast_id == &"defend" and not _skill_captured and OS.get_cmdline_user_args().has("--visual"):
			capture_skill()
	)
	var first := {"id": &"strike"}
	var second := {"id": &"strike"}
	var third := {"id": &"strike"}
	await prepare([first, second, third], 2)
	var ghost := submit_first()
	check(ui.hand_container.get_child_count() == 2 and not ui._drag_active and ui._ghost == null, "submission immediately removes hand view and releases pointer")
	check(is_same(ui.hand_container.get_child(0).get_meta("hand_entry"), second), "identical cards retain distinct instance identity")
	await get_tree().create_timer(0.1).timeout
	var view: CardView = ui.hand_container.get_child(0)
	ui._targeting.on_card_drag_started(view)
	var dragged: Control = ui._ghost
	check(ui._drag_active and is_instance_valid(dragged) and dragged != ghost, "another card is draggable during windup")
	while impacts < 1: await get_tree().process_frame
	var enemy: CombatUnit = ui.controller.enemies[0]
	var enemy_panel: EnemyPanel = ui.unit_panels[enemy]
	check(BattleDirector.input_locked and enemy_panel.get_node("Inner/HpBar").value == enemy.hp and enemy_panel.get_node("Inner/HpText").text == "HP %d/%d" % [enemy.hp, enemy.max_hp], "enemy HP updates at impact during another active drag, before cast unlock")
	check(is_instance_valid(view) and ui._ghost == dragged and ui._drag_card == view, "impact refresh preserves the other active drag")
	ui._targeting.cast_card(view, 0)
	check(ui.hand_container.get_child_count() == 1 and is_same(ui.hand_container.get_child(0).get_meta("hand_entry"), third), "submission after hand index changes selects the correct duplicate")
	check(starts == 1 and ui._play_queue.pending.size() == 1, "second submission queues without restarting first animation")
	check(not ui._play_queue.can_submit(third), "pending energy reservation prevents overspending")
	var phase := ui.controller.phase
	ui._targeting.on_end_turn()
	check(ui.controller.phase == phase, "end turn waits for queue completion")
	await drain()
	check(starts == 2 and impacts == 2 and ui.controller.energy == 0, "two queued cards each resolve and pay exactly once")
	check(ui.controller.hand.size() == 1 and is_same(ui.controller.hand[0], third), "unsubmitted duplicate stays in hand")
	check(enemy_panel.get_node("Inner/HpBar").value == enemy.hp, "queued attacks leave the health bar current without ending the turn")
	check(not is_instance_valid(ghost) and not is_instance_valid(dragged), "both independent ghosts are cleaned up")
	await prepare([{"id": &"defend"}, {"id": &"defend"}], 3)
	submit_first(-1, true)
	submit_first(-1)
	check(ui.hand_container.get_child_count() == 0, "rapid consecutive submissions both leave hand immediately")
	await drain()
	check(overlapped, "next cast starts while previous discard flight continues independently")
	check(ui.controller.energy == 1 and ui._play_queue.returning == 0, "independent returns complete without double payment")
	check(self_cast_bursts == 0, "skill casts create no green burst texture")
	await prepare([{"id": &"inflame"}], 3)
	submit_first(-1)
	await drain()
	check(self_cast_bursts == 0 and ui.controller.player.get_status(&"heat") > 0, "power cast applies its effect without green burst texture")
	var consumed := {"id": &"defend"}
	await prepare([{"id": &"fiend_fire"}, consumed], 5)
	submit_first()
	submit_first(-1)
	var before := impacts
	await drain()
	check(impacts == before + 1 and ui.controller.exhaust_pile.any(func(e): return is_same(e, consumed)), "earlier exhaust cancels an invalidated queued instance safely")
	var chosen := {"id": &"defend"}
	await prepare([{"id": &"true_grit", "upgraded": true}, chosen, {"id": &"strike"}], 5)
	submit_first(-1)
	submit_first(-1)
	var held: CardView = ui.hand_container.get_child(0)
	ui._targeting.on_card_drag_started(held)
	while ui.controller.pending_card_choice.is_empty(): await get_tree().process_frame
	check(not ui._drag_active and ui._ghost == null and ui.card_browser_open(), "mandatory choice safely cancels current drag")
	before = impacts
	await get_tree().create_timer(0.6).timeout
	check(ui._play_queue.running and impacts == before, "queue pauses while mandatory card choice is unresolved")
	var browser = ui._card_browser
	browser.confirmed.emit(0, {})
	browser.queue_free()
	await drain()
	check(impacts == before and ui.hand_container.get_child_count() == 1 and ui.controller.exhaust_pile.any(func(e): return is_same(e, chosen)), "choice invalidation resumes queue and restores remaining hand")
	var restored := {"id": &"strike"}
	await prepare([restored], 3)
	submit_first(999)
	await drain()
	check(ui.controller.energy == 3 and ui.hand_container.get_child_count() == 1 and is_same(ui.controller.hand[0], restored), "unavailable queued target restores card without payment")
	check(ui._transition_feedback_ready(), "finished queue and flights release transition gate")
	check(self_cast_bursts == 0, "all queued attacks, skills and powers create no retired burst or enemy-card textures")
	OS.remove_logger(script_errors)
	check(script_errors.messages.is_empty(), "input and queue emit no script errors: %s" % str(script_errors.messages))
	print("CARD_QUEUE_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
