extends Node
## 药水 / 附魔系统自检测试场景（由 Godot MCP run_and_verify 运行）。
## 直接驱动 CombatController，验证附魔及连续喝药、状态叠加与共存。
## 输出 [PASS]/[FAIL] 供 harness 识别。

func _ready() -> void:
	if not GameData.is_loaded:
		printerr("[FAIL] GameData 未加载")
		return
	if GameData.get_potion("ash_salve") == null:
		printerr("[FAIL] 药水 ash_salve 未加载"); return
	if GameData.get_enchant("kiln_quench") == null:
		printerr("[FAIL] 附魔 kiln_quench 未加载"); return
	print("[PASS] 数据与查询加载 OK（药水 %d / 附魔 %d）" % [GameData.potions.size(), GameData.enchants.size()])

	# 附魔加法结算（升级覆盖 → 附魔加法 → 状态结算）
	RunState.start_new_run()
	var ctrl := CombatController.new()
	add_child(ctrl)
	ctrl.start_combat(["claylump"])

	var cd_strike: CardData = GameData.get_card(&"strike")
	var out := ctrl._apply_enchant_mods([{"kind": "damage", "value": 6}], cd_strike, [&"kiln_quench"])
	if out[0]["value"] != 8:
		printerr("[FAIL] 窑淬 +2 未生效：%d" % out[0]["value"]); return
	print("[PASS] 附魔窑淬 伤害 6→%d" % out[0]["value"])

	var cd_defend: CardData = GameData.get_card(&"defend")
	var out2 := ctrl._apply_enchant_mods([{"kind": "block", "value": 5}], cd_defend, [&"glaze_seal"])
	if out2[0]["value"] != 7:
		printerr("[FAIL] 釉封 +2 未生效：%d" % out2[0]["value"]); return
	print("[PASS] 附魔釉封 格挡 5→%d" % out2[0]["value"])

	# 类型不符附魔应被忽略（defend 不享受窑淬）
	var out3 := ctrl._apply_enchant_mods([{"kind": "block", "value": 5}], cd_defend, [&"kiln_quench"])
	if out3[0]["value"] != 5:
		printerr("[FAIL] 类型不符附魔未忽略：%d" % out3[0]["value"]); return
	print("[PASS] 类型不符附魔被正确忽略（defend 不享窑淬）")

	# 药水：格挡瓶（即时型，Free Action，用后消耗）
	RunState.potions.clear()
	RunState.add_potion(&"kiln_plaster")
	var before_block := ctrl.player.block
	ctrl.use_potion(0, -1)
	if ctrl.player.block != before_block + 12:
		printerr("[FAIL] 窑壁釉 格挡未+12：%d" % ctrl.player.block); return
	if RunState.potions.size() != 0:
		printerr("[FAIL] 窑壁釉 用后未消耗"); return
	print("[PASS] 药水窑壁釉 格挡 +12 且消耗")

	# 药水：治疗瓶
	RunState.potions.clear()
	ctrl.player.hp = 40
	RunState.add_potion(&"ash_salve")
	ctrl.use_potion(0, -1)
	if ctrl.player.hp != 52:
		printerr("[FAIL] 灰烬膏 治疗未+12：%d" % ctrl.player.hp); return
	print("[PASS] 药水灰烬膏 治疗 +12（40→%d）" % ctrl.player.hp)

	# §1.5 连续喝药：不同持续效果共存，同类及其他来源状态正常叠加。
	RunState.potions.clear()
	ctrl.player.block = 0
	RunState.add_potion(&"stoke_brew")   # 自身活力 stoke 3
	ctrl.use_potion(0, -1)
	if ctrl.player.get_status(&"stoke") != 3:
		printerr("[FAIL] 活力药水 stoke 未+3：%d" % ctrl.player.get_status(&"stoke")); return
	RunState.add_potion(&"temper_paste")
	ctrl.use_potion(0, -1)
	if ctrl.player.get_status(&"stoke") != 3:
		printerr("[FAIL] 新药水清除了旧活力效果"); return
	if ctrl.player.get_status(&"temper") != 2:
		printerr("[FAIL] 敏捷药水 temper 未+2：%d" % ctrl.player.get_status(&"temper")); return
	print("[PASS] 异类药水效果共存（stoke 3 / temper 2）")

	var potion_amount := int(GameData.get_potion(&"temper_paste").effects[0]["value"])
	var energy_before := ctrl.energy
	var turn_before := ctrl.turn
	ctrl._apply_status(ctrl.player, &"temper", potion_amount) # 模拟已有卡牌/遗物来源。
	var expected_temper := ctrl.player.get_status(&"temper")
	for unused in range(RunState._potion_cap() + 1):
		RunState.add_potion(&"temper_paste")
		if not ctrl.use_potion(0):
			printerr("[FAIL] 连续喝药被次数限制拦截"); return
		expected_temper += potion_amount
		if ctrl.player.get_status(&"temper") != expected_temper:
			printerr("[FAIL] 同类或其他来源敏捷未累加"); return
	if ctrl.player.get_status(&"stoke") != 3 or ctrl.energy != energy_before or ctrl.turn != turn_before:
		printerr("[FAIL] 连续喝药清除异类状态、消耗能量或推进回合"); return
	if not RunState.potions.is_empty() or ctrl.use_potion(0):
		printerr("[FAIL] 连续喝药库存消耗或空槽保护错误"); return
	print("[PASS] 连续饮用超过携带格数量，无次数上限；同类/卡牌来源叠加，库存正确消耗")

	var debuff_amount := int(GameData.get_potion(&"craze_dust").effects[0]["value"])
	ctrl._apply_status(ctrl.enemies[0], &"crazed", debuff_amount)
	for unused in range(2):
		RunState.add_potion(&"craze_dust")
		if not ctrl.use_potion(0, 0):
			printerr("[FAIL] 易伤药粉连续饮用失败"); return
	if ctrl.enemies[0].get_status(&"crazed") != debuff_amount * 3:
		printerr("[FAIL] 药水与已有敌方易伤层数未叠加"); return
	RunState.add_potion(&"mud_bolt")
	ctrl.use_potion(0)
	if ctrl.enemies[0].get_status(&"crazed") != debuff_amount * 3 or ctrl.enemies[0].get_status(&"damp") <= 0:
		printerr("[FAIL] 群体虚弱清除了先前易伤"); return
	print("[PASS] 敌方同类减益叠加，群体药水不清除其他减益")

	RunState.add_potion(&"temper_paste")
	ctrl.phase = CombatController.Phase.ENEMY
	if ctrl.use_potion(0) or RunState.potions.size() != 1:
		printerr("[FAIL] 非玩家阶段使用或消耗了药水"); return
	ctrl.phase = CombatController.Phase.PLAYER
	print("[PASS] 非法阶段保留库存")

	# 牌组附魔持久化（RunState 存取）
	RunState.start_new_run()
	var idx := 0
	if not RunState.can_enchant_card_at(idx, &"kiln_quench"):
		printerr("[FAIL] can_enchant_card_at 应允许给 strike 贴窑淬"); return
	RunState.add_enchant_to_card_at(idx, &"kiln_quench")
	if RunState.deck[idx]["enchants"].size() != 1:
		printerr("[FAIL] 附魔未写入牌组条目"); return
	# 单卡 ≤1 约束
	if RunState.can_enchant_card_at(idx, &"glaze_seal"):
		printerr("[FAIL] 单卡 ≤1 约束失效"); return
	print("[PASS] 牌组附魔持久化 + 单卡 ≤1 约束生效")

	print("[PE_VERIFY_DONE] ALL PASS")
	get_tree().quit()
