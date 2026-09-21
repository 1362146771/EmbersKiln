extends Node
## Run in an isolated project/user directory; exercise real drag/cast and pile UI.
var ui: CombatUI
var checks := 0
var failures := 0
var visual := false
var first_hit_frame := -1

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func capture(label: String) -> void:
	if not visual: return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/card_" + label + ".png")

func _ready() -> void:
	visual = OS.get_cmdline_user_args().has("--visual")
	get_tree().create_timer(40.0).timeout.connect(func(): get_tree().quit(2))
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/card_presentation_save.json"
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_combat_enemy_ids = [&"claylump"]
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	BattleDirector.card_cast_started.connect(func(_entry, _target, _travel, _ghost): first_hit_frame = -1)
	ui.get_node("CombatFeedback").hit_presented.connect(_on_presented_hit)
	BattleDirector.card_cast_finished.connect(_on_cast_impact)
	ui.controller.enemies[0].hp = 500
	ui.controller.enemies[0].max_hp = 500
	ui.controller.enemies[0].block = 0
	ui.controller.hand = [{"id": &"strike", "upgraded": true}, {"id": &"defend"}, {"id": &"bash"}]
	ui.controller.energy = 10
	ui._refresh_all()
	await get_tree().process_frame
	var view: CardView = ui.hand_container.get_child(0)
	check(view.get_node("Body").get_theme_color("font_color") == Color("ffd083"), "upgraded hand title is gold")
	check(ui.hand_container.get_child(1).get_node("Body").get_theme_color("font_color") == Color.WHITE, "normal title stays white")
	check(view.get_node("CardBacking").get_index() < view.get_node("Art").get_index(), "gray backing beneath art and frame")
	var preview := FormalUI.card_visual({"id": &"strike", "upgrade_level": 2})
	check(preview.get_node("CardTitle").get_theme_color("font_color") == Color("ffd083"), "detail/reward shared card title is gold")
	preview.free()
	for label in [ui.draw_pile_button.get_node("Count"), ui.discard_pile_view.get_node("Content/Labels/Count")]:
		check(label.anchor_left == 1.0 and label.anchor_bottom == 1.0 and label.offset_right == 0.0, "pile count anchored bottom right")
	await capture("ready")
	var target: Control = ui.unit_panels[ui.controller.enemies[0]]
	var before_energy := ui.controller.energy
	var before_hp := ui.controller.enemies[0].hp
	ui._targeting.on_card_drag_started(view)
	ui._targeting.on_card_drag_moved(view, target.get_global_rect().get_center())
	var ghost: Control = ui._ghost
	var released_at := ghost.global_position
	ui._targeting.cast_card(view, 0)
	await get_tree().create_timer(0.12).timeout
	await get_tree().process_frame # Timers can resume before this frame's tweens advance.
	check(BattleDirector.input_locked and ui._play_queue.running and not ui._casting, "windup queues attacks without locking the hand")
	check(ui.controller.energy == before_energy and ui.controller.enemies[0].hp == before_hp, "no payment or damage before impact")
	var player: AnimatedSprite2D = ui.player_sprite.get_node("BodyAnimation")
	check(player.visible and player.animation == &"attack" and player.frame < 2, "player winds up during card flight without striking early")
	check(ghost.global_position.distance_to(released_at) > 5.0, "card pulls away before charging: %s -> %s" % [released_at, ghost.global_position])
	await capture("windup")
	while not ui.get_node("CombatFeedback").playing_hits:
		await get_tree().process_frame
	check(ui.controller.energy == before_energy - GameData.get_card(&"strike").cost, "cast pays once")
	check(ui.controller.enemies[0].hp < before_hp, "cast damages the selected enemy")
	await get_tree().create_timer(0.12).timeout
	check(is_instance_valid(ghost) and ghost.visible and ghost.rotation > 0.0, "card rotates during flight to discard")
	check(ui.get_node("CombatFeedback").playing_hits, "return flight starts during hit feedback, without waiting for recovery")
	check(ghost.scale.x < float(GameData.vfx.card_presentation.impact_scale), "card shrinks during flight")
	check(BattleDirector.input_locked and not ui._transition_feedback_ready(), "return flight gates input and victory transition")
	await capture("discard_flight")
	while ui._play_queue.busy(): await get_tree().process_frame
	check(not BattleDirector.input_locked and ui.controller.discard_pile.any(func(c): return c.id == &"strike"), "cast completes in discard and unlocks")
	# Multiple rapid changes restart the pulse without accumulating scale.
	var label: Label = ui.draw_pile_button.get_node("Count")
	ui.controller.draw_pile = [{"id": &"strike"}, {"id": &"defend"}]
	ui._hand.refresh_discard_pile()
	await get_tree().create_timer(0.06).timeout
	check(label.scale.x > 1.0, "draw count pulses on change")
	ui.controller.draw_pile.pop_front()
	ui.controller.discard_pile.append({"id": &"defend"})
	ui._hand.refresh_discard_pile()
	await get_tree().create_timer(0.06).timeout
	check(ui.discard_pile_view.get_node("Content/Labels/Count").scale.x > 1.0, "discard count pulses on change")
	await get_tree().create_timer(0.4).timeout
	check(label.scale.is_equal_approx(Vector2.ONE) and ui.discard_pile_view.get_node("Content/Labels/Count").scale.is_equal_approx(Vector2.ONE), "rapid changes settle at original size")
	await capture("finished")
	await verify_exit({"id": &"pummel"}, false)
	await verify_exit({"id": &"bludgeon", "enchants": ["town_bludgeon_1"], "enchant_active": true}, true)
	await verify_exit({"id": &"reaper", "enchants": ["town_reaper_1"], "enchant_active": true}, false)
	print("CARD_PRESENTATION_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _on_presented_hit(targets: Array[int]) -> void:
	if first_hit_frame >= 0: return
	first_hit_frame = Engine.get_process_frames()
	var player: AnimatedSprite2D = ui.player_sprite.get_node("BodyAnimation")
	check(player.animation == &"attack" and player.frame == 2 and player.get_node_or_null("PlayerSlash") != null, "player strike frame and slash coincide with first enemy hit")
	for index in targets:
		var portrait = ui.unit_panels[ui.controller.enemies[index]].get_node("Inner/SpriteRect")
		check(portrait.hit_playing, "enemy hurt starts on the impact frame")
	check(ui.get_node("DamageNumbers/Root").get_child_count() > 0, "damage number appears on the impact frame")

func _on_cast_impact(ok: bool) -> void:
	if not ok: return
	check(first_hit_frame == Engine.get_process_frames(), "first hit and card arrival resolve in the same frame")

func verify_exit(entry: Dictionary, discard: bool) -> void:
	ui.controller.hand = [entry]
	ui.controller.energy = 10
	ui.controller.kiln_heat = 0
	ui._refresh_all()
	await get_tree().process_frame
	var view: CardView = ui.hand_container.get_child(0)
	ui._targeting.on_card_drag_started(view)
	var ghost: Control = ui._ghost
	ui._targeting.cast_card(view, 0)
	var feedback := ui.get_node("CombatFeedback")
	while not feedback.playing_hits: await get_tree().process_frame
	await get_tree().create_timer(0.08).timeout
	await get_tree().process_frame
	check(is_instance_valid(ghost) and ghost.visible and feedback.playing_hits, "%s card exits while attack effects are still playing" % entry.id)
	check(ghost.rotation > 0.0 if discard else is_zero_approx(ghost.rotation) and ghost.modulate.a < 1.0, "%s returns to correct destination" % entry.id)
	await get_tree().create_timer(float(GameData.vfx.card_presentation.discard_seconds)).timeout
	check(not is_instance_valid(ghost) and feedback.playing_hits and BattleDirector.input_locked, "%s card gone before recovery finishes; input remains locked" % entry.id)
	while ui._play_queue.busy(): await get_tree().process_frame
	var pile: Array = ui.controller.discard_pile if discard else ui.controller.exhaust_pile
	check(pile.any(func(c): return is_same(c, entry)) and not BattleDirector.input_locked, "%s actual pile and unlock correct" % entry.id)
