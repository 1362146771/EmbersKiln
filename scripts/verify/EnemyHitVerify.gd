extends Node
## Every production definition, live panel refresh, repeated hit, and reduced motion.
var failures := 0
var checks := 0
var visual := false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", label)

func _ready() -> void:
	if OS.get_environment("ENEMY_HIT_TEST_ROOT").is_empty():
		push_error("Run through tools/run_enemy_hit_verify.py for isolated saves/cache/ports")
		get_tree().quit(2)
		return
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/enemy_hit_save.json"
	visual = OS.get_cmdline_user_args().has("--visual")
	DirAccess.make_dir_recursive_absolute("res://Temp/enemy-hit")
	var mapping: Dictionary = GameData.vfx["enemy_hit"]["enemy_profiles"]
	check(mapping.size() == GameData.enemies.size(), "all production enemy IDs have explicit animation profiles")
	for id in GameData.enemies:
		await verify_enemy(id)
	print("ENEMY_HIT_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func verify_enemy(id: StringName) -> void:
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_combat_enemy_ids = [id]
	var ui: CombatUI = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	var unit: CombatUnit = ui.controller.enemies[0]
	var panel: EnemyPanel = ui.unit_panels[unit]
	var portrait = panel.get_node("Inner/SpriteRect")
	var origin: Vector2 = portrait.position
	var hp_rect: Rect2 = panel.get_node("Inner/HpBar").get_global_rect()
	var intent_rect: Rect2 = panel.get_node("Inner/IntentBar").get_global_rect()
	var initial_hp := unit.hp
	check(not portrait.profile.is_empty(), String(id) + " profile bound in real combat")
	for enemy in ui.controller.enemies:
		check(not ui.unit_panels[enemy].get_node("Inner/SpriteRect").profile.is_empty(), String(enemy.id) + " formation member bound")
	var feedback := ui.get_node("CombatFeedback")
	await capture(String(id) + "_idle")
	var targets: Array[int] = [0]
	feedback._present_hit(1, targets)
	await get_tree().create_timer(0.08).timeout
	check(portrait.hit_playing and absf(portrait.rotation) > 0.001, String(id) + " recoils on hit")
	check(panel.get_node("Inner/HpBar").get_global_rect() == hp_rect and panel.get_node("Inner/IntentBar").get_global_rect() == intent_rect, String(id) + " HP and intent remain still")
	await capture(String(id) + "_hit")
	# UI updates while moving must not store the displaced position as the new origin.
	panel.build(unit, 0, false, ui.controller.enemies.size(), ui.controller)
	await get_tree().process_frame
	check(portrait.get_node("HitFlash").texture == portrait.texture, String(id) + " refresh keeps flash aligned with cropped portrait")
	await get_tree().create_timer(0.5).timeout
	if not portrait.position.is_equal_approx(origin):
		print("PORTRAIT_DRIFT %s original=%s current=%s area=%s" % [id, origin, portrait.position, panel.portrait_area])
	check(not portrait.hit_playing and portrait.position.is_equal_approx(origin) and portrait.scale == Vector2.ONE and portrait.rotation == 0.0, String(id) + " refresh during hit restores rest pose")
	check(unit.hp == initial_hp, String(id) + " animation does not mutate HP")
	# Damage outside an attack card uses the same animation without a sword slash.
	var count: int = portrait.hit_count
	ui._on_damage(true, 0, 1)
	check(portrait.hit_count == count + 1, String(id) + " indirect damage animates")
	portrait.play_hit(0.045)
	portrait.play_hit(0.045)
	await get_tree().create_timer(0.1).timeout
	check(not portrait.hit_playing and portrait.position.is_equal_approx(origin), String(id) + " rapid restart resets without drift")
	portrait.play_hit(0.0, true)
	await get_tree().create_timer(0.04).timeout
	check(portrait.position.is_equal_approx(origin) and portrait.rotation == 0.0 and portrait.scale == Vector2.ONE and portrait.get_node("HitFlash").visible, String(id) + " reduced motion keeps flash only")
	portrait.stop_hit()
	# Boss state textures change under the existing hit overlay without stale artwork.
	for state in unit.data.state_sprites:
		unit.intent = {"id": state}
		panel.build(unit, 0, false, ui.controller.enemies.size(), ui.controller)
		portrait.play_hit()
		check(portrait.get_node("HitFlash").texture == unit.data.sprite_texture(state), String(id) + " state texture " + String(state))
	ui.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func capture(label: String) -> void:
	if not visual: return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://Temp/enemy-hit/" + label + ".png") == OK, label + " viewport capture")
