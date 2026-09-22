extends Node
## Presentation only. Same-frame impacts share one pulse; rapid hits never queue up.
signal pulse_selected(cue: StringName, duration_ms: int, amplitude: float)

const SETTINGS_PATH := "user://haptic_settings.cfg"
var enabled := true
var config: Dictionary = {}
var _pending: StringName = &""
var _last_pulse_ms := -1
var _background := false
var _ad_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = GameData.vfx["haptics"]
	load_settings()
	SignalBus.haptic_requested.connect(request)
	SignalBus.ad_playback_started.connect(func(_id, _placement):
		_ad_active = true
		clear())
	SignalBus.ad_playback_finished.connect(func(_id, _placement, _result): _ad_active = false)
	set_process(false)


func load_settings() -> void:
	enabled = bool(config["default_enabled"])
	var saved := ConfigFile.new()
	if saved.load(SETTINGS_PATH) == OK:
		var value: Variant = saved.get_value("haptics", "enabled", enabled)
		if value is bool: enabled = value
	if not enabled: clear()


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled: clear()
	var saved := ConfigFile.new()
	saved.set_value("haptics", "enabled", enabled)
	if saved.save(SETTINGS_PATH) != OK: push_warning("Unable to save haptic settings")


func request(cue: StringName) -> void:
	if not enabled or _background or _ad_active or get_tree().paused: return
	var profiles: Dictionary = config["profiles"]
	if not profiles.has(String(cue)): return
	if _pending == &"" or int(profiles[String(cue)]["priority"]) > int(profiles[String(_pending)]["priority"]):
		_pending = cue
	set_process(true)


func _process(_delta: float) -> void:
	var cue := _pending
	clear()
	if cue == &"" or not enabled or _background or _ad_active or get_tree().paused: return
	var now := Time.get_ticks_msec()
	if _last_pulse_ms >= 0 and now - _last_pulse_ms < int(config["minimum_gap_ms"]): return
	var profile: Dictionary = config["profiles"][String(cue)]
	var duration := clampi(int(profile["duration_ms"]), 1, int(config["maximum_duration_ms"]))
	var amplitude := clampf(float(profile["amplitude"]), 0.0, 1.0)
	_last_pulse_ms = now
	if OS.has_feature("android"):
		Input.vibrate_handheld(duration, amplitude)
	# Observes dispatch selection on desktop too; does not claim a physical vibration.
	pulse_selected.emit(cue, duration, amplitude)


func clear() -> void:
	_pending = &""
	set_process(false)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_background = true
		clear()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_background = false
