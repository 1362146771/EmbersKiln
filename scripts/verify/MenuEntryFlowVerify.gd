extends Node
var failed := 0
const MENU := "res://scenes/main/MainMenu.tscn"
const COMBAT := "res://scenes/combat/CombatPlay.tscn"
const TOWN := "res://scenes/town/Town.tscn"
func check(ok: bool, title: String) -> void:
	if not ok: failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", title])
func settle() -> void:
	for i in 15: await get_tree().process_frame
func open_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await settle()
func _ready() -> void:
	# Keep this harness alive across real scene transitions.
	get_tree().current_scene = null
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/menu_entry_verify.json"
	SaveManager.delete_save()
	ProfileState.reset_to_defaults(false)
	await open_scene(MENU)
	var menu = get_tree().current_scene
	check(menu.find_child("TownButton", true, false) == null, "town removed from authored menu")
	check(menu.get_node("MenuCenter/MenuColumn/PlayButton").text == "开始游戏", "fresh profile shows start")
	check(menu.find_child("NewGameButton", true, false) == null and menu.find_child("ContinueButton", true, false) == null, "single authored entry replaces separate new and continue buttons")
	menu.get_node("MenuCenter/MenuColumn/PlayButton").pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == COMBAT, "first start directly enters combat")
	check(ProfileState.first_battle_started and RunState.has_combat_checkpoint(), "first battle recorded and checkpoint saved")
	check(RunState.current_map()[0][0].visited, "first encounter is an actual visited map node")
	var run_id := RunState.run_id
	var snapshot := RunState.combat_checkpoint.duplicate(true)
	var hand = get_tree().current_scene.controller.hand.duplicate(true)
	RunState.hp = 1
	RunState.gold += 123
	RunState.potions.clear()
	RunState.deck.pop_back()
	check(SaveManager.save_game(), "mid-combat save writes to disk")
	await open_scene(MENU)
	check(get_tree().current_scene.get_node("MenuCenter/MenuColumn/PlayButton").text == "继续游戏", "active combat save shows continue")
	get_tree().current_scene.get_node("MenuCenter/MenuColumn/PlayButton").pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == COMBAT, "continue routes battle save directly to combat")
	check(RunState.run_id == run_id and RunState.hp == int(snapshot.hp) and RunState.gold == int(snapshot.gold), "run and opening resources restored")
	check(RunState.deck.size() == snapshot.deck.size() and RunState.potions.size() == snapshot.potions.size(), "opening inventory restored")
	check(get_tree().current_scene.controller.hand == hand, "same seed reproduces opening hand")
	var restored_enemies: Array = []
	for enemy in get_tree().current_scene.controller.enemies:
		restored_enemies.append(String(enemy.id))
	check(restored_enemies == snapshot.enemy_ids, "same enemy encounter restored")
	check(ProfileManager.save_to_file("res://Temp/menu_entry_profile.json", ProfileState.to_save_dict()), "first battle flag written to permanent profile file")
	ProfileState.reset_to_defaults(false)
	check(ProfileState.from_save_dict(ProfileManager.load_from_file("res://Temp/menu_entry_profile.json"), false) and ProfileState.first_battle_started, "first battle flag survives profile reload")
	get_tree().current_scene.controller.finalize_player_death()
	await settle()
	check(get_tree().current_scene.scene_file_path == TOWN, "final defeat directly returns town")
	check(not RunState.is_active and not SaveManager.has_save(), "defeat ends run and removes run save")
	var town_profile := ProfileState.to_save_dict().duplicate(true)
	await open_scene(MENU)
	check(get_tree().current_scene.get_node("MenuCenter/MenuColumn/PlayButton").text == "开始游戏", "profile without active run shows start after defeat")
	get_tree().current_scene.get_node("MenuCenter/MenuColumn/PlayButton").pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == TOWN, "start with only profile returns town")
	await open_scene(MENU)
	get_tree().current_scene.get_node("MenuCenter/MenuColumn/PlayButton").pressed.emit()
	await settle()
	check(ProfileState.to_save_dict() == town_profile, "repeated start preserves the same permanent town progress")
	check(get_tree().current_scene.scene_file_path == TOWN and not RunState.is_active, "later starts route through town without creating a run")
	get_tree().current_scene._on_depart()
	await settle()
	check(RunState.is_active and get_tree().current_scene.scene_file_path != COMBAT, "town departure starts normal map/preparation flow")
	run_id = RunState.run_id
	RunState.gold = 17
	SaveManager.save_game()
	await open_scene(MENU)
	check(get_tree().current_scene.get_node("MenuCenter/MenuColumn/PlayButton").text == "继续游戏", "active noncombat save shows continue")
	get_tree().current_scene.get_node("MenuCenter/MenuColumn/PlayButton").pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == TOWN, "noncombat save continues in town")
	get_tree().current_scene._on_depart()
	await settle()
	check(RunState.run_id == run_id and RunState.gold == 17, "departing town resumes existing noncombat run")
	var legacy := ProfileState.to_save_dict()
	legacy.version = 5
	legacy.erase("first_battle_started")
	check(ProfileState.from_save_dict(legacy, false) and ProfileState.first_battle_started, "legacy profiles migrate as returning players")
	SaveManager.delete_save()
	print("MENU_ENTRY_FLOW_RESULT FAIL=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
