extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func _ready() -> void:
	if OS.get_environment("UPGRADE_VERIFY_ROOT").is_empty():
		get_tree().quit(2)
		return
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/combat_vitals_save.json"
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_combat_enemy_ids = [&"claylump", &"claylump"]
	var ui := preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	var enemy: CombatUnit = ui.controller.enemies[0]
	var panel: EnemyPanel = ui.unit_panels[enemy]
	var portrait: Control = panel.get_node("Inner/SpriteRect")
	for lock in ["cast", "drag", "return", "enemy_turn"]:
		enemy.max_hp = 100
		enemy.hp = 100
		enemy.block = 0
		ui._enemy.update_enemy_panel(enemy, 0)
		BattleDirector.input_locked = lock == "cast"
		ui._drag_active = lock == "drag"
		ui._casting = lock == "return"
		ui.controller.phase = CombatController.Phase.ENEMY if lock == "enemy_turn" else CombatController.Phase.PLAYER
		portrait.play_hit()
		ui.controller._dmg.deal_to_unit(enemy, 7)
		check(panel.get_node("Inner/HpBar").value == 93 and panel.get_node("Inner/HpText").text == "HP 93/100", "HP updates synchronously under " + lock)
		check(is_same(ui.unit_panels[enemy], panel) and is_same(panel.get_node("Inner/SpriteRect"), portrait), "persistent panel and portrait survive " + lock)
		check(portrait.hit_playing and portrait.get_node("HitFlash").visible, "vitals update preserves active hit feedback " + lock)
		enemy.block = 12
		ui.controller._dmg.deal_to_unit(enemy, 4)
		check(panel.get_node("Inner/HpBar").value == 93 and panel.get_node("Inner/BlockShield/BlockText").text == "8", "blocked damage updates shield immediately under " + lock)
		enemy.hp = 98
		SignalBus.enemy_hp_changed.emit(0, enemy.hp, enemy.max_hp)
		check(panel.get_node("Inner/HpBar").value == 98, "healing updates immediately under " + lock)
	BattleDirector.input_locked = true
	ui._drag_active = false
	ui._casting = false
	ui.controller.phase = CombatController.Phase.PLAYER
	ui.controller.hand = [{"id": &"cleave"}]
	ui.controller.energy = 3
	check(ui.controller.play_card(0), "area attack resolves")
	for unit in ui.controller.enemies:
		var view: EnemyPanel = ui.unit_panels[unit]
		check(view.get_node("Inner/HpBar").value == unit.hp, "each area target health is current before unlock")
	BattleDirector.input_locked = false
	var feedback := ui.get_node("CombatFeedback")
	while feedback.playing_hits: await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/combat_vitals.png")
	print("COMBAT_VITALS_RESULT:", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
