extends Node
var passed := 0
var failed := 0
const OPENING := "res://scenes/main/PreRunPreparation.tscn"
const AD := "res://scenes/main/PreRunAdPreparation.tscn"
const MENU := "res://scenes/main/MainMenu.tscn"
const MAP := "res://scenes/map/MapPlay.tscn"


func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])


func settle() -> void:
	for i in 10: await get_tree().process_frame
	var current := get_tree().current_scene
	while is_instance_valid(current) and current.scene_file_path == MENU and current.get("_menu_busy"):
		await get_tree().process_frame
	while TransitionManager.is_transitioning: await get_tree().process_frame


func fresh() -> void:
	RunState.start_new_run()
	GrannyStory.prepare()


func _ready() -> void:
	get_tree().current_scene = null
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/granny_run.json"
	ProfileState.reset_to_defaults(false)
	var fake := FakeRewardedAdProvider.new()
	fake.set_available(&"pre_run_buff", true)
	AdService.set_provider(fake)
	fresh()
	check(GrannyStory.needs_opening(), "fresh profile receives opening before first combat")
	check(RunState.granny_opening["offers"].size() == 4 and GameData.granny_opening["rewards"].size() == 10, "four choices from ten production rewards")
	var initial := RunState.to_save_dict()
	GrannyStory.prepare()
	check(RunState.to_save_dict() == initial, "reopening never rerolls candidates")
	RunState.granny_opening.clear()
	check(SaveManager.load_game() and RunState.granny_opening == initial["granny_opening"], "actual disk restore retains candidate identities")
	check(not GrannyStory.finish(), "cannot leave opening before free choice")
	# Rare-card rewards respect progression locks; cover unlocked production pool separately.
	for card in GameData.cards.values(): ProfileState.unlocked_card_ids.append(card.id)
	var seen: Dictionary = {}
	var all_valid := true
	for i in 80:
		RunState.granny_opening.clear()
		RunState.run_id = "coverage-%d" % i
		GrannyStory.prepare()
		var counts := {"build": 0, "supply": 0, "bargain": 0}
		var unique: Dictionary = {}
		for offer in RunState.granny_opening["offers"]:
			counts[offer["group"]] += 1
			seen[offer["id"]] = true
			unique[offer["id"]] = true
		all_valid = all_valid and counts == {"build": 2, "supply": 1, "bargain": 1} and unique.size() == 4
	check(all_valid and seen.size() == 10, "all ten options appear; each run has two build/one supply/one bargain without duplicates")
	var rng := RandomNumberGenerator.new()
	rng.seed = 100
	# Health costs cannot kill the player, and stale target snapshots cannot spend a choice.
	fresh()
	var risk := GrannyStory._materialize(GameData.granny_opening["rewards"][9], rng)
	RunState.granny_opening = {"offers": [risk]}
	RunState.hp = int(risk["lose_hp"])
	check(not GrannyStory.claim(String(risk["id"])) and not GrannyStory.chosen(), "unaffordable health cost leaves reward unclaimed")
	fresh()
	var stale_offer := GrannyStory._materialize(GameData.granny_opening["rewards"][1], rng)
	RunState.granny_opening = {"offers": [stale_offer]}
	var stale := RunState.deck[0].duplicate(true)
	RunState.deck.reverse()
	check(not GrannyStory.claim(String(stale_offer["id"]), 0, stale), "stale picker index cannot upgrade a different instance")
	for definition in GameData.granny_opening["rewards"]:
		fresh()
		var offer := GrannyStory._materialize(definition, rng)
		# Old saves may carry item names/effects in all three presentation fields.
		offer["title"] = "旧存档具体奖励名称"
		offer["description"] = "旧存档具体奖励效果"
		RunState.granny_opening = {"offers": [offer], "line": "选一样带上，路上用得着。"}
		var frozen := RunState.to_save_dict()
		check(SaveManager.save_game() and SaveManager.load_game() and RunState.to_save_dict() == frozen, "legacy offer disk restore preserves rolled reward and costs")
		get_tree().change_scene_to_file(OPENING)
		await settle()
		var disclosure_ui = get_tree().current_scene
		disclosure_ui.get_node("%TalkButton").pressed.emit()
		await settle()
		var option_text: String = disclosure_ui.get_node("%RewardOptions").get_child(0).text
		check(option_text == "[%s]\n%s" % [definition["title"], definition["description"]], "legacy option uses only current generic title and description: " + String(offer["id"]))
		check(RunState.to_save_dict() == frozen, "rendering legacy option does not reroll or mutate saved reward")
		var before := RunState.to_save_dict()
		var kind := String(offer["kind"])
		var target := 0 if kind in ["upgrade", "remove", "transform"] else -1
		var entry: Dictionary = RunState.deck[0].duplicate(true)
		check(GrannyStory.claim(String(offer["id"]), target, entry), "claim " + String(offer["id"]))
		check(RunState.hp == mini(int(before["hp"]) + (int(offer.get("amount", 0)) if kind == "max_hp" else 0), RunState.max_hp) - int(offer.get("lose_hp", 0)), "exact HP reward/cost")
		check(RunState.max_hp == int(before["max_hp"]) + (int(offer.get("amount", 0)) if kind == "max_hp" else 0) - int(offer.get("lose_max_hp", 0)), "exact max HP reward/cost")
		match kind:
			"gold": check(RunState.gold == int(before["gold"]) + int(offer["amount"]), "exact gold")
			"card": check(RunState.deck.size() == before["deck"].size() + 1 and String(RunState.deck.back()["id"]) == offer["card_id"], "advertised card granted")
			"potions": check(RunState.potions.size() == int(offer["amount"]), "all potion slots filled")
			"relic": check(RunState.relic_ids.has(StringName(offer["relic_id"])), "advertised relic granted")
			"upgrade": check(RunState.deck[0]["upgraded"] and RunState.upgrade_shards == int(before["upgrade_shards"]), "free upgrade consumes no shards")
			"remove": check(RunState.deck.size() == before["deck"].size() - 1, "chosen instance removed")
			"transform": check(RunState.deck.size() == before["deck"].size() and String(RunState.deck[0]["id"]) == offer["card_id"] and RunState.deck[0]["instance_id"] != entry["instance_id"], "transform replaces selected instance")
		check(RunState.granny_opening["result_text"] == definition["description"], "new receipt stores only generic reward description")
		RunState.granny_opening["result_text"] = "旧存档具体物品名称及效果"
		check(SaveManager.save_game() and SaveManager.load_game(), "legacy receipt reloads from disk")
		get_tree().change_scene_to_file(OPENING)
		await settle()
		disclosure_ui = get_tree().current_scene
		check(disclosure_ui.get_node("%Receipt").text == "已获得 · %s\n%s" % [definition["title"], definition["description"]], "legacy receipt hides saved names and effects: " + String(offer["id"]))
		var claimed := RunState.to_save_dict()
		check(not GrannyStory.claim(String(offer["id"]), target, entry) and RunState.to_save_dict() == claimed, "double-click cannot repeat reward/cost")
		check(SaveManager.load_game() and RunState.granny_opening.get("chosen", "") == offer["id"], "receipt persists with inventory")
		check(GrannyStory.finish() and not GrannyStory.needs_opening(), "finish closes opening once")
	check(GrannyStory.title_for({"id": "unknown", "title": "具体奖励"}) == "馈赠" and GrannyStory.describe({"id": "unknown", "description": "具体效果"}).is_empty(), "unknown legacy offer cannot fall back to disclosed saved text")
	# Disk failure must roll back both reward and receipt, including card discovery.
	fresh()
	var gold_offer := GrannyStory._materialize(GameData.granny_opening["rewards"][4], rng)
	RunState.granny_opening = {"offers": [gold_offer]}
	var before_failure := RunState.to_save_dict()
	SaveManager.runtime_save_path = "res://missing_granny_directory/save.json"
	check(not GrannyStory.claim(String(gold_offer["id"])) and RunState.to_save_dict() == before_failure, "failed disk write rolls back reward and receipt")
	SaveManager.runtime_save_path = "res://Temp/granny_run.json"
	# Old in-progress runs do not receive a retroactive free reward.
	var legacy := RunState.to_save_dict()
	legacy["version"] = 7
	legacy.erase("granny_opening")
	check(RunState.from_save_dict(legacy) and not GrannyStory.needs_opening(), "v7 migration resolves free opening without changing existing buff")
	# Actual scene: selectable target, cancel, choose, ad failure, retry, departure.
	ProfileState.unlocked_pre_run_buff_ids.assign([&"kiln_guard"])
	for definition_index in [2, 3]:
		fresh()
		var target_offer := GrannyStory._materialize(GameData.granny_opening["rewards"][definition_index], rng)
		RunState.granny_opening["offers"] = [target_offer]
		get_tree().change_scene_to_file(OPENING)
		await settle()
		var target_ui = get_tree().current_scene
		target_ui.get_node("%TalkButton").pressed.emit()
		target_ui._choose(String(target_offer["id"]))
		await settle()
		target_ui._picker.close()
		await settle()
		check(not GrannyStory.chosen(), "remove/transform cancel returns without spending choice")
		target_ui._choose(String(target_offer["id"]))
		await settle()
		target_ui._picker.select_card(0)
		target_ui._picker._confirm_selection()
		await settle()
		check(GrannyStory.chosen(), "real remove/transform picker confirms correct card snapshot")
		target_ui._depart()
		await settle()
		check(get_tree().current_scene.scene_file_path == AD, "farewell opens original advertising page")
		get_tree().current_scene.get_node("%SkipButton").pressed.emit()
		await settle()
		check(get_tree().current_scene.scene_file_path == MAP and not RunState.pre_run_buff_claimed, "skip advertising retains free target reward")
	fresh()
	var offers: Array = []
	for i in [0, 1, 7, 9]: offers.append(GrannyStory._materialize(GameData.granny_opening["rewards"][i], rng))
	RunState.granny_opening["offers"] = offers
	SaveManager.save_game()
	get_tree().change_scene_to_file(OPENING)
	await settle()
	var ui = get_tree().current_scene
	check(ui.get_node("%DepartButton").disabled, "departure requires reward choice")
	check(ui.find_child("GrannyTopics", true, false) == null, "topic menu removed")
	check(ui.get_node("%TalkButton").visible and not ui.get_node("%RewardOptions").visible, "greeting precedes reward choices")
	check(ui.find_child("DifficultySelector", true, false) == null and ui.find_child("AdBuffButton", true, false) == null, "dialogue has no difficulty selector or advertisement")
	await capture("granny_greeting")
	ui.get_node("%TalkButton").pressed.emit()
	await settle()
	check(ui.get_node("%RewardOptions").get_child_count() == offers.size(), "talk reveals all response choices")
	await capture("granny_opening")
	var options: Control = ui.get_node("%RewardOptions")
	var all_visible := true
	for option in options.get_children():
		all_visible = all_visible and options.get_global_rect().encloses(option.get_global_rect()) and get_viewport().get_visible_rect().encloses(option.get_global_rect())
	check(all_visible and options.get_child_count() == 4, "all four reward options fully visible without scrolling")
	check(not ui.get_node("%Status").visible, "redundant reward hint removed")
	check(ui.get_node("%GrannyPortrait").size.y < ui.get_node("%PlayerPortrait").size.y, "seated Granny is smaller than the player")
	ui._choose("sharpen")
	await settle()
	check(is_instance_valid(ui._picker), "upgrade opens real comparison picker")
	ui._picker.close()
	await settle()
	check(not GrannyStory.chosen(), "cancel target preserves opportunity")
	ui._choose("sharpen")
	await settle()
	ui._picker.select_card(0)
	await settle()
	await capture("granny_upgrade")
	ui._picker._confirm_selection()
	await settle()
	check(GrannyStory.chosen() and RunState.deck[0]["upgraded"], "real target confirmation grants upgrade")
	check(not ui.get_node("%DepartButton").disabled and ui.get_node("%Receipt").visible, "reward shows receipt and farewell response")
	await capture("granny_reward")
	var receipt_save := RunState.to_save_dict()
	ui.get_node("%BackButton").pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == MENU and SaveManager.load_game(), "save and exit retains claimed reward")
	get_tree().current_scene.get_node("MenuCenter/MenuColumn/PlayButton").pressed.emit()
	await settle()
	ui = get_tree().current_scene
	check(ui.get_node("%Receipt").visible and RunState.to_save_dict() == receipt_save, "continue resumes farewell without granting twice")
	SaveManager.runtime_save_path = "res://missing_granny_directory/farewell.json"
	ui.get_node("%DepartButton").pressed.emit()
	check(GrannyStory.needs_opening() and not ui._leaving, "failed farewell save remains retryable")
	SaveManager.runtime_save_path = "res://Temp/granny_run.json"
	ui.get_node("%DepartButton").pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == AD and not GrannyStory.needs_opening(), "farewell finishes dialogue before advertisement")
	ui = get_tree().current_scene
	check(not ui.find_child("AdBuffButton", true, false).disabled, "original buff card is available")
	await capture("granny_ad")
	ui.get_node("%BackButton").pressed.emit()
	await settle()
	check(SaveManager.load_game(), "ad page save succeeds")
	get_tree().current_scene.get_node("MenuCenter/MenuColumn/PlayButton").pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == AD, "continue returns to pending advertisement without replaying dialogue")
	ui = get_tree().current_scene
	fake.enqueue_result(AdService.RESULT_FAILED)
	ui._on_buff_pressed(&"kiln_guard")
	ui.get_node("%SkipButton").pressed.emit()
	check(get_tree().current_scene == ui, "pending ad cannot be skipped")
	await SignalBus.ad_reward_resolved
	await settle()
	check(GrannyStory.chosen() and not RunState.pre_run_buff_claimed and not ui.get_node("%SkipButton").disabled, "ad failure retains free reward and allows departure")
	fake.enqueue_result(AdService.RESULT_COMPLETED)
	ui._on_buff_pressed(&"kiln_guard")
	ui.get_node("%SkipButton").pressed.emit()
	check(get_tree().current_scene == ui, "pending ad cannot be skipped")
	await SignalBus.ad_reward_resolved
	await settle()
	check(get_tree().current_scene.scene_file_path == MAP and RunState.pre_run_buff_claimed and RunState.pre_run_buff_id == &"kiln_guard", "optional completed ad grants original buff and departs")
	check(RunState.deck[0]["upgraded"] and not GrannyStory.needs_opening(), "free and ad rewards coexist after departure")
	# Returning town has no NPC entry or modal instance.
	get_tree().change_scene_to_file("res://scenes/town/Town.tscn")
	await settle()
	check(get_tree().current_scene.find_child("GrannyButton", true, false) == null and get_tree().current_scene.find_child("GrannyDialogue", true, false) == null, "Granny removed from town")
	await capture("granny_town")
	# Reproduce the reported town departure with a migrated, already-started run.
	var fixture := SaveManager.load_from_file("res://Temp/town_departure_fixture.json") if FileAccess.file_exists("res://Temp/town_departure_fixture.json") else {}
	if fixture.is_empty():
		fixture = RunState.to_save_dict()
		fixture["granny_opening"] = {"resolved": true}
		fixture["resolved_floor_keys"] = ["0:0"]
	check(RunState.from_save_dict(fixture), "load reported departure fixture")
	SaveManager.save_game()
	var old_run := RunState.to_save_dict()
	var old_profile := ProfileState.to_save_dict()
	var town = get_tree().current_scene
	town._rebuild()
	check(town.get_node("%DepartButton").text == "继续当前冒险" and town.get_node("%NewRunButton").visible, "active old run labels continue separately from new run")
	town.get_node("%DepartButton").pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == MAP and RunState.run_id == old_run["run_id"], "continue preserves old run and does not replay opening")
	get_tree().change_scene_to_file("res://scenes/town/Town.tscn")
	await settle()
	town = get_tree().current_scene
	old_run = RunState.to_save_dict()
	SaveManager.save_game()
	town.get_node("%NewRunButton").pressed.emit()
	check(town.get_node("%NewRunConfirmation").visible and RunState.to_save_dict() == old_run, "new-run button only opens confirmation; no save mutation")
	await capture("granny_new_run_confirm")
	town.get_node("%CancelNewRun").pressed.emit()
	check(not town.get_node("%NewRunConfirmation").visible and RunState.to_save_dict() == old_run, "cancel preserves all run state")
	town.get_node("%NewRunButton").pressed.emit()
	SaveManager.runtime_save_path = "res://missing_granny_directory/new_run.json"
	check(town._prepare_new_run() == ERR_FILE_CANT_WRITE and RunState.to_save_dict() == old_run, "failed replacement save restores old run")
	SaveManager.runtime_save_path = "res://Temp/granny_run.json"
	check(SaveManager.load_from_file(SaveManager.runtime_save_path)["run_id"] == old_run["run_id"], "old disk save survives failed replacement")
	town.get_node("%ConfirmNewRun").pressed.emit()
	await settle()
	old_profile["first_battle_started"] = true
	check(get_tree().current_scene.scene_file_path == OPENING and RunState.run_id != old_run["run_id"] and GrannyStory.needs_opening(), "confirmed new run reaches Granny with fresh reward candidates")
	check(RunState.granny_opening.get("offers", []).size() == 4 and not GrannyStory.chosen(), "new run resets reward receipt")
	check(ProfileState.to_save_dict() == old_profile, "new run preserves town progress and permanent profile")
	await capture("granny_from_town")
	# Locked wind bellows still shows the original page and can depart without ads.
	ProfileState.reset_to_defaults(false)
	fresh()
	RunState.granny_opening["offers"] = [gold_offer]
	get_tree().change_scene_to_file(OPENING)
	await settle()
	ui = get_tree().current_scene
	ui.get_node("%TalkButton").pressed.emit()
	ui._choose(String(gold_offer.id))
	ui.get_node("%DepartButton").pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == AD, "locked buff still reaches original ad preparation page")
	ui = get_tree().current_scene
	check(ui.find_child("AdBuffButton", true, false) == null, "locked buff cannot be claimed")
	ui.get_node("%SkipButton").pressed.emit()
	await settle()
	check(get_tree().current_scene.scene_file_path == MAP, "locked buff does not block map departure")
	SaveManager.delete_save()
	print("GRANNY_RESULT:%s %d passed / %d failed" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"): return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://Temp/" + name + ".png") == OK, "capture " + name)
