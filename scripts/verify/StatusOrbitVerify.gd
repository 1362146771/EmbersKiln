extends Node

var ui: CombatUI
var failures := 0
var checks := 0
var visual := false
var receipts: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func orbit(anchor: Control, id: String) -> Control:
	for child in anchor.get_children():
		if child.get_meta("status_orbit", "") == id and not child.is_queued_for_deletion(): return child
	return null

func capture(label: String) -> void:
	if not visual: return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/status_" + label + ".png")

func _ready() -> void:
	if OS.get_environment("STATUS_ORBIT_TEST_ROOT").is_empty():
		get_tree().quit(2)
		return
	get_tree().create_timer(90).timeout.connect(func(): get_tree().quit(2))
	visual = OS.get_cmdline_user_args().has("--visual")
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/status_orbit_save.json"
	RunState.start_new_run()
	RunState.relic_ids.clear()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_combat_enemy_ids = [&"claylump"]
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	var ctrl := ui.controller
	var enemy: CombatUnit = ctrl.enemies[0]
	var portrait: Control = ui.unit_panels[enemy].get_node("Inner/SpriteRect")
	ctrl._status.status_gained.connect(func(unit, id): receipts.append([unit, id]))
	# Every defined status has its own motif, and real enemy intents reach portraits.
	for sid in GameData.statuses:
		check(GameData.vfx["status_orbit"]["profiles"].has(String(sid)), "profile exists: " + String(sid))
	var colors: Dictionary = {}
	var silhouettes: Dictionary = {}
	for profile in GameData.vfx["status_orbit"]["profiles"].values():
		colors[profile["color"]] = true
		silhouettes[profile["glyph"]] = true
	check(colors.size() == GameData.statuses.size(), "every status has a distinct color")
	check(silhouettes.size() == GameData.statuses.size(), "every status has a distinct silhouette")
	for sid in [&"heat", &"temper", &"anneal", &"stoke", &"glaze", &"damp", &"crazed", &"ashrot", &"thirst"]:
		var buff: bool = not GameData.get_status(sid).is_debuff()
		var target: CombatUnit = enemy if buff else ctrl.player
		var anchor: Control = portrait if buff else ui.player_sprite
		enemy.intent = {"intent": "buff" if buff else "debuff", "status": sid, "value": 2}
		enemy.move_effects_resolved = false
		ctrl._execute_enemy_intent(enemy)
		var effect := orbit(anchor, String(sid))
		check(effect != null and target.get_status(sid) == 2, "real intent targets correct portrait: " + String(sid))
		if effect != null:
			check(effect.mouse_filter == Control.MOUSE_FILTER_IGNORE and effect.get_node("RearRibbon").z_index < 0 and effect.get_node("FrontRibbon").z_index > 0, "depth and click-through: " + String(sid))
		await get_tree().create_timer(0.32).timeout
		await capture(String(sid))
		ctrl._apply_status(target, sid, 1)
		check(orbit(anchor, String(sid)) == effect, "repeat gain reuses aura: " + String(sid))
		var count := receipts.size()
		ctrl._apply_status(target, sid, -1)
		ctrl._apply_status(target, sid, -2)
		check(receipts.size() == count, "decrease and cleanse produce no gain receipt: " + String(sid))
		await get_tree().create_timer(1.15).timeout
		check(orbit(anchor, String(sid)) == null, "effect releases: " + String(sid))
	# Negative strength cleanup is not a gain, but moving back above zero is.
	var before := receipts.size()
	ctrl._apply_status(enemy, &"heat", -2)
	ctrl._apply_status(enemy, &"heat", 2)
	check(receipts.size() == before, "cleansing negative strength does not show a buff")
	ctrl._apply_status(enemy, &"heat", 1)
	check(receipts.size() == before + 1, "positive strength gain resumes")
	# Attack after-effects use exactly the same status receipt.
	enemy.intent = {"intent": "attack", "value": 0, "after_effects": [{"kind": "status", "target": "player", "status": "damp", "value": 2}]}
	enemy.move_effects_resolved = false
	ctrl._execute_enemy_intent(enemy)
	check(orbit(ui.player_sprite, "damp") != null, "attack after-effect has player aura")
	# Simultaneous different statuses stay independent; no transform/modulate mutations.
	var pos := portrait.position
	var scale_before := portrait.scale
	var tint := portrait.modulate
	ctrl._apply_status(enemy, &"anneal", 2)
	check(orbit(portrait, "heat") != null and orbit(portrait, "anneal") != null, "different statuses coexist")
	check(portrait.position == pos and portrait.scale == scale_before and portrait.modulate == tint, "portrait transform and tint preserved")
	ui.get_node("CombatFeedback").clear()
	await get_tree().process_frame
	check(orbit(portrait, "heat") == null and orbit(ui.player_sprite, "damp") == null, "battle cleanup removes auras")
	GameData.vfx["enchant_attack"]["reduced_motion"] = true
	ctrl._apply_status(enemy, &"temper", 1)
	check(orbit(portrait, "temper").reduced_motion, "reduced motion uses static fade")
	await get_tree().create_timer(1.15).timeout
	check(orbit(portrait, "temper") == null, "reduced motion also releases")
	GameData.vfx["enchant_attack"]["reduced_motion"] = false
	# Exercise every portrait/formation, including cropped and state-based bosses.
	for enemy_id in GameData.enemies:
		ui.queue_free()
		await get_tree().process_frame
		RunState.pending_combat_enemy_ids = [enemy_id]
		ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
		add_child(ui)
		await get_tree().process_frame
		await get_tree().process_frame
		var all_anchored := true
		for unit in ui.controller.enemies:
			ui.controller._apply_status(unit, &"heat", 1)
			var body: Control = ui.unit_panels[unit].get_node("Inner/SpriteRect")
			all_anchored = all_anchored and orbit(body, "heat") != null and not body.clip_contents
		check(all_anchored, "portrait and formation coverage: " + String(enemy_id))
		if enemy_id == &"escort_commander":
			var leader: CombatUnit = ui.controller.enemies[0]
			ui.get_node("CombatFeedback").clear()
			await get_tree().process_frame
			ui.controller._escorts.apply_effect(leader, {"kind": "rally", "strength": 2})
			for member in ui.controller.enemies:
				check(orbit(ui.unit_panels[member].get_node("Inner/SpriteRect"), "heat") != null, "rally animates each recipient")
			await get_tree().create_timer(0.32).timeout
			await capture("formation")
		if enemy_id == &"kilnheart_ember":
			var boss: CombatUnit = ui.controller.enemies[0]
			ui.get_node("CombatFeedback").clear()
			await get_tree().process_frame
			ui.controller._intent.apply_phase_on_enter(boss, {"on_enter": [{"status": "heat", "value": 2}]})
			check(orbit(ui.unit_panels[boss].get_node("Inner/SpriteRect"), "heat") != null, "boss phase buff animates")
			await get_tree().create_timer(0.32).timeout
			await capture("boss")
	# Victory and scene removal must leave no detached aura or running callback.
	var old_effect: Control = orbit(ui.unit_panels[ui.controller.enemies[0]].get_node("Inner/SpriteRect"), "heat")
	ui.get_node("CombatFeedback")._on_combat_end(true)
	await get_tree().process_frame
	check(not is_instance_valid(old_effect), "victory removes active aura")
	ui.queue_free()
	await get_tree().process_frame
	print("STATUS_ORBIT_RESULT:", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
