extends Node
var failed := 0
const MENU := "res://scenes/main/MainMenu.tscn"
const COMBAT := "res://scenes/combat/CombatPlay.tscn"
const TOWN := "res://scenes/town/Town.tscn"
const MAP := "res://scenes/map/MapPlay.tscn"
const OPENING := "res://scenes/main/PreRunPreparation.tscn"
const AD := "res://scenes/main/PreRunAdPreparation.tscn"
func check(ok: bool, title: String) -> void:
	if not ok: failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", title])
func settle() -> void:
	for i in 15: await get_tree().process_frame
	var current := get_tree().current_scene
	while is_instance_valid(current) and current.scene_file_path == MENU and current.get("_menu_busy"):
		await get_tree().process_frame
	while TransitionManager.is_transitioning: await get_tree().process_frame
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
	check(get_tree().current_scene.scene_file_path == OPENING, "first start directly enters Granny dialogue")
	var free_offer: Dictionary = RunState.granny_opening["offers"][0]
	if String(free_offer["kind"]) in ["upgrade", "remove", "transform"]:
		check(GrannyStory.claim(String(free_offer["id"]), 0, RunState.deck[0].duplicate(true)), "claim target opening reward")
	else:
		check(GrannyStory.claim(String(free_offer["id"])), "claim opening reward")
	get_tree().current_scene._depart()
	await settle()
	check(get_tree().current_scene.scene_file_path == AD, "farewell opens original ad preparation")
	get_tree().current_scene.get_node("%SkipButton").pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == MAP, "opening reward leads to route selection")
	get_tree().current_scene._on_node_pressed(0, 0)
	await settle()
	check(get_tree().current_scene.scene_file_path == COMBAT, "first route node enters combat")
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
	var fake := FakeRewardedAdProvider.new()
	fake.set_available(&"death_revive", true)
	fake.enqueue_result(AdService.RESULT_COMPLETED)
	AdService.set_provider(fake)
	get_tree().current_scene.controller.player.hp = 0
	get_tree().current_scene.controller.check_player_death()
	check(RunState.combat_death_pending and RunState.is_active, "first death offers revive without ending run")
	var dead_ui := get_tree().current_scene as CombatUI
	check(dead_ui.find_child("ReviveAdButton", true, false) == null, "revive UI remains absent when collapse starts")
	var dead_body := dead_ui.player_sprite.get_node("BodyAnimation") as AnimatedSprite2D
	dead_body.speed_scale = 0.5
	await get_tree().create_timer(0.6).timeout
	check(not dead_ui.player_sprite.death_complete and dead_ui.find_child("ReviveAdButton", true, false) == null, "revive UI waits for actual animation completion at slower playback speed")
	await dead_body.animation_finished
	var revive_button := get_tree().current_scene.find_child("ReviveAdButton", true, false) as Button
	check(revive_button != null and not revive_button.disabled, "first death shows available revive button")
	if revive_button != null:
		revive_button.pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == COMBAT and RunState.revive_used_count == 1 and not RunState.combat_death_pending, "completed ad reloads combat and consumes revive")
	get_tree().current_scene.controller.player.hp = 0
	get_tree().current_scene.controller.check_player_death()
	dead_ui = get_tree().current_scene as CombatUI
	dead_body = dead_ui.player_sprite.get_node("BodyAnimation") as AnimatedSprite2D
	check(dead_body.animation == &"death" and not dead_ui.player_sprite.death_complete, "second death also starts collapse before result transition")
	await get_tree().create_timer(0.5).timeout
	check(get_tree().current_scene == dead_ui and not dead_ui.player_sprite.death_complete, "final result cannot replace combat during collapse")
	await dead_body.animation_finished
	await settle()
	check(get_tree().current_scene.scene_file_path == MAP, "second death opens result scene instead of town")
	check(get_tree().current_scene.find_child("ReviveAdButton", true, false) == null, "second death does not offer another revive")
	var return_town := get_tree().current_scene.find_child("ReturnTownButton", true, false) as Button
	check(return_town != null and return_town.is_visible_in_tree() and not return_town.disabled, "death result shows return town button")
	check(RunState.run_id == run_id and RunState.run_end_base_settled, "death result preserves original run and settled rewards")
	check(not RunState.is_active and not SaveManager.has_save(), "defeat ends run and removes run save")
	if return_town != null:
		return_town.pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == TOWN, "confirming death result returns town")
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
	check(RunState.is_active and get_tree().current_scene.scene_file_path == OPENING, "town departure starts opening reward")
	run_id = RunState.run_id
	RunState.gold = 17
	SaveManager.save_game()
	await open_scene(MENU)
	check(get_tree().current_scene.get_node("MenuCenter/MenuColumn/PlayButton").text == "继续游戏", "active noncombat save shows continue")
	get_tree().current_scene.get_node("MenuCenter/MenuColumn/PlayButton").pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == OPENING, "unresolved opening resumes directly")
	var pending_offer: Dictionary = RunState.granny_opening["offers"][0]
	if String(pending_offer["kind"]) in ["upgrade", "remove", "transform"]:
		GrannyStory.claim(String(pending_offer["id"]), 0, RunState.deck[0].duplicate(true))
	else:
		GrannyStory.claim(String(pending_offer["id"]))
	var expected_gold := RunState.gold
	get_tree().current_scene._depart()
	await settle()
	check(RunState.run_id == run_id and RunState.gold == expected_gold, "departing opening resumes existing run and granted reward")
	var legacy := ProfileState.to_save_dict()
	legacy.version = 5
	legacy.erase("first_battle_started")
	check(ProfileState.from_save_dict(legacy, false) and ProfileState.first_battle_started, "legacy profiles migrate as returning players")
	SaveManager.delete_save()
	print("MENU_ENTRY_FLOW_RESULT FAIL=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
