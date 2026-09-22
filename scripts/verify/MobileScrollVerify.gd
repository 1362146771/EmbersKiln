extends Node

const Browser := preload("res://scripts/ui/CardBrowser.gd")
var failures := 0
var checks := 0
var taps := 0
var drags := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func settle() -> void:
	for frame in 8: await get_tree().process_frame

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/scroll_" + label.replace(" ", "_") + ".png")

func touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = get_viewport().get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)
	await get_tree().process_frame

func swipe(point: Vector2, delta: Vector2) -> void:
	await touch(point, true)
	for step in 12:
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = get_viewport().get_final_transform() * (point + delta * float(step + 1) / 12.0)
		event.relative = get_viewport().get_final_transform().basis_xform(delta / 12.0)
		Input.parse_input_event(event)
		await get_tree().process_frame
	# Stop moving before release, avoiding inertia in assertions for nested axes.
	await get_tree().create_timer(0.15).timeout
	await touch(point + delta, false)
	await settle()

func visible_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect().intersection(get_viewport().get_visible_rect())
	var parent := control.get_parent()
	while parent is Control:
		if parent.clip_contents: rect = rect.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return rect

func probe(scroll: ScrollContainer, title: String, horizontal := false, hit: Control = null) -> void:
	await settle()
	var bar: ScrollBar = scroll.get_h_scroll_bar() if horizontal else scroll.get_v_scroll_bar()
	check(scroll.is_visible_in_tree() and visible_rect(scroll).has_area(), title + ": visible touch area")
	if bar.max_value <= bar.page:
		print("[FIT] ", title, " content fits without scrolling")
		return
	bar.value = 0
	await settle()
	var rect := visible_rect(hit if hit != null else scroll)
	var point := rect.position + rect.size * Vector2(0.7, 0.7)
	var delta := Vector2(-minf(180, rect.size.x * 0.6), 0) if horizontal else Vector2(0, -minf(180, rect.size.y * 0.6))
	var deck_before := RunState.deck.duplicate(true)
	var gold_before := RunState.gold
	await swipe(point, delta)
	check(bar.value > 0, title + ": finger swipe scrolls content")
	check(RunState.deck == deck_before and RunState.gold == gold_before, title + ": swipe does not select or purchase")
	# Scroll through the whole list with repeated gestures, not direct range writes.
	var count := 0
	while bar.value < bar.max_value - bar.page - 1 and count < 45:
		var previous: float = bar.value
		await swipe(visible_rect(scroll).position + visible_rect(scroll).size * Vector2(0.75, 0.8),
			Vector2(-visible_rect(scroll).size.x * 0.65, 0) if horizontal else Vector2(0, -visible_rect(scroll).size.y * 0.65))
		count += 1
		if bar.value <= previous: break
	check(bar.value >= bar.max_value - bar.page - 1, title + ": last item reachable by swiping")
	await capture(title)

func dispose(node: Node) -> void:
	node.queue_free()
	await settle()

func mount(path: String) -> Node:
	var node := load(path).instantiate() as Node
	add_child(node)
	await settle()
	return node

func _ready() -> void:
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/mobile_scroll_save.json"
	ProfileState.reset_to_defaults(false)
	RunState.start_new_run()
	RunState.granny_opening["resolved"] = true
	RunState.pre_run_preparation_resolved = true
	RunState.clear_combat_checkpoint()
	PauseManager.hide_pause_button()
	check(DisplayServer.is_touchscreen_available(), "test uses native touchscreen path")
	if not DisplayServer.is_touchscreen_available():
		get_tree().quit(2)
		return
	var deck := RunState.deck.duplicate(true)
	for i in 2: RunState.deck.append_array(deck.duplicate(true))
	await verify_native_buttons()
	var compendium := await mount("res://scenes/ui/CardCompendium.tscn")
	await probe(compendium._scroll, "card compendium")
	await dispose(compendium)
	var browser := Browser.new()
	browser.setup("测试牌堆", "", RunState.deck, true, "确认")
	add_child(browser)
	await probe(browser._scroll, "deck browser")
	check(browser.selected_index == -1, "deck swipe never selects a card")
	await dispose(browser)
	await verify_card_detail()
	var picker := preload("res://scripts/ui/CardUpgradePicker.gd").new()
	add_child(picker)
	await probe(picker._scroll, "upgrade picker")
	check(picker._selected == -1, "upgrade swipe never opens confirmation")
	picker.select_card(0)
	await probe(picker._modal.find_child("ComparisonScroll", true, false), "upgrade comparison")
	picker._pair.custom_minimum_size.y = 1500 # Oversized presentation fixture, no gameplay changes.
	await probe(picker._modal.find_child("ComparisonScroll", true, false), "long upgrade comparison")
	await dispose(picker)
	await verify_map_shop_rewards()
	await verify_town()
	await verify_preparation_and_overview()
	await verify_relics_and_hand()
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer: child.stop()
	await get_tree().create_timer(0.2).timeout
	print("MOBILE_SCROLL_RESULT:", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)

func verify_native_buttons() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(60, 180)
	scroll.size = Vector2(600, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	for i in 18:
		var button := Button.new()
		button.text = "触摸滚动测试 %d" % i
		button.custom_minimum_size.y = 100
		button.pressed.connect(func(): taps += 1)
		column.add_child(button)
	await probe(scroll, "button-filled list")
	check(taps == 0, "swiping buttons never clicks them")
	scroll.scroll_vertical = 0
	await settle()
	var point: Vector2 = column.get_child(0).get_global_rect().get_center()
	await touch(point, true)
	await touch(point, false)
	check(taps == 1, "short tap still clicks exactly once")
	await touch(point, true)
	var cancel := InputEventScreenTouch.new()
	cancel.position = get_viewport().get_final_transform() * point
	cancel.canceled = true
	Input.parse_input_event(cancel)
	await settle()
	check(taps == 1, "canceled touch never clicks a button")
	get_tree().paused = true
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	await probe(scroll, "paused overlay")
	get_tree().paused = false
	scroll.scroll_vertical = 0
	var inner := ScrollContainer.new()
	inner.custom_minimum_size.y = 180
	inner.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(inner)
	column.move_child(inner, 0)
	var row := HBoxContainer.new()
	inner.add_child(row)
	for i in 6:
		var button := Button.new()
		button.custom_minimum_size = Vector2(240, 140)
		button.pressed.connect(func(): taps += 1)
		row.add_child(button)
	await probe(inner, "nested horizontal list", true)
	await probe(scroll, "nested vertical list", false, inner)
	check(taps == 1, "nested swipes never click a child button")
	await dispose(scroll)

func verify_card_detail() -> void:
	var source := Control.new()
	source.position = Vector2(160, 500)
	source.size = Vector2(136, 212)
	add_child(source)
	var details := Browser.new()
	details.setup_details(RunState.deck[0], "长文本验证\n".repeat(30), source)
	add_child(details)
	await probe(details._scroll, "single card detail")
	check(is_instance_valid(details) and not details._finished, "scrolling detail never closes backdrop")
	await dispose(details)
	await dispose(source)

func verify_map_shop_rewards() -> void:
	var map := await mount("res://scenes/map/MapPlay.tscn")
	await probe(map.map_scroller, "map with hidden scrollbar")
	await dispose(map)
	var shop := await mount("res://scenes/map/ShopUI.tscn")
	var outer: ScrollContainer = shop.get_node("Dim/Center/MainPanel/ContentScroll")
	var inner: ScrollContainer = outer.get_node("Content/CardScroll")
	await probe(inner, "shop card shelf", true)
	outer.scroll_vertical = 0
	await settle()
	var before_x := inner.scroll_horizontal
	await probe(outer, "shop vertical list from card shelf", false, inner)
	check(inner.scroll_horizontal == before_x, "vertical shop swipe preserves horizontal position")
	var relic_info := outer.get_node("Content/RelicOffers").find_child("InspectRelic", true, false) as Button
	check(relic_info != null, "dynamically built relic offer uses release action")
	if relic_info != null:
		outer.ensure_control_visible(relic_info)
		await settle()
		var start := visible_rect(relic_info).get_center()
		await swipe(start, Vector2(0, 100))
		check(not relic_info.get_parent().has_node("RelicDetailsPopup"), "dragging relic offer never opens a popup")
		outer.ensure_control_visible(relic_info)
		await settle()
		start = visible_rect(relic_info).get_center()
		await touch(start, true)
		await touch(start, false)
		check(relic_info.get_parent().has_node("RelicDetailsPopup"), "relic offer remains inspectable by tap")
		if relic_info.get_parent().has_node("RelicDetailsPopup"):
			var popup := relic_info.get_parent().get_node("RelicDetailsPopup")
			check(popup.get_node("Details").mouse_filter == Control.MOUSE_FILTER_STOP, "nested popup keeps its input shield")
			await dispose(popup)
	shop._build_enchant(int(GameData.balance.shop.enchant_cost))
	await settle()
	var services := shop.find_children("*", "ScrollContainer", true, false)
	if not services.is_empty(): await probe(services[0], "shop enchant service")
	await dispose(shop)
	var altar := await mount("res://scenes/map/AltarUI.tscn")
	await probe(altar.get_node("Dim/Center/MainPanel/Content/CardScroll"), "altar card selection")
	await dispose(altar)
	var reward := preload("res://scenes/rewards/RewardUI.tscn").instantiate()
	reward.setup({"cards": RewardBuilder.roll_card_choices(3), "gold": 0}, Callable())
	add_child(reward)
	await probe(reward.get_node("Dim/Center/MainPanel/Content/CardScroll"), "reward card choices", true)
	await probe(reward.get_node("Dim/Center/MainPanel/Content/CardScroll"), "reward card descriptions")
	reward._build_enchant()
	await settle()
	var enchant_lists := reward.find_children("*", "ScrollContainer", true, false)
	if not enchant_lists.is_empty(): await probe(enchant_lists[0], "reward enchant selection")
	await dispose(reward)

func verify_town() -> void:
	var town := await mount("res://scenes/town/Town.tscn")
	await town._on_facility_pressed(&"glaze_apothecary")
	await probe(town.get_node("FacilityDetailPanel/DetailMargin/DetailColumn/DetailScroll"), "town facility details")
	town._show_mutation(true)
	await settle()
	var mutation := town.get_node("FacilityDetailPanel/DetailMargin/DetailColumn/CardMutationPanel")
	await probe(mutation.get_node("Gallery"), "mutation gallery")
	check(mutation._selected_id == "", "gallery swipe never selects card")
	mutation.select_card(String(mutation.card_ids[0]))
	await probe(mutation.get_node("Scroll"), "mutation directions")
	await dispose(town)
	var enchant := StringName(GameData.enchants.keys()[0])
	for card in RunState.deck: card.enchants = [enchant]
	var loadout := await mount("res://scenes/ui/EnchantLoadout.tscn")
	var selection := RunState.selected_enchant_instance_ids.duplicate()
	await probe(loadout.get_node("Cover/Panel/Body/Scroll"), "enchant loadout")
	check(RunState.selected_enchant_instance_ids == selection, "loadout swipe does not toggle checkboxes")
	await dispose(loadout)

func verify_preparation_and_overview() -> void:
	RunState.pre_run_preparation_resolved = false
	RunState.pre_run_buff_offer_ids.assign(GameData.ad_placement_config(PreRunBuffSystem.PLACEMENT).buff_ids)
	var preparation := await mount("res://scenes/main/PreRunAdPreparation.tscn")
	await probe(preparation.get_node("PreparationPanel/Margin/Column/Scroll"), "pre-run offers")
	await dispose(preparation)
	var overview := preload("res://scenes/ui/BattleRewardOverview.tscn").instantiate()
	add_child(overview)
	overview.setup({"gold": 10, "relic_id": GameData.relics.keys()[0], "cards": [RunState.deck[0]]}, null)
	# The production overview normally fits one row; exercise overflow too.
	var grid := overview.get_node("Panel/Items/Scroll/Grid")
	for i in 8: overview._add_item(grid, "测试战利品", null)
	await probe(overview.get_node("Panel/Items/Scroll"), "battle reward overview")
	await dispose(overview)

func verify_relics_and_hand() -> void:
	RunState.relic_ids.assign(GameData.relics.keys())
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var relics := preload("res://scenes/combat/RelicBar.tscn").instantiate()
	relics.position = Vector2(50, 100)
	relics.size = Vector2(400, 60)
	host.add_child(relics)
	await probe(relics.scroll, "relic icon bar", true)
	check(not relics.details.visible, "relic swipe never opens details")
	var hand := ScrollContainer.new()
	hand.position = Vector2(50, 450)
	hand.size = Vector2(500, 270)
	hand.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	host.add_child(hand)
	var row := HBoxContainer.new()
	hand.add_child(row)
	for i in 10:
		var card := preload("res://scenes/combat/CardView.tscn").instantiate()
		card.build_visual(GameData.get_card(&"strike"), i, [])
		card.drag_started.connect(func(_card): drags += 1)
		card.tapped.connect(func(_card): taps += 1)
		row.add_child(card)
	var tap_count := taps
	await probe(hand, "combat hand", true)
	check(drags == 0 and taps == tap_count, "horizontal hand swipe neither plays nor inspects a card")
	hand.scroll_horizontal = 0
	await settle()
	await swipe(row.get_child(1).get_global_rect().get_center(), Vector2(0, -150))
	check(drags == 1, "vertical hand drag still starts card play")
	await dispose(host)
