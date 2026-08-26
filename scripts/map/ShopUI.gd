extends Control
## 真实商店：买卡 / 买遗物 / 移除卡。金币取自 RunState，价格取自 balance.shop。
## 每次操作刷新界面；离开后 done 回调回地图。

const CREAM := Color(0.984, 0.953, 0.894)
const ORANGE := Color(0.941, 0.600, 0.482)
const GREEN := Color(0.365, 0.792, 0.647)
const DARK := Color(0.25, 0.20, 0.18)
const AMBER := Color(0.937, 0.624, 0.153)
const PURPLE := Color(0.498, 0.467, 0.867)
const RED := Color(0.847, 0.353, 0.188)
const BG_DARK := Color(0.12, 0.10, 0.09)

var on_done: Callable = Callable()

## 用实色纹理贴图替代 ColorRect（避免渲染器 alpha 合成问题）
func _solid_bg(color: Color) -> TextureRect:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	return tr

var card_stock: Array = []    # [{card:Dictionary, price:int, bought:bool}]
var relic_stock: Array = []   # [{id:StringName, price:int, bought:bool}]
var potion_stock: Array = []  # [{id:StringName, price:int, bought:bool}]
var remove_cost: int = 75
var removing: bool = false


func setup(done: Callable) -> void:
	on_done = done
	_generate_stock()
	_build_main()


func _generate_stock() -> void:
	card_stock.clear()
	relic_stock.clear()
	var cfg: Dictionary = GameData.balance.get("shop", {})
	var card_prices: Array = cfg.get("card_cost", [50, 75, 100])
	var relic_prices: Array = cfg.get("relic_cost", [120, 200])
	remove_cost = int(cfg.get("remove_card_cost", 75))

	var choices: Array = RewardBuilder.roll_card_choices(4)
	for c in choices:
		var idx: int = _rarity_index(StringName(c.get("rarity", "common")))
		idx = mini(idx, card_prices.size() - 1)
		card_stock.append({"card": c, "price": int(card_prices[idx]), "bought": false})

	var rid: StringName = RewardBuilder.roll_shop_relic()
	if rid != &"":
		var r: RelicData = GameData.get_relic(rid)
		var ridx: int = _rarity_index(r.rarity if r != null else &"common")
		ridx = mini(ridx, relic_prices.size() - 1)
		relic_stock.append({"id": rid, "price": int(relic_prices[ridx]), "bought": false})
	# 药水货架
	potion_stock.clear()
	var p_prices: Array = cfg.get("potion_cost", [35, 55, 75])
	var p_count: int = int(GameData.balance.get("potions", {}).get("drop", {}).get("shop_stock", 2))
	var all_p: Array = GameData.potions.keys()
	all_p.shuffle()
	for k in all_p.slice(0, mini(p_count, all_p.size())):
		var pid: StringName = StringName(k)
		var pd: PotionData = GameData.get_potion(pid)
		var pidx: int = _rarity_index(pd.rarity if pd != null else &"common")
		pidx = mini(pidx, p_prices.size() - 1)
		potion_stock.append({"id": pid, "price": int(p_prices[pidx]), "bought": false})


func _build_main() -> void:
	removing = false
	for c in get_children():
		c.queue_free()

	var dim := _solid_bg(BG_DARK)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 1160)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 22)
	v.add_theme_constant_override("margin_bottom", 22)
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	v.add_child(_label("商 店", 40, DARK))
	v.add_child(_label("金币：%d" % RunState.gold, 26, AMBER))

	# 卡牌货架
	v.add_child(_label("卡牌", 24, DARK))
	var card_scroll := ScrollContainer.new()
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.custom_minimum_size = Vector2(0, 270)
	v.add_child(card_scroll)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 14)
	card_scroll.add_child(card_row)
	for i in card_stock.size():
		card_row.add_child(_card_offer(i))

	# 遗物货架
	v.add_child(_label("遗物", 24, DARK))
	for i in relic_stock.size():
		v.add_child(_relic_offer(i))
	# 药水货架
	v.add_child(_label("药水", 24, DARK))
	for i in potion_stock.size():
		v.add_child(_potion_offer(i))
	# 附魔服务
	var enc_cost: int = int(GameData.balance.get("shop", {}).get("enchant_cost", 75))
	var enc_btn := Button.new()
	enc_btn.text = "附魔服务（%d 金）" % enc_cost
	enc_btn.custom_minimum_size = Vector2(560, 64)
	enc_btn.add_theme_font_size_override("font_size", 22)
	enc_btn.disabled = RunState.gold < enc_cost or not RewardBuilder.can_any_card_enchant()
	enc_btn.pressed.connect(_on_enchant_pressed.bind(enc_cost))
	v.add_child(enc_btn)

	# 移除卡
	var rm_btn := Button.new()
	rm_btn.text = "移除一张卡（%d 金）" % remove_cost
	rm_btn.custom_minimum_size = Vector2(560, 64)
	rm_btn.add_theme_font_size_override("font_size", 22)
	rm_btn.disabled = RunState.gold < remove_cost or RunState.deck.size() <= 1
	rm_btn.pressed.connect(_on_remove_pressed)
	v.add_child(rm_btn)

	# 离开
	var leave_btn := Button.new()
	leave_btn.text = "离开商店"
	leave_btn.custom_minimum_size = Vector2(560, 64)
	leave_btn.add_theme_font_size_override("font_size", 22)
	leave_btn.pressed.connect(_finish)
	v.add_child(leave_btn)


func _card_offer(i: int) -> Control:
	var item: Dictionary = card_stock[i]
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(180, 250)
	box.add_theme_constant_override("separation", 8)

	var info := Label.new()
	info.text = "%s\n[%d 能 · %s]\n%s" % [
		item["card"].get("name", ""),
		int(item["card"].get("cost", 0)),
		_rarity_cn(StringName(item["card"].get("rarity", "common"))),
		item["card"].get("desc", ""),
	]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", DARK)
	box.add_child(info)

	var buy := Button.new()
	if item["bought"]:
		buy.text = "已售出"
		buy.disabled = true
	else:
		buy.text = "%d 金" % item["price"]
		buy.disabled = RunState.gold < item["price"]
	buy.custom_minimum_size = Vector2(170, 50)
	buy.add_theme_font_size_override("font_size", 20)
	buy.pressed.connect(_on_buy_card.bind(i))
	box.add_child(buy)
	return box


func _relic_offer(i: int) -> Control:
	var item: Dictionary = relic_stock[i]
	var r: RelicData = GameData.get_relic(StringName(item["id"]))
	var name_txt: String = r.name if r != null else String(item["id"])
	var desc_txt: String = r.description if r != null else ""
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(600, 70)
	box.add_theme_constant_override("separation", 16)

	var info := Label.new()
	info.text = "遗物：%s\n%s" % [name_txt, desc_txt]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", PURPLE)
	box.add_child(info)

	var buy := Button.new()
	if item["bought"]:
		buy.text = "已购"
		buy.disabled = true
	else:
		buy.text = "%d 金" % item["price"]
		buy.disabled = RunState.gold < item["price"]
	buy.custom_minimum_size = Vector2(110, 56)
	buy.add_theme_font_size_override("font_size", 20)
	buy.pressed.connect(_on_buy_relic.bind(i))
	box.add_child(buy)
	return box


func _on_buy_card(i: int) -> void:
	if i < 0 or i >= card_stock.size():
		return
	var item: Dictionary = card_stock[i]
	if item["bought"] or RunState.gold < item["price"]:
		return
	if not RunState.spend_gold(item["price"]):
		return
	RunState.add_card(StringName(item["card"].get("id", "")), false)
	item["bought"] = true
	_log("购买卡牌：%s（-%d 金）" % [item["card"].get("name", ""), item["price"]])
	_build_main()


func _on_buy_relic(i: int) -> void:
	if i < 0 or i >= relic_stock.size():
		return
	var item: Dictionary = relic_stock[i]
	if item["bought"] or RunState.gold < item["price"]:
		return
	if not RunState.spend_gold(item["price"]):
		return
	RunState.add_relic(StringName(item["id"]))
	item["bought"] = true
	_log("购买遗物：-%d 金" % item["price"])


func _potion_offer(i: int) -> Control:
	var item: Dictionary = potion_stock[i]
	var p: PotionData = GameData.get_potion(StringName(item["id"]))
	var name_txt: String = p.name if p != null else String(item["id"])
	var desc_txt: String = p.description if p != null else ""
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(600, 70)
	box.add_theme_constant_override("separation", 16)
	if p != null and p.icon != "":
		box.add_child(GameData.icon_rect(p.icon, 56))
	var info := Label.new()
	info.text = "药水：%s\n%s" % [name_txt, desc_txt]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", ORANGE)
	box.add_child(info)
	var buy := Button.new()
	if item["bought"]:
		buy.text = "已购"
		buy.disabled = true
	else:
		buy.text = "%d 金" % item["price"]
		buy.disabled = RunState.gold < item["price"]
	buy.custom_minimum_size = Vector2(110, 56)
	buy.add_theme_font_size_override("font_size", 20)
	buy.pressed.connect(_on_buy_potion.bind(i))
	box.add_child(buy)
	return box


func _on_buy_potion(i: int) -> void:
	if i < 0 or i >= potion_stock.size():
		return
	var item: Dictionary = potion_stock[i]
	if item["bought"] or RunState.gold < item["price"]:
		return
	if not RunState.spend_gold(item["price"]):
		return
	if not RunState.add_potion(StringName(item["id"])):
		RunState.add_gold(item["price"])
		_log("药水背包已满，无法购买")
		_build_main()
		return
	item["bought"] = true
	_log("购买药水：-%d 金" % item["price"])
	_build_main()


func _on_enchant_pressed(cost: int) -> void:
	if RunState.gold < cost or not RewardBuilder.can_any_card_enchant():
		return
	_build_enchant(cost)


func _build_enchant(cost: int) -> void:
	for c in get_children():
		c.queue_free()
	var dim := _solid_bg(BG_DARK)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 1080)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 22)
	v.add_theme_constant_override("margin_bottom", 22)
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(_label("附魔服务（%d 金）" % cost, 30, DARK))
	v.add_child(_label("选择要附魔的卡牌", 20, DARK))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)
	for i in RunState.deck.size():
		var entry: Dictionary = RunState.deck[i]
		if not entry.get("enchants", []).is_empty():
			continue
		var cd = GameData.get_card(StringName(entry["id"]))
		if cd == null:
			continue
		var eid: StringName = RewardBuilder.roll_enchant_for_card(cd)
		if eid == &"":
			continue
		var ed = GameData.get_enchant(eid)
		var ename: String = ed.name if ed != null else String(eid)
		var b := Button.new()
		b.custom_minimum_size = Vector2(600, 56)
		b.add_theme_color_override("font_color", DARK)
		b.text = "%s -> %s" % [cd.name, ename]
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_on_enchant_card.bind(i, cost))
		col.add_child(b)
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(300, 60)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(_build_main)
	v.add_child(back)


func _on_enchant_card(i: int, cost: int) -> void:
	if i < 0 or i >= RunState.deck.size() or RunState.gold < cost:
		_build_main()
		return
	var entry: Dictionary = RunState.deck[i]
	var cd = GameData.get_card(StringName(entry["id"]))
	if cd == null:
		_build_main()
		return
	var eid: StringName = RewardBuilder.roll_enchant_for_card(cd)
	if eid == &"":
		_build_main()
		return
	if not RunState.spend_gold(cost):
		_build_main()
		return
	if not RunState.add_enchant_to_card_at(i, eid):
		RunState.add_gold(cost)
		_build_main()
		return
	var ed = GameData.get_enchant(eid)
	_log("附魔服务：%s 附魔 %s（-%d 金）" % [cd.name, ed.name if ed != null else eid, cost])
	_build_main()
	_build_main()


func _on_remove_pressed() -> void:
	if RunState.gold < remove_cost or RunState.deck.size() <= 1:
		return
	removing = true
	_build_remove()


func _build_remove() -> void:
	for c in get_children():
		c.queue_free()

	var dim := _solid_bg(BG_DARK)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 1080)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 22)
	v.add_theme_constant_override("margin_bottom", 22)
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	v.add_child(_label("移除一张卡（%d 金）" % remove_cost, 30, DARK))
	v.add_child(_label("选择要销毁的卡牌", 20, DARK))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)
	for i in RunState.deck.size():
		var entry: Dictionary = RunState.deck[i]
		var cd: CardData = GameData.get_card(StringName(entry["id"]))
		var nm: String = cd.name if cd != null else String(entry["id"])
		if entry["upgraded"]:
			nm += "+"
		var b := Button.new()
		b.custom_minimum_size = Vector2(600, 56)
		b.add_theme_color_override("font_color", DARK)
		b.text = nm
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_on_remove_card.bind(i))
		col.add_child(b)

	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(300, 60)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(_build_main)
	v.add_child(back)


func _on_remove_card(i: int) -> void:
	if i < 0 or i >= RunState.deck.size():
		return
	if RunState.gold < remove_cost:
		return
	if not RunState.spend_gold(remove_cost):
		return
	RunState.remove_card_at(i)
	_log("移除卡牌：-%d 金" % remove_cost)
	_build_main()


func _finish() -> void:
	queue_free()
	if on_done.is_valid():
		on_done.call()


func _rarity_index(r: StringName) -> int:
	match r:
		&"common": return 0
		&"uncommon": return 1
		&"rare": return 2
		_: return 0


func _rarity_cn(r: StringName) -> String:
	match r:
		&"common": return "普通"
		&"uncommon": return "精良"
		&"rare": return "稀有"
		&"starter": return "初始"
		_: return String(r)


func _log(msg: String) -> void:
	print("[Shop] " + msg)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
