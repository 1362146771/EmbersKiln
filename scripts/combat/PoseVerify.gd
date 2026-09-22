extends Node
## Production player animation events and interruption regression.
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("[PASS] " if condition else "[FAIL] ", message)

func _ready() -> void:
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/pose_verify_save.json"
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	var ui := preload("res://scenes/combat/CombatPlay.tscn").instantiate() as CombatUI
	add_child(ui)
	await get_tree().process_frame
	var portrait := ui.player_sprite
	var body := portrait.get_node("BodyAnimation") as AnimatedSprite2D
	check(not body.visible and portrait.self_modulate.a == 1.0, "idle uses original portrait")
	check(body.material == null and portrait.material == null, "baked portrait palette has no second runtime color correction")
	for action in [&"attack", &"hurt"]:
		var frames := body.sprite_frames
		var expected_count := 8 if action == &"attack" else 30
		check(frames.get_frame_count(action) == expected_count and frames.get_animation_speed(action) == 30.0 and not frames.get_animation_loop(action), "%s: %d frames, 30 fps timeline, one shot" % [action, expected_count])
		var duration := 0.0
		for i in range(frames.get_frame_count(action)):
			duration += frames.get_frame_duration(action, i) / frames.get_animation_speed(action)
		check(is_equal_approx(duration, 1.4 if action == &"attack" else 1.0), "%s has intended duration" % action)
		var contained := true
		var native_hd := true
		for i in range(frames.get_frame_count(action)):
			native_hd = native_hd and frames.get_frame_texture(action, i).get_size() == Vector2(768, 768)
			var bounds := frames.get_frame_texture(action, i).get_image().get_used_rect()
			var upper := body.to_global(Vector2(bounds.position))
			var lower := body.to_global(Vector2(bounds.end))
			contained = contained and upper.x >= 0 and lower.x <= 720 and upper.y >= ui.player_panel.get_global_rect().end.y and lower.y <= ui.hand_container.get_global_rect().position.y
		check(contained, "%s: all frames fit between status panel and hand" % action)
		check(native_hd, "%s: all runtime frames use HD 768px textures" % action)
	var texture_scale := minf(portrait.size.x / portrait.texture.get_width(), portrait.size.y / portrait.texture.get_height())
	var inset := (portrait.size - portrait.texture.get_size() * texture_scale) * 0.5
	var static_foot: Vector2 = portrait.get_global_transform() * (inset + portrait.idle_right_foot * texture_scale)
	check(body.to_global(portrait.frame_right_foot).distance_to(static_foot) < 0.01, "animation right foot matches static portrait contact point")
	var attack_id := &"strike"
	for id in GameData.cards:
		if GameData.get_card(id).type == &"attack":
			attack_id = id
			break
	SignalBus.card_played.emit(attack_id, 0)
	check(body.visible and body.animation == &"attack" and body.is_playing(), "attack card starts animation")
	await get_tree().create_timer(0.4).timeout
	check(body.frame > 0, "attack advances frames")
	SignalBus.card_played.emit(attack_id, 0)
	check(body.frame == 0, "repeated attack restarts at frame zero")
	await get_tree().create_timer(0.75).timeout
	check(body.visible and body.is_playing(), "old pose timer cannot truncate repeated attack")
	await get_tree().create_timer(0.75).timeout
	check(not body.visible and portrait.self_modulate.a == 1.0, "attack completion restores idle")
	SignalBus.card_played.emit(&"defend", -1)
	check(not body.visible, "skill card does not swing axe")
	SignalBus.damage_dealt.emit(false, -1, 0)
	check(not body.visible, "zero damage does not trigger hurt")
	SignalBus.card_played.emit(attack_id, 0)
	SignalBus.damage_dealt.emit(false, -1, 5)
	check(body.animation == &"hurt" and body.visible, "player damage interrupts attack with hurt")
	await get_tree().create_timer(0.35).timeout
	SignalBus.damage_dealt.emit(false, -1, 5)
	check(body.frame == 0, "consecutive damage restarts hurt")
	ui._on_turn_started(true)
	check(body.is_playing() and body.visible, "turn refresh preserves hurt animation")
	await get_tree().create_timer(1.1).timeout
	check(not body.visible, "hurt completion restores idle")
	await capture(ui, body, &"attack", 2)
	await capture(ui, body, &"hit", 8)
	await capture(ui, body, &"idle", 0)
	SignalBus.unit_died.emit(true, -1)
	check(body.visible and body.animation == &"death" and body.is_playing(), "death starts collapse animation")
	SignalBus.card_played.emit(attack_id, 0)
	SignalBus.damage_dealt.emit(false, -1, 5)
	ui._on_turn_started(true)
	check(ui._player_dead and body.visible and body.animation == &"death", "death rejects later poses")
	await get_tree().create_timer(0.4).timeout
	var death_frame := body.frame
	SignalBus.unit_died.emit(true, -1)
	portrait.begin_cast_attack(0.2)
	portrait.strike_cast_attack()
	check(death_frame > 0 and body.frame == death_frame and body.animation == &"death", "duplicate death and late attack callbacks cannot restart or interrupt collapse")
	await body.animation_finished
	check(portrait.death_complete and body.visible and body.frame == 5 and portrait.self_modulate.a == 0.0, "completed death retains final fallen pose")
	await capture(ui, body, &"death", 5)
	ui.queue_free()
	await get_tree().process_frame
	var legacy := CombatUI.new()
	add_child(legacy)
	await get_tree().process_frame
	legacy._set_player_pose(&"attack")
	check(legacy.player_sprite.get_node("BodyAnimation").is_playing(), "CombatUI.new reuses animated scene")
	legacy.queue_free()
	await get_tree().process_frame
	print("POSE_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func capture(ui: CombatUI, body: AnimatedSprite2D, pose: StringName, frame: int) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	ui._set_player_pose(pose)
	body.pause()
	body.frame = frame
	await RenderingServer.frame_post_draw
	var path := "res://Temp/player_%s_integrated.png" % pose
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE: ", path)
