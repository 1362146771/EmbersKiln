extends Node
## F6 sandbox: real cast pipeline, repeatable targets, and manual Shader inspection.
var ui: CombatUI
var fx: Node
var fixture: Dictionary
var busy := false
var _previous_autosave := true
var _previous_save_path := ""
var _previous_time_scale := 1.0
var _has_preview := false
@onready var card_choice: OptionButton = $Tools/Panel/Body/Selection/Card
@onready var target_choice: OptionButton = $Tools/Panel/Body/Selection/Target
@onready var play_button: Button = $Tools/Panel/Body/Actions/Play
@onready var pause_button: Button = $Tools/Panel/Body/Actions/Pause
@onready var reset_button: Button = $Tools/Panel/Body/Actions/Reset
@onready var speed_choice: OptionButton = $Tools/Panel/Body/Playback/Speed
@onready var repeat_button: CheckButton = $Tools/Panel/Body/Playback/Repeat
@onready var timeline: HSlider = $Tools/Panel/Body/Timeline
@onready var state_label: Label = $Tools/Panel/Body/State

func _ready() -> void:
	fixture = JSON.parse_string(FileAccess.get_file_as_string("res://data/testing/enchant_attack_lab.json"))
	_previous_autosave = ProfileManager.autosave_enabled
	_previous_save_path = SaveManager.runtime_save_path
	_previous_time_scale = Engine.time_scale
	ProfileManager.autosave_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Temp/enchant_fx_lab"))
	SaveManager.runtime_save_path = "res://Temp/enchant_fx_lab/save.json"
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_combat_enemy_ids = fixture["enemies"].duplicate()
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	ui.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Battle.add_child(ui)
	PauseManager.hide_pause_button()
	await get_tree().process_frame
	fx = ui.get_node("EnchantAttackFX")
	for id in fixture["cards"]:
		card_choice.add_item(GameData.get_card(StringName(id)).name)
	for speed in fixture["speeds"]: speed_choice.add_item("%s×" % str(speed))
	speed_choice.select(fixture["speeds"].find(1.0))
	target_choice.select(1)
	card_choice.select(fixture["cards"].find("carnage"))
	play_button.pressed.connect(_play)
	pause_button.pressed.connect(_toggle_pause)
	reset_button.pressed.connect(_reset)
	speed_choice.item_selected.connect(_change_speed)
	card_choice.item_selected.connect(_selection_changed)
	target_choice.item_selected.connect(_selection_changed)
	timeline.value_changed.connect(_scrub)
	$Tools/Panel/Body/TitleRow/Collapse.pressed.connect(_toggle_panel)
	_reset()
	if OS.get_cmdline_user_args().has("--smoke"): _smoke_test.call_deferred()

func _entry(id: String) -> Dictionary:
	var enchant_ids: Array = CardMutation.directions(id)
	return {"id": StringName(id), "instance_id": "lab_" + id, "enchants": [enchant_ids[0]], "enchant_active": true}

func _reset() -> void:
	if busy: return
	get_tree().paused = false
	pause_button.text = "暂停"
	fx.clear()
	_has_preview = false
	VFXSystem.cancel_screen_shake()
	ui.controller.hand.clear()
	ui.controller.discard_pile.clear()
	ui.controller.exhaust_pile.clear()
	ui.controller.kiln_heat = 0
	ui.controller.energy = int(fixture["energy"])
	ui.controller._first_attack_done = false
	ui.controller.hand.append(_entry(String(fixture["cards"][card_choice.selected])))
	for id in fixture["support_cards"]: ui.controller.hand.append({"id": StringName(id)})
	for enemy in ui.controller.enemies:
		enemy.hp = int(fixture["target_hp"])
		enemy.max_hp = int(fixture["target_hp"])
		enemy.block = 0
		enemy.statuses.clear()
		ui._prev_ehp[enemy] = enemy.hp
	ui.controller.player.hp = ui.controller.player.max_hp
	ui.controller.player.block = 0
	ui.controller.player.statuses.clear()
	RunState.hp = ui.controller.player.hp
	ui._prev_php = RunState.hp
	ui.player_sprite.call("_restore_idle")
	ui._refresh_all()
	timeline.set_value_no_signal(0.0)
	state_label.text = "完整演出 %.2f 秒 · 播放或拖动时间轴" % _total_seconds()
	pause_button.disabled = true

func _set_busy(value: bool) -> void:
	busy = value
	play_button.disabled = value
	reset_button.disabled = value
	card_choice.disabled = value
	target_choice.disabled = value
	timeline.editable = not value
	pause_button.disabled = not value and not _has_preview

func _play() -> void:
	if busy: return
	_reset()
	_change_speed(speed_choice.selected)
	_set_busy(true)
	await get_tree().process_frame
	var view: CardView = ui.hand_container.get_child(0)
	# Use the same drag/cast entry as the playable battle, including its ghost lifetime.
	ui._targeting.on_card_drag_started(view)
	if is_instance_valid(ui._ghost): ui._ghost.global_position = view.global_position
	await ui._targeting.cast_card(view, target_choice.selected)
	await get_tree().create_timer(float(fx.config["impact_seconds"]), false).timeout
	_set_busy(false)
	state_label.text = "播放完成 · 可重播或拖动时间轴"
	if repeat_button.button_pressed: _play.call_deferred()

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	pause_button.text = "继续" if get_tree().paused else "暂停"

func _toggle_panel() -> void:
	var expanded: bool = $Tools/Panel/Body/Selection.visible
	for row in ["Selection", "Actions", "Playback", "State", "Timeline"]:
		get_node("Tools/Panel/Body/" + row).visible = not expanded
	$Tools/Panel/Body/TitleRow/Collapse.text = "展开" if expanded else "收起"
	$Tools/Panel.set_deferred("size", Vector2($Tools/Panel.size.x, 0.0))

func _change_speed(index: int) -> void:
	Engine.time_scale = float(fixture["speeds"][index])

func _selection_changed(_index: int) -> void:
	_reset()

func _charge_seconds() -> float:
	return BattleDirector.CAST_TRAVEL + fx.prelude_for(_entry(String(fixture["cards"][card_choice.selected])))

func _total_seconds() -> float:
	return _charge_seconds() + float(fx.config["impact_seconds"])

func _phase_label() -> String:
	if fx.phase == "charge":
		return "红眼特写" if fx.elapsed < fx.prelude_duration else "蓄势"
	return "命中 / 收尾"

func _scrub(value: float) -> void:
	if busy: return
	var card := _entry(String(fixture["cards"][card_choice.selected]))
	if not fx.begin(card, target_choice.selected, BattleDirector.CAST_TRAVEL): return
	var seconds := value * _total_seconds()
	if seconds >= _charge_seconds():
		var targets: Array[int] = [target_choice.selected]
		fx.impact(targets)
		fx.elapsed = seconds - _charge_seconds()
	else:
		fx.elapsed = seconds
	fx.set_process(false)
	fx._update_visuals()
	_has_preview = true
	state_label.text = "关键帧 · %s · %d ms" % [_phase_label(), roundi(seconds * 1000.0)]
	# Manual scrubbing already holds the frame; the next Play starts a fresh real cast.
	pause_button.disabled = true

func _process(_delta: float) -> void:
	if not busy or not is_instance_valid(fx): return
	var total: float = _total_seconds()
	var seconds: float = fx.elapsed + (_charge_seconds() if fx.phase == "impact" else 0.0)
	if fx.phase == "idle": seconds = total
	timeline.set_value_no_signal(clampf(seconds / total, 0.0, 1.0))
	state_label.text = ("已暂停 · " if get_tree().paused else "播放中 · ") + _phase_label()

func _exit_tree() -> void:
	get_tree().paused = false
	Engine.time_scale = _previous_time_scale
	BattleDirector.input_locked = false
	# This F6-only run never becomes a resumable production adventure.
	RunState.is_active = false
	ProfileManager.autosave_enabled = _previous_autosave
	SaveManager.runtime_save_path = _previous_save_path

func _smoke_test() -> void:
	get_tree().create_timer(60.0, true).timeout.connect(func():
		printerr("ENCHANT_LAB_TIMEOUT")
		get_tree().quit(2))
	var failures := 0
	for index in fixture["cards"].size():
		card_choice.select(index)
		var before: int = fx.impact_count
		await _play()
		if fx.impact_count != before + 1 or busy or BattleDirector.input_locked: failures += 1
		_reset()
		if ui.controller.hand.size() != 1 + fixture["support_cards"].size(): failures += 1
	timeline.value = 0.5
	if fx.phase != "impact" or fx.is_processing(): failures += 1
	var energy_before: int = ui.controller.energy
	timeline.value = 0.1
	if fx.phase != "charge" or ui.controller.energy != energy_before: failures += 1
	speed_choice.select(0)
	_change_speed(0)
	if Engine.time_scale != float(fixture["speeds"][0]): failures += 1
	await _play()
	if fx.phase != "idle" or busy: failures += 1
	speed_choice.select(fixture["speeds"].find(1.0))
	_change_speed(speed_choice.selected)
	_play()
	await get_tree().process_frame
	_toggle_pause()
	var frozen: float = fx.elapsed
	await get_tree().create_timer(0.06, true).timeout
	if not busy or fx.elapsed != frozen: failures += 1
	_toggle_pause()
	while busy: await get_tree().process_frame
	var loop_start: int = fx.impact_count
	repeat_button.button_pressed = true
	_play()
	while fx.impact_count < loop_start + 2: await get_tree().process_frame
	repeat_button.button_pressed = false
	while busy: await get_tree().process_frame
	_toggle_panel()
	if $Tools/Panel/Body/Selection.visible: failures += 1
	_toggle_panel()
	if not $Tools/Panel/Body/Selection.visible: failures += 1
	card_choice.select(0)
	_reset()
	if fx.screen.visible or get_tree().paused: failures += 1
	if OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/enchant_fx_lab/controls.png")
	print("ENCHANT_LAB_RESULT:%s" % ("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(0 if failures == 0 else 1)
