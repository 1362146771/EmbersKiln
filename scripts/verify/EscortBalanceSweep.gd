extends Node
## Paired-seed diagnostic only; production stats never change.
class ProbeCombat extends CombatController:
	var legacy := false
	var leader_turn := -1
	var leader_hp := -1
	func _log(_message: String) -> void:
		pass
	func _post_enemy_death(unit: CombatUnit) -> void:
		if not unit.is_alive() and not unit.death_resolved and not unit.data.escort_ids.is_empty():
			leader_turn = turn
			leader_hp = player.hp
			if legacy:
				for escort in enemies:
					if escort.leader_index == enemies.find(unit) and escort.is_alive():
						escort.hp = 0
						escort.death_resolved = true
						escort.intent = {}
		super._post_enemy_death(unit)

var cfg: Dictionary
var template: Dictionary
var results: Array = []
var invalid := 0
var profile_filter := ""
var current_build := ""

func _ready() -> void:
	if OS.get_environment("ESCORT_TEST_APPDATA").is_empty():
		get_tree().quit(2)
		return
	await get_tree().process_frame
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/escort_balance_save.json"
	ProfileState.reset_to_defaults(false)
	RunState.start_new_run()
	template = RunState.to_save_dict()
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/testing/escort_balance_sweep.json"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="): profile_filter = arg.trim_prefix("--profile=")
	for build in cfg.builds:
		for id in build.cards:
			assert(GameData.get_card(StringName(id)) != null, "Unknown probe card: " + id)
	var cc := ProbeCombat.new()
	add_child(cc)
	for encounter in cfg.encounters:
		for profile in cfg.profiles:
			if not profile_filter.is_empty() and profile.id != profile_filter: continue
			for build in cfg.builds:
				var policies: Array = profile.get("policies", cfg.policies) if encounter.escort else ["adds_first"]
				for policy in policies:
					var modes := [true, false] if encounter.escort else [false]
					for legacy in modes:
						for attempt in int(cfg.sim.attempts_per_match):
							results.append(simulate(cc, encounter, profile, build, policy, legacy, int(cfg.sim.seed_base) + attempt))
				await get_tree().process_frame
			print("SWEEP_PROGRESS %s %s rows=%d" % [encounter.id, profile.id, results.size()])
			write_results()
	cc.free()
	write_results()
	print("ESCORT_BALANCE_RESULT:%s matches=%d invalid=%d" % ["COMPLETE" if invalid == 0 else "ERROR", results.size(), invalid])
	get_tree().quit(0 if invalid == 0 else 1)

func write_results() -> void:
	var suffix := "_" + profile_filter if not profile_filter.is_empty() else ""
	var file := FileAccess.open("res://Temp/escort_balance_results%s.json" % suffix, FileAccess.WRITE)
	file.store_string(JSON.stringify(results))

func simulate(cc: ProbeCombat, enc: Dictionary, profile: Dictionary, build: Dictionary, policy: String, legacy: bool, random_seed: int) -> Dictionary:
	RunState.from_save_dict(template)
	RunState.current_act = int(enc.act)
	RunState.current_node_type = &"elite"
	RunState.relic_ids.assign(profile.relics)
	RunState.deck.clear()
	var cards: Array = build.cards
	var starter_count := int(build.starter_count)
	if profile.has("starter_cards"):
		cards = profile.starter_cards + build.cards.slice(starter_count)
		starter_count = profile.starter_cards.size()
	for i in cards.size():
		RunState.deck.append({"id":StringName(cards[i]),"upgraded":bool(profile.upgrade_additions) and i >= starter_count,"enchants":[],"instance_id":"probe_%d" % i})
	current_build = build.id
	RunState.clear_combat_checkpoint()
	cc.legacy = legacy
	cc.leader_turn = -1
	cc.leader_hp = -1
	seed(random_seed)
	cc.start_combat([StringName(enc.id)])
	var starting_hp := cc.player.hp
	var capped := false
	while cc.combat_active() and cc.turn <= int(cfg.sim.max_turns):
		var count := 0
		while cc.combat_active() and count < int(cfg.sim.max_card_plays):
			count += 1
			if not cc.pending_card_choice.is_empty():
				resolve_choice(cc)
				continue
			var target := target_index(cc, policy)
			var index := choose_card(cc, target)
			if index < 0: break
			if not cc.play_card(index, target):
				invalid += 1
				break
		if count >= int(cfg.sim.max_card_plays):
			capped = true
			break
		if not cc.combat_active(): break
		cc.end_player_turn()
		for unit in cc.enemies.duplicate():
			if cc.enemy_pre(unit):
				cc._execute_enemy_intent(unit)
				cc.enemy_post(unit)
		cc.enemy_phase_done()
	var win := not cc.combat_active() and cc.player.is_alive()
	return {"enemy":enc.id,"profile":profile.id,"build":build.id,"policy":policy,"legacy":legacy,"seed":random_seed,"win":win,"turns":cc.turn,"hp":cc.player.hp,"loss":starting_hp - cc.player.hp,"leader_turn":cc.leader_turn,"tail_turns":cc.turn-cc.leader_turn if cc.leader_turn >= 0 else -1,"tail_loss":cc.leader_hp-cc.player.hp if cc.leader_hp >= 0 else -1,"capped":capped or cc.combat_active()}

func target_index(cc: CombatController, policy: String) -> int:
	if policy == "leader_first" and cc.enemies[0].is_alive(): return 0
	if policy == "tactical" and cc.enemies[0].is_alive():
		match cc.enemies[0].id:
			&"escort_commander": return 0
			&"escort_vanguard":
				return 1 if cc.enemies[1].is_alive() else 0
			&"escort_overseer":
				var side := 2 if current_build == "strength" else 1
				return side if cc.enemies[side].is_alive() else 0
	var best := -1
	var durability := INF
	for i in cc.enemies.size():
		var enemy: CombatUnit = cc.enemies[i]
		if not enemy.is_alive(): continue
		var value := float(enemy.hp + enemy.block)
		if value < durability:
			durability = value
			best = i
	return best

func resolve_choice(cc: CombatController) -> void:
	var candidates: Array = cc.pending_card_choice.candidates
	var selected := 0
	var best := -INF
	var exhausting: bool = String(cc.pending_card_choice.kind).begins_with("exhaust")
	for i in candidates.size():
		var cd := GameData.get_card(StringName(candidates[i].id))
		var value := 0.0
		if cd.type == &"status": value = 3.0
		elif String(cd.id) in ["strike", "defend"]: value = 2.0
		else: value = 1.0
		if not exhausting: value = -value
		if value > best:
			best = value
			selected = i
	cc.resolve_card_choice(selected)

func choose_card(cc: CombatController, target: int) -> int:
	if target < 0: return -1
	var incoming := 0
	var alive := 0
	for enemy in cc.enemies:
		if not enemy.is_alive(): continue
		alive += 1
		if enemy.intent.get("intent", "") == "attack":
			incoming += cc.enemy_preview_outgoing(enemy, int(enemy.intent.get("value", 0))) * int(enemy.intent.get("times", 1))
	var ai: Dictionary = cfg.ai
	var best := -1
	var best_score := -INF
	for i in cc.hand.size():
		if not cc.can_play_card(i): continue
		var entry: Dictionary = cc.hand[i]
		var cd := GameData.get_card(StringName(entry.id))
		if cd.id == &"fiend_fire":
			# Do not burn the engine before playing it, or exhaust every remaining
			# attack in a nonlethal multi-enemy fight (a known naive-pilot failure).
			var engine_in_hand := false
			for other in cc.hand:
				var other_data := GameData.get_card(StringName(other.id))
				if other_data.type == &"power": engine_in_hand = true
			var attacks_outside := false
			for other in cc.draw_pile + cc.discard_pile:
				if GameData.get_card(StringName(other.id)).type == &"attack": attacks_outside = true
			if engine_in_hand or (not attacks_outside and alive > 1): continue
		var effects := cd.get_effects(bool(entry.get("upgraded", false)))
		var score := 0.0
		var damage := 0.0
		var block := 0.0
		var setup: bool = cd.type == &"power" or ai.setup_skills.has(String(cd.id))
		if setup: score += float(ai.setup_priority if cc.turn <= int(ai.setup_turns) else ai.setup_late_priority)
		for effect in effects:
			var value := int(effect.get("value", 0))
			var kind := String(effect.get("kind", ""))
			match kind:
				"damage", "fatal_damage", "aoe_damage", "strength_scaled_damage", "x_aoe_damage", "exhaust_hand_damage", "damage_from_block":
					var times := int(effect.get("times", 1))
					if kind == "strength_scaled_damage": value += (int(effect.get("strength_multiplier", 1))-1) * cc.player.get_status(&"heat")
					if kind == "damage_from_block": value = cc.player.block
					if kind == "x_aoe_damage": times = cc.energy
					if kind == "exhaust_hand_damage": times = cc.hand.size()-1
					var hit := float(cc._dmg.compute_outgoing(cc.player, cc.enemies[target], value) * times)
					damage += hit
					if kind in ["aoe_damage", "x_aoe_damage"]: score += hit * (alive-1)
				"block": block += value + cc.player.get_status(&"temper")
				"double_block": block += cc.player.block
				"draw": score += float(ai.draw_priority) * value
				"energy": score += float(ai.energy_priority) * value
				"apply_status":
					if effect.get("status", "") in ["damp", "crazed"]: score += float(ai.debuff_priority)
		if damage >= cc.enemies[target].hp + cc.enemies[target].block: score += float(ai.kill_priority)
		score += damage * float(ai.damage_weight)
		score += minf(block, maxf(0.0, incoming-cc.player.block)) * float(ai.block_weight)
		if cd.id == &"entrench" and cc.player.block == 0: continue
		if cd.id == &"body_slam" and cc.player.block == 0: continue
		if cd.id == &"limit_break" and cc.player.get_status(&"heat") == 0: continue
		if cd.id == &"fiend_fire": score *= float(ai.finisher_priority)
		var cost := cc.card_cost(entry, cd)
		score /= maxf(1.0, cost if cost >= 0 else cc.energy)
		if score > best_score:
			best_score = score
			best = i
	return best
