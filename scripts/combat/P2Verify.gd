extends Node
## P2 新机制确定性验证（headless）：
##  - 2.4 窑温·共鸣：每攻击牌 +1 窑温，满 5 触发贯穿 5 伤给全体敌人并消耗 5
##  - 2.5 蓄焰 stoke：攻击伤害 +层数，出手后 -1 层
##  - 2.5 釉光 glaze：受击减伤 =层数，触发 1 次后 -1 层
##  - 2.5 焦渴 thirst：空过回合→下回合 -1 能量；打出攻击则不惩罚
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


func run() -> void:
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

	# ---- 2.5 蓄焰 stoke ----
	start("t_dummy", ["t_strike", "t_strike", "t_strike", "t_strike", "t_strike"])
	controller.player.add_status(&"stoke", 3)
	var shp0: int = controller.enemies[0].hp   # 200
	play_attacks(1)
	check("蓄焰：攻击伤害 +层数（6+3=9）",
		controller.enemies[0].hp == shp0 - 9,
		"hp=%d" % controller.enemies[0].hp)
	check("蓄焰：出手后 -1 层（3→2）",
		controller.player.get_status(&"stoke") == 2,
		"stoke=%d" % controller.player.get_status(&"stoke"))

	# ---- 2.5 釉光 glaze ----
	start("t_dummy", ["t_strike", "t_strike", "t_strike", "t_strike", "t_strike"])
	controller.player.hp = 300
	controller.player.max_hp = 300
	controller.player.block = 0
	controller.player.add_status(&"glaze", 2)
	var ghp0: int = controller.player.hp   # 300
	controller.enemies[0].intent = {"intent": "attack", "value": 10}
	controller._execute_enemy_intent(controller.enemies[0])
	check("釉光：受击减伤 =层数（10-2=8）",
		controller.player.hp == ghp0 - 8,
		"hp=%d" % controller.player.hp)
	check("釉光：触发 1 次后 -1 层（2→1）",
		controller.player.get_status(&"glaze") == 1,
		"glaze=%d" % controller.player.get_status(&"glaze"))

	# ---- 2.5 焦渴 thirst ----
	# 空过回合 → 下回合 -1 能量
	start("t_dummy", ["t_strike", "t_strike", "t_strike", "t_strike", "t_strike"])
	controller.player.add_status(&"thirst", 2)
	controller.player.hp = 300
	controller.player.max_hp = 300
	controller._attack_played_this_turn = false
	controller.end_player_turn()
	check("焦渴：空过回合 → 下回合能量 -1",
		controller.energy == controller.max_energy - 1,
		"energy=%d max=%d" % [controller.energy, controller.max_energy])
	check("焦渴：回合衰减 -1（2→1）",
		controller.player.get_status(&"thirst") == 1,
		"thirst=%d" % controller.player.get_status(&"thirst"))

	# 打出攻击 → 不惩罚
	start("t_dummy", ["t_strike", "t_strike", "t_strike", "t_strike", "t_strike"])
	controller.player.add_status(&"thirst", 2)
	controller.player.hp = 300
	controller.player.max_hp = 300
	play_attacks(1)
	controller.end_player_turn()
	check("焦渴：打出攻击则不惩罚（能量 = max）",
		controller.energy == controller.max_energy,
		"energy=%d max=%d" % [controller.energy, controller.max_energy])


func _print_report() -> void:
	for r in results:
		print(r)
	var verdict := "PASS" if fail_count == 0 else "FAIL"
	print("P2_RESULT:%s  (%d 项通过, %d 项失败)" % [verdict, pass_count, fail_count])
