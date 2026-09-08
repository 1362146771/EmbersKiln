extends Node
## P2 新机制确定性验证（headless）：
##  - 2.4 窑温·共鸣：每攻击牌 +1 窑温，满 5 触发贯穿 5 伤给全体敌人并消耗 5
##  - 2.5 活力 stoke：攻击伤害 +层数，出手后 -1 层
##  - 2.5 缓冲 glaze：受击减伤 =层数，触发 1 次后 -1 层
##  - 正式载体：鼓风令基础/升级活力 1；不裂基础缓冲 1、升级缓冲 2
##  - 2.5 衰朽 thirst：空过回合→下回合 -1 能量；打出攻击则不惩罚
## 纯逻辑层驱动，不依赖 UI。输出 P2_RESULT:PASS / FAIL。

var controller: CombatController
var results: Array[String] = []
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()

	# 注入测试用卡 / 敌人（不污染正式数据）
	GameData.cards[StringName("t_strike")] = CardData.from_dict({
		"id": "t_strike", "name": "测试劈", "type": "attack", "cost": 1,
		"target": "enemy", "effects": [{"kind": "damage", "value": 6}]
	})
	GameData.cards[StringName("t_double")] = CardData.from_dict({
		"id": "t_double", "name": "测试二连", "type": "attack", "cost": 1,
		"target": "enemy", "effects": [{"kind": "damage", "value": 3, "times": 2}]
	})
	GameData.enemies[StringName("t_dummy")] = EnemyData.from_dict({
		"id": "t_dummy", "name": "测试木桩", "tier": "normal", "hp": 200,
		"ai": "weighted_random",
		"moves": [{"id": "guard", "intent": "defend", "value": 0, "chance": 1.0}]
	})

	if not RunState.is_active:
		RunState.start_new_run()

	controller = CombatController.new()
	add_child(controller)

	run()
	_print_report()


func start(enemy_id: String, deck_ids: Array) -> void:
	RunState.deck = []
	for id in deck_ids:
		RunState.deck.append({"id": id, "upgraded": false})
	controller.start_combat([enemy_id])


## 从手牌里打出最多 n 张 attack 牌（自动选首个存活敌人）。
func play_attacks(n: int) -> void:
	var played := 0
	while played < n:
		var idx := -1
		for i in range(controller.hand.size()):
			var c: Dictionary = controller.hand[i]
			var cd: CardData = GameData.get_card(StringName(c["id"]))
			if cd != null and cd.type == &"attack":
				idx = i
				break
		if idx < 0 or controller.energy < 1:
			break
		controller.play_card(idx, -1)
		played += 1


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] " + name)
	else:
		fail_count += 1
		results.append("[FAIL] " + name + "  " + detail)


func effect_value(effects: Array, kind: String, status: String = "") -> int:
	for eff in effects:
		if not (eff is Dictionary) or String(eff.get("kind", "")) != kind:
			continue
		if status != "" and String(eff.get("status", "")) != status:
			continue
		return int(eff.get("value", 0))
	return -1


func run() -> void:
	# ---- 状态显示名：统一采用《杀戮尖塔 2》通用术语，内部 id 不迁移 ----
	var expected_status_names := {
		&"heat": "力量",
		&"temper": "敏捷",
		&"crazed": "易伤",
		&"damp": "虚弱",
		&"ashrot": "燃烧",
		&"anneal": "再生",
		&"stoke": "活力",
		&"glaze": "缓冲",
		&"thirst": "衰朽",
		&"command": "领袖气质",
	}
	for status_id in expected_status_names:
		var status := GameData.get_status(status_id)
		check("状态显示名 %s" % status_id,
			status != null and status.name == expected_status_names[status_id],
			"actual=%s" % (status.name if status != null else "missing"))

	# ---- 正式卡牌载体数据 ----
	var war_cry := GameData.get_card(&"warcry")
	var impervious := GameData.get_card(&"impervious")
	check("鼓风令：基础抽 1、升级抽 2且消耗",
		war_cry != null
		and effect_value(war_cry.effects, "draw") == 1
		and effect_value(war_cry.upgrade_effects, "draw") == 2
		and war_cry.exhaust)
	check("末薪：基础格挡 30、升级 40且消耗",
		impervious != null
		and effect_value(impervious.effects, "block") == 30
		and effect_value(impervious.upgrade_effects, "block") == 40
		and impervious.exhaust)

	start("t_dummy", ["impervious", "impervious", "impervious", "impervious", "impervious"])
	controller.play_card(0, -1)
	check("末薪：实际出牌获得格挡 30并进入消耗堆",
		controller.player.block == 30 and controller.exhaust_pile.size() == 1,
		"block=%d exhaust=%d" % [controller.player.block, controller.exhaust_pile.size()])

	# ---- 2.4 窑温·共鸣 ----
	start("t_dummy", ["t_strike", "t_strike", "t_strike", "t_strike", "t_strike",
		"t_strike", "t_strike", "t_strike", "t_strike", "t_strike"])
	controller.max_energy = 10
	controller.energy = 10
	var hp0: int = controller.enemies[0].hp   # 200
	play_attacks(4)
	check("窑温：前 4 张攻击累计 +4 未触发窑变",
		controller.kiln_heat == 4 and controller.enemies[0].hp == hp0 - 24,
		"kiln=%d hp=%d" % [controller.kiln_heat, controller.enemies[0].hp])
	play_attacks(1)   # 第 5 张 → 触发
	check("窑温：第 5 张触发窑变（贯穿 5 伤，窑温归 0）",
		controller.kiln_heat == 0 and controller.enemies[0].hp == hp0 - 35,
		"kiln=%d hp=%d" % [controller.kiln_heat, controller.enemies[0].hp])

	# ---- 2.5 活力 stoke ----
	start("t_dummy", ["t_strike", "t_strike", "t_strike", "t_strike", "t_strike"])
	controller.player.add_status(&"stoke", 3)
	var shp0: int = controller.enemies[0].hp   # 200
	play_attacks(1)
	check("活力：攻击伤害 +层数（6+3=9）",
		controller.enemies[0].hp == shp0 - 9,
		"hp=%d" % controller.enemies[0].hp)
	check("活力：出手后 -1 层（3→2）",
		controller.player.get_status(&"stoke") == 2,
		"stoke=%d" % controller.player.get_status(&"stoke"))

	start("t_dummy", ["t_double", "t_double", "t_double", "t_double", "t_double"])
	controller.player.add_status(&"stoke", 2)
	var multi_hp0: int = controller.enemies[0].hp
	play_attacks(1)
	check("活力：每个伤害实例均加层数（(3+2)×2=10）",
		controller.enemies[0].hp == multi_hp0 - 10,
		"hp=%d" % controller.enemies[0].hp)
	check("活力：多段攻击整张结算后只减 1 层（2→1）",
		controller.player.get_status(&"stoke") == 1,
		"stoke=%d" % controller.player.get_status(&"stoke"))

	# ---- 2.5 缓冲 glaze ----
	start("t_dummy", ["t_strike", "t_strike", "t_strike", "t_strike", "t_strike"])
	controller.player.hp = 300
	controller.player.max_hp = 300
	controller.player.block = 0
	controller.player.add_status(&"glaze", 2)
	var ghp0: int = controller.player.hp   # 300
	controller.enemies[0].intent = {"intent": "attack", "value": 10}
	controller._execute_enemy_intent(controller.enemies[0])
	check("缓冲：受击减伤 =层数（10-2=8）",
		controller.player.hp == ghp0 - 8,
		"hp=%d" % controller.player.hp)
	check("缓冲：触发 1 次后 -1 层（2→1）",
		controller.player.get_status(&"glaze") == 1,
		"glaze=%d" % controller.player.get_status(&"glaze"))

	# ---- 2.5 衰朽 thirst ----
	# 空过回合 → 下回合 -1 能量
	start("t_dummy", ["t_strike", "t_strike", "t_strike", "t_strike", "t_strike"])
	controller.player.add_status(&"thirst", 2)
	controller.player.hp = 300
	controller.player.max_hp = 300
	controller._attack_played_this_turn = false
	controller.end_player_turn()
	controller.enemy_phase_done()   # 推进敌人阶段→下一玩家回合（BattleDirector 异步驱动）
	check("衰朽：空过回合 → 下回合能量 -1",
		controller.energy == controller.max_energy - 1,
		"energy=%d max=%d" % [controller.energy, controller.max_energy])
	check("衰朽：回合衰减 -1（2→1）",
		controller.player.get_status(&"thirst") == 1,
		"thirst=%d" % controller.player.get_status(&"thirst"))

	# 打出攻击 → 不惩罚
	start("t_dummy", ["t_strike", "t_strike", "t_strike", "t_strike", "t_strike"])
	controller.player.add_status(&"thirst", 2)
	controller.player.hp = 300
	controller.player.max_hp = 300
	play_attacks(1)
	controller.end_player_turn()
	controller.enemy_phase_done()
	check("衰朽：打出攻击则不惩罚（下一回合能量 = max）",
		controller.energy == controller.max_energy,
		"energy=%d max=%d" % [controller.energy, controller.max_energy])


func _print_report() -> void:
	for r in results:
		print(r)
	var verdict := "PASS" if fail_count == 0 else "FAIL"
	print("P2_RESULT:%s  (%d 项通过, %d 项失败)" % [verdict, pass_count, fail_count])
