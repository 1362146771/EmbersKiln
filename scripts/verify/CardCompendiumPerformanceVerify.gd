extends Node
## 冷开/重开图鉴计时与渲染纹理内存；隔离档案，覆盖全部已发现的最重场景。

func _ready() -> void:
	await get_tree().process_frame
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/compendium_performance_save.json"
	for id in ProfileState.collectible_card_ids():
		ProfileState.discover_card(id, false)
	for attempt in 2:
		var before := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
		var started := Time.get_ticks_usec()
		var ui := preload("res://scenes/ui/CardCompendium.tscn").instantiate()
		add_child(ui)
		var built := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		print("COMPENDIUM_PERF attempt=%d build_ms=%.2f first_frame_ms=%.2f panels=%d texture_delta_mib=%.2f" % [attempt,
			(built - started) / 1000.0, (Time.get_ticks_usec() - started) / 1000.0,
			ui._grid.get_child_count(), (Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) - before) / 1048576.0])
		var deadline := Time.get_ticks_msec() + 5000
		while not ui._requested_art.is_empty() and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		var pixels := 0
		for art in ui._grid.find_children("CardArt", "TextureRect", true, false):
			pixels += art.texture.get_width() * art.texture.get_height()
		print("COMPENDIUM_ART ready_ms=%.2f rgba_estimate_mib=%.2f pending=%d" % [
			(Time.get_ticks_usec() - started) / 1000.0, pixels * 4.0 / 1048576.0, ui._requested_art.size()])
		if OS.get_cmdline_user_args().has("--visual"):
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://Temp/compendium_performance.png")
		ui.close()
		for frame in 8:
			await get_tree().process_frame
	print("COMPENDIUM_PERF_DONE")
	get_tree().quit()
