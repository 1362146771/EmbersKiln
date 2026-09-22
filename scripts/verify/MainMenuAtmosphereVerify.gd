extends Node
## Render-based checks: masked movement, seamless wrap, UI input and portrait resize.

const OUTPUT := "res://Temp/menu_atmosphere_verify"
var failed := 0
var menu: Control
var atmosphere: Control
var material: ShaderMaterial


func check(ok: bool, title: String) -> void:
	if not ok:
		failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", title])


func settle() -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func capture(label: String) -> Image:
	await settle()
	var image := get_viewport().get_texture().get_image()
	image.save_png(OUTPUT.path_join(label + ".png"))
	return image


func difference(a: Image, b: Image, region: Rect2i) -> float:
	var total := 0.0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	return total / (region.size.x * region.size.y * 3.0)


func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	ProfileManager.autosave_enabled = false
	get_window().size = Vector2i(720, 1280)
	menu = load("res://scenes/main/MainMenu.tscn").instantiate()
	add_child(menu)
	atmosphere = menu.get_node("Atmosphere")
	material = menu.get_node("Background").material
	await settle()
	var before: float = atmosphere.elapsed
	await get_tree().create_timer(0.2).timeout
	check(atmosphere.elapsed > before, "atmosphere clock advances while menu visible")
	var scene_copy: Control = load("res://scenes/main/MainMenu.tscn").instantiate()
	check(scene_copy.get_node("Background").material != material, "menu instances own their shader state")
	check(scene_copy.get_node("Atmosphere/Embers").process_material != atmosphere.get_node("Embers").process_material, "menu instances own emission bounds")
	scene_copy.free()
	check(atmosphere.mouse_filter == Control.MOUSE_FILTER_IGNORE, "atmosphere does not intercept input")
	check(atmosphere.get_index() < menu.get_node("MenuCenter").get_index(), "logo and buttons render above atmosphere")
	await capture("menu")
	# Isolate the background so moving particles cannot contaminate pixel tests.
	menu.get_node("MenuCenter").hide()
	atmosphere.get_node("Ash").hide()
	atmosphere.get_node("Embers").hide()
	atmosphere.set_process(false)
	material.set_shader_parameter("cycle_phase", 0.0)
	var start := await capture("phase_00")
	# Check perceptible motion over TWO seconds, not just a tiny pixel change
	# between distant points in the loop. Upper ring is unobstructed by the UI.
	material.set_shader_parameter("cycle_phase", 2.0 / atmosphere.cycle_seconds)
	var two_seconds := await capture("phase_2seconds")
	var upper_delta := difference(start, two_seconds, Rect2i(350, 50, 120, 180))
	var lower_delta := difference(start, two_seconds, Rect2i(35, 825, 250, 68))
	print("TWO_SECOND_SMOKE upper=%f lower=%f" % [upper_delta, lower_delta])
	check(upper_delta > 0.012 and lower_delta > 0.012, "smoke changes clearly in both exposed bands within two seconds")
	material.set_shader_parameter("cycle_phase", 0.23)
	var later := await capture("phase_23")
	# Compare the actual rendered edge against the old ribbon-only treatment.
	material.set_shader_parameter("shed_strength", 0.0)
	var without_shed := await capture("without_shed")
	material.set_shader_parameter("shed_strength", 0.8)
	var shed_delta := difference(later, without_shed, Rect2i(485, 85, 65, 185))
	print("SHED_PIXEL_DELTA=%f" % shed_delta)
	check(shed_delta > 0.0003, "detached smoke visibly extends beyond the painted upper ribbon")
	# Regions refer to 720x1280 output, not source-image coordinates.
	var fog_delta := difference(start, later, Rect2i(75, 825, 210, 68))
	var fire_delta := difference(start, later, Rect2i(118, 771, 18, 35))
	var brick_delta := difference(start, later, Rect2i(189, 672, 90, 100))
	print("PIXEL_DELTA fog=%f fire=%f brick=%f" % [fog_delta, fire_delta, brick_delta])
	check(fog_delta > 0.012, "painted smoke has substantial movement")
	check(fire_delta > 0.001, "window fire animates")
	check(brick_delta < 0.0001, "tower masonry stays pixel-stable")
	material.set_shader_parameter("cycle_phase", 1.0)
	var end := await capture("phase_100")
	check(difference(start, end, Rect2i(0, 0, 720, 1280)) < 0.00001, "full background cycle closes without a jump")
	# Check the moving boundary, not just equality of the end frames.
	material.set_shader_parameter("cycle_phase", 1.0 - 1.0 / 720.0)
	var wrap_before := await capture("wrap_before")
	material.set_shader_parameter("cycle_phase", 1.0 / 720.0)
	var wrap_after := await capture("wrap_after")
	var step_before := difference(wrap_before, start, Rect2i(350, 50, 120, 180))
	var step_after := difference(start, wrap_after, Rect2i(350, 50, 120, 180))
	var shed_step_before := difference(wrap_before, start, Rect2i(470, 70, 100, 230))
	var shed_step_after := difference(start, wrap_after, Rect2i(470, 70, 100, 230))
	check(shed_step_before > 0.000001 and shed_step_after > 0.000001 and absf(shed_step_before - shed_step_after) < 0.0002,
		"detached wisps keep drifting smoothly through the cycle boundary")
	check(step_before > 0.00001 and step_after > 0.00001 and absf(step_before - step_after) < 0.0005,
		"smoke crosses loop boundary at continuous speed, with no held frame")
	# Advection has an internal two-phase handoff as well as the full-cycle wrap.
	material.set_shader_parameter("cycle_phase", 1.0 / 6.0 - 0.00001)
	var handoff_a := await capture("handoff_before")
	material.set_shader_parameter("cycle_phase", 1.0 / 6.0 + 0.00001)
	var handoff_b := await capture("handoff_after")
	check(difference(handoff_a, handoff_b, Rect2i(75, 825, 210, 68)) < 0.0002, "smoke phase handoff is continuous")
	if OS.get_cmdline_user_args().has("--record"):
		# Deterministic twelve-FPS, full-cycle view of the actual shader. Explicit
		# phase avoids accelerating the preview when saving frames takes time.
		for i in 288:
			material.set_shader_parameter("cycle_phase", float(i) / 288.0)
			await RenderingServer.frame_post_draw
			var frame := get_viewport().get_texture().get_image()
			frame.resize(432, 768, Image.INTERPOLATE_LANCZOS)
			frame.save_png(OUTPUT.path_join("spiral_%03d.png" % i))
	menu.get_node("MenuCenter").show()
	atmosphere.get_node("Ash").show()
	atmosphere.get_node("Embers").show()
	atmosphere.set_process(true)
	# Exercise an actual GUI click through the added full-screen Control.
	await click(menu.get_node("MenuCenter/MenuColumn/CompendiumButton"))
	var compendium := menu.find_child("CardCompendium", true, false)
	check(compendium != null, "real mouse click opens card compendium")
	if compendium != null:
		await click(compendium.find_child("CloseButton", true, false))
	check(menu.find_child("CardCompendium", true, false) == null, "compendium closes and returns to animated menu")
	menu.hide()
	before = atmosphere.elapsed
	await get_tree().create_timer(0.1).timeout
	check(is_equal_approx(atmosphere.elapsed, before) and not atmosphere.get_node("Embers").emitting, "hidden menu stops clock and particle emission")
	menu.show()
	await settle()
	check(atmosphere.is_processing() and atmosphere.get_node("Embers").emitting, "shown menu resumes atmosphere")
	get_tree().paused = true
	before = atmosphere.elapsed
	await get_tree().create_timer(0.1, true).timeout
	check(is_equal_approx(atmosphere.elapsed, before), "pause freezes atmosphere clock")
	get_tree().paused = false
	# A native hidden window can be clamped by the desktop. Use a real offscreen
	# viewport to guarantee the Android 20:9 dimensions actually get rendered.
	var tall := SubViewport.new()
	tall.size = Vector2i(720, 1600)
	tall.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(tall)
	menu.reparent(tall)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	var tall_image := tall.get_texture().get_image()
	tall_image.save_png(OUTPUT.path_join("menu_tall.png"))
	check(tall_image.get_size() == Vector2i(720, 1600) and menu.size.is_equal_approx(Vector2(720, 1600)), "tall portrait really renders at 720x1600")
	check(atmosphere.size.is_equal_approx(menu.size), "atmosphere follows tall portrait viewport")
	check(menu.get_global_rect().encloses(menu.get_node("MenuCenter/MenuColumn").get_global_rect()), "all menu options remain inside tall portrait viewport")
	menu.reparent(self)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tall.queue_free()
	await settle()
	menu.queue_free()
	await settle()
	check(not is_instance_valid(atmosphere), "leaving menu frees atmosphere and emitters")
	print("MENU_ATMOSPHERE_RESULT FAIL=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)
