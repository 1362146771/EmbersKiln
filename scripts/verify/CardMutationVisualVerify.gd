extends Node
## Run with isolated APPDATA and an actual renderer; screenshots stay in project logs.

func shot(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func _ready() -> void:
	var isolated := OS.get_environment("MUTATION_TEST_APPDATA").replace("\\", "/")
	if isolated == "" or not OS.get_user_data_dir().begins_with(isolated + "/"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	ProfileManager.autosave_enabled = false
	ProfileState.reset_to_defaults(false)
	ProfileState.completed_project_ids.append(&"apothecary_research_1")
	ProfileState.fireseed_balance = 1000
	CardMutation.storage_path = "user://visual_mutation.json"
	for cid in CardMutation.config().card_directions:
		ProfileState.unlocked_card_ids.append(StringName(cid))
		ProfileState.discovered_card_ids.append(StringName(cid))
	RunState.is_active = false
	var town := preload("res://scenes/town/Town.tscn").instantiate()
	add_child(town)
	await town._on_facility_pressed(&"glaze_apothecary")
	town._show_mutation(true)
	await shot("res://logs/mutation_town.png")
	var panel := town.get_node("FacilityDetailPanel/DetailMargin/DetailColumn/CardMutationPanel")
	panel.select_card(String(panel.card_ids[0]))
	panel.get_node("Actions/Fire").pressed.emit()
	await shot("res://logs/mutation_result.png")
	panel.get_node("Actions/Accept").pressed.emit()
	town.queue_free()
	await get_tree().process_frame
	ProfileState.mutation_data = {"patterns":{"bludgeon":"town_bludgeon_1","carnage":"town_carnage_2","impervious":"town_impervious_2","reaper":"town_reaper_1"}}
	RunState.start_new_run()
	RunState.base_run_deck_capacity = -1
	for cid in ["bludgeon","carnage","impervious","reaper"]: RunState.add_card(StringName(cid))
	RunState.pending_enchant_review = false
	var map := preload("res://scenes/map/MapPlay.tscn").instantiate()
	RunState.pre_run_preparation_resolved = true
	add_child(map)
	await shot("res://logs/mutation_map.png")
	var loadout := preload("res://scenes/ui/EnchantLoadout.tscn").instantiate()
	add_child(loadout)
	await shot("res://logs/mutation_loadout.png")
	loadout.queue_free()
	map.queue_free()
	await get_tree().process_frame
	var browser := preload("res://scripts/ui/CardBrowser.gd").new()
	browser.setup("附魔卡牌", "配印预览", RunState.deck.slice(10))
	add_child(browser)
	await shot("res://logs/mutation_cards.png")
	browser.queue_free()
	await get_tree().process_frame
	print("MUTATION_VISUAL_CAPTURE_COMPLETE")
	get_tree().quit()
