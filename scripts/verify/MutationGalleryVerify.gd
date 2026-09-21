extends Node

var failures := 0
var visual := false

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func settle() -> void:
	for i in 10: await get_tree().process_frame

func shot(name: String) -> void:
	if not visual: return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/" + name + ".png")

func _ready() -> void:
	if OS.get_environment("UPGRADE_VERIFY_ROOT").is_empty():
		get_tree().quit(2)
		return
	visual = OS.get_cmdline_user_args().has("--visual")
	ProfileManager.autosave_enabled = false
	ProfileState.reset_to_defaults(false)
	ProfileState.completed_project_ids.append(&"apothecary_research_1")
	ProfileState.fireseed_balance = 1000
	CardMutation.storage_path = "user://gallery_verify_profile.json"
	RunState.is_active = false
	var ids: Array = CardMutation.config().card_directions.keys()
	var first := String(ids[0])
	var second := String(ids[1])
	ProfileState.unlocked_card_ids.append(StringName(first))
	ProfileState.discovered_card_ids.append(StringName(first))
	var town := preload("res://scenes/town/Town.tscn").instantiate()
	add_child(town)
	await town._on_facility_pressed(&"glaze_apothecary")
	town._show_mutation(true)
	var panel = town.get_node("FacilityDetailPanel/DetailMargin/DetailColumn/CardMutationPanel")
	await settle()
	check(panel.get_node("Gallery/Cards").get_child_count() == ids.size(), "all configured cards appear in the gallery")
	check(panel.get_node("Gallery").visible and not panel.get_node("Actions").visible, "starts with gallery and no accidental purchase action")
	var gold_before := ProfileState.fireseed_balance
	panel._tiles[first].get_node("Select").pressed.emit()
	await settle()
	check(panel._selected_id == first and panel.get_node("Scroll").visible, "clicking card opens the selected detail")
	check(ProfileState.fireseed_balance == gold_before and CardMutation.pending().is_empty(), "browsing never spends fireseed or rolls an enchant")
	panel.show_gallery()
	panel.select_card(second)
	await settle()
	check(panel.get_node("Actions/Fire").disabled and panel.get_node("Scroll/Body/Status").visible, "locked cards remain browsable with reason and disabled purchase")
	panel._fire()
	check(ProfileState.fireseed_balance == gold_before, "locked card cannot spend fireseed even through handler")
	panel.show_gallery()
	panel.select_card(first)
	panel._fire()
	check(not CardMutation.pending().is_empty() and panel.get_node("Selection/Back").disabled, "pending enchant locks card switching")
	panel.select_card(second)
	panel.show_gallery()
	check(panel._selected_id == first and not panel.get_node("Gallery").visible, "pending result cannot be switched or hidden by selector")
	# Reopening recovers the persisted result for its original card.
	var restored := preload("res://scenes/town/CardMutationPanel.tscn").instantiate()
	add_child(restored)
	check(restored._selected_id == first and restored.get_node("Actions/Accept").visible, "pending result restores directly into the matching detail")
	restored.queue_free()
	panel._resolve(true)
	panel.show_gallery()
	check(panel._tiles[first].get_node("Column/Status").text == "可重铸", "accepted enchant updates gallery status")
	for dimensions in [Vector2i(720, 1280), Vector2i(1080, 2400)]:
		get_tree().root.size = dimensions
		await settle()
		var gallery: ScrollContainer = panel.get_node("Gallery")
		var grid: GridContainer = panel.get_node("Gallery/Cards")
		check(grid.size.x <= gallery.size.x and grid.size.y > gallery.size.y, "gallery fits width and scrolls vertically " + str(dimensions))
		panel.select_card(first)
		await settle()
		check(get_viewport().get_visible_rect().encloses(panel.get_node("Actions/Fire").get_global_rect()), "action remains inside viewport " + str(dimensions))
		panel.show_gallery()
	get_tree().root.size = Vector2i(720, 1280)
	await settle()
	await shot("mutation_gallery")
	panel.select_card(first)
	await settle()
	await shot("mutation_card_detail")
	print("MUTATION_GALLERY_RESULT:", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
