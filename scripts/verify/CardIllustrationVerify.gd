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
	var remaining: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/cards/illustrations/remaining/manifest.json"))
	var illustrations: Array = manifest.cards.duplicate()
	illustrations.append_array(uncommon.cards)
	illustrations.append_array(remaining.cards)
	check(remaining.cards.size() == 19, "all 19 rare and status illustrations approved")
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
		check(is_equal_approx(view.size.y - view.size.x, 52.0), "hand frame reserves name and type rows " + item.id)
		check(view.get_node("Art").stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "hand illustration never crops " + item.id)
		check(view.get_node("Art").size.x >= view.size.x - 28.0, "hand art fills decorated frame interior " + item.id)
		check(view.get_node("Body").get_rect().end.y <= view.get_node("Art").position.y, "title above framed art " + item.id)
		check(view.get_theme_stylebox("panel") is StyleBoxEmpty, "no backing panel " + item.id)
		check(view.get_node("CardEnergyCost/Badge/Value").text == ("—" if not cd.playable else ("X" if view.resolved_cost < 0 else str(view.resolved_cost))), "hex cost value " + item.id)
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
	check(count == 78, "all 78 card illustrations")
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	var ui: CombatUI = load("res://scenes/combat/CombatPlay.tscn").instantiate()
	add_child(ui)
	await settle()
	ui.controller.hand = []
	for id in ["immolate", "barricade", "wound", "burn", "dazed"]:
		ui.controller.hand.append({"id": id, "upgraded": false, "enchants": []})
	ui._refresh_all()
	await settle()
	await capture("combat")
	var first: CardView = ui.hand_container.get_child(0)
	var before: int = ui.controller.energy
	first.tapped.emit(first)
	await settle()
	check(ui._card_browser._cards.find_child("CardArt", true, false) != null, "popup contains illustration")
	check_full_width_art(ui._card_browser._cards.find_child("CardArt", true, false), "popup")
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
	for id in ["immolate", "wound", "burn", "dazed"]:
		entries.append({"id": id})
	gallery.setup("卡牌插画", "已验收稀有与状态卡", entries)
	add_child(gallery)
	await settle()
	await capture("browser")
	for panel in gallery._cards.get_children():
		check_full_width_art(panel.find_child("CardArt", true, false), "browser")
	gallery.close()
	await settle()
	# 覆盖奖励、商店固定尺寸及图鉴宽卡框的共用布局。
	var samples := Control.new()
	add_child(samples)
	var sizes := [Vector2(180, 280), Vector2(158, 295), Vector2(280, 340)]
	for i in sizes.size():
		var offer: Control = Button.new() if i == 0 else (Panel.new() if i == 1 else PanelContainer.new())
		offer.position = Vector2(24 + i * 198, 80)
		offer.size = sizes[i]
		samples.add_child(offer)
		var cd := GameData.get_card(&"immolate")
		FormalUI.card_face(offer, {"id": cd.id, "name": cd.name, "cost": cd.cost, "desc": cd.description, "rarity": cd.rarity})
	await settle()
	for offer in samples.get_children():
		var art: TextureRect = offer.find_child("CardArt", true, false)
		check(art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "offer shows complete illustration without cropping")
		check(offer.get_global_rect().encloses(art.get_global_rect()), "offer art enclosed by outer frame")
		check(art.size.x >= offer.size.x - 32.0, "offer art fills decorated frame interior")
		var body: Control = art.get_parent()
		check(body.size.y <= offer.size.y, "offer content remains within frame")
		var title: Control = offer.find_child("CardTitle", true, false)
		var description: Control = offer.find_child("CardDescription", true, false)
		check(is_equal_approx(body.size.y - body.size.x, 52.0), "offer frame follows shared name-image-type layout")
		check(title.get_global_rect().end.y <= art.global_position.y, "name above artwork frame")
		check(description.global_position.y >= body.get_global_rect().end.y, "description below artwork frame")
		check(offer.get_global_rect().encloses(description.get_global_rect()), "description stays within offer")
	await capture("offers")
	samples.queue_free()
	print("CARD_ILLUSTRATION_RESULT FAIL=%d" % failed)
	get_tree().quit(0 if failed == 0 else 1)

func check(ok: bool, title: String) -> void:
	if not ok: failed += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", title])

func check_full_width_art(art: TextureRect, title: String) -> void:
	check(art != null and art.size.x > 0 and absf(art.size.x - art.size.y) <= 1.0
		and absf(art.size.x - (art.get_parent().size.x - 24.0)) <= 1.0, title + " image fills available width without distortion")

func settle(frames: int = 8) -> void:
	for i in frames: await get_tree().process_frame

func capture(label: String) -> void:
	if visual:
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://Temp/card_illustration_" + label + ".png") == OK, "capture " + label)
