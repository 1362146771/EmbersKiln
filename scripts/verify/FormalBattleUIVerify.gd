extends Node
## 正式战斗布局、拖卡落点和只读奖励概览回归；可加 --visual 保存真实截图。
var failed := 0
var visual := false

func _ready() -> void:
	visual = OS.get_cmdline_user_args().has("--visual")
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/formal_battle_verify_save.json"
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	var ui := (load("res://scenes/combat/CombatPlay.tscn") as PackedScene).instantiate() as CombatUI
	add_child(ui)
	await settle()
	check(ui.player_hp_bar.get_theme_stylebox("fill") is StyleBoxTexture, "authored player HP texture")
	check(ui.get_node("EnergyBar").value == ui.controller.energy, "energy fill uses live energy")
	check(ui.hand_container.get_global_rect().position.y >= 1080, "hand occupies bottom strip")
	check(ui.end_turn_btn.get_global_rect().end.x <= 721, "end turn stays inside viewport")
	var potions: Control = ui.get_node("Safe/Layout/PotionBar")
	check(potions.get_global_rect().position.x >= 460 and potions.get_global_rect().end.x <= 720, "potions occupy upper right player area")
	check(ui.get_node("PlayerSprite").position.y <= 784, "player portrait meets state frame")
	ui.controller._summon_minion(&"emberhound", 1)
	await get_tree().create_timer(0.45).timeout
	await settle()
	for panel in ui.ally_panels.values():
		check(panel.get_global_rect().position.y >= potions.get_global_rect().end.y, "ally below potion shelf")
		check(panel.get_global_rect().end.x <= 720, "ally stays inside viewport")
		check(panel.get_global_rect().end.y <= 1085, "ally does not cover hand")
	await capture("single")
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
	check(ui.has_node("EnergyBar") and ui.unit_panels.size() == 3, "new entry point shares formal scene")
	for panel in ui.unit_panels.values():
		check(panel.get_global_rect().end.x <= 721, "multi enemy panel within screen")
		check(panel.get_node("Inner/HpBar").size.x > 0, "multi enemy HP bar retains positive width")
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
