extends Node

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)


func settle() -> void:
	for frame in 4: await get_tree().process_frame


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://settings_" + label + ".png")


func click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = get_viewport().get_final_transform() * control.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout


func _ready() -> void:
	ProfileManager.autosave_enabled = false
	await settle()
	var menu := preload("res://scenes/main/MainMenu.tscn").instantiate()
	add_child(menu)
	await settle()
	var column := menu.get_node("MenuCenter/MenuColumn")
	var settings := column.get_node("SettingsButton") as Button
	check(settings.get_index() == column.get_node("CompendiumButton").get_index() + 1
		and column.get_node("QuitButton").get_index() == settings.get_index() + 1,
		"settings between compendium and quit")
	check(not menu.has_node("AudioButton"), "old corner entry removed")
	check(get_viewport().get_visible_rect().encloses(column.get_global_rect()), "menu fits portrait")
	await capture("menu")
	await click(settings)
	check(menu.has_node("SettingsPopup"), "real click opens settings")
	var popup := menu.get_node("SettingsPopup")
	var content := popup.get_node("Cover/Center/Panel/Margin/Column")
	check(settings.disabled and column.get_node("PlayButton").disabled, "modal blocks background actions")
	check(content.get_node("AudioSettings").visible and not content.get_node("Graphics").visible, "audio opens by default")
	check(get_viewport().get_visible_rect().encloses(popup.get_node("Cover/Center/Panel").get_global_rect()), "settings panel fits portrait")
	var music := content.get_node("AudioSettings/Music/Slider") as HSlider
	music.value = 37
	check(is_equal_approx(AudioManager.volumes.Music, 0.37), "sound slider applies to audio manager")
	await capture("audio")
	var haptics := content.get_node("AudioSettings/Haptics") as CheckButton
	HapticFeedback.set_enabled(true)
	haptics.set_pressed_no_signal(true)
	await click(haptics)
	check(not HapticFeedback.enabled, "real settings click disables haptics")
	HapticFeedback.load_settings()
	check(not HapticFeedback.enabled, "haptic preference persists independently")
	await click(content.get_node("Tabs/GraphicsTab"))
	check(content.get_node("Graphics").visible and not content.get_node("AudioSettings").visible, "graphics tab switches content")
	var fps := content.get_node("Graphics/FrameLimit/Options") as OptionButton
	var aa := content.get_node("Graphics/Antialiasing/Options") as OptionButton
	fps.select(fps.get_item_index(30))
	fps.item_selected.emit(fps.selected)
	aa.select(aa.get_item_index(Viewport.MSAA_4X))
	aa.item_selected.emit(aa.selected)
	check(Engine.max_fps == 30 and get_viewport().msaa_2d == Viewport.MSAA_4X, "graphics changes reach engine and viewport")
	var saved := ConfigFile.new()
	check(saved.load(GraphicsSettings.SETTINGS_PATH) == OK and saved.get_value("graphics", "frame_limit") == 30
		and saved.get_value("graphics", "antialiasing") == Viewport.MSAA_4X, "graphics preferences persisted")
	GraphicsSettings.frame_limit = 0
	GraphicsSettings.antialiasing = Viewport.MSAA_DISABLED
	GraphicsSettings.load_settings()
	check(Engine.max_fps == 30 and get_viewport().msaa_2d == Viewport.MSAA_4X, "saved preferences restored and applied")
	await capture("graphics")
	if DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(540, 960)
		await settle()
		check(get_viewport().get_visible_rect().encloses(popup.get_node("Cover/Center/Panel").get_global_rect()), "settings fits smaller portrait window")
		await capture("small")
	await click(content.get_node("CloseButton"))
	check(not menu.has_node("SettingsPopup"), "done closes popup")
	check(not settings.disabled and settings.has_focus(), "done restores menu and focus")
	check(saved.load(AudioManager.SETTINGS_PATH) == OK and is_equal_approx(saved.get_value("volume", "Music"), 0.37), "audio persisted on close")
	await click(settings)
	content = menu.get_node("SettingsPopup/Cover/Center/Panel/Margin/Column")
	check(content.get_node("AudioSettings/Music/Slider").value == 37, "reopen restores volume")
	check(content.get_node("Graphics/FrameLimit/Options").get_selected_id() == 30, "reopen restores graphics selection")
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await settle()
	check(not menu.has_node("SettingsPopup") and not settings.disabled, "back closes popup without activating menu")
	# Corrupt or obsolete persisted values must not reach the rendering API.
	saved.clear()
	saved.set_value("graphics", "frame_limit", "bad")
	saved.set_value("graphics", "antialiasing", 999)
	saved.save(GraphicsSettings.SETTINGS_PATH)
	GraphicsSettings.load_settings()
	check(GraphicsSettings.frame_limit == int(ProjectSettings.get_setting_with_override("application/run/max_fps")), "invalid frame limit uses project default")
	check(get_viewport().msaa_2d == Viewport.MSAA_DISABLED, "invalid graphics values fall back safely")
	GraphicsSettings.save_settings()
	menu.queue_free()
	await settle()
	var pause := preload("res://scenes/ui/PauseMenu.tscn").instantiate()
	add_child(pause)
	await settle()
	check(get_viewport().get_visible_rect().encloses(pause.get_node("Center/Panel").get_global_rect()), "pause menu including vibration toggle fits portrait")
	check(not pause.get_node("Center/Panel/Buttons/AudioSettings/Haptics").button_pressed, "pause menu restores shared vibration preference")
	await capture("pause_haptics")
	pause.queue_free()
	await settle()
	# Let the audio thread release streaming voices before this short test exits.
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer: child.stop()
	await get_tree().create_timer(0.2).timeout
	print("SETTINGS_RESULT:", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(0 if failures == 0 else 1)
