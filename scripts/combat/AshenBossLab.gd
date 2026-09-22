extends Node
## F6 可玩的灰络测试场；正式存档与永久档案只读，测试写入独立目录。
var ui: CombatUI
var fixture: Dictionary
var old_run: Dictionary
var old_profile: Dictionary
var old_save_path := ""
var old_profile_path := ""
var old_autosave := true
var original_profile_hash := ""
var original_run_hash := ""
var changing := false
var preset: OptionButton
var difficulty: OptionButton
var status: Label
var reset_button: Button
var heal_button: Button
var energy_button: Button
var tools_body: VBoxContainer

func _ready() -> void:
	old_run = RunState.to_save_dict().duplicate(true)
	old_profile = ProfileState.to_save_dict().duplicate(true)
	old_save_path = SaveManager.runtime_save_path
	old_profile_path = ProfileManager.runtime_profile_path
	old_autosave = ProfileManager.autosave_enabled
	original_profile_hash = FileAccess.get_sha256(old_profile_path) if FileAccess.file_exists(old_profile_path) else ""
	original_run_hash = FileAccess.get_sha256(old_save_path) if FileAccess.file_exists(old_save_path) else ""
	ProfileManager.autosave_enabled = false
	DirAccess.make_dir_recursive_absolute("user://ashen_boss_lab")
	SaveManager.runtime_save_path = "user://ashen_boss_lab/run.json"
	ProfileManager.runtime_profile_path = "user://ashen_boss_lab/profile.json"
	fixture = JSON.parse_string(FileAccess.get_file_as_string("res://data/testing/ashen_boss_lab.json"))
	_build_tools()
	await restart()
	if "--smoke" in OS.get_cmdline_user_args(): _smoke.call_deferred()

func _build_tools() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 130
	add_child(layer)
	var panel := PanelContainer.new()
	panel.name = "LabTools"
	panel.position = Vector2(282, 790)
	panel.custom_minimum_size = Vector2(426, 0)
	panel.theme = FormalUI.theme()
	panel.add_theme_stylebox_override("panel", FormalUI.stone("bd_stone_framed.png", 16))
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	var title := HBoxContainer.new()
	column.add_child(title)
	var label := Label.new()
	label.text = "灰络 · 测试场"
	label.add_theme_font_size_override("font_size", 23)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(label)
	var collapse := Button.new()
	collapse.text = "收起"
	collapse.add_theme_font_size_override("font_size", 20)
	title.add_child(collapse)
	tools_body = VBoxContainer.new()
	column.add_child(tools_body)
	collapse.pressed.connect(func():
		tools_body.visible = not tools_body.visible
		collapse.text = "收起" if tools_body.visible else "展开"
		panel.set_deferred("size", Vector2(panel.size.x, 0)))
	var selections := HBoxContainer.new()
	tools_body.add_child(selections)
	preset = OptionButton.new()
	preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset.add_theme_font_size_override("font_size", 20)
	for item in fixture.presets: preset.add_item(item.name)
	selections.add_child(preset)
	difficulty = OptionButton.new()
	difficulty.add_theme_font_size_override("font_size", 20)
	for item in DifficultyRules.tiers(): difficulty.add_item(item.name)
	selections.add_child(difficulty)
	var row := HBoxContainer.new()
	tools_body.add_child(row)
	reset_button = _button(row, "重开", restart)
	heal_button = _button(row, "回满生命", heal)
	energy_button = _button(row, "补满能量", refill_energy)
	preset.item_selected.connect(func(_index): restart())
	difficulty.item_selected.connect(func(_index): restart())
	status = Label.new()
	status.custom_minimum_size.x = 390
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 18)
	tools_body.add_child(status)

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 42
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func can_edit() -> bool:
	return not changing and is_instance_valid(ui) and not BattleDirector.input_locked and not ui._play_queue.busy() and not TransitionManager.is_transitioning and ui.controller.pending_card_choice.is_empty()

func restart() -> void:
	if changing or is_instance_valid(ui) and not can_edit(): return
	changing = true
	if is_instance_valid(ui):
		ui.queue_free()
		await get_tree().process_frame
	VFXSystem.cancel_screen_shake()
	ProfileState.reset_to_defaults(false)
	RunState.start_new_run()
	# Test selection bypasses unlocks only in this local scene, using real rule data.
	RunState.difficulty_snapshot = DifficultyRules.tiers()[difficulty.selected].duplicate(true)
	RunState.current_act = GameData.act_configs.size() - 1
	RunState.current_node_type = &"boss"
	RunState.granny_opening = {"resolved":true}
	RunState.pre_run_preparation_resolved = true
	RunState.revive_used_count = CombatReviveSystem.max_per_run()
	RunState.run_id = "" # No lab fireseed or reward transaction, even on defeat.
	RunState.deck.clear()
	var chosen: Dictionary = fixture.presets[preset.selected]
	var cards: Array = GameData.balance.starting_deck if chosen.get("starting_deck", false) else chosen.cards
	for id in cards: RunState.deck.append(RunState._new_card_entry(StringName(id)))
	RunState.pending_combat_enemy_ids = [fixture.boss_id]
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	$Battle.add_child(ui)
	SignalBus.combat_ended.disconnect(ui._on_combat_end)
	if not SignalBus.combat_ended.is_connected(_ended): SignalBus.combat_ended.connect(_ended)
	PauseManager.hide_pause_button()
	status.text = "直接拖牌战斗；切换牌组/难度会重开。\n测试不记录通关，不覆盖正式存档。"
	changing = false

func heal() -> void:
	if not can_edit() or not ui.controller.combat_active(): return
	ui.controller.player.hp = ui.controller.player.max_hp
	ui.controller._sync_player_hp()
	ui._refresh_all()

func refill_energy() -> void:
	if not can_edit() or ui.controller.phase != CombatController.Phase.PLAYER: return
	ui.controller.energy = ui.controller.max_energy
	SignalBus.energy_changed.emit(ui.controller.energy, ui.controller.max_energy)
	ui._refresh_all()

func _ended(won: bool) -> void:
	ui.combat_over = true
	ui._close_card_browser()
	ui._refresh_all()
	status.text = "击败灰络！点击重开再次挑战。" if won else "挑战失败。点击重开再次挑战。"

func _process(_delta: float) -> void:
	if not is_instance_valid(reset_button): return
	var locked := not can_edit()
	reset_button.disabled = locked
	preset.disabled = locked
	difficulty.disabled = locked
	heal_button.disabled = locked or not ui.controller.combat_active()
	energy_button.disabled = locked or not ui.controller.combat_active() or ui.controller.phase != CombatController.Phase.PLAYER

func _exit_tree() -> void:
	if old_run.is_empty(): return
	RunState.is_active = false
	ProfileState.from_save_dict(old_profile, false)
	RunState.from_save_dict(old_run)
	ProfileManager.autosave_enabled = old_autosave
	ProfileManager.runtime_profile_path = old_profile_path
	SaveManager.runtime_save_path = old_save_path

func _smoke() -> void:
	get_tree().create_timer(45.0).timeout.connect(func(): get_tree().quit(2))
	var failures := 0
	for i in fixture.presets.size():
		preset.select(i)
		await restart()
		if ui.controller.enemies[0].id != &"ashen_binder" or ui.controller.enemies[0].max_hp != GameData.get_enemy(&"ashen_binder").base_hp: failures += 1
		ui.controller.player.hp = 1
		heal()
		ui.controller.energy = 0
		refill_energy()
		if ui.controller.player.hp != ui.controller.player.max_hp or ui.controller.energy != ui.controller.max_energy: failures += 1
	preset.select(0)
	difficulty.select(DifficultyRules.tiers().size() - 1)
	await restart()
	if RunState.difficulty_snapshot.id != "extreme": failures += 1
	ui.controller.phase = CombatController.Phase.ENEMY
	await BattleDirector.run_enemy_turn(ui.controller, ui.player_panel, func(e): return ui.unit_panels.get(e))
	if not ui.controller.enemies[0].ash_sealed: failures += 1
	ui.controller.enemies[0].hp = 0
	ui.controller._check_combat_end()
	await get_tree().process_frame
	if not ui.combat_over or TransitionManager.is_transitioning or not status.text.contains("击败"): failures += 1
	await restart()
	ui.controller.player.hp = 0
	ui.controller.check_player_death()
	await get_tree().process_frame
	if not ui.combat_over or TransitionManager.is_transitioning or not status.text.contains("失败"): failures += 1
	await restart()
	ProfileState.first_battle_started = not bool(old_profile.get("first_battle_started", false))
	ProfileManager.save_profile()
	SaveManager.save_game()
	var current_profile_hash := FileAccess.get_sha256(old_profile_path) if FileAccess.file_exists(old_profile_path) else ""
	var current_run_hash := FileAccess.get_sha256(old_save_path) if FileAccess.file_exists(old_save_path) else ""
	if current_profile_hash != original_profile_hash or current_run_hash != original_run_hash: failures += 1
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/ashen_boss_lab.png")
	print("ASHEN_LAB_RESULT:%s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(0 if failures == 0 else 1)
