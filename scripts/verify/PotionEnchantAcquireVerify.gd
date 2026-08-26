extends Node
## 药水/附魔获取链路自检测试（run_and_verify 运行）。
## 覆盖：RewardBuilder 抽取、RunState 库存/上限、附魔套用、商店/事件/宝箱发放等价逻辑。

func _ready() -> void:
	if not GameData.is_loaded:
		printerr("[FAIL] GameData 未加载"); return
	RunState.start_new_run()

	# 1. roll_potion(boss, force) 必给且合法
	var pid: StringName = RewardBuilder.roll_potion(&"boss", true)
	if pid == &"" or GameData.get_potion(pid) == null:
		printerr("[FAIL] roll_potion(boss,force) 应返回合法药水，得到 %s" % pid); return
	print("[PASS] roll_potion(boss,force) 返回合法药水：%s" % pid)

	# 2. add_potion 进库存 + 携带上限
	RunState.potions.clear()
	if not RunState.add_potion(pid):
		printerr("[FAIL] add_potion 应成功"); return
	if not RunState.potions.has(pid):
		printerr("[FAIL] 药水未进入 RunState.potions"); return
	print("[PASS] add_potion 进入库存")

	RunState.potions.clear()
	var keys: Array = GameData.potions.keys()
	var cap: int = RunState._potion_cap()
	for k in keys.slice(0, mini(cap, keys.size())):
		RunState.add_potion(StringName(k))
	var before: int = RunState.potions.size()
	if before >= cap:
		var added := RunState.add_potion(StringName(keys[0]))
		if added:
			printerr("[FAIL] 携带上限失效：size=%d" % RunState.potions.size()); return
		if RunState.potions.size() != before:
			printerr("[FAIL] 超出上限后 size 变化"); return
		print("[PASS] 携带上限生效（max=%d）" % cap)
	else:
		print("[PASS] 携带上限（药水种类不足，跳过满载断言，max=%d）" % cap)

	# 3. roll_enchant_for_card 对攻击卡返回合法附魔
	var cd_strike: CardData = GameData.get_card(&"strike")
	var eid: StringName = RewardBuilder.roll_enchant_for_card(cd_strike)
	if eid == &"":
		printerr("[FAIL] strike 应能匹配某附魔"); return
	var ed: EnchantData = GameData.get_enchant(eid)
	if ed == null or not ed.matches_card(cd_strike):
		printerr("[FAIL] roll_enchant_for_card 返回非法附魔 %s" % eid); return
	print("[PASS] roll_enchant_for_card(strike) 返回合法附魔：%s" % eid)

	# 4. 事件 add_potion / add_enchant 发放等价逻辑
	RunState.start_new_run()
	RunState.potions.clear()
	var ev_pid: StringName = RewardBuilder.roll_potion(&"combat", true)
	if ev_pid == &"" or not RunState.add_potion(ev_pid):
		printerr("[FAIL] 事件 add_potion 发放失败"); return
	print("[PASS] 事件 add_potion 等价发放 OK：%s" % ev_pid)
	var enc_done := false
	for i in RunState.deck.size():
		var ecd: CardData = GameData.get_card(StringName(RunState.deck[i]["id"]))
		if ecd == null: continue
		var ee: StringName = RewardBuilder.roll_enchant_for_card(ecd)
		if ee != &"" and RunState.add_enchant_to_card_at(i, ee):
			enc_done = true
			print("[PASS] 事件 add_enchant 等价发放 OK：%s" % ee)
			break
	if not enc_done:
		printerr("[FAIL] 事件 add_enchant 未能给任何卡附魔"); return

	# 5. ShopUI 药水库存生成 + 购买扣金
	var shop = load("res://scripts/map/ShopUI.gd").new()
	add_child(shop)
	shop.setup(func(): pass)
	var pstock: int = shop.potion_stock.size()
	var expect: int = mini(int(GameData.balance.get("potions", {}).get("drop", {}).get("shop_stock", 2)), GameData.potions.size())
	if pstock != expect:
		printerr("[FAIL] 商店药水库存数=%d 期望=%d" % [pstock, expect]); return
	print("[PASS] 商店药水库存生成（%d 瓶）" % pstock)
	if pstock > 0:
		RunState.add_gold(999)
		var g0: int = RunState.gold
		var buy_id: StringName = StringName(shop.potion_stock[0]["id"])
		shop._on_buy_potion(0)
		if RunState.gold >= g0:
			printerr("[FAIL] 购买药水未扣金"); return
		if not RunState.potions.has(buy_id):
			printerr("[FAIL] 购买后药水未进入库存"); return
		print("[PASS] 商店购买药水扣金且入库存")

	# 6. 宝箱药水发放等价逻辑（TreasureUI._on_take_potion 内部一致）
	RunState.potions.clear()
	var tpid: StringName = RewardBuilder.roll_potion(&"combat", true)
	if tpid == &"" or not RunState.add_potion(tpid):
		printerr("[FAIL] 宝箱药水发放失败"); return
	print("[PASS] 宝箱药水发放等价 OK：%s" % tpid)

	print("[ACQUIRE_VERIFY_DONE] ALL PASS")
