extends Node
## Authored, programmatic and reparented combat HUDs must keep working bindings.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[PASS] " if ok else "[FAIL] ", label)

func _ready() -> void:
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/combat_node_binding_save.json"
	for mode in ["authored", "programmatic", "reparented"]:
		await verify_entry(mode)
	print("COMBAT_NODE_BINDING_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func verify_entry(mode: String) -> void:
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_combat_enemy_ids = [&"claylump"]
	var ui: CombatUI
	if mode == "programmatic":
		ui = CombatUI.new()
	else:
		ui = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	if mode == "reparented":
		# Moving controls in the editor must not invalidate script bindings again.
		var discard: Control = ui.get_node("%DiscardPile")
		var energy: Label = ui.get_node("%PlayerEnergy")
		discard.reparent(ui.get_node("Safe/Layout/HandArea/HandRow"))
		energy.reparent(ui.get_node("Safe/Layout/HandArea/EnergyRow"))
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	check(ui.discard_pile_view != null, mode + " discard bound")
	check(ui.player_energy != null, mode + " energy bound")
	if ui.discard_pile_view == null or ui.player_energy == null:
		ui.queue_free()
		await get_tree().process_frame
		return
	check(ui.get_node_or_null("%DiscardPile") == ui.discard_pile_view, mode + " discard unique name")
	check(ui.get_node_or_null("%PlayerEnergy") == ui.player_energy, mode + " energy unique name")
	check(ui.controller.phase == CombatController.Phase.PLAYER, mode + " combat initialized")
	check(ui.player_energy.text == str(ui.controller.energy), mode + " initial energy display")
	ui.controller.hand = [{"id": &"defend", "upgraded": false}]
	var before := ui.controller.energy
	var discard_before := ui.controller.discard_pile.size()
	check(ui.controller.play_card(0, 0), mode + " card plays")
	await get_tree().process_frame
	check(ui.controller.energy == before - GameData.get_card(&"defend").cost, mode + " card pays energy")
	check(ui.player_energy.text == str(ui.controller.energy), mode + " energy display refreshes")
	check(ui.controller.discard_pile.size() == discard_before + 1, mode + " played card reaches discard")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	ui.discard_pile_view.gui_input.emit(click)
	check(ui.card_browser_open(), mode + " discard click opens browser")
	ui._close_card_browser()
	await get_tree().process_frame
	check(not ui.card_browser_open(), mode + " discard browser closes")
	ui.draw_pile_button.pressed.emit()
	check(ui.card_browser_open(), mode + " draw pile still opens")
	ui._close_card_browser()
	if mode == "authored" and OS.get_cmdline_user_args().has("--visual"):
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://Temp/combat_node_binding.png") == OK, "fixed HUD screenshot")
	ui.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
