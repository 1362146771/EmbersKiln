extends Node
## Display preferences are independent of run/profile saves.

const SETTINGS_PATH := "user://graphics_settings.cfg"
const FRAME_LIMITS := [0, 30, 60, 120]
const AA_MODES := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]

var frame_limit: int
var antialiasing: int


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	frame_limit = int(ProjectSettings.get_setting_with_override("application/run/max_fps"))
	antialiasing = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", Viewport.MSAA_DISABLED))
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var fps: Variant = config.get_value("graphics", "frame_limit", frame_limit)
		var aa: Variant = config.get_value("graphics", "antialiasing", antialiasing)
		if fps is int and fps in FRAME_LIMITS:
			frame_limit = fps
		if aa is int and aa in AA_MODES:
			antialiasing = aa
	_apply()


func set_frame_limit(value: int) -> void:
	if value not in FRAME_LIMITS: return
	frame_limit = value
	_apply()
	save_settings()


func set_antialiasing(value: int) -> void:
	if value not in AA_MODES: return
	antialiasing = value
	_apply()
	save_settings()


func _apply() -> void:
	Engine.max_fps = frame_limit
	get_viewport().msaa_2d = antialiasing as Viewport.MSAA


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "frame_limit", frame_limit)
	config.set_value("graphics", "antialiasing", antialiasing)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("Unable to save graphics settings")
