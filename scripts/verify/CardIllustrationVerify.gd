extends Node
## 已验收插画的资源映射、卡面布局与输入回归；--visual 输出实际渲染截图。

var failed := 0
var visual := false

func _ready() -> void:
	visual = OS.get_cmdline_user_args().has("--visual")
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/card_illustration_verify_save.json"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/cards/illustrations/manifest.json"))
	var uncommon: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/cards/illustrations/uncommon/manifest.json"))
	var illustrations: Array = manifest.cards.duplicate()
	illustrations.append_array(uncommon.cards)
	check(uncommon.cards.size() == 36, "all 36 uncommon illustrations approved")
	var browser = load("res://scripts/ui/CardBrowser.gd").new()
	var count := 0
	for item in illustrations:
		var cd: CardData = GameData.get_card(StringName(item.id))
		var expected: String = item.runtime_art
		check(cd != null and cd.art == expected, "approved mapping " + item.id)
		if cd == null: continue
		var texture := GameData.icon_texture(cd.art)
		check(texture != null and texture.get_width() == texture.get_height(), "square texture " + item.id)
		var view: CardView = load("res://scenes/combat/CardView.tscn").instantiate()
		view.build_visual(cd, 0, [], true)
		view.set_anchors_preset(Control.PRESET_TOP_LEFT)
		view.size = view.custom_minimum_size
		add_child(view)
		await settle(1)
		check(view.get_node("Art").texture == texture and view.get_node("Art").visible, "hand art " + item.id)
		check(view.get_node("Art").mouse_filter == Control.MOUSE_FILTER_IGNORE, "art passes pointer " + item.id)
		check(view.get_node("Art").get_rect().end.y <= view.get_node("Body").position.y, "art and title separated " + item.id)
		var entry := {"id": item.id, "upgraded": true, "enchants": []}
		var panel: Control = browser._card_panel(entry, 0, false)
		check(panel.find_child("CardArt", true, false) != null, "browser art " + item.id)
		panel.free()
		var offer := Button.new()
		FormalUI.card_face(offer, {"id": item.id, "name": cd.name, "cost": cd.cost, "desc": cd.description})
		check(offer.find_child("CardArt", true, false).texture == texture, "reward/shop art " + item.id)
		offer.free()
		remove_child(view)
		view.queue_free()
		count += 1
	browser.free()
	check(count == 59, "all starter, common and uncommon illustrations")
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	var ui: CombatUI = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await settle()
	ui.controller.hand = []
	for id in ["blood_for_blood", "disarm", "dual_wield", "infernal_blade", "whirlwind"]:
		ui.controller.hand.append({"id": id, "upgraded": false, "enchants": []})
	ui._refresh_all()
	await settle()
	await capture("combat")
	var first: CardView = ui.hand_container.get_child(0)
	var before: int = ui.controller.energy
	first.tapped.emit(first)
	await settle()
	check(ui._card_browser._cards.find_child("CardArt", true, false) != null, "popup contains illustration")
	check(ui.controller.energy == before, "viewing art costs no energy")
	await capture("details")
	ui._close_card_browser()
	await settle()
	ui._targeting.on_card_drag_started(first)
	check(ui._ghost != null and ui._ghost.get_node("Art").texture == first.get_node("Art").texture, "drag ghost shares art")
	ui._targeting.on_card_drag_ended(first, Vector2(-100, -100))
	await get_tree().create_timer(0.3).timeout
	remove_child(ui)
	ui.queue_free()
	await settle()
	var gallery = load("res://scripts/ui/CardBrowser.gd").new()
	var entries: Array = []
	for id in ["blood_for_blood", "disarm", "infernal_blade", "whirlwind"]:
		entries.append({"id": id})
	gallery.setup("卡牌插画", "已验收精良卡", entries)
	add_child(gallery)
	await settle()
	await capture("browser")
	gallery.close()
	await settle()
	print("CARD_ILLUSTRATION_RESULT FAIL=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)

func check(ok: bool, title: String) -> void:
	if not ok: failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", title])

func settle(frames: int = 8) -> void:
	for i in frames: await get_tree().process_frame

func capture(label: String) -> void:
	if visual:
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://Temp/card_illustration_" + label + ".png") == OK, "capture " + label)
