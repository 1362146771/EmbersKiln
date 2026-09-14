extends Node
var failures := 0
var checks := 0
var ui: CombatUI
var feedback: Node
var receipt: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func portrait(index: int) -> Control:
	return ui.unit_panels[ui.controller.enemies[index]].get_node("Inner/SpriteRect")

func play(id: StringName, target: int, cost_override := -999, energy := 5) -> void:
	ui.controller.hand = [{"id":id}]
	if cost_override != -999:
		ui.controller.hand[0]["temporary_cost"] = cost_override
	ui.controller.energy = energy
	ui.controller.kiln_heat = 0
	receipt.clear()
	check(ui.controller.play_card(0,target), "real card resolves: %s" % id)

func settled() -> void:
	await get_tree().create_timer(0.5).timeout

func _ready() -> void:
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/combat_feedback_verify_save.json"
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	RunState.pending_combat_enemy_ids = [&"claylump", &"claylump", &"claylump"]
	ui = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await get_tree().process_frame
	feedback = ui.get_node("CombatFeedback")
	ui.controller.attack_feedback.connect(func(cost: int, targets: Array[int]): receipt.assign([cost, targets.duplicate()]))
	for enemy in ui.controller.enemies:
		enemy.hp = 1000
		enemy.max_hp = 1000
	var origins := [portrait(0).position,portrait(1).position,portrait(2).position]
	var canvas_origin := get_viewport().canvas_transform.origin
	await settled()
	play(&"strike",1)
	check(receipt == [1,[1]], "single attack receipt uses real target and paid cost")
	check(portrait(1).has_node("WhiteSlash") and not portrait(0).has_node("WhiteSlash") and not portrait(2).has_node("WhiteSlash"), "slash only on selected enemy")
	var peak_movement := 0.0
	for frame in range(12):
		await get_tree().process_frame
		peak_movement = maxf(peak_movement,portrait(1).position.distance_to(origins[1]))
	check(peak_movement > 0.1, "enemy portrait actually moves")
	check(portrait(0).position == origins[0] and portrait(2).position == origins[2], "other portraits remain still")
	check(get_viewport().canvas_transform.origin == canvas_origin, "one-cost attack does not shake screen")
	await settled()
	check(portrait(1).position == origins[1] and not portrait(1).has_node("WhiteSlash"), "portrait restored and slash freed")
	play(&"bash",0)
	check(receipt == [2,[0]], "two-cost receipt")
	await get_tree().create_timer(0.1).timeout
	check(get_viewport().canvas_transform.origin.distance_to(canvas_origin)>0.1, "two-cost attack shakes screen")
	await capture("attack_slash")
	play(&"bash",0)
	await settled()
	check(get_viewport().canvas_transform.origin == canvas_origin, "overlapping screen shakes restore original origin")
	check(portrait(0).position == origins[0], "overlapping portrait shakes restore original origin")
	play(&"bash",0,1)
	check(receipt[0]==1, "discount uses actual cost")
	await get_tree().create_timer(0.08).timeout
	check(get_viewport().canvas_transform.origin == canvas_origin, "discounted bash does not shake screen")
	await settled()
	play(&"cleave",-1)
	check(receipt[1]==[0,1,2], "AOE identifies every actual target")
	check(portrait(0).has_node("WhiteSlash") and portrait(1).has_node("WhiteSlash") and portrait(2).has_node("WhiteSlash"), "AOE slashes all enemy portraits")
	await settled()
	play(&"pummel",2)
	check(receipt[1]==[2], "multi-hit target deduplicated per card")
	await settled()
	play(&"whirlwind",-1,-999,2)
	check(receipt==[2,[0,1,2]], "X attack reports actual energy spent")
	await get_tree().create_timer(0.08).timeout
	check(get_viewport().canvas_transform.origin.distance_to(canvas_origin)>0.1, "X=2 shakes screen")
	await settled()
	play(&"defend",-1,2)
	check(receipt.is_empty() and not portrait(0).has_node("WhiteSlash"), "expensive skill has no attack feedback")
	await settled()
	SignalBus.player_hp_changed.emit(15,100)
	check(not feedback.low_health_active and not feedback.blood.visible, "exactly 15 percent is not low health")
	SignalBus.player_hp_changed.emit(14,100)
	await get_tree().create_timer(0.4).timeout
	check(feedback.low_health_active and feedback.blood.visible, "below 15 percent activates blood edge")
	check(feedback.blood.mouse_filter == Control.MOUSE_FILTER_IGNORE, "blood overlay does not block input")
	var dim: float = feedback.blood_material.get_shader_parameter("opacity")
	await get_tree().create_timer(0.5).timeout
	check(float(feedback.blood_material.get_shader_parameter("opacity")) > dim, "blood edge breathes over time")
	await capture("low_health_breath")
	SignalBus.player_hp_changed.emit(30,200)
	await settled()
	check(not feedback.blood.visible and not feedback.is_processing(), "max-HP-aware recovery fades and stops processing")
	SignalBus.player_hp_changed.emit(1,100)
	SignalBus.player_hp_changed.emit(0,100)
	await settled()
	check(not feedback.blood.visible, "zero HP clears blood overlay")
	SignalBus.player_hp_changed.emit(1,100)
	SignalBus.player_hp_changed.emit(20,100)
	SignalBus.player_hp_changed.emit(1,100)
	await settled()
	check(feedback.blood.visible, "rapid threshold crossing cancels stale fade")
	feedback.clear()
	check(not feedback.blood.visible and not feedback.is_processing(), "combat end cleanup hides overlay")
	receipt.clear()
	ui.controller.hand = [{"id":&"bash"}]
	ui.controller.energy = 0
	check(not ui.controller.play_card(0,0) and receipt.is_empty(), "failed card has no feedback receipt")
	ui.controller.enemies[1].block = 1000
	var blocked_hp: int = ui.controller.enemies[1].hp
	play(&"strike",1)
	check(ui.controller.enemies[1].hp == blocked_hp and portrait(1).has_node("WhiteSlash"), "fully blocked attack still has impact")
	await settled()
	ui.controller.enemies[2].hp = 1
	ui.controller.enemies[2].block = 0
	play(&"strike",2)
	check(receipt[1] == [2] and portrait(2).has_node("WhiteSlash"), "killing hit retains correct portrait impact")
	await settled()
	check(not ui.unit_panels.has(ui.controller.enemies[2]), "death clears target and its transient VFX")
	VFXSystem.screen_shake(6.0)
	await get_tree().create_timer(0.06).timeout
	ui.queue_free()
	await get_tree().process_frame
	check(get_viewport().canvas_transform.origin == canvas_origin, "scene exit clears screen shake")
	print("FEEDBACK_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/%s.png" % label)
