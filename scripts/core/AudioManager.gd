extends Node
## Presentation only: never consumes gameplay RNG or delays a gameplay action.
signal cue_played(cue: StringName, variant: int)
signal volumes_changed

const SETTINGS_PATH := "user://audio_settings.cfg"
var config: Dictionary = {}
var volumes: Dictionary = {}
var _cache: Dictionary = {}
var _variants: Dictionary = {}
var _last_played: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _ambience: Array[AudioStreamPlayer] = []
var _ambient_index := 0
var _ambient_cue: StringName = &""
var _ambient_tween: Tween
var _music: Array[AudioStreamPlayer] = []
var _music_index := 0
var _music_cue: StringName = &""
var _music_tween: Tween
var _background := false
var _ad_active := false
var _world_paused := false
var _batch_muted := false
var _hp := -1
var _energy := -1
var _heat := -1
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json"))
	for bus in [&"SFX", &"UI", &"Ambience", &"Music"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	# A limiter catches exceptional simultaneous impacts without flattening assets.
	var limiter := AudioEffectLimiter.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"SFX"), limiter)
	volumes = config.default_volumes.duplicate()
	var saved := ConfigFile.new()
	if saved.load(SETTINGS_PATH) == OK:
		for bus in volumes:
			var value: Variant = saved.get_value("volume", bus, volumes[bus])
			if value is float or value is int: volumes[bus] = clampf(float(value), 0.0, 1.0)
	_apply_volumes()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.3
	_save_timer.timeout.connect(save_settings)
	add_child(_save_timer)
	for i in int(config.voices):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		add_child(player)
		_voices.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Ambience%d" % i
		player.bus = &"Ambience"
		add_child(player)
		_ambience.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.bus = &"Music"
		add_child(player)
		_music.append(player)
	SignalBus.sound_requested.connect(play)
	SignalBus.sound_batch_muted.connect(func(muted): _batch_muted = muted)
	SignalBus.card_drawn.connect(func(_id): play(&"card_draw"))
	SignalBus.card_discarded.connect(func(_id): play(&"card_discard"))
	SignalBus.card_exhausted.connect(func(_id): play(&"card_exhaust"))
	SignalBus.card_played.connect(_card_played)
	SignalBus.combat_started.connect(_combat_started)
	SignalBus.turn_started.connect(func(player):
		if player: play(&"turn_start"))
	SignalBus.turn_ended.connect(func(player):
		if player: play(&"turn_end"))
	SignalBus.player_hp_changed.connect(_hp_changed)
	SignalBus.energy_changed.connect(_energy_changed)
	SignalBus.kiln_heat_changed.connect(_heat_changed)
	SignalBus.relic_gained.connect(func(_id): play(&"relic_gain"))
	SignalBus.construction_started.connect(func(_id): play(&"town_build_start"))
	SignalBus.construction_ready.connect(func(_id): play(&"town_build_ready"))
	SignalBus.construction_claimed.connect(_construction_claimed)
	SignalBus.combat_revive_ready.connect(func(): play(&"revive"))
	SignalBus.card_acquisition_blocked.connect(func(_data): play(&"ui_deny"))
	SignalBus.ad_playback_started.connect(func(_id, _placement): _set_ad(true))
	SignalBus.ad_playback_finished.connect(func(_id, _placement, _result): _set_ad(false))
	SignalBus.ad_reward_resolved.connect(func(_id, _placement, result):
		if result == &"granted": play(&"ad_reward"))
	SignalBus.run_loaded.connect(_reset_baselines)
	SignalBus.run_started.connect(_reset_baselines)
	get_tree().node_added.connect(_node_added)
	_bind_late.call_deferred()


func _bind_late() -> void:
	BattleDirector.enemy_visual_impact.connect(_enemy_impact)
	TransitionManager.scene_revealing.connect(_scene_revealing)
	TransitionManager.transition_started.connect(func(kind):
		if kind == &"panel_open": play(&"ui_open")
		elif kind == &"panel_close": play(&"ui_close"))
	get_tree().scene_changed.connect(_scene_changed)
	_scene_changed()


func stream_for(cue: StringName, variant := 0) -> AudioStream:
	var spec: Dictionary = config.cues.get(String(cue), {})
	if spec.is_empty(): return null
	var paths: Array = spec.files
	var path: String = paths[posmod(variant, paths.size())]
	var cache_key := path + ("|loop" if bool(spec.loop) else "|once")
	if not _cache.has(cache_key):
		var stream := load(path) as AudioStream
		if stream == null: return null
		if bool(spec.loop) and stream is AudioStreamWAV:
			stream = stream.duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		elif bool(spec.loop) and stream is AudioStreamOggVorbis:
			stream = stream.duplicate()
			stream.loop = true
			stream.loop_offset = 0.0
		_cache[cache_key] = stream
	return _cache[cache_key]


func play(cue: StringName) -> void:
	if cue == &"" or _background or _ad_active or _batch_muted: return
	var spec: Dictionary = config.cues.get(String(cue), {})
	if spec.is_empty():
		push_warning("Unknown audio cue: %s" % cue)
		return
	if bool(spec.loop):
		if spec.bus == "Music": set_music(cue)
		else: set_ambience(cue)
		return
	if cue in [&"defeat", &"run_win"]: set_music(&"")
	if get_tree().paused and spec.bus != "UI": return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(cue, -100000)) < float(spec.cooldown) * 1000.0: return
	var voice: AudioStreamPlayer
	for candidate in _voices:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		for candidate in _voices:
			if int(candidate.get_meta("priority", 0)) <= int(spec.priority):
				if voice == null or int(candidate.get_meta("started", 0)) < int(voice.get_meta("started", 0)): voice = candidate
	if voice == null: return
	var variant := int(_variants.get(cue, 0))
	var stream := stream_for(cue, variant)
	if stream == null: return
	voice.stop()
	voice.stream = stream
	voice.bus = StringName(spec.bus)
	voice.volume_db = float(spec.gain_db)
	voice.stream_paused = false
	voice.set_meta("priority", int(spec.priority))
	voice.set_meta("started", now)
	voice.play()
	_last_played[cue] = now
	_variants[cue] = (variant + 1) % spec.files.size()
	cue_played.emit(cue, variant)


func set_ambience(cue: StringName) -> void:
	if cue == _ambient_cue: return
	_ambient_cue = cue
	if _ambient_tween != null and _ambient_tween.is_valid(): _ambient_tween.kill()
	var old := _ambience[_ambient_index]
	_ambient_index = 1 - _ambient_index
	var next := _ambience[_ambient_index]
	next.stop()
	_ambient_tween = create_tween().set_parallel(true)
	_ambient_tween.tween_property(old, "volume_db", -60.0, float(config.ambience_fade_seconds))
	if cue != &"":
		next.stream = stream_for(cue)
		next.volume_db = -60.0
		next.play()
		next.stream_paused = get_tree().paused or _background or _ad_active
		_ambient_tween.tween_property(next, "volume_db", float(config.cues[String(cue)].gain_db), float(config.ambience_fade_seconds))
	_ambient_tween.chain().tween_callback(old.stop)
	if get_tree().paused or _background or _ad_active: _ambient_tween.pause()


func set_music(cue: StringName) -> void:
	if cue == _music_cue: return
	_music_cue = cue
	if _music_tween != null and _music_tween.is_valid(): _music_tween.kill()
	var old := _music[_music_index]
	_music_index = 1 - _music_index
	var next := _music[_music_index]
	next.stop()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(old, "volume_db", -60.0, float(config.music_fade_seconds))
	if cue != &"":
		next.stream = stream_for(cue)
		next.volume_db = -60.0
		next.play()
		next.stream_paused = get_tree().paused or _background or _ad_active
		_music_tween.tween_property(next, "volume_db", float(config.cues[String(cue)].gain_db), float(config.music_fade_seconds))
	_music_tween.chain().tween_callback(old.stop)
	if get_tree().paused or _background or _ad_active: _music_tween.pause()


func music_for_scene(filename: String) -> StringName:
	var act := clampi(RunState.current_act, 0, config.act_music.size() - 1)
	if filename == "CombatPlay.tscn":
		if RunState.current_node_type == &"boss": return StringName(config.boss_music[act])
		if RunState.current_node_type == &"elite": return StringName(config.elite_music)
	if filename == "MapPlay.tscn" and not RunState.is_active: return &""
	return StringName(config.scene_music.get(filename, config.act_music[act]))


func set_volume(bus: StringName, value: float) -> void:
	if not volumes.has(String(bus)): return
	volumes[String(bus)] = clampf(value, 0.0, 1.0)
	_apply_volumes()
	_save_timer.start()
	volumes_changed.emit()


func _apply_volumes() -> void:
	for bus in volumes:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(float(volumes[bus]), 0.00001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"UI"), linear_to_db(maxf(float(volumes.SFX), 0.00001)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), _background or _ad_active or float(volumes.Master) == 0.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"SFX"), float(volumes.SFX) == 0.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"UI"), float(volumes.SFX) == 0.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Ambience"), float(volumes.Ambience) == 0.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), float(volumes.Music) == 0.0)


func save_settings() -> void:
	var file := ConfigFile.new()
	for bus in volumes: file.set_value("volume", bus, volumes[bus])
	if file.save(SETTINGS_PATH) != OK: push_warning("Unable to save audio settings")


func _exit_tree() -> void:
	if not volumes.is_empty(): save_settings()
	for tween in [_ambient_tween, _music_tween]:
		if tween != null and tween.is_valid(): tween.kill()
	for player in _voices + _ambience + _music:
		player.stop()
		player.stream = null
	_cache.clear()


func _process(_delta: float) -> void:
	var paused := get_tree().paused or _background or _ad_active
	if paused == _world_paused: return
	_world_paused = paused
	for voice in _voices:
		if voice.bus != &"UI": voice.stream_paused = paused
	for player in _ambience: player.stream_paused = paused
	for player in _music: player.stream_paused = paused
	if _ambient_tween != null and _ambient_tween.is_valid():
		if paused: _ambient_tween.pause()
		else: _ambient_tween.play()
	if _music_tween != null and _music_tween.is_valid():
		if paused: _music_tween.pause()
		else: _music_tween.play()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_background = true
		if not volumes.is_empty():
			_apply_volumes()
			save_settings()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_background = false
		if not volumes.is_empty(): _apply_volumes()


func _set_ad(active: bool) -> void:
	_ad_active = active
	_apply_volumes()


func _node_added(node: Node) -> void:
	if node is BaseButton: _wire_button.call_deferred(weakref(node))


func _wire_button(ref: WeakRef) -> void:
	var button := ref.get_ref() as BaseButton
	if button == null or button.has_meta("audio_wired"): return
	button.set_meta("audio_wired", true)
	button.pressed.connect(_button_pressed.bind(ref))


func _button_pressed(ref: WeakRef) -> void:
	var button := ref.get_ref() as BaseButton
	if button == null or button.disabled: return
	var cue: String = button.get_meta("sound_cue", config.button_cues.get(String(button.name), "ui_toggle" if button.toggle_mode else "ui_click"))
	play(StringName(cue))


func _scene_changed() -> void:
	if get_tree().current_scene != null: _scene_revealing(get_tree().current_scene)


var _last_scene: WeakRef
func _scene_revealing(scene: Node) -> void:
	if _last_scene != null and _last_scene.get_ref() == scene: return
	_last_scene = weakref(scene)
	scene.tree_exiting.connect(_stop_world_voices, CONNECT_ONE_SHOT)
	_reset_baselines()
	var filename := scene.scene_file_path.get_file()
	var act := clampi(RunState.current_act, 0, config.act_ambience.size() - 1)
	var cue: String = config.scene_ambience.get(filename, config.act_ambience[act])
	set_ambience(StringName(cue))
	set_music(music_for_scene(filename))
	if config.scene_cues.has(filename): play(StringName(config.scene_cues[filename]))
	if filename == "RewardUI.tscn": play(&"victory")


func _stop_world_voices() -> void:
	for voice in _voices:
		if voice.bus == &"SFX": voice.stop()


func _reset_baselines() -> void:
	_hp = RunState.hp
	_energy = -1
	_heat = -1


func _combat_started(_ids: Array) -> void:
	_reset_baselines()
	play(&"combat_start")


func _card_played(id: StringName, _target: int) -> void:
	var card: CardData = GameData.get_card(id)
	if card != null and card.type != &"attack": play(StringName("card_" + String(card.type)))


func _hp_changed(value: int, _maximum: int) -> void:
	if _hp >= 0 and value > _hp: play(&"heal")
	_hp = value


func _energy_changed(value: int, _maximum: int) -> void:
	if _energy >= 0 and value > _energy: play(&"energy_gain")
	_energy = value


func _heat_changed(value: int, _threshold: int) -> void:
	if _heat >= 0 and value > _heat: play(&"heat_gain")
	_heat = value


func _enemy_impact(enemy: CombatUnit) -> void:
	var data: Dictionary = config.enemies.get(String(enemy.id), {})
	play(StringName(data.get("moves", {}).get(String(enemy.intent.get("id", "")), "enemy_hex")))


func _construction_claimed(id: StringName) -> void:
	var grants: Dictionary = GameData.get_meta_project(id).get("grants", {})
	play(&"town_research" if grants.has("unlocked_card_ids") or grants.has("unlocked_potion_ids") or String(id).contains("research") else &"town_upgrade")


func hit_cue(enemy_id: StringName) -> StringName:
	return StringName(config.enemies.get(String(enemy_id), {}).get("hit", "hit_ceramic"))


func enchant_cue(entry: Dictionary) -> StringName:
	if entry.is_empty() or CardMutation.effective_ids(entry).is_empty(): return &""
	var profile: String = GameData.vfx.enchant_attack.card_profiles.get(String(entry.get("id", "")), "")
	return StringName(config.enchant_profiles.get(profile, "enchant_rush"))


func impact_cue(receipt: Dictionary) -> StringName:
	if bool(receipt.get("interrupted", false)): return &"enemy_interrupt"
	if bool(receipt.get("broken", false)): return &"block_break"
	if bool(receipt.get("blocked", false)): return &"block_hit"
	if bool(receipt.get("player", false)): return &"player_hit"
	return hit_cue(StringName(receipt.get("id", "")))
