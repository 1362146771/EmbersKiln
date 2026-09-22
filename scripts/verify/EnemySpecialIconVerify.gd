extends Node
## Read-only presentation coverage of every enemy definition and live mechanism state.
const BAR := preload("res://scenes/combat/IntentIconBar.tscn")
var failures := 0
var checks := 0
var seen: Dictionary = {}
var cc: CombatController
var bar: HFlowContainer

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("[FAIL] ", label)

func refresh(unit: CombatUnit) -> void:
	bar.set_unit(unit, cc, unit.data.combat_hint)
	for badge in bar.get_children():
		var special: String = badge.get_meta("special_effect", "")
		var texture: Texture2D = badge.get_node("Icon").texture
		check(texture != null, String(unit.id) + " texture loaded")
		check(not String(badge.get_meta("info_title", "")).is_empty(), "individual title")
		check(not String(badge.get_meta("info_body", "")).is_empty(), "individual description")
		check(badge.tooltip_text.is_empty() and bar.tooltip_text.is_empty(), "no combined native tooltip")
		if not special.is_empty():
			seen[special] = true
			check(texture.resource_path.begins_with("res://art/icons/enemy_special/"), special + " independent resource")
			check(texture.get_size() == Vector2(128, 128), special + " 128px canvas")
			check(texture.get_image().detect_alpha() == Image.ALPHA_BLEND, special + " transparent asset")

func has_icon(key: String) -> bool:
	return bar.get_children().any(func(b): return b.get_meta("special_effect", "") == key)

func fresh(id: StringName) -> CombatUnit:
	if is_instance_valid(cc): cc.free()
	RunState.start_new_run("normal")
	RunState.pre_run_preparation_resolved = true
	cc = CombatController.new()
	add_child(cc)
	cc.start_combat([id])
	return cc.enemies[0]

func _ready() -> void:
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/enemy_special_save.json"
	bar = BAR.instantiate()
	add_child(bar)
	for id in GameData.enemies:
		var leader := fresh(id)
		for unit in cc.enemies:
			var moves: Array = unit.data.moves.duplicate()
			for phase in unit.data.phases:
				moves.append_array(phase.get("moves", []))
				if phase.has("entry_move"): moves.append(phase.entry_move)
			for move in moves:
				unit.intent = move.duplicate(true)
				refresh(unit)
				if move.has("if_missing"):
					unit.intent.merge(move.if_missing, true)
					refresh(unit)
			if unit.leader_index >= 0:
				unit.can_act_from_turn = cc.turn + 1
				refresh(unit)
				check(has_icon("arrival"), "new escort arrival badge")
		leader.block_break_next = &"harden"
		refresh(leader)
	var binder := fresh(&"ashen_binder")
	refresh(binder)
	check(has_icon("vent") and not has_icon("backlash"), "unsealed backlash paused")
	binder.ash_sealed = true
	refresh(binder)
	check(has_icon("backlash") and not has_icon("vent"), "sealed backlash active")
	binder.ash_backlash_used = int(binder.data.boss_rules.backlash_raw_cap)
	refresh(binder)
	check(bar.get_children().any(func(b): return b.get_meta("special_effect", "") == "backlash" and "还可造成 0 点" in b.get_meta("info_body", "")), "backlash cap refreshed")
	var reaction = bar.get_children().filter(func(b): return b.get_meta("special_effect", "") == "backlash")[0]
	var reaction_id: int = reaction.get_instance_id()
	reaction.gui_input.emit(_touch(reaction.get_global_rect().get_center()))
	check(reaction.get_node("CombatIconDetails").pinned, "tap pins independent explanation")
	binder.ash_backlash_used = 0
	refresh(binder)
	check(reaction.get_instance_id() == reaction_id, "live update preserves inspected badge")
	check(reaction.get_node("CombatIconDetails/Panel/Body/Description").text == reaction.get_meta("info_body"), "open explanation updates remaining cap")
	reaction.get_node("CombatIconDetails").close()
	binder.ash_sealed = false
	refresh(binder)
	check(has_icon("vent") and not has_icon("backlash"), "vent removes active backlash icon")
	var chi := fresh(&"chi_the_first")
	chi.phase_index = 0
	refresh(chi)
	check(has_icon("power_watch") and has_icon("regeneration"), "boss reaction and healing separate")
	for badge in bar.get_children():
		if badge.get_meta("special_effect", "") == "regeneration":
			check(not "能力牌" in badge.get_meta("info_body"), "regeneration explains only itself")
	chi.phase_index = 1
	refresh(chi)
	check(not has_icon("power_watch") and has_icon("regeneration"), "phase change stops reaction, keeps healing")
	var leader := fresh(&"escort_vanguard")
	var guard: CombatUnit = cc.enemies.filter(func(e): return e.data.escort_rules.has("protect_leader_attack_mult"))[0]
	refresh(guard)
	check(has_icon("guard"), "living leader protection")
	leader.hp = 0
	refresh(guard)
	check(not has_icon("guard"), "dead leader removes protection")
	leader = fresh(&"escort_overseer")
	for unit in cc.enemies:
		refresh(unit)
		if unit.data.escort_rules.get("react_card_type", "") == "skill": check(has_icon("skill_watch"), "skill watcher")
		if unit.data.escort_rules.get("react_card_type", "") == "power": check(has_icon("power_watch"), "power watcher")
	leader.hp = 0
	for unit in cc.enemies:
		refresh(unit)
		if unit.data.escort_rules.get("react_card_type", "") == "skill": check(has_icon("skill_watch"), "self reaction survives leader")
		if unit.data.escort_rules.get("react_card_type", "") == "power": check(not has_icon("power_watch"), "leader reaction removed")
	for key in bar.SPECIAL_ICONS:
		check(seen.has(key), "all configured mechanisms covered: " + key)
	var normal := fresh(&"claylump")
	normal.intent = {"intent":"buff", "status":"heat", "value":1}
	refresh(normal)
	check(bar.get_child(0).get_node("Icon").texture.resource_path == "res://art/icons/intent/ICO_Intent_Buff.png", "ordinary strength keeps general icon")
	cc.free()
	bar.queue_free()
	await get_tree().process_frame
	if "--visual" in OS.get_cmdline_user_args():
		for id in [&"ashen_binder", &"chi_the_first", &"escort_overseer", &"escort_vanguard", &"escort_commander"]:
			await visual_combat(id)
	print("ENEMY_SPECIAL_ICON_RESULT:%s checks=%d enemies=%d icons=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, GameData.enemies.size(), seen.size(), failures])
	get_tree().quit(0 if failures == 0 else 1)

func visual_combat(id: StringName) -> void:
	RunState.start_new_run("normal")
	RunState.pre_run_preparation_resolved = true
	RunState.granny_opening = {"resolved":true}
	RunState.pending_combat_enemy_ids = [id]
	var ui = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().create_timer(0.5).timeout
	if id == &"ashen_binder": ui.controller.enemies[0].ash_sealed = true
	ui._enemy.refresh_enemy()
	for i in 8: await get_tree().process_frame
	for panel in ui.unit_panels.values():
		var intent: Control = panel.get_node("Inner/IntentBar")
		for badge in intent.get_children():
			check(intent.get_global_rect().encloses(badge.get_global_rect()), String(id) + " badge inside bar")
		check(intent.get_global_rect().end.y <= panel.get_node("Inner/SpriteRect").global_position.y, String(id) + " icons clear portrait")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/enemy_special_%s.png" % id)
	var inspected: Control
	for panel in ui.unit_panels.values():
		for badge in panel.get_node("Inner/IntentBar").get_children():
			if not String(badge.get_meta("special_effect", "")).is_empty():
				inspected = badge
				break
		if inspected != null: break
	if inspected != null:
		inspected.mouse_entered.emit()
		for i in 4: await get_tree().process_frame
		var popup = inspected.get_node("CombatIconDetails")
		check(popup.panel.visible and not popup.pinned, "hover opens own explanation")
		check(get_viewport().get_visible_rect().encloses(popup.panel.get_global_rect()), "tooltip stays inside screen")
		check(popup.get_node("Panel/Body/Description").text == inspected.get_meta("info_body"), "one icon one explanation")
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/enemy_special_%s_tooltip.png" % id)
		inspected.mouse_exited.emit()
		check(not popup.panel.visible, "mouse exit dismisses hover")
		inspected.gui_input.emit(_touch(inspected.get_global_rect().get_center()))
		inspected.mouse_exited.emit()
		check(popup.panel.visible and popup.pinned, "touch explanation stays open")
		popup._input(_touch(Vector2(5, 1100)))
		check(not popup.panel.visible, "outside tap dismisses")
		var status_unit: CombatUnit = ui.controller.enemies[0]
		status_unit.add_status(&"heat", 2)
		ui._enemy.refresh_enemy()
		for i in 4: await get_tree().process_frame
		var status_badge: Control = ui.unit_panels[status_unit].get_node("Inner/StatusBar/heat")
		status_badge.gui_input.emit(_touch(status_badge.get_global_rect().get_center()))
		for i in 4: await get_tree().process_frame
		check(status_badge.get_node("CombatIconDetails/Panel").visible and status_badge.get_meta("info_title") == "力量", "common status uses same independent details")
		check(get_viewport().get_visible_rect().encloses(status_badge.get_node("CombatIconDetails/Panel").get_global_rect()), "status tooltip stays inside screen")
		status_badge.get_node("CombatIconDetails").close()
		# Send actual viewport input to a different enemy's icon, exercising GUI
		# propagation instead of only calling the description handlers directly.
		var last_panel: Control = ui.unit_panels.values().back()
		var input_badge: Control = last_panel.get_node("Inner/IntentBar").get_child(0)
		var target_before: int = ui.selected_target
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = input_badge.get_global_rect().get_center()
		get_viewport().push_input(click)
		click = click.duplicate()
		click.pressed = false
		get_viewport().push_input(click)
		await get_tree().process_frame
		check(input_badge.get_node("CombatIconDetails/Panel").visible, "real pointer input opens icon explanation")
		check(ui.selected_target == target_before, "icon click does not select enemy")
		input_badge.get_node("CombatIconDetails").close()
		if id == &"ashen_binder": await edge_popup(ui)
	ui.queue_free()
	await get_tree().process_frame

func _touch(point: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = true
	return event

func edge_popup(ui: CombatUI) -> void:
	var edge = load("res://scenes/combat/StatusIconBar.tscn").instantiate()
	edge.position = get_viewport().get_visible_rect().size - Vector2(52, 44)
	edge.size = Vector2(40, 34)
	edge.z_index = 80
	add_child(edge)
	var unit := CombatUnit.new()
	unit.add_status(&"heat", 2)
	edge.set_unit(unit)
	for i in 3: await get_tree().process_frame
	var badge: Control = edge.get_node("heat")
	var hand_before := ui.controller.hand.size()
	var touch := _touch(badge.get_global_rect().get_center())
	get_viewport().push_input(touch)
	touch = touch.duplicate()
	touch.pressed = false
	get_viewport().push_input(touch)
	for i in 4: await get_tree().process_frame
	var popup = badge.get_node("CombatIconDetails")
	check(popup.panel.visible and popup.pinned, "real touch opens pinned explanation")
	check(get_viewport().get_visible_rect().grow(-10).encloses(popup.panel.get_global_rect()), "bottom-right tooltip clamped on both axes")
	check(popup.panel.get_global_rect().encloses(popup.get_node("Panel/Body/Description").get_global_rect()), "wrapped description remains inside panel")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/enemy_special_edge_tooltip.png")
	touch = _touch(Vector2(20, 1120))
	get_viewport().push_input(touch)
	touch = touch.duplicate()
	touch.pressed = false
	get_viewport().push_input(touch)
	await get_tree().process_frame
	check(not popup.panel.visible, "real outside touch closes explanation")
	check(ui.controller.hand.size() == hand_before, "dismiss touch does not play a card")
	edge.queue_free()
	await get_tree().process_frame
