extends Node
var failures := 0
var checks := 0
var heard: Array[StringName] = []
var variants: Array[int] = []
var ui: CombatUI

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func reset_audio() -> void:
	heard.clear()
	variants.clear()
	AudioManager._last_played.clear()
	AudioManager._background = false
	AudioManager._apply_volumes()

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func(): get_tree().quit(2))
	await get_tree().process_frame
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/audio_save.json"
	AudioManager.cue_played.connect(func(cue, variant): heard.append(cue); variants.append(variant))
	reset_audio()
	var file_count := 0
	for id in AudioManager.config.cues:
		var spec: Dictionary = AudioManager.config.cues[id]
		for variant in spec.files.size():
			var stream := AudioManager.stream_for(StringName(id), variant)
			check(stream != null and stream.get_length() > 0.0, "stream %s/%d" % [id, variant])
			if bool(spec.loop):
				var looping: bool = stream is AudioStreamOggVorbis and stream.loop or stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > stream.loop_begin
				check(looping, "loop metadata " + id)
			check(String(spec.files[variant]).begins_with("res://art/audio/sts/"), "STS source " + id)
			file_count += 1
	check(file_count == int(AudioManager.config.runtime_file_count), "all mapped STS files are runtime resources")
	for id in AudioManager.config.enemies:
		var enemy := CombatUnit.new()
		enemy.id = StringName(id)
		for move in AudioManager.config.enemies[id].moves:
			reset_audio()
			enemy.intent = {"id": move}
			BattleDirector.enemy_visual_impact.emit(enemy)
			check(heard.has(StringName(AudioManager.config.enemies[id].moves[move])), "enemy action " + id + "/" + move)
	reset_audio()
	AudioManager.play(&"hit_ceramic")
	AudioManager.play(&"hit_ceramic")
	check(heard.size() == 1, "same-frame duplicates are limited")
	var first: int = variants.back()
	# Audio cooldown uses wall time; accelerated headless frames are not wall time.
	var after_cooldown := Time.get_ticks_msec() + 70
	while Time.get_ticks_msec() < after_cooldown: await get_tree().process_frame
	AudioManager.play(&"hit_ceramic")
	check(heard.count(&"hit_ceramic") == 2 and variants.back() == (first + 1) % 3, "round-robin variant without gameplay RNG")
	seed(8241)
	var expected := randi()
	seed(8241)
	AudioManager._last_played.clear()
	AudioManager.play(&"axe_swing")
	check(randi() == expected, "sound does not consume global gameplay random state")
	AudioManager.set_ambience(&"amb_rest")
	var ambient := AudioManager._ambience[AudioManager._ambient_index]
	check(ambient.playing, "ambient stream running")
	AudioManager.set_music(&"music_menu")
	var music := AudioManager._music[AudioManager._music_index]
	check(music.playing and music.bus == &"Music", "music has independent playback and bus")
	AudioManager.set_music(&"music_menu")
	check(AudioManager._music[AudioManager._music_index] == music, "same scene track does not restart")
	for act in 4:
		RunState.current_act = act
		RunState.current_node_type = &"boss"
		check(AudioManager.music_for_scene("CombatPlay.tscn") == StringName(AudioManager.config.boss_music[act]), "boss soundtrack for act %d" % act)
		RunState.current_node_type = &"combat"
		check(AudioManager.music_for_scene("CombatPlay.tscn") == StringName(AudioManager.config.act_music[act]), "normal soundtrack for act %d" % act)
	RunState.current_node_type = &"elite"
	check(AudioManager.music_for_scene("CombatPlay.tscn") == &"music_elite", "elite soundtrack")
	check(AudioManager.music_for_scene("MainMenu.tscn") == &"music_menu" and AudioManager.music_for_scene("RestUI.tscn") == &"music_rest", "menu and camp soundtrack")
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	reset_audio()
	AudioManager.play(&"enemy_slam")
	AudioManager.play(&"ui_click")
	check(ambient.stream_paused and heard == [&"ui_click"], "pause suspends world while menus stay audible")
	check(music.stream_paused, "pause suspends music position")
	var settings := preload("res://scenes/ui/AudioSettings.tscn").instantiate()
	add_child(settings)
	settings.get_node("SFX/Slider").value = 0
	AudioManager.save_settings()
	var saved := ConfigFile.new()
	check(saved.load(AudioManager.SETTINGS_PATH) == OK and saved.get_value("volume", "SFX") == 0.0, "slider persists mute while paused")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"UI")) and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")), "sound mute includes UI and combat")
	settings.get_node("SFX/Slider").value = 100
	settings.get_node("Music/Slider").value = 0
	AudioManager.save_settings()
	saved.load(AudioManager.SETTINGS_PATH)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")) and saved.get_value("volume", "Music") == 0.0, "music mute independent and persisted")
	settings.get_node("Music/Slider").value = 50
	settings.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	await get_tree().process_frame
	check(not ambient.stream_paused, "resume restores existing ambient position")
	check(not music.stream_paused, "resume restores existing music position")
	reset_audio()
	SignalBus.ad_playback_started.emit("audio-test", &"audio-test")
	SignalBus.sound_requested.emit(&"ui_click")
	check(heard.is_empty() and AudioServer.is_bus_mute(0), "ad suppresses UI and world")
	SignalBus.ad_playback_finished.emit("audio-test", &"audio-test", &"failed")
	check(not AudioServer.is_bus_mute(0), "failed ad restores user mute settings")
	AudioManager._notification(NOTIFICATION_APPLICATION_PAUSED)
	check(AudioServer.is_bus_mute(0), "background mute")
	AudioManager._notification(NOTIFICATION_APPLICATION_RESUMED)
	check(not AudioServer.is_bus_mute(0), "foreground restore")
	reset_audio()
	SignalBus.sound_batch_muted.emit(true)
	SignalBus.sound_requested.emit(&"relic_gain")
	SignalBus.sound_batch_muted.emit(false)
	check(heard.is_empty(), "uncommitted reward batch stays silent")
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_combat_enemy_ids = [&"claylump"]
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	ui.controller.enemies[0].hp = 500
	ui.controller.enemies[0].max_hp = 500
	await play_twin(false)
	await play_twin(true)
	reset_audio()
	ui.controller._status.apply_status(ui.controller.player, &"damp", 2)
	ui.controller._status.apply_status(ui.controller.player, &"damp", -1)
	check(heard.count(&"status_damp") == 1, "status gain sounds once; reduction stays silent")
	reset_audio()
	check(not ui.controller.use_potion(-1), "invalid potion rejected")
	check(not heard.has(&"potion_use"), "invalid potion has no success sound")
	ui.queue_free()
	await get_tree().process_frame
	var menu := preload("res://scenes/main/MainMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.get_node("MenuCenter/MenuColumn/SettingsButton").pressed.emit()
	await get_tree().create_timer(0.5).timeout
	check(menu.has_node("SettingsPopup"), "main menu opens settings with audio controls")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://audio_settings.png")
	menu.get_node("SettingsPopup").queue_free()
	await get_tree().process_frame
	PauseManager._open_pause()
	await get_tree().create_timer(0.4).timeout
	var panel: Control = PauseManager._overlay.get_node("Center/Panel")
	check(get_viewport().get_visible_rect().encloses(panel.get_global_rect()), "pause settings and actions fit portrait viewport")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://audio_pause.png")
	PauseManager._close_pause()
	menu.queue_free()
	await get_tree().process_frame
	while TransitionManager.is_transitioning: await get_tree().process_frame
	for effect in [&"boss", &"chapter"]:
		var error := TransitionManager.change_scene_to_file("res://scenes/main/MainMenu.tscn", func(): return ERR_BUSY, 0.0, effect)
		check(error == OK, "special transition request accepted: " + String(effect))
		while TransitionManager.is_transitioning: await get_tree().process_frame
		var expected_stream: AudioStream = TransitionManager._boss_sound if effect == &"boss" else TransitionManager._chapter_sound
		check(TransitionManager._sound.stream == expected_stream and expected_stream.resource_path.begins_with("res://art/audio/sts/"), "STS transition audio: " + String(effect))
		check(TransitionManager._sound.bus == &"SFX", "transition follows SFX volume")
	print("AUDIO_RESULT:%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func play_twin(blocked: bool) -> void:
	ui.controller.enemies[0].block = 999 if blocked else 0
	ui.controller.hand = [{"id": &"twin_strike", "upgraded": false}]
	ui.controller.energy = ui.controller.max_energy
	ui._refresh_all()
	await get_tree().process_frame
	reset_audio()
	var view: CardView = ui.hand_container.get_child(0)
	ui._targeting.on_card_drag_started(view)
	ui._targeting.cast_card(view, 0)
	check(not heard.has(&"hit_clay") and not heard.has(&"block_hit"), "no hit sound during card flight")
	while ui._play_queue.busy(): await get_tree().process_frame
	var cue := &"block_hit" if blocked else &"hit_clay"
	check(heard.count(cue) == 2, "two actual hit beats: " + String(cue))
	check(ui.controller.enemies[0].is_alive(), "audio does not change outcome")
