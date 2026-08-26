extends Node
## 药水 / 附魔系统自检测试场景（由 Godot MCP run_and_verify 运行）。
## 直接驱动 CombatController 的附魔结算与药水使用逻辑，断言关键数值与 §1.5 互斥规则。
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

	# §1.5 互斥：持续型新顶旧（stoke → temper）
	RunState.potions.clear()
	ctrl.player.block = 0
	RunState.add_potion(&"stoke_brew")   # 自身 stoke 3
	ctrl.use_potion(0, -1)
	if ctrl.player.get_status(&"stoke") != 3:
		printerr("[FAIL] 蓄焰酒 stoke 未+3：%d" % ctrl.player.get_status(&"stoke")); return
	RunState.add_potion(&"temper_paste") # 自身 temper 2，应先清 stoke
	ctrl.use_potion(0, -1)
	if ctrl.player.get_status(&"stoke") != 0:
		printerr("[FAIL] §1.5 互斥失败：stoke 残留 %d" % ctrl.player.get_status(&"stoke")); return
	if ctrl.player.get_status(&"temper") != 2:
		printerr("[FAIL] 塑形膏 temper 未+2：%d" % ctrl.player.get_status(&"temper")); return
	print("[PASS] §1.5 互斥 蓄焰→塑形 顶替成功（stoke 0 / temper 2）")

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
