extends Control
## 真实商店：买卡 / 买遗物 / 移除卡。金币取自 RunState，价格取自 balance.shop。
## 每次操作刷新界面；离开后 done 回调回地图。

const CREAM := Color(0.984, 0.953, 0.894)
const ORANGE := Color(0.941, 0.600, 0.482)
const GREEN := Color(0.365, 0.792, 0.647)
const TEXT := Color("f2e8d5")
const AMBER := Color(0.937, 0.624, 0.153)
const PURPLE := Color(0.498, 0.467, 0.867)
const RED := Color(0.847, 0.353, 0.188)
const BG_DARK := Color(0.12, 0.10, 0.09)
const CardBrowserScript := preload("res://scripts/ui/CardBrowser.gd")

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
var remove_cost: int = 0
var removing: bool = false
var _remove_browser: CanvasLayer
var _remove_sources: Array = []
var _remove_quote := 0
var _remove_status := ""
var _finished := false
var shop_id := ""
var refresh_count := 0
var _refresh_status := ""


func setup(done: Callable) -> void:
	on_done = done
	_prepare_stock()
	_build_main()


## P2 场景化：作为独立场景加载时自构建（货架只生成一次，避免重复刷新）。
func _ready() -> void:
	if not SignalBus.shop_inventory_changed.is_connected(_on_shop_inventory_changed):
		SignalBus.shop_inventory_changed.connect(_on_shop_inventory_changed)
	if not SignalBus.card_acquisition_resolved.is_connected(_on_card_acquisition_resolved):
		SignalBus.card_acquisition_resolved.connect(_on_card_acquisition_resolved)
	if not SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.connect(_on_ad_reward_resolved)
	if card_stock.is_empty():
		_prepare_stock()
	_build_main()


func _exit_tree() -> void:
	if SignalBus.shop_inventory_changed.is_connected(_on_shop_inventory_changed):
		SignalBus.shop_inventory_changed.disconnect(_on_shop_inventory_changed)
	if SignalBus.card_acquisition_resolved.is_connected(_on_card_acquisition_resolved):
		SignalBus.card_acquisition_resolved.disconnect(_on_card_acquisition_resolved)
	if SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.disconnect(_on_ad_reward_resolved)


func _prepare_stock() -> void:
	shop_id = ShopInventorySystem.current_shop_id()
	if ShopInventorySystem.has_state(shop_id):
		_apply_stock_state(ShopInventorySystem.get_state(shop_id))
		return
	_generate_stock()
	_persist_stock()


func _apply_stock_state(state: Dictionary) -> void:
	card_stock = state.get("card_stock", []).duplicate(true)
	relic_stock = state.get("relic_stock", []).duplicate(true)
	potion_stock = state.get("potion_stock", []).duplicate(true)
	refresh_count = int(state.get("refresh_count", 0))
	remove_cost = int(GameData.balance.get("shop", {}).get("remove_card_cost", 0))


func _persist_stock() -> void:
	if shop_id.is_empty():
		shop_id = ShopInventorySystem.current_shop_id()
	ShopInventorySystem.capture_state(shop_id, card_stock, relic_stock, potion_stock, refresh_count)


func _generate_stock() -> void:
	card_stock.clear()
	relic_stock.clear()
	var cfg: Dictionary = GameData.balance.get("shop", {})
	var card_prices: Array = cfg.get("card_cost", [50, 75, 100])
	var relic_prices: Array = cfg.get("relic_cost", [120, 200])
	remove_cost = int(cfg["remove_card_cost"])

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
	var all_p: Array = []
	for potion_id in GameData.potions:
		if GameData.is_potion_unlocked(potion_id):
			all_p.append(potion_id)
	all_p.shuffle()
	for k in all_p.slice(0, mini(p_count, all_p.size())):
		var pid: StringName = StringName(k)
		var pd: PotionData = GameData.get_potion(pid)
		var pidx: int = _rarity_index(pd.rarity if pd != null else &"common")
		pidx = mini(pidx, p_prices.size() - 1)
		potion_stock.append({"id": pid, "price": int(p_prices[pidx]), "bought": false})


func _build_main() -> void:
	removing = false
	_remove_browser = null
	_remove_sources.clear()
	var scene_panel: Panel = get_node_or_null("Dim/Center/MainPanel")
	if scene_panel != null:
		scene_panel.add_theme_stylebox_override("panel", CardBrowserScript.style(Color("3a4554")))
		var content: VBoxContainer = scene_panel.get_node("ContentScroll/Content")
		var gold_label: Label = content.get_node("Gold")
		gold_label.text = "金币：%d" % RunState.gold
		var remove_button: Button = content.get_node("Removal/RemoveCardButton")
		remove_button.text = "永久移除卡牌 · %d 金" % remove_cost
		remove_button.disabled = RunState.gold < remove_cost or not RunState.can_remove_card()
		var remove_hint := "选牌后确认 · 仅移除本局牌组中的该卡"
		if not RunState.can_remove_card():
			remove_hint = "牌组至少保留 %d 张卡" % int(GameData.balance["card_removal"]["minimum_remaining"])
		elif RunState.gold < remove_cost:
			remove_hint = "金币不足 · 需要 %d 金，当前 %d 金" % [remove_cost, RunState.gold]
		if _remove_status != "":
			remove_hint = _remove_status + "\n" + remove_hint
		content.get_node("Removal/Hint").text = remove_hint
		if not remove_button.pressed.is_connected(_on_remove_pressed):
			remove_button.pressed.connect(_on_remove_pressed)
		var card_row: HBoxContainer = content.get_node("CardScroll/CardRow")
		for child in card_row.get_children():
			child.queue_free()
		for i in card_stock.size():
			card_row.add_child(_card_offer(i))
		var relic_list: VBoxContainer = content.get_node("RelicOffers")
		for child in relic_list.get_children():
			child.queue_free()
		for i in relic_stock.size():
			relic_list.add_child(_relic_offer(i))
		var potion_list: VBoxContainer = content.get_node("PotionOffers")
		for child in potion_list.get_children():
			child.queue_free()
		for i in potion_stock.size():
			potion_list.add_child(_potion_offer(i))
		var enchant_cost: int = int(GameData.balance.get("shop", {}).get("enchant_cost", 75))
		var enchant_button: Button = content.get_node("EnchantButton")
		enchant_button.text = "附魔服务（%d 金）" % enchant_cost
		enchant_button.disabled = RunState.gold < enchant_cost or not RewardBuilder.can_any_card_enchant()
		var enchant_callable := _on_enchant_pressed.bind(enchant_cost)
		if not enchant_button.pressed.is_connected(enchant_callable):
			enchant_button.pressed.connect(enchant_callable)
		var refresh_box: VBoxContainer = content.get_node("Refresh")
		refresh_box.visible = AdService.is_placement_enabled(ShopInventorySystem.PLACEMENT)
		if refresh_box.visible:
			var refresh_button: Button = refresh_box.get_node("ShopRefreshAdButton")
			refresh_button.text = "观看广告 · 刷新未购买商品（剩余%d次）" % ShopInventorySystem.remaining_refreshes(shop_id) if ShopInventorySystem.is_refresh_configured() else "观看广告 · 刷新未购买商品"
			refresh_button.disabled = not ShopInventorySystem.can_offer_refresh(shop_id)
			refresh_button.tooltip_text = ShopInventorySystem.refresh_block_reason(shop_id) if refresh_button.disabled else "已购买槽位与服务状态保持不变"
			if not refresh_button.pressed.is_connected(_on_refresh_pressed):
				refresh_button.pressed.connect(_on_refresh_pressed)
			var refresh_hint := "只替换未购买槽位；已售商品、金币和服务状态保持不变。"
			if not _refresh_status.is_empty():
				refresh_hint = _refresh_status + "\n" + refresh_hint
			elif refresh_button.disabled:
				refresh_hint = ShopInventorySystem.refresh_block_reason(shop_id) + "\n" + refresh_hint
			refresh_box.get_node("Hint").text = refresh_hint
		var leave_button: Button = content.get_node("LeaveButton")
		if not leave_button.pressed.is_connected(_finish):
			leave_button.pressed.connect(_finish)
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()

	var dim := _solid_bg(BG_DARK)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 1160)
	panel.add_theme_stylebox_override("panel", CardBrowserScript.style(Color("3a4554")))
	center.add_child(panel)

	var content_scroll := ScrollContainer.new()
	content_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_scroll.offset_left = 20
	content_scroll.offset_right = -20
	content_scroll.offset_top = 16
	content_scroll.offset_bottom = -16
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(content_scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 22)
	v.add_theme_constant_override("margin_bottom", 22)
	v.add_theme_constant_override("separation", 14)
	content_scroll.add_child(v)

	v.add_child(_label("商 店", 40, TEXT))
	v.add_child(_label("金币：%d" % RunState.gold, 26, AMBER))

	# 将永久移除放在金币下方，避免服务入口被货架挤出屏幕。
	var removal := VBoxContainer.new()
	removal.add_theme_constant_override("separation", 6)
	var rm_btn := CardBrowserScript.button("永久移除卡牌 · %d 金" % remove_cost, _on_remove_pressed)
	rm_btn.name = "RemoveCardButton"
	rm_btn.disabled = RunState.gold < remove_cost or not RunState.can_remove_card()
	removal.add_child(rm_btn)
	var hint := "选牌后确认 · 仅移除本局牌组中的该卡"
	if not RunState.can_remove_card():
		hint = "牌组至少保留 %d 张卡" % int(GameData.balance["card_removal"]["minimum_remaining"])
	elif RunState.gold < remove_cost:
		hint = "金币不足 · 需要 %d 金，当前 %d 金" % [remove_cost, RunState.gold]
	if _remove_status != "":
		hint = _remove_status + "\n" + hint
	removal.add_child(_label(hint, 20, TEXT))
	v.add_child(removal)

	# 卡牌货架
	v.add_child(_label("卡牌", 24, TEXT))
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
	v.add_child(_label("遗物", 24, TEXT))
	for i in relic_stock.size():
		v.add_child(_relic_offer(i))
	# 药水货架
	v.add_child(_label("药水", 24, TEXT))
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

	if AdService.is_placement_enabled(ShopInventorySystem.PLACEMENT):
		var refresh_btn := Button.new()
		refresh_btn.name = "ShopRefreshAdButton"
		refresh_btn.custom_minimum_size = Vector2(560, 64)
		refresh_btn.add_theme_font_size_override("font_size", 22)
		if ShopInventorySystem.is_refresh_configured():
			refresh_btn.text = "观看广告 · 刷新未购买商品（剩余%d次）" % ShopInventorySystem.remaining_refreshes(shop_id)
		else:
			refresh_btn.text = "观看广告 · 刷新未购买商品"
		refresh_btn.disabled = not ShopInventorySystem.can_offer_refresh(shop_id)
		refresh_btn.tooltip_text = ShopInventorySystem.refresh_block_reason(shop_id) if refresh_btn.disabled else "已购买槽位与服务状态保持不变"
		refresh_btn.pressed.connect(_on_refresh_pressed)
		v.add_child(refresh_btn)
		var refresh_hint := "只替换未购买槽位；已售商品、金币和服务状态保持不变。"
		if not _refresh_status.is_empty():
			refresh_hint = _refresh_status + "\n" + refresh_hint
		elif refresh_btn.disabled:
			refresh_hint = ShopInventorySystem.refresh_block_reason(shop_id) + "\n" + refresh_hint
		v.add_child(_label(refresh_hint, 18, TEXT))

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
	info.add_theme_color_override("font_color", TEXT)
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
	if removing:
		return
	if i < 0 or i >= card_stock.size():
		return
	var item: Dictionary = card_stock[i]
	if item["bought"] or RunState.gold < item["price"]:
		return
	var result := CardAcquireService.acquire_shop_card(
		shop_id,
		i,
		StringName(String(item["card"].get("id", ""))),
		int(item["price"])
	)
	if result == CardAcquireService.RESULT_ACQUIRED:
		_log("购买卡牌：%s（-%d 金）" % [item["card"].get("name", ""), item["price"]])
	elif result == CardAcquireService.RESULT_FULL:
		_log("牌库已满，等待选择是否观看广告扩容；尚未扣费。")


func _on_buy_relic(i: int) -> void:
	if removing:
		return
	if i < 0 or i >= relic_stock.size():
		return
	var item: Dictionary = relic_stock[i]
	if item["bought"] or RunState.gold < item["price"]:
		return
	if not RunState.spend_gold(item["price"]):
		return
	RunState.add_relic(StringName(item["id"]))
	item["bought"] = true
	_persist_stock()
	_log("购买遗物：-%d 金" % item["price"])
	_build_main()


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
	if removing:
		return
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
	_persist_stock()
	_log("购买药水：-%d 金" % item["price"])
	_build_main()


func _on_refresh_pressed() -> void:
	var request_id := ShopInventorySystem.request_refresh(shop_id)
	_refresh_status = "广告播放中……" if not request_id.is_empty() else ShopInventorySystem.refresh_block_reason(shop_id)
	_build_main()


func _on_shop_inventory_changed(changed_shop_id: String) -> void:
	if changed_shop_id != shop_id or not is_inside_tree():
		return
	_apply_stock_state(ShopInventorySystem.get_state(shop_id))
	_refresh_status = "商品刷新完成。"
	_build_main()


func _on_ad_reward_resolved(_transaction_id: String, placement_id: StringName, result: StringName) -> void:
	if placement_id != ShopInventorySystem.PLACEMENT or result == &"granted":
		return
	match result:
		AdService.RESULT_SKIPPED, AdService.RESULT_CLOSED:
			_refresh_status = "广告未完整观看，商品没有变化。"
		AdService.RESULT_FAILED:
			_refresh_status = "广告播放失败，商品没有变化。"
		_:
			_refresh_status = "刷新奖励待恢复，请稍后重试。"
	if is_inside_tree():
		_build_main()


func _on_card_acquisition_resolved(acquisition: Dictionary, result: StringName) -> void:
	if String(acquisition.get("source_id", "")) != "shop":
		return
	if result == CardAcquireService.RESULT_ACQUIRED:
		_log("扩容后购买卡牌成功。")
	elif result == CardAcquireService.RESULT_ABANDONED:
		_log("已放弃本次购卡；未扣金币。")
	else:
		_log("容量已处理，但商品、价格或金币状态已变化，本次未扣费、未领卡。")
	if is_inside_tree():
		_apply_stock_state(ShopInventorySystem.get_state(shop_id))
		_build_main()


func _on_enchant_pressed(cost: int) -> void:
	if removing:
		return
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
	v.add_child(_label("附魔服务（%d 金）" % cost, 30, TEXT))
	v.add_child(_label("选择要附魔的卡牌", 20, TEXT))
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
		b.add_theme_color_override("font_color", TEXT)
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
	if removing or _finished or not is_inside_tree() or is_queued_for_deletion() or RunState.gold < remove_cost or not RunState.can_remove_card():
		return
	removing = true
	_build_remove()


func _build_remove() -> void:
	_remove_sources = RunState.deck.duplicate()
	_remove_quote = remove_cost
	var browser := CardBrowserScript.new()
	browser.setup("永久移除", "商店服务 · %d 金 / 张 · 当前 %d 金\n牌组共 %d 张，选择要移除的卡牌。" % [_remove_quote, RunState.gold, RunState.deck.size()],
		RunState.deck, true, "确认 · 支付 %d 金" % _remove_quote, "确认后支付 %d 金。取消或重新选牌不会扣费。" % _remove_quote)
	_remove_browser = browser
	browser.confirmed.connect(_confirm_remove)
	browser.closed.connect(func():
		removing = false
		_remove_browser = null
		_remove_sources.clear()
	)
	add_child(browser)


func _on_remove_card(i: int) -> void:
	if removing and is_instance_valid(_remove_browser):
		_remove_browser.select_card(i)


func _confirm_remove(i: int, snapshot: Dictionary) -> void:
	if not removing or not is_inside_tree():
		return
	removing = false  # 锁定此轮确认，库存信号同步重入不可再次结算。
	var valid := i >= 0 and i < _remove_sources.size() and i < RunState.deck.size()
	if valid:
		valid = RunState.deck[i] == snapshot and is_same(RunState.deck[i], _remove_sources[i])
	var removed := valid and RunState.try_remove_card(i, _remove_sources[i], _remove_quote)
	_remove_status = "已永久移除：%s（-%d 金）" % [CardBrowserScript.card_name(snapshot), _remove_quote] if removed else "未移除、未扣费：金币或牌组已变化，请重新选择。"
	_log(_remove_status)
	_build_main()


func _finish() -> void:
	if _finished or removing or not is_inside_tree():
		return
	_finished = true
	var tree := get_tree()
	if self == tree.current_scene:
		RunState.pending_node_resolved = true
		tree.change_scene_to_packed(load("res://scenes/map/MapPlay.tscn") as PackedScene)
	elif on_done.is_valid():
		queue_free()
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
