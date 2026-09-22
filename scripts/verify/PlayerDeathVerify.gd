extends Node
## Death presentation, terminal pose, layout and restored death-decision regression.
var failures := 0
var checks := 0
var seen_frames: Array[int] = []
var ui: CombatUI
var body: AnimatedSprite2D

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func _ready() -> void:
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/player_death_verify_save.json"
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.current_node_type = &"combat"
	RunState.create_combat_checkpoint([&"claylump"])
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	body = ui.player_sprite.get_node("BodyAnimation")
	var frames := body.sprite_frames
	check(frames.has_animation(&"death") and frames.get_frame_count(&"death") == 6 and not frames.get_animation_loop(&"death"), "six-frame one-shot death resource loaded")
	body.frame_changed.connect(_inspect_frame)
	body.speed_scale = 0.5
	ui._set_player_pose(&"attack")
	SignalBus.damage_dealt.emit(false, -1, 5)
	ui.controller.player.hp = 0
	ui.controller.check_player_death()
	check(body.animation == &"death" and body.is_playing(), "lethal hit interrupts hurt with collapse")
	check(ui.combat_over and not ui.controller.combat_active() and ui.find_child("ReviveAdButton", true, false) == null, "combat stops immediately; death UI waits")
	_inspect_frame()
	await get_tree().create_timer(0.5).timeout
	var before := body.frame
	SignalBus.unit_died.emit(true, -1)
	SignalBus.combat_death_pending.emit()
	ui.player_sprite.begin_cast_attack(0.2)
	ui.player_sprite.strike_cast_attack()
	ui._on_turn_started(true)
	SignalBus.damage_dealt.emit(false, -1, 5)
	check(before > 0 and body.frame == before and body.animation == &"death", "duplicate death and late attack/hurt/turn callbacks cannot restart collapse")
	await body.animation_finished
	check(ui.player_sprite.death_complete and body.visible and body.frame == 5 and ui.player_sprite.self_modulate.a == 0.0, "last fallen frame remains visible after completion")
	check(seen_frames.size() == 6, "all six frames played")
	check(ui.find_child("ReviveAdButton", true, false) != null, "revive prompt appears only after final hold")
	var prompt := ui._revive_prompt
	SignalBus.combat_death_pending.emit()
	check(ui._revive_prompt == prompt, "duplicate completion does not recreate death UI")
	ui.queue_free()
	await get_tree().process_frame
	# Loading a pending-death checkpoint must finish its presentation as well.
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	body = ui.player_sprite.get_node("BodyAnimation")
	check(body.animation == &"death" and ui.find_child("ReviveAdButton", true, false) == null, "restored death decision also waits for collapse")
	await body.animation_finished
	check(ui.find_child("ReviveAdButton", true, false) != null, "restored death decision opens prompt without hanging")
	ui.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()
	print("PLAYER_DEATH_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _inspect_frame() -> void:
	if body.animation != &"death" or seen_frames.has(body.frame): return
	seen_frames.append(body.frame)
	var frame := body.frame
	var texture := body.sprite_frames.get_frame_texture(&"death", frame) as AtlasTexture
	var bounds := texture.atlas.get_image().get_region(texture.region).get_used_rect()
	var upper := body.to_global(Vector2(bounds.position))
	var lower := body.to_global(Vector2(bounds.end))
	check(upper.x >= 0 and lower.x <= 720 and upper.y >= ui.player_panel.get_global_rect().end.y and lower.y <= ui.hand_container.get_global_rect().position.y, "death frame %d fits screen and clears hand/status UI" % (frame + 1))
	check(ui.find_child("ReviveAdButton", true, false) == null, "death frame %d has no early overlay" % (frame + 1))
	if OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/player_death_frame_%d.png" % (frame + 1))
