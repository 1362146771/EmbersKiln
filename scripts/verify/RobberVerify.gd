extends Node
## 「抢劫的」正式数据与偷金/返还机制专项验证。

var passed := 0
var failed := 0
var ctrl: CombatController


func _ready() -> void:
	await get_tree().process_frame
	check("正式目录可加载", GameData.is_loaded)
	_test_catalog_and_pool()
	_test_gold_steal_once_per_attack()
	_test_refund_after_victory()
	_test_refund_waits_for_combat_end()
	_test_only_actual_gold_is_stolen()
	_test_intent_text()
	if ctrl != null:
		ctrl.free()
	print("ROBBER_RESULT:%s %d PASS / %d FAIL" % ["PASS" if failed == 0 else "FAIL", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])


func _fresh(enemy_ids: Array, starting_gold: int) -> void:
	if ctrl != null:
		ctrl.free()
	RunState.is_active = false
	RunState.start_new_run()
	RunState.relic_ids.clear()
	RunState.gold = starting_gold
	ctrl = CombatController.new()
	add_child(ctrl)
	ctrl.start_combat(enemy_ids)


func _robber() -> CombatUnit:
	for e in ctrl.enemies:
		if e.id == &"robber":
			return e
	return null


func _attack_once(e: CombatUnit) -> void:
	check("抢劫者可进入敌方行动", ctrl.enemy_pre(e))
	ctrl.player.block = ctrl.player.max_hp
	var damage := ctrl.enemy_outgoing(e, int(e.intent.get("value", 0)))
	ctrl.enemy_attack_hit(e, damage)


func _test_catalog_and_pool() -> void:
	var ed := GameData.get_enemy(&"robber")
	check("敌人 robber 已登记", ed != null)
	if ed == null:
		return
	check("名称与层级正确", ed.name == "抢劫的" and ed.tier == &"normal")
	check("正式立绘可加载", ed.sprite == "SPR_Enemy_Robber" and ed.sprite_texture() != null)
	check("小刀攻击带偷金字段", ed.moves.size() == 1 and ed.moves[0].get("intent", "") == "attack" and int(ed.moves[0].get("gold_steal", 0)) == 15)
	var names: Dictionary = {}
	var unique := true
	for enemy in GameData.enemies.values():
		if names.has(enemy.name):
			unique = false
		names[enemy.name] = true
	check("所有敌人名称无重复", unique)
	var acts: Array = GameData.act_configs
	var in_act_one := false
	var leaked_to_later_act := false
	for act in acts:
		var pool: Array = act.get("enemy_pool", {}).get("normal", [])
		if int(act.get("act", 0)) == 1:
			in_act_one = pool.has("robber")
		else:
			leaked_to_later_act = leaked_to_later_act or pool.has("robber")
	check("仅投放第一幕普通敌人池", in_act_one and not leaked_to_later_act)


func _test_gold_steal_once_per_attack() -> void:
	_fresh([&"robber"], 40)
	var e := _robber()
	_attack_once(e)
	check("攻击扣除 15 金币", RunState.gold == 25 and e.stolen_gold == 15)
	ctrl.enemy_attack_hit(e, 0)
	check("同一攻击意图不会重复偷金", RunState.gold == 25 and e.stolen_gold == 15)
	ctrl.enemy_post(e)
	_attack_once(e)
	check("下一回合攻击可再次偷金", RunState.gold == 10 and e.stolen_gold == 30)


func _test_refund_after_victory() -> void:
	_fresh([&"robber"], 40)
	var e := _robber()
	_attack_once(e)
	ctrl._dmg.deal_to_unit(e, e.hp + e.block)
	check("击杀并胜利后返还全部失窃金币", not ctrl.combat_active() and RunState.gold == 40 and e.stolen_gold == 0)


func _test_refund_waits_for_combat_end() -> void:
	_fresh([&"robber", &"claylump"], 40)
	var e := _robber()
	_attack_once(e)
	ctrl._dmg.deal_to_unit(e, e.hp + e.block)
	check("抢劫者死亡但战斗未结束时暂不返还", ctrl.combat_active() and RunState.gold == 25)
	var other: CombatUnit = null
	for enemy in ctrl.enemies:
		if enemy.is_alive():
			other = enemy
			break
	ctrl._dmg.deal_to_unit(other, other.hp + other.block)
	check("整场胜利时返还已击杀抢劫者金币", not ctrl.combat_active() and RunState.gold == 40)


func _test_only_actual_gold_is_stolen() -> void:
	_fresh([&"robber"], 7)
	var e := _robber()
	_attack_once(e)
	check("金币不足时只记录实际损失", RunState.gold == 0 and e.stolen_gold == 7)
	ctrl._dmg.deal_to_unit(e, e.hp + e.block)
	check("返还不超出实际损失", RunState.gold == 7)


func _test_intent_text() -> void:
	_fresh([&"robber"], 40)
	var e := _robber()
	var panel: EnemyPanel = load("res://scenes/combat/EnemyPanel.tscn").instantiate()
	add_child(panel)
	panel.build(e, 0, false, 1, ctrl)
	var text: String = panel.get_node("Inner/IntentBar").tooltip_text
	var scaled_damage := int(e.intent.get("value", 0))
	check("意图明确显示缩放后攻击伤害与抢金币", text.contains("攻击 %d" % scaled_damage) and text.contains("抢 15 金币"))
	panel.free()
