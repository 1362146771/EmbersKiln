extends Node
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("[FAIL] ", label)

func _ready() -> void:
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/difficulty_run.json"
	ProfileState.reset_to_defaults(false)
	check(GameData.is_loaded, "data valid")
	check(not RunState.start_new_run("extreme"), "locked difficulty rejected")
	RunState.start_new_run()
	var initial := RunState.to_save_dict()
	check(not RunState.start_new_run("extreme") and RunState.to_save_dict() == initial, "locked request preserves live run")
	var roller := IntentRoller.new()
	for config in DifficultyRules.tiers():
		var id := String(config.id)
		check(RunState.start_new_run(id), "progressive unlock " + id)
		var snapshot := RunState.difficulty_snapshot.duplicate(true)
		for act in GameData.act_configs.size():
			RunState.current_act = act
			for enemy in GameData.enemies.values():
				for move in enemy.moves:
					var original: Dictionary = move.duplicate(true)
					RunState.difficulty_snapshot = {}
					var base := roller.scale_intent_damage(move, enemy.tier, enemy.effective_stats)
					RunState.difficulty_snapshot = snapshot
					var modified := roller.scale_intent_damage(move, enemy.tier, enemy.effective_stats)
					var bonus := DifficultyRules.attack_bonus(enemy.tier, move)
					check(int(modified.get("value", 0)) == int(base.get("value", 0)) + bonus, "final attack applies once")
					check(move == original, "shared move immutable")
		check(is_equal_approx(DifficultyRules.rest_percent(), 0.25 if id in ["molten", "extreme"] else 0.3), "rest rate " + id)
		var saved := RunState.to_save_dict()
		check(RunState.from_save_dict(saved), "reload")
		check(RunState.difficulty_snapshot == snapshot, "rule snapshot preserved")
		if id == "warm":
			RunState.current_act = 0
			check(roller.scale_intent_damage({"intent":"attack", "value":10}, &"normal").value == 8, "warm +1 after act scaling")
			check(roller.scale_intent_damage({"intent":"attack", "value":10,"times":3}, &"normal").value == 7, "warm multi hit unchanged")
		if id == "extreme":
			var cc := CombatController.new()
			add_child(cc)
			RunState.current_act = 2
			cc.start_combat([&"chi_the_first"])
			var boss: CombatUnit = cc.enemies[0]
			check(boss.max_hp == 660 and boss.intent.value == 28, "extreme real boss HP unchanged and single hit +2")
			var old_hp := cc.player.hp
			cc.enemy_pre(boss)
			cc._execute_enemy_intent(boss)
			cc.enemy_post(boss)
			check(cc.player.hp == old_hp - 28, "extreme real damage matches preview")
			check(boss.intent.value == 8 and boss.intent.times == 4, "boss multi hit stays unchanged")
			cc.free()
		check(DifficultyRules.record_clear(), "record clear")
		check(DifficultyRules.record_clear(), "idempotent clear")
	check(ProfileState.difficulty_data.cleared.size() == DifficultyRules.tiers().size(), "no duplicate wins")
	check(ProfileState.difficulty_data.hidden_unlocked, "highest clear permanently unlocks")
	check(RunState.start_new_run("normal"), "lower tier replay")
	check(ProfileState.difficulty_data.hidden_unlocked, "replay preserves hidden unlock")
	var profile := ProfileState.to_save_dict()
	check(ProfileState.from_save_dict(profile, false), "profile round trip")
	var old := RunState.to_save_dict()
	old.version = 8
	old.erase("difficulty_snapshot")
	check(RunState.from_save_dict(old) and RunState.difficulty_snapshot.is_empty(), "legacy run unchanged")
	var old_profile := profile.duplicate(true)
	old_profile.version = 8
	old_profile.erase("difficulty_data")
	check(ProfileState.from_save_dict(old_profile, false) and not DifficultyRules.unlocked("warm"), "legacy profile no invented wins")
	var bad := profile.duplicate(true)
	bad.difficulty_data = {"cleared": "extreme"}
	check(not ProfileState.from_save_dict(bad, false, false), "invalid profile rejected")
	# Exercise actual third-act reward completion and permanent unlock.
	# Kept after migration so this really starts from a clean profile.
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.granny_opening = {"resolved":true}
	RunState.current_act = GameData.act_configs.size() - 1
	RunState.current_node_type = &"boss"
	RunState.current_floor = RunState.total_floors() - 1
	var map_ui: Control = load("res://scenes/map/MapPlay.tscn").instantiate()
	add_child(map_ui)
	map_ui._on_reward_done()
	check(not RunState.is_active and RunState.victory and DifficultyRules.unlocked("warm"), "third act completion unlocks next tier")
	map_ui.queue_free()
	await get_tree().process_frame
	ProfileState.reset_to_defaults(false)
	while TransitionManager.is_transitioning: await get_tree().process_frame
	RunState.start_new_run()
	var opening: Control = load("res://scenes/main/PreRunPreparation.tscn").instantiate()
	add_child(opening)
	await get_tree().process_frame
	check(opening.find_child("DifficultySelector", true, false) == null, "dialogue removes difficulty controls")
	check(not DifficultyRules.select_at_opening("warm"), "locked opening selection rejected")
	ProfileState.difficulty_data = {"cleared":["normal","warm","blazing","molten","extreme"]}
	var original := RunState.to_save_dict()
	check(DifficultyRules.select_at_opening("warm") and DifficultyRules.select_at_opening("blazing"), "existing difficulty snapshot API remains compatible")
	var changed := RunState.to_save_dict()
	original.erase("difficulty_snapshot")
	changed.erase("difficulty_snapshot")
	check(original == changed, "switching changes neither gifts, map, inventory, run id nor ad state")
	check(SaveManager.load_game() and RunState.difficulty_snapshot.id == "blazing", "difficulty snapshot survives disk reload")
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/difficulty_granny.png")
	DifficultyRules.select_at_opening("warm")
	check(RunState.difficulty_snapshot.id == "warm", "existing API selects preceding difficulty")
	var saved_path := SaveManager.runtime_save_path
	SaveManager.runtime_save_path = "res://missing_difficulty_directory/run.json"
	check(not DifficultyRules.select_at_opening("normal") and RunState.difficulty_snapshot.id == "warm", "failed save rolls back difficulty")
	SaveManager.runtime_save_path = saved_path
	var offer: Dictionary = RunState.granny_opening.offers[0]
	if String(offer.kind) in ["upgrade", "remove", "transform"]:
		check(GrannyStory.claim(String(offer.id), 0, RunState.deck[0].duplicate(true)), "claim target blessing")
	else:
		check(GrannyStory.claim(String(offer.id)), "claim blessing")
	var rewarded := RunState.to_save_dict()
	check(DifficultyRules.select_at_opening("blazing"), "can change difficulty after choosing blessing")
	var after_reward_switch := RunState.to_save_dict()
	rewarded.erase("difficulty_snapshot")
	after_reward_switch.erase("difficulty_snapshot")
	check(rewarded == after_reward_switch, "claimed reward and receipt unchanged")
	check(GrannyStory.finish(), "finish opening")
	check(not DifficultyRules.select_at_opening("normal") and RunState.difficulty_snapshot.id == "blazing", "difficulty locked after departure")
	opening.queue_free()
	print("DIFFICULTY_PROGRESSION_RESULT:%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
