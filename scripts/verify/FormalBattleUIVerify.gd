extends Node
## 正式战斗布局、拖卡落点和只读奖励概览回归；可加 --visual 保存真实截图。
var failed := 0
var visual := false

func _ready() -> void:
	visual = OS.get_cmdline_user_args().has("--visual")
	if OS.get_cmdline_user_args().has("--victory-presentation-only"):
		var combat_scene := (load("res://scenes/combat/CombatPlay.tscn") as PackedScene).instantiate()
		check(not combat_scene.has_node("ResultLabel"), "combat scene has no victory splash")
		combat_scene.free()
		var reward_scene := (load("res://scenes/ui/BattleRewardOverview.tscn") as PackedScene).instantiate()
		check(reward_scene.get_node("Panel/Title").text == "战斗奖励", "post-combat panel uses a reward heading")
		reward_scene.free()
		print("VICTORY_PRESENTATION_RESULT FAIL=%d" % failed)
		get_tree().quit(0 if failed == 0 else 1)
		return
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/formal_battle_verify_save.json"
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	var ui := (load("res://scenes/combat/CombatPlay.tscn") as PackedScene).instantiate() as CombatUI
	add_child(ui)
	await settle()
	check(not ui.has_node("ResultLabel"), "combat scene has no victory splash")
	check(ui.player_hp_bar.get_theme_stylebox("fill") is StyleBoxTexture, "authored player HP texture")
	check(not ui.has_node("EnergyBar"), "legacy energy bar removed")
	check(ui.has_node("Safe/Layout/HandArea/EnergyRow/EnergyBadge"), "ceramic energy badge is present")
	var energy_badge: Control = ui.get_node("Safe/Layout/HandArea/EnergyRow/EnergyBadge")
	check(ui.player_energy.text == "%d" % ui.controller.energy, "energy badge shows current energy only")
	ui._on_energy(0, ui.controller.max_energy)
	check(ui.player_energy.text == "0" and ui.player_energy.get_theme_color("font_color") == Color("7a1f1f"), "zero energy uses deep red number")
	await capture("energy_zero")
	ui._on_energy(ui.controller.max_energy, ui.controller.max_energy)
	check(ui.player_energy.text == "%d" % ui.controller.max_energy and ui.player_energy.get_theme_color("font_color") == ui.CREAM, "positive energy restores light number")
	check(ui.hand_container.get_global_rect().position.y >= 1080, "hand occupies bottom strip")
	check(ui.end_turn_btn.get_global_rect().end.x <= 721, "end turn stays inside viewport")
	var potions: Control = ui.get_node("Safe/Layout/PotionBar")
	var relics: Control = ui.get_node("Safe/Layout/TopRow/RelicBar")
	check(potions.get_global_rect().position.y <= 4 and potions.get_global_rect().end.y <= 100, "potions occupy top frame")
	check(relics.get_global_rect().position.y <= 8 and relics.get_global_rect().end.y <= 100, "relics occupy top frame")
	check(ui.player_sprite.position.y >= ui.player_panel.get_global_rect().end.y
		and ui.player_sprite.get_global_rect().end.y <= ui.hand_container.get_global_rect().position.y,
		"player portrait fits between state frame and hand")
	var player_shield: Control = ui.get_node("Safe/Layout/Bottom/PlayerPanel/Phbox/Plv/PlayerBlockShield")
	check(energy_badge.get_global_rect().position.x < player_shield.get_global_rect().position.x
		and player_shield.get_global_rect().position.x < ui.player_hp_bar.get_global_rect().position.x
		and absf(energy_badge.get_global_rect().get_center().y - ui.player_hp_bar.get_global_rect().get_center().y) <= 2.0,
		"energy badge, block shield and HP bar share one left-to-right row")
	check(player_shield.get_global_rect().position.x < ui.player_hp_bar.get_global_rect().position.x
		and player_shield.get_global_rect().end.x - ui.player_hp_bar.get_global_rect().position.x >= 16.0, "player shield visibly overlaps HP bar left end")
	check(ui.player_block.text == "%d" % ui.controller.player.block, "player block value renders on shield")
	var original_player_block := ui.controller.player.block
	ui.controller.player.block = 13
	ui._on_pblock(13)
	check(ui.player_block.text == "13", "player shield refreshes live block value")
	for panel in ui.unit_panels.values():
		var sprite_rect: Control = panel.get_node("Inner/SpriteRect")
		var hp_bar: Control = panel.get_node("Inner/HpBar")
		var block_shield: Control = panel.get_node("Inner/BlockShield")
		check(hp_bar.get_global_rect().position.y >= sprite_rect.get_global_rect().end.y, "enemy HP bar sits below monster")
		check(block_shield.get_global_rect().position.x < hp_bar.get_global_rect().position.x
			and block_shield.get_global_rect().end.x - hp_bar.get_global_rect().position.x >= 16.0, "enemy shield visibly overlaps HP bar left end")
		check(panel.get_node("Inner/BlockShield/BlockText").text == "0", "enemy block value renders on shield")
	var preview_enemy: CombatUnit = ui.controller.enemies[0]
	preview_enemy.block = 8
	ui.unit_panels[preview_enemy].build(preview_enemy, 0, false, 1, ui.controller)
	check(ui.unit_panels[preview_enemy].get_node("Inner/BlockShield/BlockText").text == "8", "enemy shield refreshes live block value")
	await capture("single")
	preview_enemy.block = 0
	ui.controller.player.block = original_player_block
	ui._on_pblock(original_player_block)
	var source: CardView = ui.hand_container.get_child(0)
	var before := ui.controller.hand.size()
	ui._targeting.on_card_drag_started(source)
	var target: Control = ui.unit_panels.values()[0]
	ui._targeting.on_card_drag_moved(source, target.get_global_rect().get_center())
	check(ui.drop_layer.arrow_visible, "drag arrow appears")
	await capture("drag")
	ui._targeting.on_card_drag_ended(source, Vector2(-100, -100))
	await get_tree().create_timer(0.3).timeout
	check(not ui.drop_layer.arrow_visible and ui.controller.hand.size() == before, "invalid drop clears arrow and preserves card")
	var backdrop: Texture2D
	if visual:
		await RenderingServer.frame_post_draw
		backdrop = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	remove_child(ui)
	ui.queue_free()
	await settle()
	FormalUI.combat_reward_pending = true
	FormalUI.combat_reward_backdrop = backdrop
	var reward := (load("res://scenes/rewards/RewardUI.tscn") as PackedScene).instantiate()
	var data := {"gold": 12, "cards": RewardBuilder.roll_card_choices(3, &"combat")}
	reward.setup(data, func(): pass)
	var gold_before := RunState.gold
	var deck_before := RunState.deck.size()
	add_child(reward)
	await settle()
	var overview: Control = reward.get_node("BattleRewardOverview")
	check(overview.get_node("Panel/Title").text == "战斗奖励", "post-combat panel uses a reward heading")
	check(overview.get_node("Panel/Items/Scroll/Grid").get_child_count() == 2, "overview shows gold and pending card choice only")
	check(RunState.gold == gold_before and RunState.deck.size() == deck_before, "overview does not grant duplicate rewards")
	await capture("victory")
	overview.get_node("Panel/Continue").pressed.emit()
	await settle()
	check(not reward.has_node("BattleRewardOverview"), "continue closes overview")
	check(reward.get_node("Dim/Center/MainPanel/Content/CardScroll/Cards").get_child_count() == 3, "original card choice remains available")
	remove_child(reward)
	reward.queue_free()
	await settle()
	# .new() must use the same authored layout and fit three enemies.
	RunState.pending_combat_enemy_ids.clear()
	ui = CombatUI.new()
	ui.pending_enemy_ids = ["claylump", "claylump", "claylump"]
	add_child(ui)
	await settle()
	check(ui.has_node("Safe/Layout/HandArea/EnergyRow/EnergyBadge") and ui.unit_panels.size() == 3, "new entry point shares formal scene")
	for panel in ui.unit_panels.values():
		check(panel.get_global_rect().end.x <= 721, "multi enemy panel within screen")
		check(panel.get_node("Inner/HpBar").size.x > 0, "multi enemy HP bar retains positive width")
		check(panel.get_node("Inner/HpBar").get_global_rect().position.y >= panel.get_node("Inner/SpriteRect").get_global_rect().end.y, "multi enemy HP bar remains below monster")
		check(panel.get_node("Inner/HpText").get_minimum_size().x <= panel.get_node("Inner/HpText").size.x, "multi enemy HP text fits bar")
	await capture("multi")
	remove_child(ui)
	ui.queue_free()
	await settle()
	print("FORMAL_BATTLE_RESULT FAIL=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)

func settle() -> void:
	for i in 8: await get_tree().process_frame

func capture(file: String) -> void:
	if visual:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/formal_battle_" + file + ".png")

func check(ok: bool, title: String) -> void:
	if not ok: failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", title])
