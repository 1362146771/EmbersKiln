extends Node
## Runs only in the isolated copy created by tools/build_android.py.
var failures := 0
var checks := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.get_cmdline_user_args().has("--android-verify"):
		return
	var project_path := ProjectSettings.globalize_path("res://").replace("\\", "/")
	if not project_path.contains("/Temp/android-build-") or not OS.get_user_data_dir().replace("\\", "/").begins_with(project_path):
		get_tree().quit(2)
		return
	_run.call_deferred()

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("ANDROID_CHECK:%s %s" % ["PASS" if passed else "FAIL", label])

func _run() -> void:
	get_tree().create_timer(100.0, true, false, true).timeout.connect(func(): get_tree().quit(2))
	check("game data loads", GameData.is_loaded and GameData.load_errors.is_empty())
	check("portrait configured", ProjectSettings.get_setting("display/window/handheld/orientation") == DisplayServer.SCREEN_PORTRAIT)
	check("back does not automatically quit", not ProjectSettings.get_setting("application/config/quit_on_go_back"))
	check("no test bridge or MCP autoload in export copy", not get_tree().root.has_node("TestBridge") and not get_tree().root.has_node("_mcp_game_helper"))
	check("application icon loads", ResourceLoader.exists(ProjectSettings.get_setting("application/config/icon")))
	for file in GameData.FILES.values():
		check("JSON " + file, FileAccess.file_exists("res://data/" + file))
		_check_resources(JSON.parse_string(FileAccess.get_file_as_string("res://data/" + file)))
	_check_resources(GameData.vfx)
	_check_resources(JSON.parse_string(FileAccess.get_file_as_string("res://data/town_visuals.json")))
	_check_resources(JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json")))
	for enemy in GameData.enemies.values():
		check("enemy sprite " + String(enemy.id), enemy.sprite_texture() != null)
	var import_fixture := "res://data/testing/android_assets.json"
	if FileAccess.file_exists(import_fixture):
		for entry in JSON.parse_string(FileAccess.get_file_as_string(import_fixture)):
			var texture := load(String(entry.path)) as Texture2D
			check("import dimensions " + String(entry.path), texture != null and texture.get_width() == int(entry.width) and texture.get_height() == int(entry.height))
	for card in GameData.cards.values():
		var path: String = card.art
		if not path.is_empty():
			check("card art " + String(card.id), ResourceLoader.exists(path))
	get_tree().current_scene._on_play()
	await _wait_transition()
	if not await _complete_opening():
		_finish()
		return
	var battle := get_tree().current_scene
	check("first battle starts", battle is CombatUI and RunState.has_combat_checkpoint())
	if not battle is CombatUI:
		_finish()
		return
	var original_checkpoint := JSON.stringify(RunState.combat_checkpoint)
	check("initial save writes", SaveManager.save_game())
	check("existing save replaced", SaveManager.save_game())
	check("replacement leaves no temporary file", not FileAccess.file_exists(SaveManager.runtime_save_path + ".tmp"))
	var saved := SaveManager.load_from_file(SaveManager.runtime_save_path)
	check("save is readable", saved.get("run_id") == RunState.run_id)
	var view := battle.hand_container.get_child(0) as CardView
	var hand_size: int = battle.controller.hand.size()
	var energy: int = battle.controller.energy
	view._pressing = true
	view._update_drag_position(view.get_global_rect().get_center())
	check("drag starts", battle._drag_active and is_instance_valid(battle._ghost))
	PauseManager.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check("pause immediately cancels gesture", not view._pressing and not view._dragging)
	await _wait_transition()
	check("Android back opens pause", get_tree().paused and PauseManager._open)
	check("pause cancels drag", not battle._drag_active and battle._ghost == null)
	check("pause preserves hand views", battle.hand_container.get_child_count() == hand_size)
	check("cancel does not play or discard", battle.controller.hand.size() == hand_size and battle.controller.energy == energy)
	PauseManager.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _wait_transition()
	check("Android back resumes", not get_tree().paused and not PauseManager._open)
	view = battle.hand_container.get_child(0) as CardView
	view._pressing = true
	view._update_drag_position(view.get_global_rect().get_center())
	check("drag restarts after pause", battle._drag_active and is_instance_valid(battle._ghost))
	SaveManager.notification(NOTIFICATION_APPLICATION_PAUSED)
	PauseManager.notification(NOTIFICATION_APPLICATION_PAUSED)
	await _wait_transition()
	check("background opens pause", get_tree().paused and PauseManager._open)
	check("background cancels drag without losing cards", not battle._drag_active and battle._ghost == null and battle.hand_container.get_child_count() == hand_size and battle.controller.hand.size() == hand_size and battle.controller.energy == energy)
	check("background preserves combat checkpoint", JSON.stringify(RunState.combat_checkpoint) == original_checkpoint)
	check("background save remains readable", not SaveManager.load_from_file(SaveManager.runtime_save_path).is_empty())
	PauseManager.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _wait_transition()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://android-combat.png")
		for sample in ["res://art/cards/illustrations/CARD_strike.png", "res://art/backgrounds/BG_Combat_KilnMouth.png", "res://art/enemies/SPR_Enemy_Ashcantor.png"]:
			(load(sample) as Texture2D).get_image().save_png("user://quality-" + sample.get_file())
	PauseManager._on_save_to_menu()
	await _wait_transition()
	check("return to menu", get_tree().current_scene.scene_file_path == "res://scenes/main/MainMenu.tscn")
	get_tree().current_scene._on_play()
	await _wait_transition()
	check("continue restores combat", get_tree().current_scene is CombatUI and RunState.has_combat_checkpoint())
	_finish()

func _check_resources(value: Variant) -> void:
	if value is Dictionary:
		for item in value.values():
			_check_resources(item)
	elif value is Array:
		for item in value:
			_check_resources(item)
	elif value is String and value.begins_with("res://"):
		check("dynamic resource " + value, ResourceLoader.exists(value))

func _wait_transition() -> void:
	# Scene routing can be deferred from _ready() (Granny -> ad -> map).
	for frame in 15:
		await get_tree().process_frame
	while TransitionManager.is_transitioning:
		await get_tree().process_frame

func _complete_opening() -> bool:
	var opening := get_tree().current_scene
	check("first start opens Granny", opening.scene_file_path == "res://scenes/main/PreRunPreparation.tscn")
	if opening.scene_file_path != "res://scenes/main/PreRunPreparation.tscn":
		return false
	opening._talk()
	var choice: Dictionary = {}
	for offer in RunState.granny_opening.get("offers", []):
		if GrannyStory.blocked_reason(offer).is_empty() and String(offer.get("kind", "")) not in ["upgrade", "remove", "transform"]:
			choice = offer
			break
	check("opening has a usable reward", not choice.is_empty())
	if choice.is_empty():
		return false
	opening._choose(String(choice["id"]))
	check("opening reward claimed", GrannyStory.chosen())
	if not GrannyStory.chosen():
		return false
	opening._depart()
	await _wait_transition()
	var preparation := get_tree().current_scene
	check("farewell opens ad preparation", preparation.scene_file_path == "res://scenes/main/PreRunAdPreparation.tscn")
	if preparation.scene_file_path != "res://scenes/main/PreRunAdPreparation.tscn":
		return false
	preparation.get_node("%SkipButton").pressed.emit()
	await _wait_transition()
	var map := get_tree().current_scene
	check("skip preparation opens map", map.scene_file_path == "res://scenes/map/MapPlay.tscn")
	if map.scene_file_path != "res://scenes/map/MapPlay.tscn":
		return false
	map._on_node_pressed(0, 0)
	await _wait_transition()
	return true

func _finish() -> void:
	# Let the active battle cancel its coroutines/tweens before shutting down.
	get_tree().paused = false
	var scene := get_tree().current_scene
	get_tree().current_scene = null
	if is_instance_valid(scene):
		scene.queue_free()
	# Flush audio playback cleanup while the tree/audio server are still running.
	AudioManager.queue_free()
	for frame in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	print("ANDROID_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
