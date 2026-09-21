extends Node

var failures := 0
var gold_events := 0
var deck_events := 0

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func _ready() -> void:
	if OS.get_environment("UPGRADE_VERIFY_ROOT").is_empty():
		get_tree().quit(2)
		return
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/shop_potion_save.json"
	RunState.start_new_run()
	RunState.relic_ids.assign([&"charcoal_chit"])
	var shop := preload("res://scenes/map/ShopUI.tscn").instantiate()
	add_child(shop)
	var offer: Dictionary = shop.potion_stock[0].duplicate(true)
	offer.bought = false
	shop.potion_stock.assign([offer, offer.duplicate(true)])
	var price := int(offer.price)
	RunState.gold = price * 4
	RunState.potions.clear()
	for i in RunState._potion_cap(): RunState.add_potion(StringName(offer.id))
	var before_gold := RunState.gold
	var before_potions := RunState.potions.duplicate()
	SignalBus.gold_changed.connect(func(_gold): gold_events += 1)
	SignalBus.deck_changed.connect(func(): deck_events += 1)
	for i in 5: shop._on_buy_potion(0)
	check(RunState.gold == before_gold, "repeated full-slot purchases with gold bonus relic never add or deduct gold")
	check(RunState.potions == before_potions and not shop.potion_stock[0].bought, "full slots leave potion inventory and merchandise unchanged")
	check(gold_events == 0 and deck_events == 0, "rejected full-slot purchase emits no economy or inventory changes")
	check(shop._purchase_status.contains("药水槽已满"), "full-slot rejection has visible feedback")
	var row: Control = shop._potion_offer(0)
	var buy: Button = row.get_child(row.get_child_count() - 1)
	check(buy.disabled and buy.text.replace("\n", "").contains("药水槽已满"), "sold-out capacity is explained on the purchase button")
	row.free()
	RunState.remove_potion_at(0)
	RunState.gold = price - 1
	var before_count := RunState.potions.size()
	shop._on_buy_potion(0)
	check(RunState.gold == price - 1 and RunState.potions.size() == before_count and not shop.potion_stock[0].bought, "insufficient gold never grants potion or marks sold")
	RunState.gold = before_gold
	var reenter := func(_gold): shop._on_buy_potion(0)
	SignalBus.gold_changed.connect(reenter)
	gold_events = 0
	deck_events = 0
	shop._on_buy_potion(0)
	SignalBus.gold_changed.disconnect(reenter)
	check(RunState.gold == before_gold - price and RunState.potions.size() == before_count + 1, "successful purchase deducts exactly price and adds one potion, including reentrant signal")
	check(gold_events == 1 and deck_events == 1 and shop.potion_stock[0].bought, "successful purchase publishes once and marks sold")
	check(ShopInventorySystem.get_state(shop.shop_id).potion_stock[0].bought, "sold potion persists in shop stock")
	var purchased_gold := RunState.gold
	shop._on_buy_potion(0)
	shop._on_buy_potion(1)
	check(RunState.gold == purchased_gold and not shop.potion_stock[1].bought, "sold item and remaining full-slot offer cannot be bought again")
	RunState.remove_potion_at(0)
	row = shop._potion_offer(1)
	buy = row.get_child(row.get_child_count() - 1)
	check(not buy.disabled and buy.text.contains(str(price)), "purchase becomes available when capacity is freed")
	row.free()
	before_count = RunState.potions.size()
	check(not RunState.try_buy_potion(&"missing_potion", price) and not RunState.try_buy_potion(StringName(offer.id), -price), "invalid potion and negative price rejected")
	check(RunState.gold == purchased_gold and RunState.potions.size() == before_count, "invalid purchase has no side effects")
	RunState.add_potion(StringName(offer.id))
	shop._on_buy_potion(1)
	await get_tree().process_frame
	await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--visual"):
		get_tree().root.size = Vector2i(720, 1280)
		var scroll: ScrollContainer = shop.get_node("Dim/Center/MainPanel/ContentScroll")
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		for i in 6: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://Temp/shop_potion_full.png")
	print("SHOP_POTION_RESULT:", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
