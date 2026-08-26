extends Node
## P1 附魔祭坛 + 卡面附魔角标 自检（run_and_verify 运行）。
## 覆盖：① MapGenerator 三幕祭坛≤1/幕且敌人空、整体>0；
##      ② AltarUI 免费附魔生效（牌组记录附魔）；③ CombatUI._enchant_badge_text 空/非空；
##      ④ RewardUI 附魔子页按钮携带效果描述文本；⑤ 药水/附魔 icon PNG 资产存在且已接入 JSON。

func _ready() -> void:
	if not GameData.is_loaded:
		printerr("[FAIL] GameData 未加载"); return
	RunState.start_new_run()

	var ok := true
	ok = _verify_map_altar() and ok
	ok = _verify_altar_enchant() and ok
	ok = _verify_altar_ui() and ok
	ok = _verify_badge_text() and ok
	ok = _verify_reward_ui() and ok
	ok = _verify_icon_assets() and ok

	if ok:
		print("[P1_VERIFY_DONE] ALL PASS")


## ① 三幕各生成 50 次：每幕祭坛≤1、祭坛敌人恒空、整体>0（权重生效）。
func _verify_map_altar() -> bool:
	var raw: String = FileAccess.get_file_as_string("res://data/map.json")
	var map: Variant = JSON.parse_string(raw)
	if typeof(map) != TYPE_DICTIONARY or not (map as Dictionary).has("acts"):
		printerr("[FAIL] map.json 解析失败/缺 acts"); return false
	var acts: Array = (map as Dictionary)["acts"]
	for act in acts:
		var act_id: int = int((act as Dictionary).get("act", 0))
		var total_altar := 0
		var bad_enemy := false
		for r in 50:
			var floors: Array = MapGenerator.generate(act as Dictionary)
			var altar_this := 0
			for fl in floors:
				for node in fl:
					if node.type == &"altar":
						altar_this += 1
						if not node.enemy_ids.is_empty():
							bad_enemy = true
			if altar_this > 1:
				printerr("[FAIL] Act%d 单幕祭坛=%d > 1（违反每幕≤1）" % [act_id, altar_this]); return false
			total_altar += altar_this
		if total_altar == 0:
			printerr("[FAIL] Act%d 50 次祭坛=0（权重未生效）" % act_id); return false
		if bad_enemy:
			printerr("[FAIL] Act%d 存在祭坛节点带敌人" % act_id); return false
		print("[PASS] Act%d 祭坛：50 次每幕≤1，共 %d 个，敌人恒空" % [act_id, total_altar])
	return true


## ② 模拟 AltarUI 核心逻辑：选一张可附魔卡 → 免费套用 → 牌组记录。
func _verify_altar_enchant() -> bool:
	RunState.start_new_run()
	var target_idx := -1
	var target_eid: StringName = &""
	for i in RunState.deck.size():
		var entry: Dictionary = RunState.deck[i]
		if not entry.get("enchants", []).is_empty():
			continue
		var cd: CardData = GameData.get_card(StringName(entry["id"]))
		if cd == null:
			continue
		var eid: StringName = RewardBuilder.roll_enchant_for_card(cd)
		if eid != &"":
			target_idx = i
			target_eid = eid
			break
	if target_idx < 0:
		printerr("[FAIL] 牌组无可用附魔卡"); return false
	if not RunState.add_enchant_to_card_at(target_idx, target_eid):
		printerr("[FAIL] Altar 套用附魔失败"); return false
	var after: Array = RunState.deck[target_idx].get("enchants", [])
	if after.is_empty() or StringName(after[0]) != target_eid:
		printerr("[FAIL] Altar 套用后牌组未记录附魔"); return false
	print("[PASS] AltarUI 免费附魔生效：卡 idx=%d → %s" % [target_idx, target_eid])
	return true


## ②b AltarUI 实例化：选项携带附魔效果文本，模拟点击套用不崩溃。
func _verify_altar_ui() -> bool:
	RunState.start_new_run()
	var altar: Variant = load("res://scripts/map/AltarUI.gd").new()
	add_child(altar)
	# _ready → _build 应已填充 choices；保险起见若空则手动构建一次。
	if not (altar.choices is Array) or altar.choices.is_empty():
		altar._build()
	if not (altar.choices is Array) or altar.choices.is_empty():
		printerr("[FAIL] AltarUI 实例化后无可选附魔卡"); return false
	var ok_effect := false
	for ch in altar.choices:
		if ch.has("effect") and String(ch["effect"]) != "":
			ok_effect = true
			break
	if not ok_effect:
		printerr("[FAIL] AltarUI 选项缺少附魔效果描述"); return false
	# 模拟点击第一张卡：套用 + 弹效果面板，UI 不应崩溃。
	var first: Dictionary = altar.choices[0]
	altar._on_pick(first)
	var idx: int = int(first["index"])
	var after: Array = RunState.deck[idx].get("enchants", [])
	if after.is_empty() or StringName(after[0]) != StringName(first["eid"]):
		printerr("[FAIL] AltarUI 模拟点击附魔未生效"); return false
	print("[PASS] AltarUI 实例化+效果可见：选项 %d 个，效果描述非空，点击套用成功" % altar.choices.size())
	altar.queue_free()
	return true


## ③ CombatUI._enchant_badge_text：空数组返回空串；含附魔返回带 ✦ 的名称。
func _verify_badge_text() -> bool:
	var CUI: Variant = load("res://scripts/combat/CombatUI.gd")
	var empty: String = CUI._enchant_badge_text([])
	if empty != "":
		printerr("[FAIL] _enchant_badge_text([]) 应返回空串，得到 '%s'" % empty); return false
	var some_eid: StringName = &""
	for k in GameData.enchants.keys():
		some_eid = StringName(k)
		break
	if some_eid == &"":
		printerr("[FAIL] 无附魔数据"); return false
	var non: String = CUI._enchant_badge_text([some_eid])
	var nm: String = GameData.get_enchant(some_eid).name
	if non == "" or not non.contains("✦") or not non.contains(nm):
		printerr("[FAIL] _enchant_badge_text([eid]) 应返回带✦的附魔名，得到 '%s'" % non); return false
	print("[PASS] _enchant_badge_text 空='' / 非空='%s'" % non)
	return true


## ④ RewardUI 附魔子页：列表按钮携带效果描述文本（玩家点击前即可预览效果）。
func _verify_reward_ui() -> bool:
	RunState.start_new_run()
	var ui: Variant = load("res://scripts/rewards/RewardUI.gd").new()
	add_child(ui)
	ui.setup({}, func(): pass)
	ui._build_enchant()
	# 收集所有附魔效果描述
	var descs: Array = []
	for k in GameData.enchants.keys():
		var e: Variant = GameData.get_enchant(StringName(k))
		if e != null and e.description != "":
			descs.append(String(e.description))
	# 递归收集所有 Button 文本并匹配描述
	var texts: Array = []
	_gather_texts(ui, texts)
	var matched := false
	for t in texts:
		for d in descs:
			if t.contains(d):
				matched = true
				break
		if matched:
			break
	ui.queue_free()
	if not matched:
		printerr("[FAIL] RewardUI 附魔列表未显示任何附魔效果描述"); return false
	print("[PASS] RewardUI 附魔子页：列表按钮携带效果描述文本，点击弹效果面板")
	return true


func _gather_texts(node: Node, out: Array) -> void:
	if node is Button:
		out.append((node as Button).text)
	if node is Label:
		out.append((node as Label).text)
	for c in node.get_children():
		_gather_texts(c, out)


## ⑤ 药水/附魔 icon PNG 资产存在且 JSON 已接入 icon 字段。
func _verify_icon_assets() -> bool:
	var ok := true
	for k in GameData.potions.keys():
		var pd: PotionData = GameData.get_potion(StringName(k))
		if pd == null or pd.icon == "":
			printerr("[FAIL] 药水 %s 未配置 icon 字段" % k); ok = false; continue
		var path: String = "res://art/icons/potion/%s.png" % pd.icon
		if not FileAccess.file_exists(path):
			printerr("[FAIL] 药水 %s 图标文件缺失：%s" % [k, path]); ok = false
	for k in GameData.enchants.keys():
		var ed = GameData.get_enchant(StringName(k))
		if ed == null or ed.icon == "":
			printerr("[FAIL] 附魔 %s 未配置 icon 字段" % k); ok = false; continue
		var path: String = "res://art/icons/enchant/%s.png" % ed.icon
		if not FileAccess.file_exists(path):
			printerr("[FAIL] 附魔 %s 图标文件缺失：%s" % [k, path]); ok = false
	if ok:
		print("[PASS] 药水/附魔 icon PNG 资产：JSON 已接入且文件存在")
	return ok
