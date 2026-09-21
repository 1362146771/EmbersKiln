extends Node
## Deterministic real-combat integration checks plus renderer framebuffer captures.
var ui: CombatUI
var fx: Node
var failures := 0
var checks := 0
var visual := false
var shot_id := ""
var capture_done := false

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func entry(id: String, active := true) -> Dictionary:
	return {"id": StringName(id), "instance_id": "vfx_" + id, "enchants": ["town_" + id + "_1"], "enchant_active": active}

func prepare(card: Dictionary) -> void:
	ui.controller.hand = [card.duplicate(true), {"id": &"defend"}, {"id": &"strike"}, {"id": &"bash"}]
	ui.controller.energy = 5
	ui.controller.kiln_heat = 0
	for enemy in ui.controller.enemies:
		enemy.hp = 500
		enemy.max_hp = 500
		enemy.block = 0
		enemy.statuses.clear()
		ui._prev_ehp[enemy] = enemy.hp
	ui._refresh_all()

func snapshot() -> Dictionary:
	var enemies: Array = []
	for enemy in ui.controller.enemies: enemies.append([enemy.hp, enemy.block, enemy.statuses.duplicate(true)])
	return {"energy": ui.controller.energy, "hp": ui.controller.player.hp, "block": ui.controller.player.block, "statuses": ui.controller.player.statuses.duplicate(true), "enemies": enemies, "hand": ui.controller.hand.duplicate(true), "draw": ui.controller.draw_pile.duplicate(true), "discard": ui.controller.discard_pile.duplicate(true), "exhaust": ui.controller.exhaust_pile.duplicate(true), "heat": ui.controller.kiln_heat}

func cast(card: Dictionary) -> void:
	prepare(card)
	await get_tree().process_frame
	var cd: CardData = GameData.get_card(card["id"])
	var ghost: CardView = ui.CardViewScene.instantiate()
	ghost.set_ghost(true)
	ghost.build_visual(cd, -1, card.get("enchants", []), false, ui.controller.card_cost(card, cd), card)
	ui.drag_layer.add_child(ghost)
	ghost.global_position = ui.hand_container.get_child(0).global_position
	ui._casting = true
	var target: Control = ui.unit_panels[ui.controller.enemies[1]].get_node("Inner/SpriteRect")
	await BattleDirector.play_card_cast(ghost, target, cd, 0, 1, ui.controller)
	if is_instance_valid(ghost): ghost.queue_free()
	ui._casting = false
	ui._refresh_all()

func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func():
		printerr("ENCHANT_FX_TIMEOUT")
		get_tree().quit(2))
	visual = OS.get_cmdline_user_args().has("--visual")
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/enchant_fx_verify_save.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Temp/enchant_fx"))
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_combat_enemy_ids = [&"claylump", &"claylump", &"claylump"]
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	fx = ui.get_node("EnchantAttackFX")
	check(is_equal_approx(BattleDirector.CAST_TRAVEL + float(fx.config["impact_seconds"]), 1.2), "base attack presentation lasts 1.20 seconds")
	check(ui.get_node("DamageNumbers").layer > fx.layer, "damage numbers render above fullscreen composite")
	ui.controller.attack_feedback.connect(_on_impact)
	BattleDirector.card_cast_started.connect(_capture_charge)
	prepare(entry("bludgeon"))
	check(not fx.screen.visible and fx.copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "idle disables screen pass and copy")
	check(not fx.begin(entry("bludgeon", false), 1, 0.18), "standby mutation does not start")
	var ordinary := entry("bludgeon")
	ordinary["enchants"] = ["kiln_quench"]
	check(not fx.begin(ordinary, 1, 0.18), "run-only enchant stays on ordinary feedback")
	check(not fx.begin(CardMutation.strip_copy(entry("bludgeon")), 1, 0.18), "temporary stripped copy has no mutation VFX")
	check(not fx.begin(entry("impervious"), 1, 0.18), "non-attack mutations remain outside attack VFX scope")
	var before := snapshot()
	seed(90215)
	var expected_random := randi()
	seed(90215)
	check(fx.begin(entry("bludgeon"), 1, 0.18), "active mutation starts charge")
	fx.elapsed = 0.1
	fx._update_visuals()
	check(snapshot() == before and randi() == expected_random, "visual update changes neither combat state nor RNG")
	check(fx.screen.mouse_filter == Control.MOUSE_FILTER_IGNORE, "overlay never consumes input")
	check(fx.screen.get_global_rect().size == ui.get_viewport_rect().size, "composite covers the full viewport")
	fx.finish_cast(false)
	check(fx.phase == "idle", "failed cast cancels prelude")
	fx.begin(entry("bludgeon"), 1, 0.18)
	fx.finish_cast(true)
	check(fx.phase == "idle", "successful cast without hits does not burst")
	if visual: await _verify_fullscreen_coverage()
	await _verify_impact_rhythm()
	await _verify_reaper_prelude()
	for id in fx.config["card_profiles"]:
		var count: int = fx.impact_count
		shot_id = id if visual else ""
		capture_done = false
		await cast(entry(id))
		var atlas: Texture2D = fx.shader_material.get_shader_parameter("effect_atlas")
		check(atlas != null and atlas.get_size() == Vector2(1536, 1024), "%s has six-frame painted atlas" % id)
		check(fx.impact_count == count + (3 if id == "fiend_fire" else 1), "%s plays every real impact" % id)
		check(not BattleDirector.input_locked, "input unlocks after prelude, flight and settle")
		var numbers: Control = ui.get_node("DamageNumbers/Root")
		check(numbers.get_child_count() > 0 and numbers.get_child(0).modulate.a == 1.0, "%s damage stays opaque during impact" % id)
		if id == "fiend_fire":
			check(ui.controller.hand.is_empty(), "Fiend Fire consumes all three supporting cards")
			check(numbers.get_child_count() == 1 and numbers.get_child(0).get_node("Value").text == "-%d" % int(ui.controller.attack_hits.back()["amount"]), "Fiend Fire displays the final hit separately after earlier numbers expire")
			var hit_total := 0
			for hit in ui.controller.attack_hits: hit_total += int(hit["amount"])
			check(hit_total == 500 - ui.controller.enemies[1].hp, "Fiend Fire per-hit amounts match actual HP lost")
		if id == "sever_soul":
			check(ui.controller.hand.size() == 2 and ui.controller.hand[0]["id"] == &"strike" and ui.controller.hand[1]["id"] == &"bash", "Sever Soul consumes non-attacks and retains both attacks")
		if visual:
			while not capture_done: await get_tree().process_frame
		shot_id = ""
		fx.set_process(true)
		await get_tree().create_timer(float(fx.config["impact_seconds"]) + 0.1).timeout
		check(not fx.screen.visible and fx.phase == "idle", "%s tail cleans up" % id)
		check(numbers.get_child_count() == 0, "%s damage numbers clean up" % id)
	# Cost changes don't remove mutation identity; the existing cost-based shake stays off.
	prepare(entry("fiend_fire"))
	ui.controller.hand.resize(1)
	var no_hit_count: int = fx.impact_count
	fx.begin(entry("fiend_fire"), 1, 0.18)
	var no_hit_ok: bool = ui.controller.play_card(0, 1)
	fx.finish_cast(no_hit_ok)
	check(no_hit_ok and fx.phase == "idle" and fx.impact_count == no_hit_count and ui.controller.enemies[1].hp == 500, "Fiend Fire with zero supporting cards clears charge without a false impact")
	var discounted := entry("bludgeon")
	discounted["temporary_cost"] = 0
	var count: int = fx.impact_count
	await cast(discounted)
	check(fx.impact_count == count + 1, "zero paid cost keeps active mutation visuals")
	check(get_viewport().canvas_transform.origin == Vector2.ZERO and fx.shader_material.get_shader_parameter("impact_offset") == Vector2.ZERO, "zero-cost mutation adds no screen shake")
	await get_tree().create_timer(float(fx.config["impact_seconds"]) + 0.1).timeout
	prepare(entry("bludgeon"))
	ui.controller.enemies[1].block = 1000
	fx.begin(entry("bludgeon"), 1, 0.18)
	count = fx.impact_count
	ui.controller.play_card(0, 1)
	check(fx.impact_count == count + 1 and ui.controller.enemies[1].hp == 500, "fully blocked attack still bursts without HP damage")
	fx.begin(entry("reaper"), 1, 0.18)
	await get_tree().create_timer(0.55).timeout
	check(fx.phase == "charge", "previous impact cannot clear a new cast")
	fx.clear()
	fx.begin(entry("immolate"), 1, 0.18)
	var held: float = fx.elapsed
	get_tree().paused = true
	await get_tree().create_timer(0.05, true).timeout
	check(fx.elapsed == held, "pause freezes visual progress")
	get_tree().paused = false
	fx.clear()
	check(fx.copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "cleanup disables backbuffer")
	prepare(entry("bludgeon"))
	ui.controller._double_tap_charges = 1
	count = fx.impact_count
	fx.begin(entry("bludgeon"), 1, 0.18)
	ui.controller.play_card(0, 1)
	check(fx.impact_count == count + 1, "double-tap starts with its first fullscreen impact")
	var feedback := ui.get_node("CombatFeedback")
	if feedback.playing_hits: await feedback.playback_finished
	check(fx.impact_count == count + 2, "double-tap repeats the fullscreen impact for its second hit")
	check(ui.controller.enemies[1].hp == 420, "double-tap still resolves both enchanted hits")
	await get_tree().create_timer(float(fx.config["impact_seconds"]) + 0.1).timeout
	prepare(entry("immolate"))
	for enemy in ui.controller.enemies: enemy.hp = 1
	count = fx.impact_count
	fx.begin(entry("immolate"), 1, 0.18)
	ui.controller.play_card(0, 1)
	check(ui.combat_over and fx.impact_count == count + 1 and fx.screen.visible, "final killing hit survives combat-end notification")
	await get_tree().create_timer(0.9).timeout
	check(is_instance_valid(ui) and ui.is_inside_tree() and fx.screen.visible, "victory preserves extended tail past original 0.85-second transition")
	ui.queue_free()
	await get_tree().process_frame
	check(not BattleDirector.input_locked and get_viewport().canvas_transform.origin == Vector2.ZERO, "scene exit restores lock and screen transform")
	print("ENCHANT_FX_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _verify_impact_rhythm() -> void:
	var targets: Array[int] = [1]
	for id in fx.config["card_profiles"]:
		prepare(entry(id))
		var unchanged := snapshot()
		fx.begin(entry(id), 1, BattleDirector.CAST_TRAVEL)
		fx.impact(targets)
		fx.set_process(false)
		var rhythm: Dictionary = fx.rhythm
		var contact := float(rhythm["contact_seconds"])
		var hold := float(rhythm["hold_seconds"])
		var release := contact + hold
		fx.elapsed = contact + hold * 0.2
		fx._update_visuals()
		var frozen_progress: float = fx.shader_material.get_shader_parameter("progress")
		var kick: Vector2 = fx.shader_material.get_shader_parameter("impact_offset")
		fx.elapsed = contact + hold * 0.8
		fx._update_visuals()
		check(is_equal_approx(frozen_progress, float(fx.shader_material.get_shader_parameter("progress"))) and kick == fx.shader_material.get_shader_parameter("impact_offset"), "%s hit-stop holds both art and camera" % id)
		check(kick.length() >= 20.0, "%s initial kick has a strong directional amplitude" % id)
		if visual:
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png("res://Temp/enchant_fx/%s_hitstop.png" % id) == OK, "%s rendered hit-stop screenshot saved" % id)
		var step := float(rhythm["step_seconds"])
		check(is_equal_approx(fx._impact_progress(release + step * 0.2), fx._impact_progress(release + step * 0.8)), "%s stepped interval holds between sampled frames" % id)
		check(fx._impact_progress(release + step * 1.1) > fx._impact_progress(release + step * 0.8), "%s sampled frame jumps forward at the next beat" % id)
		var rebound: Vector2 = fx._impact_offset(release + step * 0.2)
		check(kick.dot(rebound) < 0.0 and rebound.length() < kick.length(), "%s rebound reverses direction with changed amplitude" % id)
		check(fx._impact_offset(0.65) == Vector2.ZERO and is_equal_approx(fx._impact_progress(1.02), 1.0), "%s shake returns to zero and tail keeps original duration" % id)
		fx.reduced_motion = true
		fx._update_visuals()
		check(fx.shader_material.get_shader_parameter("impact_offset") == Vector2.ZERO and not bool(fx.shader_material.get_shader_parameter("stepped_frames")), "%s reduced motion disables kick and stepped frames" % id)
		fx.reduced_motion = false
		check(snapshot() == unchanged, "%s impact rhythm does not change combat state" % id)
		fx.clear()
		check(fx.shader_material.get_shader_parameter("impact_offset") == Vector2.ZERO and not fx.screen.visible, "%s interruption clears camera offset" % id)

func _verify_reaper_prelude() -> void:
	check(fx.prelude_for(entry("reaper", false)) == 0.0 and fx.prelude_for(entry("bludgeon")) == 0.0, "cut-in is exclusive to active Reaper mutation")
	check(is_equal_approx(fx.prelude_for(entry("reaper")) + 1.2, 1.85), "Reaper total includes 0.65-second portrait before 1.20-second attack")
	cast(entry("reaper"))
	await get_tree().create_timer(0.25).timeout
	check(fx.phase == "charge" and BattleDirector.input_locked, "portrait holds cast input before impact")
	check(ui.controller.enemies[1].hp == 500 and ui.controller.energy == 5, "portrait does not resolve damage or spend energy early")
	check(ui.get_node("DamageNumbers/Root").get_child_count() == 0, "portrait has no premature damage numbers")
	check(float(fx.shader_material.get_shader_parameter("cutin_progress")) > 0.0 and float(fx.shader_material.get_shader_parameter("strength")) == 0.0, "portrait appears before attack atlas")
	var frozen: float = fx.elapsed
	get_tree().paused = true
	await get_tree().create_timer(0.07, true).timeout
	check(fx.elapsed == frozen and ui.controller.enemies[1].hp == 500, "pause freezes portrait and delayed damage together")
	if visual:
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://Temp/enchant_fx/reaper_cutin.png") == OK, "rendered half-face screenshot saved")
	get_tree().paused = false
	while BattleDirector.input_locked: await get_tree().process_frame
	check(fx.phase == "impact" and ui.controller.enemies[1].hp == 495, "portrait transitions into one real Reaper hit")
	check(float(fx.shader_material.get_shader_parameter("cutin_progress")) < 0.0, "portrait mask clears for attack")
	await get_tree().create_timer(float(fx.config["impact_seconds"]) + 0.1).timeout
	fx.begin(entry("reaper"), 1, 0.18)
	fx.finish_cast(false)
	check(not fx.screen.visible and float(fx.shader_material.get_shader_parameter("cutin_progress")) < 0.0, "cancel clears portrait and full-screen mask")

func _verify_fullscreen_coverage() -> void:
	await RenderingServer.frame_post_draw
	var baseline := get_viewport().get_texture().get_image()
	fx.begin(entry("bludgeon"), 1, BattleDirector.CAST_TRAVEL)
	var targets: Array[int] = [1]
	fx.impact(targets)
	fx.set_process(false)
	fx.elapsed = float(fx.config["impact_seconds"]) * 0.2
	fx._update_visuals()
	await RenderingServer.frame_post_draw
	var masked := get_viewport().get_texture().get_image()
	# Sample stable HUD pixels outside the attack sprite, including the bottom hand.
	var probes := {"top HUD": Vector2(0.5, 0.035), "player HUD": Vector2(0.5, 0.52), "hand": Vector2(0.12, 0.90)}
	for label in probes:
		var uv: Vector2 = probes[label]
		var point := Vector2i(int(uv.x * baseline.get_width()), int(uv.y * baseline.get_height()))
		var before := baseline.get_pixelv(point)
		var after := masked.get_pixelv(point)
		check(after.r + after.g + after.b < (before.r + before.g + before.b) * 0.95, "%s receives fullscreen shading" % label)
	fx.clear()

func _on_impact(_paid: int, _targets: Array[int]) -> void:
	if shot_id.is_empty(): return
	# Freeze the real, event-triggered Shader at a repeatable keyframe for QA.
	fx.set_process(false)
	fx.elapsed = float(fx.config["impact_seconds"]) * 0.25
	fx._update_visuals()
	_capture_keyframes.call_deferred(shot_id)

func _capture_charge(_entry: Dictionary, _target: int, _travel: float, _ghost: Control) -> void:
	if shot_id.is_empty(): return
	if fx.prelude_duration == 0.0: fx.elapsed = 0.13
	else: await get_tree().create_timer(0.25).timeout
	fx._update_visuals()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://Temp/enchant_fx/%s_charge.png" % shot_id) == OK, "%s rendered charge screenshot saved" % shot_id)

func _capture_keyframes(id: String) -> void:
	# Let the existing 0.14s cast settle refresh hand/HP while holding the FX keyframe.
	await get_tree().create_timer(BattleDirector.CAST_SETTLE).timeout
	await get_tree().process_frame
	fx._update_visuals()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://Temp/enchant_fx/%s_impact.png" % id) == OK, "%s rendered impact screenshot saved" % id)
	fx.elapsed = float(fx.config["impact_seconds"]) * 0.72
	fx._update_visuals()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://Temp/enchant_fx/%s_tail.png" % id) == OK, "%s rendered tail screenshot saved" % id)
	capture_done = true
