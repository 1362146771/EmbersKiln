extends VBoxContainer

func _ready() -> void:
	$Haptics.set_pressed_no_signal(HapticFeedback.enabled)
	$Haptics.toggled.connect(HapticFeedback.set_enabled)
	for bus in ["Master", "SFX", "Music", "Ambience"]:
		var slider := get_node(bus + "/Slider") as HSlider
		slider.set_value_no_signal(float(AudioManager.volumes[bus]) * 100.0)
		_update_label(slider.value, bus)
		slider.value_changed.connect(func(value: float):
			_update_label(value, bus)
			AudioManager.set_volume(StringName(bus), value / 100.0))
		slider.drag_ended.connect(func(changed: bool):
			if changed: SignalBus.sound_requested.emit(&"ui_confirm"))


func _update_label(value: float, bus: String) -> void:
	get_node(bus + "/Value").text = "%d%%" % roundi(value)


func _exit_tree() -> void:
	AudioManager.save_settings()
