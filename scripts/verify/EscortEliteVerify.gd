extends Node
## ES 用户确认数值，真实控制器、地图与 Director 回归。夹具耐久只用于观测长循环。
var passed := 0
var failed := 0
var victories := 0
var cc: CombatController
const LEADERS := [&"escort_commander", &"escort_vanguard", &"escort_deployer", &"escort_overseer"]

func _ready() -> void:
	var isolated := OS.get_environment("ESCORT_TEST_APPDATA").replace("\\", "/")
	if isolated.is_empty() or not OS.get_user_data_dir().begins_with(isolated + "/"):
		push_error("EscortEliteVerify requires isolated APPDATA")
		get_tree().quit(2)
		return
	await get_tree().process_frame
	ProfileManager.autosave_enabled = false
	SignalBus.combat_ended.connect(func(won: bool):
		if won: victories += 1)
	_test_formation_and_cycles()
	_test_recruitment()
	_test_guard()
	_test_observers()
	_test_deaths_and_rewards()
	_test_map_and_restart()
	await _test_director()
	await _test_ui()
	if OS.get_cmdline_user_args().has("--visual"):
		await _test_visual()
	await _test_reward_flow()
	if cc != null: cc.free()
	print("ESCORT_ELITE_RESULT:%s %d PASS / %d FAIL" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func check(label: String, ok: bool) -> void:
	if ok: passed += 1
	else: failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", label])

func fresh(id: StringName) -> CombatUnit:
	if cc != null: cc.free()
	RunState.is_active = false
	RunState.start_new_run()
	RunState.current_act = 1 if id in LEADERS.slice(0, 2) else 2
	RunState.relic_ids.clear()
	RunState.pending_combat_enemy_ids.clear()
	cc = CombatController.new()
	add_child(cc)
	cc.start_combat([id])
	cc.player.max_hp = 10000
	cc.player.hp = 10000
	cc.hand.clear()
	return cc.enemies[0]

func round_step() -> int:
	var before := cc.player.hp
	cc.end_player_turn()
	for unit in cc.enemies.duplicate():
		if cc.enemy_pre(unit):
			cc._execute_enemy_intent(unit)
			cc.enemy_post(unit)
	cc.enemy_phase_done()
	return before - cc.player.hp

func wounds() -> int:
	var count := 0
	for pile in [cc.hand, cc.draw_pile, cc.discard_pile, cc.exhaust_pile]:
		for card in pile:
			if String(card.id) == "wound": count += 1
	return count

func play(id: StringName, target: int = 0) -> bool:
	cc.energy = 100
	cc.hand = [{"id": id, "upgraded": false}]
	return cc.play_card(0, target)

func _test_formation_and_cycles() -> void:
	var hp_targets := [[165,35,35], [150,50,38], [210,28,28], [220,42,42]]
	var damage_targets := [[20,50,41,26,65], [26,34,32], [38,80,0,40,84], [32,36]]
	for i in LEADERS.size():
		var leader := fresh(LEADERS[i])
		check("编队HP不叠幕倍率 " + String(leader.id), cc.enemies.map(func(e):return e.max_hp) == hp_targets[i])
		check("固定主从顺序 " + String(leader.id), cc.enemies.size() == 3 and cc.enemies[1].leader_index == 0 and cc.enemies[2].leader_index == 0)
		var deck := RunState.deck.duplicate(true)
		for n in damage_targets[i].size():
			var actual := round_step()
			check("%s 第%d回合攻击：%d" % [leader.id,n+1,actual], actual == damage_targets[i][n])
			if i == 0 and n == 0:
				check("全队力量3与随从格挡6保留", cc.enemies.all(func(e):return e.get_status(&"heat") == 3) and cc.enemies[1].block == 6 and cc.enemies[2].block == 6)
		check("状态牌不进入永久卡组", RunState.deck == deck)
		if i == 1: check("干扰兵实际施加虚弱与2伤口", wounds() == 2 and cc.player.get_status(&"damp") > 0)
		if i == 2: check("两波攻击各加入2伤口", wounds() == 4)

func _test_recruitment() -> void:
	var leader := fresh(&"escort_commander")
	var old := cc.enemies[1]
	cc._dmg.deal_kiln_resonance(old, old.hp)
	check("先清一兵第一回合只受10", round_step() == 10)
	round_step()
	check("第3行动明确预告补兵", leader.intent.intent == "unknown")
	check("补兵回合只受旧兵10伤", round_step() == 10)
	var recruit := cc.enemies[1]
	check("复用槽位但新建独立单位", cc.enemies.size() == 3 and recruit != old and recruit != cc.enemies[2])
	check("新兵满血无旧力量且出生回合未行动", recruit.hp == 35 and recruit.get_status(&"heat") == 0 and recruit.enemy_actions == 0)
	check("补兵获得12格挡", leader.block == 12)
	check("下一回合新旧兵分别吃新强化", round_step() == 23 and recruit.enemy_actions == 1 and recruit.get_status(&"heat") == 3 and cc.enemies[2].get_status(&"heat") == 6)
	leader = fresh(&"escort_commander")
	round_step()
	round_step()
	check("满员第3行动预告攻击", leader.intent.intent == "attack")
	cc._dmg.deal_kiln_resonance(cc.enemies[2], cc.enemies[2].hp)
	check("公布后击杀随从立刻将攻击切为补兵", leader.intent.intent == "unknown" and leader.intent.id == "deploy")
	check("临时缺员执行补兵且不暗打18", round_step() == 10 and cc.enemies[2].enemy_actions == 0)
	leader = fresh(&"escort_deployer")
	for n in 12: round_step()
	check("连续补充不突破三槽且主怪持续成长", cc.enemies.size() == 3 and leader.get_status(&"heat") == 8)
	check("重复击杀及自毁随从不累积局外击杀火种", RunState.defeated.is_empty())

func _test_guard() -> void:
	var leader := fresh(&"escort_vanguard")
	cc.player.add_status(&"heat", 3)
	cc.player.add_status(&"damp", 2)
	leader.add_status(&"crazed", 2)
	leader.block = 4
	var before := leader.hp
	cc._deal_attack_value(cc.player, leader, 10)
	check("护卫在力量/虚弱/易伤后取整、格挡前减伤", before - leader.hp == 2 and leader.block == 0)
	cc.player.statuses.clear()
	leader.statuses.clear()
	cc.player.add_status(&"stoke", 3)
	before = leader.hp
	cc._deal_attack_value(cc.player, leader, 10)
	check("额外攻击伤害同样计入护卫减伤", before - leader.hp == 6)
	before = leader.hp
	cc._dmg.deal_to_unit(leader, 11)
	check("直接伤害不吃护卫减伤", before - leader.hp == 11)
	leader.block = 10
	before = leader.hp
	cc._dmg.deal_kiln_resonance(leader, 11)
	check("直接失血同时绕过护卫和格挡", before - leader.hp == 11 and leader.block == 10)
	cc.player.statuses.clear()
	check("护卫自身不减伤", cc._dmg.compute_outgoing(cc.player, cc.enemies[1], 11) == 11)
	cc._dmg.deal_kiln_resonance(cc.enemies[1], 50)
	check("护卫死亡减伤立即解除", cc._dmg.compute_outgoing(cc.player, leader, 11) == 11)

func _test_observers() -> void:
	var leader := fresh(&"escort_overseer")
	for n in 5: play(&"defend")
	cc.player.block = 0
	check("5张技能令技能监视者+5且主怪不涨", cc.enemies[1].get_status(&"heat") == 5 and leader.get_status(&"heat") == 0)
	check("技能反制当回合伤害37", round_step() == 37)
	leader = fresh(&"escort_overseer")
	for n in 3: play(&"inflame")
	check("3张能力给主怪6力量", leader.get_status(&"heat") == 6)
	check("能力反制首回合38、次回合54", round_step() == 38 and round_step() == 54)
	leader = fresh(&"escort_overseer")
	cc.energy = 0
	cc.hand = [{"id":&"defend","upgraded":false}]
	check("能量不足出牌不触发", not cc.play_card(0) and cc.enemies[1].get_status(&"heat") == 0)
	cc.draw_pile = [{"id":&"defend","upgraded":false}]
	cc._play_top_draw_card_exhausted()
	check("自动技能触发监视一次", cc.enemies[1].get_status(&"heat") == 1)
	cc.draw_pile = [{"id":&"inflame","upgraded":false}]
	cc._play_top_draw_card_exhausted()
	check("自动能力触发主怪强化一次", leader.get_status(&"heat") == 2)
	cc._dmg.deal_kiln_resonance(cc.enemies[2], cc.enemies[2].hp)
	play(&"inflame")
	check("能力监视者死后停止新增且旧力量保留", leader.get_status(&"heat") == 2)
	cc._dmg.deal_kiln_resonance(cc.enemies[1], cc.enemies[1].hp)
	play(&"defend")
	check("两个来源死亡无残留反制", leader.get_status(&"heat") == 2)
	fresh(&"escort_overseer")
	cc._resolve_effects(GameData.get_card(&"defend").get_effects(false), cc.player, cc.player)
	check("单独复制技能效果不计为出牌", cc.enemies[1].get_status(&"heat") == 0)

func _test_deaths_and_rewards() -> void:
	for id in LEADERS:
		var leader := fresh(id)
		var before := victories
		var escort_hp := [cc.enemies[1].hp, cc.enemies[2].hp]
		var intents := [cc.enemies[1].intent.duplicate(true), cc.enemies[2].intent.duplicate(true)]
		cc._dmg.deal_kiln_resonance(leader, leader.hp)
		cc._check_combat_end()
		cc._post_enemy_death(leader)
		check("主怪死亡不提前胜利 " + String(id), victories == before and cc.combat_active())
		check("随从保留生命与意图 " + String(id), [cc.enemies[1].hp,cc.enemies[2].hp] == escort_hp and [cc.enemies[1].intent,cc.enemies[2].intent] == intents)
		check("主怪死后随从继续行动 " + String(id), round_step() > 0 and cc.enemies[1].enemy_actions == 1 and cc.enemies[2].enemy_actions == 1)
		cc._dmg.deal_kiln_resonance(cc.enemies[1], cc.enemies[1].hp)
		check("仍剩一名随从时继续战斗 " + String(id), cc.combat_active() and victories == before)
		cc._dmg.deal_kiln_resonance(cc.enemies[2], cc.enemies[2].hp)
		cc._check_combat_end()
		cc._post_enemy_death(cc.enemies[2])
		check("全部击败才发一次胜利 " + String(id), victories == before + 1 and not cc.combat_active())
		check("实际击杀随从仍不计永久收益 " + String(id), not RunState.defeated.has(cc.enemies[1].id) and not RunState.defeated.has(cc.enemies[2].id))
		fresh(id)
		before = victories
		for unit in cc.enemies: unit.hp = 1
		play(&"cleave")
		check("群攻逐个结算死亡且胜利一次 " + String(id), not cc.combat_active() and victories == before + 1 and cc.enemies.all(func(e):return e.death_resolved))
	var leader := fresh(&"escort_deployer")
	cc.enemies[1].hp = 1
	var hp := RunState.max_hp
	play(&"feed", 1)
	check("吞噬随从无永久生命收益且不爆炸", RunState.max_hp == hp and cc.player.hp == 10000)
	leader.hp = 1
	play(&"feed", 0)
	check("吞噬主怪正常获得永久生命", RunState.max_hp == hp + 3)
	leader = fresh(&"escort_deployer")
	cc._dmg.deal_kiln_resonance(cc.enemies[1], 28)
	round_step()
	check("拆一枚第二回合峰值52", round_step() == 52)
	leader = fresh(&"escort_deployer")
	cc._dmg.deal_kiln_resonance(cc.enemies[1], 28)
	cc._dmg.deal_kiln_resonance(cc.enemies[2], 28)
	round_step()
	check("拆两枚第二回合只剩24", round_step() == 24)
	fresh(&"escort_deployer")
	round_step()
	cc.player.block = 1000
	check("自爆可全部格挡并仍然自毁", round_step() == 0 and not cc.enemies[1].is_alive() and not cc.enemies[2].is_alive())
	leader = fresh(&"escort_commander")
	leader.hp = 1
	leader.add_status(&"ashrot", 1)
	check("主怪行动前燃烧死亡随从仍攻击", round_step() == 14 and cc.combat_active() and cc.enemies[1].enemy_actions == 1)
	leader = fresh(&"escort_overseer")
	cc._dmg.deal_kiln_resonance(leader, leader.hp)
	play(&"defend")
	play(&"inflame")
	check("主怪死后技能反制仍生效但不会强化尸体", cc.enemies[1].get_status(&"heat") == 1 and leader.get_status(&"heat") == 0)
	leader = fresh(&"escort_deployer")
	cc._dmg.deal_kiln_resonance(leader, leader.hp)
	check("投放者死后倒计时随从正常首轮行动", round_step() == 16 and cc.combat_active())
	var before := victories
	check("剩余倒计时随从按原规则自爆后才胜利", round_step() == 56 and not cc.combat_active() and victories == before + 1)

func _test_map_and_restart() -> void:
	var seen: Dictionary = {}
	for act in [1,2]:
		for trial in 30:
			for row in MapGenerator.generate(GameData.act_configs[act]):
				for node in row:
					if node.type == &"elite": seen[String(node.enemy_ids[0])] = true
	check("四套都可从正式地图精英池生成", LEADERS.all(func(id):return seen.has(String(id))))
	check("现有精英保留且总计9种", GameData.get_enemies_by_tier(&"elite").size() == 9 and GameData.get_enemies_by_tier(&"minion").size() == 6)
	for id in LEADERS:
		fresh(id)
		RunState.create_combat_checkpoint([id])
		var initial := cc.enemies.map(func(e):return [e.id,e.hp,e.intent.id,e.get_status(&"heat")])
		round_step()
		var saved := RunState.to_save_dict()
		check("检查点随单局存档可还原 " + String(id), RunState.from_save_dict(saved) and RunState.restore_combat_checkpoint())
		cc.start_combat([id])
		check("重开确定性还原编队 " + String(id), initial == cc.enemies.map(func(e):return [e.id,e.hp,e.intent.id,e.get_status(&"heat")]))

func state() -> Array:
	return [cc.player.hp, wounds(), cc.enemies.map(func(e):return [e.id,e.hp,e.block,e.get_status(&"heat"),e.enemy_actions,e.intent.get("id",""),e.can_act_from_turn])]

func _test_director() -> void:
	for id in LEADERS:
		fresh(id)
		for n in 5: round_step()
		var direct := state()
		fresh(id)
		for n in 5:
			cc.end_player_turn()
			await BattleDirector.run_enemy_turn(cc, null, func(_e):return null)
		check("五回合Director和直接结算完全一致 " + String(id), state() == direct)
	var leader := fresh(&"escort_overseer")
	leader.hp = 1
	cc._temporary_thorns = 1
	cc.end_player_turn()
	await BattleDirector.run_enemy_turn(cc, null, func(_e):return null)
	check("反伤击败主怪后随从当轮继续攻击", cc.combat_active() and cc.player.hp == 9968 and cc.enemies[1].enemy_actions == 1 and cc.enemies[2].enemy_actions == 1)

func _test_ui() -> void:
	var leader := fresh(&"escort_commander")
	var panel := load("res://scenes/combat/EnemyPanel.tscn").instantiate() as EnemyPanel
	add_child(panel)
	await get_tree().process_frame
	panel.build(cc.enemies[1], 1, false, 3, cc)
	check("突击兵意图预览包含先行动的全队强化", panel._format_intent(cc.enemies[1],cc).contains("10"))
	panel.build(leader, 0, false, 3, cc)
	check("全队强化与护盾显示", panel.get_node("Inner/IntentBar").get_child_count() >= 3)
	leader = fresh(&"escort_overseer")
	panel.build(cc.enemies[1], 1, false, 3, cc)
	check("技能反制说明显示", panel.get_node("Inner/IntentBar").tooltip_text.contains("技能"))
	panel.queue_free()

func _test_reward_flow() -> void:
	if cc != null:
		cc.free()
		cc = null
	get_tree().current_scene = null
	RunState.is_active = false
	RunState.start_new_run()
	RunState.relic_ids.clear()
	RunState.current_act = 1
	RunState.current_node_type = &"elite"
	RunState.pending_combat_enemy_ids = [&"escort_commander"]
	var gold := RunState.gold
	var gold_range: Dictionary = GameData.balance.rewards.elite_gold
	var before := victories
	var ui := load("res://scenes/combat/CombatPlay.tscn").instantiate() as CombatUI
	get_tree().root.add_child(ui)
	get_tree().current_scene = ui
	await get_tree().process_frame
	var c := ui.controller
	c._dmg.deal_kiln_resonance(c.enemies[0], c.enemies[0].hp)
	check("实际精英战主怪击杀不提前回程发奖", not RunState.pending_post_combat and c.combat_active() and victories == before and RunState.gold == gold and RunState.relic_ids.is_empty())
	c._dmg.deal_kiln_resonance(c.enemies[1], c.enemies[1].hp)
	check("剩最后一兵仍不回程", not RunState.pending_post_combat and c.combat_active())
	c._dmg.deal_kiln_resonance(c.enemies[2], c.enemies[2].hp)
	check("实际精英战全灭才写入回程状态", RunState.pending_post_combat and RunState.last_combat_victory and victories == before + 1)
	await get_tree().create_timer(VFXSystem.DEATH_DUR + 0.8).timeout
	var reward := get_tree().current_scene
	check("精英编队战后实际进入RewardUI", reward != null and reward.scene_file_path == "res://scenes/rewards/RewardUI.tscn")
	var awarded_gold := RunState.gold - gold
	check("三敌只发一份精英金币和一件遗物", awarded_gold >= int(gold_range.min) and awarded_gold <= int(gold_range.max) and RunState.relic_ids.size() == 1)
	if reward != null and reward.has_method("_finish"):
		while TransitionManager.is_transitioning: await get_tree().process_frame
		reward._finish()
		await get_tree().scene_changed
		await get_tree().process_frame
	check("返回地图不重复发奖", RunState.gold == gold + awarded_gold and RunState.relic_ids.size() == 1 and RunState.current_act == 1)

func _test_visual() -> void:
	cc.free()
	cc = null
	for id in LEADERS:
		RunState.is_active = false
		RunState.start_new_run()
		RunState.pending_combat_enemy_ids.clear()
		RunState.current_act = 1 if id in LEADERS.slice(0,2) else 2
		var ui := load("res://scenes/combat/CombatPlay.tscn").instantiate() as CombatUI
		ui.pending_enemy_ids = [id]
		add_child(ui)
		await get_tree().process_frame
		await get_tree().process_frame
		ui._refresh_all()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://Temp")
		check("截图 " + String(id), get_viewport().get_texture().get_image().save_png("res://Temp/%s.png" % id) == OK)
		check("三单位均有正式可选面板 " + String(id), ui.unit_panels.size() == 3)
		_check_portrait_sizes(ui)
		for unit in ui.controller.enemies:
			var panel: EnemyPanel = ui.unit_panels[unit]
			var bar := panel.get_node("Inner/IntentBar") as Control
			var sprite := panel.get_node("Inner/SpriteRect") as Control
			check("意图不遮挡立绘 " + String(unit.id), bar.get_global_rect().end.y <= sprite.get_global_rect().position.y)
		if id == &"escort_commander":
			var c := ui.controller
			c.player.hp = 10000
			c.player.max_hp = 10000
			var old := c.enemies[1]
			c._dmg.deal_kiln_resonance(old, old.hp)
			for n in 3:
				c.end_player_turn()
				await BattleDirector.run_enemy_turn(c, ui.player_panel, func(e):return ui.unit_panels.get(e))
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			check("真实演出补兵后无遗留面板", ui.unit_panels.size() == 3 and not ui.unit_panels.has(old) and ui.unit_panels.has(c.enemies[1]))
			check("补兵仍在左翼槽位", ui.unit_panels[c.enemies[1]].global_position.x < ui.unit_panels[c.enemies[2]].global_position.x)
			check("补兵图形路径出生回合零行动", c.enemies[1].enemy_actions == 0 and c.enemies[1].hp == 35)
			_check_portrait_sizes(ui)
			check("补兵截图", get_viewport().get_texture().get_image().save_png("res://Temp/escort-refill.png") == OK)
		if id == &"escort_overseer":
			var c := ui.controller
			ui._casting = true
			c.energy = 100
			c.hand = [{"id":&"inflame","upgraded":false}]
			c.play_card(0)
			var bar: Control = ui.unit_panels[c.enemies[0]].get_node("Inner/IntentBar")
			check("出牌锁内反制伤害预览即时更新", bar.get_child(0).get_node("Value").text == "22")
			ui._casting = false
		var leader := ui.controller.enemies[0]
		ui.controller._dmg.deal_kiln_resonance(leader, leader.hp)
		await get_tree().create_timer(VFXSystem.DEATH_DUR + 0.1).timeout
		ui._refresh_all()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check("主怪死亡后两名随从面板保持可选 " + String(id), ui.unit_panels.size() == 2 and not ui.unit_panels.has(leader) and ui.controller.combat_active())
		for unit in ui.controller.enemies:
			if not unit.is_alive(): continue
			# Playing the preceding card schedules a deferred portrait layout.
			await get_tree().process_frame
			await get_tree().process_frame
			var panel: EnemyPanel = ui.unit_panels[unit]
			var sprite: TextureRect = panel.get_node("Inner/SpriteRect")
			check("主怪死后随从保持裁切适配 " + String(unit.id), sprite.texture is AtlasTexture and sprite.size.y > 200.0)
			var labels := ""
			for badge in panel.get_node("Inner/IntentBar").get_children():
				labels += badge.get_node("Value").text
			if unit.id == &"escort_guard": check("主怪死后隐藏失效护主提示", not labels.contains("护主"))
			if unit.id == &"escort_power_observer": check("主怪死后隐藏失效能力强化提示", not labels.contains("能力+"))
			if unit.id == &"escort_skill_observer": check("主怪死后保留自身技能反制提示", labels.contains("技能+"))
			var durability := unit.hp + unit.block
			ui.controller.energy = 100
			ui.controller.hand = [{"id":&"strike","upgraded":false}]
			var played := ui.controller.play_card(0, ui.controller.enemies.find(unit))
			check("主怪死后随从可被单独出牌命中 " + String(unit.id), played and unit.hp + unit.block < durability)
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		check("主怪死亡后随从截图 " + String(id), get_viewport().get_texture().get_image().save_png("res://Temp/%s-leader-dead.png" % id) == OK)
		ui.queue_free()
		await get_tree().process_frame


func _portrait_visible_rect(sprite: TextureRect) -> Rect2:
	var texture_size := sprite.texture.get_size()
	var fit := minf(sprite.size.x / texture_size.x, sprite.size.y / texture_size.y)
	var bounds := Rect2(sprite.texture.get_image().get_used_rect())
	return Rect2(sprite.global_position + (sprite.size - texture_size * fit) / 2.0 + bounds.position * fit, bounds.size * fit)


func _check_portrait_sizes(ui: CombatUI) -> void:
	var leader := ui.controller.enemies[0]
	var leader_sprite: TextureRect = ui.unit_panels[leader].get_node("Inner/SpriteRect")
	var leader_bounds := _portrait_visible_rect(leader_sprite)
	var occupied := 0.0
	var intent_limited := false
	for unit in ui.controller.enemies:
		var panel: EnemyPanel = ui.unit_panels[unit]
		var sprite: TextureRect = ui.unit_panels[unit].get_node("Inner/SpriteRect")
		var bounds := _portrait_visible_rect(sprite)
		var room := Rect2(panel.global_position + panel.portrait_area.position, panel.portrait_area.size)
		occupied = maxf(occupied, maxf(bounds.size.x / room.size.x, bounds.size.y / room.size.y))
		check("主体适配而非透明画布 " + String(unit.id), sprite.texture is AtlasTexture)
		var intent: Control = panel.get_node("Inner/IntentBar")
		intent_limited = intent_limited or absf(bounds.position.y - panel.global_position.y - panel.portrait_top_limit()) < 0.1
		check("主体保持在意图与状态之间 " + String(unit.id), bounds.position.y >= intent.get_global_rect().end.y and bounds.end.y <= room.end.y + 0.1)
		check("独立新立绘 " + String(unit.id), unit.data.sprite.begins_with("SPR_Enemy_Escort"))
		check("新立绘完整位于视口 " + String(unit.id), ui.get_viewport_rect().encloses(bounds))
		if unit != leader:
			var ratio := leader_bounds.get_area() / bounds.get_area()
			check("主怪与随从可见面积约3:2 " + String(unit.id), absf(ratio - 1.5) < 0.02)
			print("PORTRAIT_AREA_RATIO %s / %s = %.4f" % [leader.id, unit.id, ratio])
	var target := float(GameData.vfx["enemy_portrait"]["multi_enemy_scale"])
	check("编队放大至确认比例或意图安全上限", occupied <= target + 0.01 and (absf(occupied - target) < 0.01 or intent_limited))
	print("PORTRAIT_SCREEN_SIZE %s %.1fx%.1f occupation=%.3f" % [leader.id, leader_bounds.size.x, leader_bounds.size.y, occupied])
