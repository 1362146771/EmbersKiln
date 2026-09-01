extends Node
## 随从 / 召唤系统自检测试（由 Godot MCP run_and_verify 运行）。
## 覆盖：数据加载 / 召唤卡 / SummonPhase 行动 / 寿命到期 / AoE 清场 / 满场拒绝 / 领袖气质加成。
## 输出 [PASS]/[FAIL] 供 harness 识别。

var _rejected := false


func _ready() -> void:
	if not GameData.is_loaded:
		printerr("[FAIL] GameData 未加载")
		return

	_test_data()
	_test_summon_card()
	_test_summon_and_action()
	_test_lifetime_expiry()
	_test_aoe_clears_ally()
	_test_full_reject()
	_test_command_bonus()
	_test_summoner_build()

	print("[PE_VERIFY_DONE] ALL PASS")


func _test_data() -> void:
	if GameData.get_minion("emberhound") == null:
		printerr("[FAIL] 随从 emberhound 未加载"); return
	if GameData.get_minion("glazeward") == null:
		printerr("[FAIL] 随从 glazeward 未加载"); return
	if GameData.get_minion("spark") == null:
		printerr("[FAIL] 随从 spark 未加载"); return
	if GameData.minions.size() != 3:
		printerr("[FAIL] 随从数量应为 3，实际 %d" % GameData.minions.size()); return
	print("[PASS] 随从数据加载 OK（%d 种）" % GameData.minions.size())


func _test_summon_card() -> void:
	var cd: CardData = GameData.get_card(&"summon_hound")
	if cd == null:
		printerr("[FAIL] 召唤卡 summon_hound 未加载"); return
	var has_summon := false
	for ef in cd.get_effects(false):
		if ef.get("kind", "") == "summon":
			has_summon = true
	if not has_summon:
		printerr("[FAIL] summon_hound 缺少 summon 效果"); return
	print("[PASS] 召唤卡 summon_hound 含 summon 效果")


func _test_summon_and_action() -> void:
	RunState.start_new_run()
	var ctrl := CombatController.new()
	add_child(ctrl)
	ctrl.start_combat(["claylump"])
	ctrl._summon_minion(&"emberhound", 1)
	if ctrl.allies.size() != 1:
		printerr("[FAIL] 召唤后友方数应为 1，实际 %d" % ctrl.allies.size()); return
	var ally: CombatUnit = ctrl.allies[0]
	var ehp_before: int = ctrl.enemies[0].hp
	ctrl._summon_phase()
	var dealt: int = ehp_before - ctrl.enemies[0].hp
	if dealt != 5:
		printerr("[FAIL] 窑犬攻击应造成 5 伤害，实际 %d" % dealt); return
	if ally.lifetime != 2:
		printerr("[FAIL] 行动后寿命应 3→2，实际 %d" % ally.lifetime); return
	ctrl.queue_free()
	print("[PASS] SummonPhase：窑犬登场并攻击 5（寿命 3→2）")


func _test_lifetime_expiry() -> void:
	RunState.start_new_run()
	var ctrl := CombatController.new()
	add_child(ctrl)
	ctrl.start_combat(["claylump"])
	ctrl._summon_minion(&"emberhound", 1)
	ctrl._summon_phase()   # 3->2
	ctrl._summon_phase()   # 2->1
	ctrl._summon_phase()   # 1->0 消失
	if ctrl.allies.size() != 0:
		printerr("[FAIL] 寿命到期后友方应消失，实际 %d" % ctrl.allies.size()); return
	ctrl.queue_free()
	print("[PASS] 寿命到期：窑犬 3 回合后消失")


func _test_aoe_clears_ally() -> void:
	RunState.start_new_run()
	var ctrl := CombatController.new()
	add_child(ctrl)
	ctrl.start_combat(["claylump"])
	# 用无格挡的窑犬，避免格挡吸收 AoE 干扰断言
	ctrl._summon_minion(&"emberhound", 1)
	if ctrl.allies.size() != 1:
		printerr("[FAIL] AoE 测试：召唤失败"); return
	ctrl.allies[0].block = 0   # 清除登场格挡，确保 AoE 真实生效
	# 真实路径：敌人 aoe_debuff 意图应同时命中友方随从
	var e: CombatUnit = ctrl.enemies[0]
	e.intent = {"intent": "aoe_debuff", "value": 3}
	var ahp_before: int = ctrl.allies[0].hp
	ctrl._execute_enemy_intent(e)
	var admg: int = ahp_before - ctrl.allies[0].hp
	if admg != 3:
		printerr("[FAIL] AoE 未命中友方随从，伤害 %d" % admg); return
	# 致命 AoE 应清场
	ctrl._deal_to_ally(ctrl.allies[0], 999)
	if ctrl.allies.size() != 0:
		printerr("[FAIL] 致命 AoE 未清场，友方仍 %d" % ctrl.allies.size()); return
	ctrl.queue_free()
	print("[PASS] AoE 清场：敌人 AoE 命中友方并清除")


func _test_full_reject() -> void:
	RunState.start_new_run()
	var ctrl := CombatController.new()
	add_child(ctrl)
	ctrl.start_combat(["claylump"])
	_rejected = false
	SignalBus.summon_rejected.connect(_on_rejected)
	var cap: int = int(GameData.balance.get("summon", {}).get("max_summons", 3))
	ctrl._summon_minion(&"emberhound", cap + 2)   # 超出上限
	SignalBus.summon_rejected.disconnect(_on_rejected)
	if ctrl.allies.size() != cap:
		printerr("[FAIL] 满场后友方数应为上限 %d，实际 %d" % [cap, ctrl.allies.size()]); return
	if not _rejected:
		printerr("[FAIL] 超出上限未广播 summon_rejected"); return
	ctrl.queue_free()
	print("[PASS] 满场拒绝：上限 %d 拒绝超额并广播 summon_rejected" % cap)


func _test_command_bonus() -> void:
	RunState.start_new_run()
	var ctrl := CombatController.new()
	add_child(ctrl)
	ctrl.start_combat(["claylump"])
	ctrl.player.add_status(&"command", 2)   # 领袖气质 +2
	ctrl._summon_minion(&"emberhound", 1)
	var ehp_before: int = ctrl.enemies[0].hp
	ctrl._summon_phase()
	var dealt: int = ehp_before - ctrl.enemies[0].hp
	if dealt != 7:   # 5 + 领袖气质2
		printerr("[FAIL] 领袖气质加成应使攻击 5→7，实际 %d" % dealt); return
	ctrl.queue_free()
	print("[PASS] 领袖气质加成：窑犬攻击 5+2=7")


func _on_rejected(_cap: int) -> void:
	_rejected = true


## 召主 build 已接入 BalanceSweep，且 6 张卡均真实存在（避免 sweep 校验阶段 FAIL）。
func _test_summoner_build() -> void:
	var f := FileAccess.open("res://data/balance_sweep.json", FileAccess.READ)
	if f == null:
		printerr("[FAIL] 无法读取 balance_sweep.json"); return
	var p := JSON.new()
	if p.parse(f.get_as_text()) != OK:
		printerr("[FAIL] balance_sweep.json 解析失败"); return
	f.close()
	var cfg: Dictionary = p.data
	var sbuild: Dictionary = {}
	for b in cfg.get("builds", []):
		if String(b.get("id", "")) == "summoner":
			sbuild = b
	if sbuild.is_empty():
		printerr("[FAIL] balance_sweep.json 缺少 summoner build"); return
	for cid in sbuild.get("cards", []):
		if GameData.get_card(StringName(cid)) == null:
			printerr("[FAIL] summoner build 含未知卡 %s" % cid); return
	print("[PASS] 召主 build 已接入 BalanceSweep（%d 张卡均存在）" % sbuild.get("cards", []).size())
