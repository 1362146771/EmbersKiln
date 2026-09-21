extends Node
## Actual rendered title: fire visibility, fixed glyph alpha, loop and layout.

const OUTPUT := "res://Temp/menu_atmosphere_verify"
var failed := 0


func check(ok: bool, title: String) -> void:
	if not ok:
		failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", title])


func settle() -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func difference(a: Image, b: Image, box: Rect2i) -> float:
	var total := 0.0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) + absf(ca.a - cb.a)
	return total / float(box.get_area() * 4)


func sample_phase(logo: TextureRect, viewport: SubViewport, phase: float) -> Image:
	logo.set_cycle_phase(phase)
	await settle()
	return viewport.get_texture().get_image()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	ProfileManager.autosave_enabled = false
	var menu: Control = load("res://scenes/main/MainMenu.tscn").instantiate()
	add_child(menu)
	var live_logo: TextureRect = menu.get_node("MenuCenter/MenuColumn/Logo")
	await settle()
	var before: float = live_logo.elapsed
	await get_tree().create_timer(0.2).timeout
	check(live_logo.elapsed > before, "title animation advances in live menu")
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join("title_menu.png"))
	check(live_logo.flames.show_behind_parent and live_logo.flames.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"flames render behind lettering and do not intercept clicks")
	var button: Control = menu.get_node("MenuCenter/MenuColumn/PlayButton")
	check(live_logo.get_global_rect().end.y < button.get_global_rect().position.y,
		"title leaves the existing gap above play button")
	menu.hide()
	before = live_logo.elapsed
	await get_tree().create_timer(0.1).timeout
	check(is_equal_approx(live_logo.elapsed, before), "hidden menu freezes title clock")
	menu.show()
	await settle()
	check(live_logo.is_processing(), "title resumes when menu is shown")
	get_tree().paused = true
	before = live_logo.elapsed
	await get_tree().create_timer(0.1, true).timeout
	check(is_equal_approx(live_logo.elapsed, before), "pause freezes title clock")
	get_tree().paused = false
	# A separate scene instance provides a transparent, isolated title capture.
	var template: Control = load("res://scenes/main/MainMenu.tscn").instantiate()
	var logo: TextureRect = template.get_node("MenuCenter/MenuColumn/Logo")
	logo.get_parent().remove_child(logo)
	template.free()
	check(logo.material != live_logo.material and logo.get_node("Flames").material != live_logo.flames.material,
		"title instances own their heat and flame materials")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(500, 320)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(logo)
	logo.position = Vector2(50, 60)
	logo.size = Vector2(400, 200)
	await settle()
	logo.set_process(false)
	var all := Rect2i(0, 0, 500, 320)
	var start := await sample_phase(logo, viewport, 0.0)
	start.save_png(OUTPUT.path_join("title_phase_0.png"))
	var later := await sample_phase(logo, viewport, 0.22)
	later.save_png(OUTPUT.path_join("title_phase_22.png"))
	var change := difference(start, later, all)
	print("TITLE_PIXEL_DELTA %f" % change)
	check(change > 0.003, "title fire visibly changes within two seconds")
	var end := await sample_phase(logo, viewport, 1.0)
	check(difference(start, end, all) < 0.00001, "eight-second title cycle closes exactly")
	var before_wrap := await sample_phase(logo, viewport, 1.0 - 1.0 / 240.0)
	var after_wrap := await sample_phase(logo, viewport, 1.0 / 240.0)
	check(absf(difference(before_wrap, start, all) - difference(start, after_wrap, all)) < 0.0005,
		"fire keeps continuous motion across the loop boundary")
	logo.flames.hide()
	var body_a := await sample_phase(logo, viewport, 0.0)
	var body_b := await sample_phase(logo, viewport, 0.22)
	var max_alpha_change := 0.0
	for y in 320:
		for x in 500:
			max_alpha_change = maxf(max_alpha_change, absf(body_a.get_pixel(x, y).a - body_b.get_pixel(x, y).a))
	check(max_alpha_change == 0.0, "glyph alpha and silhouette remain pixel-identical")
	check(difference(body_a, body_b, all) > 0.0005, "cracks and kiln opening animate independently of outer flames")
	var drawn: Vector2 = logo.flames.material.get_shader_parameter("logo_size")
	var origin := logo.position + (logo.size - drawn) * 0.5
	var tag := Rect2i(Vector2i(origin + drawn * Vector2(0.89, 0.22)), Vector2i(drawn * Vector2(0.07, 0.07)))
	check(difference(body_a, body_b, tag) == 0.0, "pale paper charm remains unburned and stable")
	logo.flames.show()
	var max_border_alpha := 0.0
	for i in 16:
		var frame := await sample_phase(logo, viewport, float(i) / 16.0)
		var bounds := Rect2i(logo.position + logo.flames.position, logo.flames.size)
		for x in range(bounds.position.x, bounds.end.x):
			max_border_alpha = maxf(max_border_alpha, frame.get_pixel(x, bounds.position.y).a)
			max_border_alpha = maxf(max_border_alpha, frame.get_pixel(x, bounds.end.y - 1).a)
		for y in range(bounds.position.y, bounds.end.y):
			max_border_alpha = maxf(max_border_alpha, frame.get_pixel(bounds.position.x, y).a)
			max_border_alpha = maxf(max_border_alpha, frame.get_pixel(bounds.end.x - 1, y).a)
	check(max_border_alpha < 0.004, "flames and sparks clear padded bounds throughout the cycle")
	if OS.get_cmdline_user_args().has("--record"):
		for i in 128:
			logo.set_cycle_phase(float(i) / 128.0)
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(OUTPUT.path_join("title_%03d.png" % i))
	viewport.queue_free()
	menu.queue_free()
	await settle()
	check(not is_instance_valid(logo) and not is_instance_valid(live_logo), "leaving menu releases both title effects")
	print("MENU_LOGO_RESULT FAIL=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
