extends Node2D
## 遗物系统冒烟测试：注入全部战斗相关遗物，断言各触发点正确生效。
## 真实运行（run_and_verify）后用 stdout 判定 PASS/FAIL。不依赖随机起手。

var controller: CombatController
var results: Array[String] = []
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	controller = $CombatController
	run()
	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if detail != "" else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if detail != "" else ""])


func run() -> void:
	seed(12345)
	RunState.start_new_run()
	check("新局: 不自动获得遗物", RunState.relic_ids.is_empty())
	var empty_save := RunState.to_save_dict()
	RunState.add_relic(&"emberheart")
	var owned_save := RunState.to_save_dict()
	RunState.start_new_run()
	check("重开: 清空上一局持有遗物且不补发", RunState.relic_ids.is_empty())
	check("读档: 保留已有遗物", RunState.from_save_dict(owned_save) and RunState.has_relic(&"emberheart"))
	check("读档: 空库存不补发遗物", RunState.from_save_dict(empty_save) and RunState.relic_ids.is_empty())
	var relic_heal: int = GameData.get_relic(&"emberheart").value
	RunState.take_damage(relic_heal)
	var hp_without_relic := RunState.hp
	controller._apply_relics_after_combat()
	check("无遗物: 不触发余温炭战后回血", RunState.hp == hp_without_relic)
	RunState.heal(relic_heal)
	# 显式注入战斗相关遗物，仅用于测试效果，不依赖开局赠送。
	RunState.add_relic(&"emberheart")
	RunState.add_relic(&"hearth_totem")
	RunState.add_relic(&"bellows_glove")
	RunState.add_relic(&"keeper_apron")
	RunState.add_relic(&"draft_flue")
	RunState.add_relic(&"firewood_axe")
	RunState.add_relic(&"heat_siphon")
	RunState.add_relic(&"sherd_vest")

	controller.start_combat(["claylump"])

	check("围炉小灶: 开局格挡=5", controller.player.block == 5, "block=%d" % controller.player.block)
	check("风箱手套: 开局炽热=1", controller.player.get_status(&"heat") == 1, "heat=%d" % controller.player.get_status(&"heat"))
	check("守窑围裙: 手牌=6(5+1)", controller.hand.size() == 6, "hand=%d" % controller.hand.size())
	check("抽风口: 首回合能量=4(3+1)", controller.energy == 4, "energy=%d" % controller.energy)
	check("余温炭: 显式获得后在场", RunState.has_relic(&"emberheart"))

	# ---- 汲热钳 + 劈薪斧：打出首张攻击牌 ----
	controller.player.hp = 50
	var ai := _find_attack()
	if ai >= 0:
		var ehp_before: int = controller.enemies[0].hp
		var base: int = _base_damage(ai)
		var heat: int = controller.player.get_status(&"heat")
		controller.play_card(ai, 0)
		check("劈薪斧: 首攻 +4 伤害（含炽热加成）", controller.enemies[0].hp == ehp_before - (base + heat + 4),
			"enemy %d -> %d (base=%d heat=%d)" % [ehp_before, controller.enemies[0].hp, base, heat])
		check("汲热钳: 攻击后回血 +2", controller.player.hp == 52, "hp=%d" % controller.player.hp)
	else:
		check("首张攻击牌可取得", false, "手牌无攻击牌")

	# ---- 陶片背心：强制敌人攻击并验证反伤 ----
	var ehp2: int = controller.enemies[0].hp
	controller.enemies[0].intent = {"intent": "attack", "value": 6}
	controller.end_player_turn()
	_advance_to_player_turn()   # 驱动敌人真实攻击 → 触发陶片背心反伤
	check("陶片背心: 受击反伤 3", controller.enemies[0].hp == ehp2 - 3,
		"enemy %d -> %d" % [ehp2, controller.enemies[0].hp])

	# ---- 余温炭：战后回血 ----
	var hp_before: int = RunState.hp
	controller.enemies[0].apply_damage(999)
	controller._check_combat_end()
	check("余温炭: 战后回血 +6", RunState.hp == hp_before + 6,
		"hp %d -> %d" % [hp_before, RunState.hp])


func _find_attack() -> int:
	for i in controller.hand.size():
		var cd: CardData = GameData.get_card(StringName(controller.hand[i]["id"]))
		if cd != null and cd.type == &"attack":
			return i
	# 没有就结束一回合重抽再看一次
	controller.end_player_turn()
	for i in controller.hand.size():
		var cd: CardData = GameData.get_card(StringName(controller.hand[i]["id"]))
		if cd != null and cd.type == &"attack":
			return i
	return -1


func _base_damage(hand_index: int) -> int:
	var cd: CardData = GameData.get_card(StringName(controller.hand[hand_index]["id"]))
	var effs: Array = cd.get_effects(false)
	for eff in effs:
		if eff is Dictionary and String(eff.get("kind", "")) == "damage":
			return int(eff.get("value", 0))
	return 0


## 模拟 BattleDirector 驱动一整轮敌人阶段（与真实战斗走同一组公开 API）：
## 对每个存活敌人执行 清旧格挡 → 执行意图(攻击走 outgoing/attack_hit，其余走 act)
## → 状态衰减+滚动下一意图，最后 enemy_phase_done 收尾回到下一玩家回合。
func _advance_to_player_turn() -> void:
	for e in controller.enemies:
		if not e.is_alive():
			continue
		controller.enemy_pre(e)
		var mv: Dictionary = e.intent
		var kind: String = String(mv.get("intent", "unknown"))
		if kind == "attack":
			var dmg: int = controller.enemy_outgoing(e, int(mv.get("value", 0)))
			controller.enemy_attack_hit(e, dmg)
		else:
			controller.enemy_act(e)
		controller.enemy_post(e)
	controller.enemy_phase_done()


func _print_report() -> void:
	for r in results:
		print(r)
	print("[RelicTest] PASS=%d FAIL=%d" % [pass_count, fail_count])
	if fail_count > 0:
		print("[RelicTest] RESULT=FAIL")
	else:
		print("[RelicTest] RESULT=PASS")
