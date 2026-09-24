extends Node
var failures := 0
var checks := 0
var ui: CombatUI
var feedback: Node
var receipt: Array = []
var presented: Array = []
var capture_combo := false
var player_slashes := 0
var hit_times: Array[float] = []
var attack_started := 0.0
var attack_finished := 0.0

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
	presented.clear()
	hit_times.clear()
	player_slashes = 0
	attack_started = Time.get_ticks_usec() / 1000000.0
	check(ui.controller.play_card(0,target), "real card resolves: %s" % id)
	if not receipt.is_empty() and not ui.controller.attack_hits.is_empty():
		check(presented.is_empty(), "impact waits for player windup")
		await feedback.hit_presented
		var body: AnimatedSprite2D = ui.player_sprite.get_node("BodyAnimation")
		await get_tree().process_frame
		check(body.frame >= 2 and body.has_node("PlayerSlash"), "player slash accompanies impact: %s (frame=%d, slash=%s)" % [id, body.frame, body.has_node("PlayerSlash")])

func settled() -> void:
	if feedback.playing_hits: await feedback.playback_finished
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
	var player_body: AnimatedSprite2D = ui.player_sprite.get_node("BodyAnimation")
	player_body.animation_finished.connect(func(): attack_finished = Time.get_ticks_usec() / 1000000.0)
	player_body.child_entered_tree.connect(func(child: Node):
		if child.name == &"PlayerSlash": player_slashes += 1)
	check(player_body.sprite_frames.get_frame_count(&"attack") == 8, "attack includes three new recovery drawings")
	var attack_duration := 0.0
	for index in player_body.sprite_frames.get_frame_count(&"attack"):
		attack_duration += player_body.sprite_frames.get_frame_duration(&"attack", index) / player_body.sprite_frames.get_animation_speed(&"attack")
	check(is_equal_approx(attack_duration, 1.4), "source attack timeline remains 1.4 seconds")
	check(is_equal_approx(feedback._player_attack_duration(), 0.98), "player attack duration is 70 percent: 0.98 seconds")
	check(is_equal_approx(feedback._attack_windup(), 11.0 / 30.0 * 0.7), "first impact windup follows accelerated player animation")
	feedback.hit_presented.connect(on_hit)
	ui.controller.attack_feedback.connect(func(cost: int, targets: Array[int]): receipt.assign([cost, targets.duplicate()]))
	for enemy in ui.controller.enemies:
		enemy.hp = 1000
		enemy.max_hp = 1000
	await settled()
	var origins := [portrait(0).position,portrait(1).position,portrait(2).position]
	var canvas_origin := get_viewport().canvas_transform.origin
	await play(&"strike",1)
	check(is_equal_approx(player_body.get_playing_speed(), 1.0 / 0.7), "player attack actually runs at the configured faster speed")
	check(receipt == [1,[1]], "single attack receipt uses real target and paid cost")
	check(portrait(1).has_node("WhiteSlash") and not portrait(0).has_node("WhiteSlash") and not portrait(2).has_node("WhiteSlash"), "slash only on selected enemy")
	var peak_movement := 0.0
	for frame in range(12):
		await get_tree().process_frame
		peak_movement = maxf(peak_movement,portrait(1).position.distance_to(origins[1]))
	check(peak_movement > 0.1, "enemy portrait actually moves")
	check(portrait(0).position == origins[0] and portrait(2).position == origins[2], "other portraits remain still")
	check(get_viewport().canvas_transform.origin == canvas_origin, "one-cost attack does not shake screen")
	check(feedback.playing_hits, "presentation stays busy during axe recovery")
	await settled()
	check(absf(attack_finished - attack_started - 0.98) < 0.1, "real player animation completes in approximately 0.98 seconds")
	check(portrait(1).position == origins[1] and not portrait(1).has_node("WhiteSlash"), "portrait restored and slash freed")
	var status_origin := await status_layout_origin(0, &"bash")
	check(not status_origin.is_equal_approx(origins[0]), "status icon creates a distinct legal portrait layout")
	check(portrait(0).position.is_equal_approx(origins[0]), "removing reference status restores initial layout without hit drift")
	await play(&"bash",0)
	check(receipt == [2,[0]], "two-cost receipt")
	await get_tree().create_timer(0.1).timeout
	check(get_viewport().canvas_transform.origin.distance_to(canvas_origin)>0.1, "two-cost attack shakes screen")
	await capture("attack_slash")
	await play(&"bash",0)
	await settled()
	check(get_viewport().canvas_transform.origin == canvas_origin, "overlapping screen shakes restore original origin")
	check(portrait(0).position.is_equal_approx(status_origin), "repeated Bash returns to the independent status-layout origin")
	# Restart the active hurt animation explicitly; this must not accumulate offsets.
	var hit_before: int = portrait(0).hit_count
	portrait(0).play_hit()
	await get_tree().create_timer(0.05).timeout
	check(portrait(0).hit_playing and not portrait(0).position.is_equal_approx(status_origin), "overlap fixture restarts an actually displaced portrait")
	portrait(0).play_hit()
	await settled()
	check(portrait(0).hit_count == hit_before + 2 and not portrait(0).hit_playing
		and portrait(0).position.is_equal_approx(status_origin)
		and portrait(0).scale.is_equal_approx(Vector2.ONE) and is_zero_approx(portrait(0).rotation),
		"overlapping hurt restarts restore position scale and rotation without drift")
	await play(&"bash",0,1)
	check(receipt[0]==1, "discount uses actual cost")
	await get_tree().create_timer(0.08).timeout
	check(get_viewport().canvas_transform.origin == canvas_origin, "discounted bash does not shake screen")
	await settled()
	await play(&"cleave",-1)
	check(receipt[1]==[0,1,2], "AOE identifies every actual target")
	check(portrait(0).has_node("WhiteSlash") and portrait(1).has_node("WhiteSlash") and portrait(2).has_node("WhiteSlash"), "AOE slashes all enemy portraits")
	await settled()
	# Keep synchronous screenshot encoding out of measured combo timing.
	await play(&"pummel",2)
	check(receipt[1]==[2] and presented == [[2]], "multi-hit starts with one visible hit")
	var first_slash: WeakRef = weakref(portrait(2).get_node("WhiteSlash"))
	await get_tree().create_timer(0.2).timeout
	check(not is_instance_valid(first_slash.get_ref()), "four-hit enemy slash uses the compressed lifetime")
	await settled()
	capture_combo = false
	check(presented == [[2],[2],[2],[2]], "Pummel plays all four hits separately")
	var four_hit_gap: float = (hit_times.back() - hit_times.front()) / 3.0
	check(four_hit_gap < 0.25, "four-hit combo delivers continuous impacts below 0.25 seconds apart")
	check(player_slashes == 1 and not player_body.is_playing(), "Pummel plays one player swing and one player slash for four enemy impacts")
	await play(&"whirlwind",-1,-999,2)
	check(receipt==[2,[0,1,2]], "X attack reports actual energy spent")
	await get_tree().create_timer(0.08).timeout
	check(get_viewport().canvas_transform.origin.distance_to(canvas_origin)>0.1, "X=2 shakes screen")
	await settled()
	check(presented == [[0,1,2],[0,1,2]], "Whirlwind plays two simultaneous AOE rounds")
	check(player_slashes == 1, "Whirlwind plays one player slash for both AOE rounds")
	await play(&"twin_strike", 1)
	await settled()
	check(presented == [[1],[1]], "Twin Strike replays both hits")
	check(hit_times[1] - hit_times[0] > four_hit_gap, "two-hit attack has longer beats than four-hit attack")
	ui.controller.hand = [{"id": &"pummel"}]
	ui.controller.energy = 5
	ui.controller.kiln_heat = 0
	presented.clear()
	hit_times.clear()
	var ghost := Control.new()
	ghost.set_meta("discard_target", weakref(ui.discard_pile_view))
	ui.drag_layer.add_child(ghost)
	var cast_hp: int = ui.controller.enemies[1].hp
	BattleDirector.play_card_cast(ghost, portrait(1), GameData.get_card(&"pummel"), 0, 1, ui.controller)
	await feedback.hit_presented
	check(BattleDirector.input_locked and presented == [[1]], "real cast keeps input locked during remaining combo hits")
	check(ui.controller.enemies[1].hp == cast_hp - 8 and ui.controller.energy == 4, "presentation leaves four-hit damage and one card cost unchanged")
	get_tree().paused = true
	await get_tree().create_timer(0.1, true).timeout
	check(presented == [[1]], "pausing suspends queued hits")
	get_tree().paused = false
	await settled()
	check(presented == [[1],[1],[1],[1]] and not BattleDirector.input_locked, "real cast unlocks only after all four hits")
	ghost.queue_free()
	ui.controller._double_tap_charges = 1
	await play(&"strike", 0)
	await settled()
	check(presented == [[0],[0]], "Double Tap replays both attacks")
	check(player_slashes == 1, "Double Tap repeats enemy impacts without repeating player swing")
	ui.controller._double_tap_charges = 1
	await play(&"pummel", 0)
	await settled()
	check(presented.size() == 8 and player_slashes == 1, "eight-hit combo keeps every enemy hit and only one player swing")
	check((hit_times.back() - hit_times.front()) / 7.0 < four_hit_gap, "eight-hit combo plays faster per hit than four-hit combo")
	check(feedback._hit_interval(false, 100) == float(GameData.vfx["attack"]["combo_min_hit_seconds"]), "very long combo retains a visible minimum hit duration")
	await play(&"sword_boomerang", -1)
	var random_targets: Array = []
	for hit in ui.controller.attack_hits: random_targets.append([hit["target"]])
	await settled()
	check(presented == random_targets and presented.size() == 3, "random attacks preserve all three actual targets in order")
	await verify_enchanted_combo()
	if OS.get_cmdline_user_args().has("--visual"):
		capture_combo = true
		await play(&"pummel", 1)
		await settled()
		capture_combo = false
	await play(&"whirlwind", -1, -999, 0)
	check(presented.is_empty(), "zero-energy Whirlwind has no false attack pose or impact")
	ui.controller.enemies[2].hp = 3
	await play(&"pummel", 2)
	check(ui.unit_panels.has(ui.controller.enemies[2]) and feedback.pending_deaths == [2], "lethal combo retains portrait until its second actual hit")
	await settled()
	check(presented == [[2],[2]] and not ui.unit_panels.has(ui.controller.enemies[2]), "combo stops on killing hit and then frees target")
	ui.controller.enemies[2].hp = 1000
	ui.controller.enemies[2].death_resolved = false
	ui._enemy.create_enemy_panel(ui.controller.enemies[2], 2)
	await get_tree().process_frame
	await play(&"defend",-1,2)
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
	await play(&"strike",1)
	check(ui.controller.enemies[1].hp == blocked_hp and portrait(1).has_node("WhiteSlash"), "fully blocked attack still has impact")
	await settled()
	ui.controller.enemies[2].hp = 1
	ui.controller.enemies[2].block = 0
	await play(&"strike",2)
	check(receipt[1] == [2] and portrait(2).has_node("WhiteSlash"), "killing hit retains correct portrait impact")
	await settled()
	check(not ui.unit_panels.has(ui.controller.enemies[2]), "death clears target and its transient VFX")
	ui._set_player_pose(&"hit")
	check(is_equal_approx(player_body.get_playing_speed(), 1.0), "hurt animation retains normal speed after accelerated attack")
	VFXSystem.screen_shake(6.0)
	await get_tree().create_timer(0.06).timeout
	ui.queue_free()
	await get_tree().process_frame
	check(get_viewport().canvas_transform.origin == canvas_origin, "scene exit clears screen shake")
	print("FEEDBACK_RESULT:%s (%d checks, %d failures)" % ["PASS" if failures==0 else "FAIL",checks,failures])
	await preload("res://scripts/verify/CombatRegressionSupport.gd").finish(get_tree(), 0 if failures==0 else 1)

func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--visual"):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/%s.png" % label)
	# Synchronous PNG encoding must not become the next animation's first delta.
	await get_tree().process_frame
	await get_tree().process_frame

func on_hit(targets: Array[int]) -> void:
	for target in targets:
		check(portrait(target).hit_playing, "actual hit starts enemy hurt animation: %d" % target)
	presented.append(targets.duplicate())
	hit_times.append(Time.get_ticks_usec() / 1000000.0)
	if capture_combo and OS.get_cmdline_user_args().has("--visual"):
		var number := presented.size()
		await get_tree().create_timer(0.12).timeout
		await capture("multihit_pummel_%d" % number)

func verify_enchanted_combo() -> void:
	var entry := {"id": &"fiend_fire", "instance_id": "single_swing", "enchants": ["town_fiend_fire_1"], "enchant_active": true}
	ui.controller.hand = [entry, {"id": &"defend"}, {"id": &"strike"}, {"id": &"bash"}]
	ui.controller.energy = 5
	ui.controller.kiln_heat = 0
	presented.clear()
	hit_times.clear()
	player_slashes = 0
	var fx := ui.get_node("EnchantAttackFX")
	var before: int = fx.impact_count
	var ghost := Control.new()
	ghost.set_meta("discard_target", weakref(ui.discard_pile_view))
	ui.drag_layer.add_child(ghost)
	await BattleDirector.play_card_cast(ghost, portrait(1), GameData.get_card(&"fiend_fire"), 0, 1, ui.controller)
	check(presented == [[1],[1],[1]], "enchanted Fiend Fire retains three separate enemy hits")
	check(fx.impact_count == before + 3, "enchanted enemy impact effect plays for all three hits")
	check(hit_times.back() - hit_times.front() < 0.6, "enchanted combo compresses its three impacts into a rapid burst")
	check(fx.phase == "idle", "compressed enchant tail finishes before the player recovers")
	check(player_slashes == 1, "enchanted combo plays player animation and slash only once")
	check(not BattleDirector.input_locked, "enchanted combo unlocks after enemy impacts finish")
	ghost.queue_free()

func status_layout_origin(index: int, card_id: StringName) -> Vector2:
	# Establish expected layout independently, before any hit can pollute its origin.
	var enemy: CombatUnit = ui.controller.enemies[index]
	var saved := enemy.statuses.duplicate(true)
	var hit_before: int = portrait(index).hit_count
	for effect in GameData.get_card(card_id).effects:
		if effect.get("kind") == "apply_status" and effect.get("target") == "enemy":
			enemy.statuses[StringName(effect["status"])] = int(effect["value"])
	ui._enemy.refresh_enemy()
	await settled()
	var expected := portrait(index).position
	check(portrait(index).hit_count == hit_before and not portrait(index).hit_playing, "status reference changes layout without playing a hit")
	enemy.statuses.assign(saved)
	ui._enemy.refresh_enemy()
	await settled()
	return expected
