extends Node
## 串行验证镇景、院落、工程领取与档案恢复；不写玩家永久档案。
var failures := 0
var town: Control

func _ready() -> void:
	var original_autosave := ProfileManager.autosave_enabled
	var original_profile := ProfileState.to_save_dict()
	ProfileManager.autosave_enabled = false
	ProfileState.reset_to_defaults(false)
	town = load("res://scenes/town/Town.tscn").instantiate()
	add_child(town)
	town.get_node("%RefreshTimer").stop()
	await get_tree().process_frame
	await get_tree().process_frame
	var layer: Control = town.get_node("%FacilityLayer")
	var courtyard: TextureRect = town.get_node("%CourtyardView")
	var detail: Control = town.get_node("%FacilityDetailPanel")
	check("five layered buildings", layer.get_child_count() == 5)
	check("portrait layout", town.size.is_equal_approx(Vector2(720, 1280)))
	for level in range(4):
		town.call("_close_facility_details")
		ProfileState.town_visual_stage = level
		ProfileState.facility_levels["town_restoration"] = level
		for button in layer.get_children():
			ProfileState.facility_levels[String(button.get_meta("facility_id"))] = level
		SignalBus.profile_changed.emit()
		await get_tree().process_frame
		check("town stage %d" % level, town.get_node("%TownBackground").texture.resource_path.ends_with("town_level_%d_base_preview.png" % level))
		await capture("town_integrated_level_%d" % level)
		for button in layer.get_children():
			var id := String(button.get_meta("facility_id"))
			town.call("_close_facility_details")
			var atlas := button.texture_normal as AtlasTexture
			check("%s exterior %d" % [id, level], atlas.atlas.resource_path.ends_with("%s_level_%d.png" % [id, level]))
			check("%s alpha mask" % id, button.texture_click_mask.get_size() == Vector2i(atlas.get_size()) and not button.texture_click_mask.get_bit(0, 0))
			click_building(button)
			check("outline precedes detail", not detail.visible)
			var pulse: Tween = town.get("_facility_tweens").get(StringName(id))
			check("pointer reaches %s" % id, pulse != null)
			if pulse == null:
				continue
			# Advance the animation deterministically; first-use shader compilation can stall a frame.
			pulse.pause()
			pulse.custom_step(0.14)
			check("outline pulse", float(button.material.get_shader_parameter("highlight")) > 0.9)
			var rest_scale: Vector2 = town.get("_facility_rest_scales")[button]
			check("press shrinks around center", button.scale.x < rest_scale.x and button.pivot_offset.is_equal_approx(button.size * 0.5))
			if id == "bellows_station" and level == 0:
				await capture("town_integrated_outline")
			pulse.custom_step(0.11)
			check("press returns before courtyard", button.scale.is_equal_approx(rest_scale))
			pulse.play()
			await wait_detail()
			check("%s courtyard %d" % [id, level], courtyard.texture != null and courtyard.texture.resource_path.ends_with("%s_interior_level_%d.png" % [id, level]))
			check("courtyard and existing panel", courtyard.visible and detail.visible and not layer.visible)
			if id == "hearth" and level == 2:
				await capture("town_integrated_courtyard_2")
	# Later clicks win; close cancels pending opens.
	town.call("_close_facility_details")
	layer.get_node("Hearth").pressed.emit()
	var repeated: Tween = town.get("_facility_tweens")[&"hearth"]
	repeated.pause()
	repeated.custom_step(0.08)
	layer.get_node("Hearth").pressed.emit()
	layer.get_node("BellowsStation").pressed.emit()
	await wait_detail()
	check("rapid click latest selection", courtyard.texture.resource_path.contains("bellows_station_interior"))
	town.call("_close_facility_details")
	layer.get_node("Hearth").pressed.emit()
	town.call("_close_facility_details")
	await get_tree().create_timer(0.7).timeout
	check("close cancels pending detail", not detail.visible and not courtyard.visible)
	check("scale restored after close", layer.get_node("Hearth").scale.is_equal_approx(town.get("_facility_rest_scales")[layer.get_node("Hearth")]))
	check("outline fades", is_zero_approx(float(layer.get_node("Hearth").material.get_shader_parameter("highlight"))))
	# Real production costs/durations/grants; ready must not change art before claim.
	ProfileState.reset_to_defaults()
	var project := GameData.get_meta_project(&"hearth_rekindle_1")
	ProfileState.add_fireseed(int(project["fireseed_cost"]))
	var start := int(Time.get_unix_time_from_system())
	check("start existing upgrade", WorkshopSystem.start_project(&"hearth_rekindle_1", start))
	check("building remains zero during construction", int(layer.get_node("Hearth").get_meta("visual_level")) == 0)
	var finish := start + int(project["duration_seconds"])
	WorkshopSystem.refresh(finish)
	check("ready remains zero", int(layer.get_node("Hearth").get_meta("visual_level")) == 0)
	layer.get_node("Hearth").pressed.emit()
	await wait_detail()
	check("claim existing upgrade", WorkshopSystem.claim_project(&"hearth_rekindle_1", finish))
	await wait_courtyard("hearth_interior_level_1.png")
	check("claim refreshes exterior and open courtyard", int(layer.get_node("Hearth").get_meta("visual_level")) == 1 and courtyard.texture.resource_path.ends_with("hearth_interior_level_1.png"))
	project = GameData.get_meta_project(&"town_restore_1")
	ProfileState.add_fireseed(int(project["fireseed_cost"]))
	check("start restoration", WorkshopSystem.start_project(&"town_restore_1", start))
	check("claim restoration", WorkshopSystem.claim_project(&"town_restore_1", start + int(project["duration_seconds"])))
	check("restoration only changes background", town.get_node("%TownBackground").texture.resource_path.ends_with("town_level_1_base_preview.png") and int(layer.get_node("BellowsStation").get_meta("visual_level")) == 0)
	check("save isolated profile", ProfileManager.save_to_file("res://Temp/town_visual_profile.json", ProfileState.to_save_dict()))
	ProfileState.reset_to_defaults()
	check("reload isolated profile", ProfileState.from_save_dict(ProfileManager.load_from_file("res://Temp/town_visual_profile.json")))
	await wait_courtyard("hearth_interior_level_1.png")
	check("restored mixed levels", int(layer.get_node("Hearth").get_meta("visual_level")) == 1 and int(layer.get_node("BellowsStation").get_meta("visual_level")) == 0 and town.get_node("%TownBackground").texture.resource_path.ends_with("town_level_1_base_preview.png"))
	town.call("_close_facility_details")
	await capture("town_integrated_mixed_levels")
	town.get_node("%TownRestoration").pressed.emit()
	check("restoration uses existing panel and live town", detail.visible and layer.visible and not courtyard.visible and town.get_node("%DetailName").text == "镇貌修复")
	await capture("town_integrated_restoration")
	town.call("_close_facility_details")
	check("return restores controls", layer.visible and town.get_node("%DepartButton").visible and town.get_node("%TownRestoration").visible)
	# Resize the actual layout: map and overlays must keep the same normalized positions.
	var canvas: Control = layer.get_parent()
	var hearth: TextureButton = layer.get_node("Hearth")
	var normalized_position := hearth.position / canvas.size
	var normalized_size := hearth.size / canvas.size
	town.size = Vector2(900, 1280)
	await get_tree().process_frame
	await get_tree().process_frame
	check("resize keeps map alignment", (hearth.position / canvas.size).is_equal_approx(normalized_position) and (hearth.size / canvas.size).is_equal_approx(normalized_size) and is_equal_approx(canvas.size.x / canvas.size.y, 941.0 / 1673.0))
	town.queue_free()
	await get_tree().process_frame
	ProfileState.from_save_dict(original_profile, false)
	ProfileManager.autosave_enabled = original_autosave
	print("TOWN_VISUAL_CAPTURE:%s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(0 if failures == 0 else 1)

func wait_detail() -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not town.get_node("%FacilityDetailPanel").visible and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check("detail opens", town.get_node("%FacilityDetailPanel").visible)

func wait_courtyard(suffix: String) -> void:
	var view: TextureRect = town.get_node("%CourtyardView")
	var deadline := Time.get_ticks_msec() + 10000
	while (view.texture == null or not view.texture.resource_path.ends_with(suffix)) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame

func check(label: String, passed: bool) -> void:
	if not passed:
		failures += 1
	print("[TownVisualCapture] %s %s" % ["PASS" if passed else "FAIL", label])

func click_building(button: TextureButton) -> void:
	var mask := button.texture_click_mask
	var mask_size := mask.get_size()
	var point := Vector2.ZERO
	var found := false
	for y in range(mask_size.y / 3, mask_size.y, 8):
		for x in range(mask_size.x / 3, mask_size.x * 2 / 3, 8):
			if mask.get_bit(x, y):
				point = button.global_position + Vector2(x, y) / Vector2(mask_size) * button.size
				found = true
				break
		if found:
			break
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)

func capture(stem: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	check("capture %s" % stem, get_viewport().get_texture().get_image().save_png("res://Temp/%s.png" % stem) == OK)
