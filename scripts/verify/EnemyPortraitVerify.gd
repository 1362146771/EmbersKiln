extends Node
## Production portrait regression. Uses isolated APPDATA; -- --visual saves
## real CombatPlay viewport captures (not composited mockups).

const MANIFEST := "res://art/enemies/manifest.json"
const OUTPUT := "res://Temp/enemy-art-verify/"
var passed := 0
var failed := 0
var visual := false
var records: Array = []


func _ready() -> void:
	var isolated := OS.get_environment("ENEMY_ART_TEST_APPDATA").replace("\\", "/")
	if isolated.is_empty() or not OS.get_user_data_dir().begins_with(isolated + "/"):
		push_error("EnemyPortraitVerify requires isolated APPDATA")
		get_tree().quit(2)
		return
	visual = OS.get_cmdline_user_args().has("--visual")
	await get_tree().process_frame
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	records = manifest.get("images", [])
	check("20 selected production portraits", records.size() == 20)
	check("21 existing enemy definitions", GameData.enemies.size() == 21)
	var ids: Array = []
	for record in records:
		var path := "res://" + String(record.production)
		check(record.key + " production file hash", FileAccess.get_sha256(path) == record.sha256)
		var found: EnemyData = null
		for id in GameData.enemies:
			var ed := GameData.get_enemy(id)
			if "res://art/enemies/%s.png" % ed.sprite == path:
				found = ed
				break
		check(record.key + " existing data mapping", found != null)
		if found == null:
			continue
		ids.append(found.id)
		var texture := found.sprite_texture()
		check(record.key + " imported texture", texture != null)
		if texture == null:
			continue
		var img := texture.get_image()
		check(record.key + " original canvas", img.get_size() == Vector2i(int(record.size[0]), int(record.size[1])))
		check(record.key + " real antialiased alpha", img.detect_alpha() == Image.ALPHA_BLEND)
		check(record.key + " transparent corners", img.get_pixel(0, 0).a == 0.0 and img.get_pixel(img.get_width() - 1, img.get_height() - 1).a == 0.0)
		for seed in record.gap_seeds:
			check(record.key + " enclosed background gap", img.get_pixel(int(seed[0]), int(seed[1])).a == 0.0)
	check("Sagger remains loadable", GameData.get_enemy(&"sagger_matron").sprite_texture() != null)
	for id in ids:
		await combat([id], "single_" + String(id))
	await combat([&"claylump", &"sootling"], "two_enemies")
	await combat([&"embermoth", &"glazemaw", &"glazetick"], "three_enemies")
	await combat([&"sootling", &"potsherd", &"kilnwarden"], "three_humanoids")
	await combat([&"sagger_matron"], "sagger_unchanged")
	print("ENEMY_PORTRAIT_RESULT:%s %d PASS / %d FAIL" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])


func combat(ids: Array, tag: String) -> void:
	RunState.start_new_run()
	RunState.pending_combat_enemy_ids = ids.duplicate()
	var ui: CombatUI = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	check(tag + " actual combat enemy count", ui.controller.enemies.size() == ids.size())
	for unit in ui.controller.enemies:
		var panel: Control = ui.unit_panels.get(unit)
		check(tag + " live panel", is_instance_valid(panel))
		if not is_instance_valid(panel):
			continue
		var sprite: TextureRect = panel.get_node("Inner/SpriteRect")
		check(tag + " production portrait bound", sprite.texture == unit.data.sprite_texture())
		check(tag + " preserve aspect", sprite.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		check(tag + " sprite visible", sprite.is_visible_in_tree() and sprite.size.x > 0 and sprite.size.y > 0)
		check(tag + " portrait fits viewport", ui.get_viewport_rect().encloses(sprite.get_global_rect()))
		check(tag + " panel fits viewport", ui.get_viewport_rect().encloses(panel.get_global_rect()))
	check(tag + " current player portrait", ui.player_sprite.texture == load("res://art/player/SPR_Player_Tannaro.png"))
	if visual:
		await RenderingServer.frame_post_draw
		check(tag + " viewport screenshot", get_viewport().get_texture().get_image().save_png(OUTPUT + tag + ".png") == OK)
	ui.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
