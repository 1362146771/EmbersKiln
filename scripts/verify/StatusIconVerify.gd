extends Node
## 串行覆盖 1/2/3 敌布局、全部状态图标、负层数、原位刷新与移除；不写玩家存档。
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func _ready() -> void:
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/status_icon_verify_save.json"
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	for data in GameData.statuses.values():
		var texture := GameData.icon_texture(data.icon)
		check(texture != null, "configured icon " + String(data.id))
		if texture != null:
			check(texture.get_image().detect_alpha() != Image.ALPHA_NONE, "transparent icon " + String(data.id))
	for count in [1, 2, 3]:
		RunState.pending_combat_enemy_ids.clear()
		for i in count:
			RunState.pending_combat_enemy_ids.append(&"claylump")
		var ui = load("res://scenes/combat/CombatPlay.tscn").instantiate()
		add_child(ui)
		await get_tree().create_timer(0.4).timeout
		ui.controller.player.statuses.clear()
		for sid in GameData.statuses:
			ui.controller.player.add_status(sid, 3)
		for enemy in ui.controller.enemies:
			enemy.statuses.clear()
			var index: int = ui.controller.enemies.find(enemy)
			if index == 0:
				enemy.intent = {"intent": "attack", "value": 7, "gold_steal": 15}
			elif index == 1:
				enemy.intent = {"intent": "charge", "value": 12, "next": "heavy_slam"}
			else:
				enemy.intent = {"intent": "attack", "value": 8, "times": 3}
				enemy.block_break_next = &"harden"
			# Visual stress fixture includes all statuses regardless of gameplay recipient rules.
			for sid in GameData.statuses:
				enemy.add_status(sid, 2)
		ui._hud.refresh_resources()
		ui._enemy.refresh_enemy()
		await get_tree().process_frame
		await get_tree().process_frame
		var player_bar: Control = ui.player_status
		check(player_bar.get_child_count() == GameData.statuses.size(), "all player statuses rendered")
		check(not player_bar.has_node("kiln_heat"), "zero kiln hidden")
		ui._hud.on_kiln(2, ui.controller._kiln_threshold())
		check(player_bar.has_node("kiln_heat") and player_bar.get_node("kiln_heat/Stacks").text == "2", "kiln joins status bar")
		ui._hud.on_kiln(0, ui.controller._kiln_threshold())
		check(not player_bar.has_node("kiln_heat"), "kiln removed at zero")
		ui._hud.on_kiln(2, ui.controller._kiln_threshold())
		await get_tree().process_frame
		await get_tree().process_frame
		check(player_bar.global_position.y >= ui.player_hp_bar.get_global_rect().end.y, "player statuses below HP")
		check(player_bar.get_global_rect().end.y < ui.get_node("Safe/Layout/HandArea").global_position.y, "statuses above hand")
		for panel in ui.unit_panels.values():
			var bar: Control = panel.get_node("Inner/StatusBar")
			var sprite: Control = panel.get_node("Inner/SpriteRect")
			var hp: Control = panel.get_node("Inner/HpBar")
			check(bar.get_child_count() == GameData.statuses.size(), "all enemy statuses rendered")
			check(sprite.get_global_rect().end.y <= bar.global_position.y, "portrait clears statuses")
			check(bar.get_global_rect().end.y <= hp.global_position.y, "enemy statuses above HP")
			for badge in bar.get_children():
				check(bar.get_global_rect().encloses(badge.get_global_rect()), "wrapped badge contained")
			check(panel.get_global_rect().end.x <= 721, "enemy UI inside viewport")
			var intent: Control = panel.get_node("Inner/IntentBar")
			check(intent.get_global_rect().end.y <= sprite.global_position.y, "intent clears portrait")
			for item in intent.get_children():
				check(item.get_node("Icon").size.x == 42, "intent icon 30 percent larger")
				check(item.get_node("Icon").texture != null, "intent texture exists")
				check(intent.get_global_rect().encloses(item.get_global_rect()), "intent within bar")
			check_centered(bar)
		check_centered(player_bar)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://Temp/status_icons_%d_enemies.png" % count)
		var badge_id: int = player_bar.get_node("heat").get_instance_id()
		ui.controller.player.add_status(&"heat", -126)
		ui._hud.refresh_resources()
		check(player_bar.get_node("heat/Stacks").text == "-123", "negative strength preserved")
		check(player_bar.get_node("heat/Stacks").get_minimum_size().x <= player_bar.get_node("heat").size.x, "signed stack number fits badge")
		check(player_bar.get_node("heat").get_instance_id() == badge_id, "stack update reuses badge")
		ui.controller.player.add_status(&"heat", 123)
		ui._hud.refresh_resources()
		check(not player_bar.has_node("heat"), "zero status removed")
		ui.controller.player.statuses.clear()
		ui._hud.refresh_resources()
		check(not player_bar.visible and player_bar.get_child_count() == 0, "empty bar hidden")
		for sid in [&"heat", &"temper", &"glaze"]:
			ui.controller.player.add_status(sid, 1)
			ui._hud.refresh_resources()
			await get_tree().process_frame
			await get_tree().process_frame
			check_centered(player_bar)
		var enemy: CombatUnit = ui.controller.enemies[0]
		var intent_bar: Control = ui.unit_panels[enemy].get_node("Inner/IntentBar")
		for kind in ["attack", "defend", "buff", "debuff", "unknown", "aoe_debuff"]:
			enemy.intent = {"intent": kind, "value": 4}
			ui.unit_panels[enemy].build(enemy, 0, false, count, ui.controller)
			check(intent_bar.get_child(0).get_node("Icon").texture != null, kind + " intent rendered")
			if kind == "unknown":
				check(not intent_bar.get_child(0).get_node("Value").visible, "unknown has no misleading zero")
		ui.queue_free()
		await get_tree().process_frame
	RunState.pending_combat_enemy_ids.clear()
	print("STATUS_ICON_VERIFY: %d failures" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func check_centered(bar: Control) -> void:
	var rows: Dictionary = {}
	for badge in bar.get_children():
		var y: float = badge.position.y
		if not rows.has(y): rows[y] = [badge.position.x, badge.position.x + badge.size.x]
		else: rows[y][1] = badge.position.x + badge.size.x
	for row in rows.values():
		check(absf(row[0] - (bar.size.x - row[1])) <= 2.0, "status row centered symmetrically")
