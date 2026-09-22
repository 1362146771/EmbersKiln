extends Node
var failures := 0
var pulses: Array = []
var ui: CombatUI

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func settle() -> void:
	await get_tree().create_timer(0.13, true).timeout
	pulses.clear()

func flush() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func play(id: StringName, target: int, cost := -1) -> void:
	await settle()
	ui.controller.hand = [{"id": id}]
	if cost >= 0: ui.controller.hand[0]["temporary_cost"] = cost
	ui.controller.energy = 9
	ui.controller.kiln_heat = 0
	check(ui.controller.play_card(0, target), "card resolves: " + String(id))
	check(pulses.is_empty(), "haptic waits for visible impact")
	var feedback := ui.get_node("CombatFeedback")
	if feedback.playing_hits: await feedback.playback_finished
	await flush()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/haptic_verify_save.json"
	HapticFeedback.pulse_selected.connect(func(cue, duration, amplitude): pulses.append([cue, duration, amplitude]))
	HapticFeedback.set_enabled(true)
	SignalBus.haptic_requested.emit(&"attack")
	SignalBus.haptic_requested.emit(&"player_hit")
	SignalBus.haptic_requested.emit(&"block")
	await flush()
	check(pulses.size() == 1 and pulses[0][0] == &"player_hit", "same-frame impacts choose one highest priority pulse")
	SignalBus.haptic_requested.emit(&"attack")
	await flush()
	check(pulses.size() == 1, "rapid events are dropped without a delayed queue")
	await settle()
	SignalBus.haptic_requested.emit(&"attack")
	HapticFeedback.set_enabled(false)
	await flush()
	check(pulses.is_empty(), "disabling clears pending feedback")
	HapticFeedback.enabled = true
	HapticFeedback.load_settings()
	check(not HapticFeedback.enabled, "disabled preference survives reload")
	HapticFeedback.set_enabled(true)
	get_tree().paused = true
	SignalBus.haptic_requested.emit(&"player_hit")
	await flush()
	check(pulses.is_empty(), "paused battle cannot vibrate")
	get_tree().paused = false
	SignalBus.ad_playback_started.emit("verify", &"verify")
	SignalBus.haptic_requested.emit(&"player_hit")
	await flush()
	check(pulses.is_empty(), "ads suppress feedback")
	SignalBus.ad_playback_finished.emit("verify", &"verify", &"cancelled")
	HapticFeedback.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	SignalBus.haptic_requested.emit(&"player_hit")
	await flush()
	check(pulses.is_empty(), "background suppresses feedback")
	HapticFeedback.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_combat_enemy_ids = [&"claylump", &"claylump", &"claylump"]
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await flush()
	for enemy in ui.controller.enemies:
		enemy.hp = 1000
		enemy.max_hp = 1000
	await play(&"strike", 0)
	check(pulses.size() == 1 and pulses[0][0] == &"attack", "Strike produces one light pulse")
	await play(&"bash", 0)
	check(pulses.size() == 1 and pulses[0][0] == &"attack_heavy", "Bash produces a heavy pulse")
	await play(&"bash", 0, 1)
	check(pulses.size() == 1 and pulses[0][0] == &"attack", "discount follows actual paid energy")
	await play(&"cleave", -1)
	check(pulses.size() == 1, "AOE has one pulse for all targets")
	await play(&"pummel", 1)
	check(pulses.size() == 4, "four-hit combo pulses at each visible hit")
	ui.controller.enemies[0].block = 1000
	await play(&"strike", 0)
	check(pulses.size() == 1 and pulses[0][0] == &"block", "fully blocked outgoing attack is light")
	ui.controller.enemies[0].block = 1
	await play(&"strike", 0)
	check(pulses.size() == 1 and pulses[0][0] == &"block_break", "enemy shield break has distinct pulse")
	await settle()
	ui.controller.player.block = 0
	ui.controller._dmg.deal_to_player(2)
	await flush()
	check(pulses.size() == 1 and pulses[0][0] == &"player_hit", "actual incoming damage pulses")
	await settle()
	ui.controller.player.block = 100
	ui.controller._dmg.deal_to_player(2)
	await flush()
	check(pulses.size() == 1 and pulses[0][0] == &"block", "fully blocked incoming hit has light pulse")
	await settle()
	ui.controller.player.block = 1
	ui.controller._dmg.deal_to_player(2)
	await flush()
	check(pulses.size() == 1 and pulses[0][0] == &"block_break", "player shield break has distinct pulse")
	await settle()
	ui.controller.kiln_heat = ui.controller._kiln_threshold()
	ui.controller._dmg.check_kiln_resonance()
	await flush()
	check(pulses.size() == 1 and pulses[0][0] == &"kiln_burst", "kiln resonance pulses once for all targets")
	ui.controller.enemies[2].hp = 1
	await play(&"strike", 2)
	check(pulses.size() == 1 and pulses[0][0] == &"enemy_defeat", "kill and impact merge into a single pulse")
	ui.controller.enemies[1].data = ui.controller.enemies[1].data.duplicate()
	ui.controller.enemies[1].data.tier = &"boss"
	ui.controller.enemies[1].hp = 1
	await play(&"strike", 1)
	check(pulses.size() == 1 and pulses[0][0] == &"boss_defeat", "boss death wins over the killing impact")
	await settle()
	ui.controller._dmg.deal_to_player(0)
	await flush()
	check(pulses.is_empty(), "zero damage does not trigger a hurt pulse")
	await settle()
	SignalBus.haptic_requested.emit(&"attack")
	ui.free()
	await flush()
	check(pulses.is_empty(), "combat exit cancels pending pulse")
	print("HAPTIC_RESULT:", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(0 if failures == 0 else 1)
