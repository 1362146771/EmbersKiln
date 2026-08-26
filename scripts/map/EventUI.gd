extends Control
## 事件：数据驱动于 res://data/events.json（经 GameData 加载）。
## 选项带后果网络（金币/回血/掉血/得卡/得遗物），由 _on_choose 解释执行。
## done 回调回地图。

const CREAM := Color(0.984, 0.953, 0.894)
const DARK := Color(0.25, 0.20, 0.18)
const RED := Color(0.847, 0.353, 0.188)
const AMBER := Color(0.937, 0.624, 0.153)
const PURPLE := Color(0.498, 0.467, 0.867)
const GREEN := Color(0.365, 0.792, 0.647)
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


func _ready() -> void:
	pass


func setup(done: Callable) -> void:
	on_done = done
	_build_main()


## 从 GameData 取一个随机事件；GameData 未就绪时退回一个兜底事件，避免空屏。
func _pick_event() -> Dictionary:
	if GameData.is_loaded and not GameData.events.is_empty():
		return GameData.random_event()
	return {
		"title": "岔路口",
		"desc": "前路不明，你原地整备。",
		"options": [
			{"label": "稍作休整（恢复 8 生命）", "effects": {"heal": 8}},
			{"label": "继续赶路", "effects": {}},
		],
	}


func _build_main() -> void:
	for c in get_children():
		c.queue_free()

	var dim := _solid_bg(BG_DARK)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 1040)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 22)
	v.add_theme_constant_override("margin_bottom", 22)
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)

	var ev: Dictionary = _pick_event()
	v.add_child(_label(ev["title"], 38, DARK))
	var desc := _label(ev["desc"], 24, DARK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)

	for opt in ev["options"]:
		var b := Button.new()
		b.text = opt["label"]
		b.custom_minimum_size = Vector2(600, 72)
		b.add_theme_font_size_override("font_size", 22)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_choose.bind(opt["effects"]))
		v.add_child(b)


func _on_choose(effects: Dictionary) -> void:
	var parts: Array[String] = []
	if effects.has("gold"):
		var g: int = int(effects["gold"])
		RunState.add_gold(g)
		parts.append("金币 %+d" % g)
	if effects.has("heal"):
		var h: int = int(effects["heal"])
		RunState.heal(h)
		parts.append("恢复 %d 生命" % h)
	if effects.has("lose_hp"):
		var d: int = int(effects["lose_hp"])
		RunState.hp = maxi(1, RunState.hp - d)
		SignalBus.player_hp_changed.emit(RunState.hp, RunState.max_hp)
		parts.append("失去 %d 生命" % d)
	if effects.get("add_card", false):
		var cd: Dictionary = RewardBuilder.roll_single_card()
		if not cd.is_empty():
			RunState.add_card(StringName(cd.get("id", "")), false)
			parts.append("获得卡牌 %s" % cd.get("name", ""))
	if effects.get("add_relic", false):
		var rid: StringName = RewardBuilder.roll_shop_relic()
		if rid != &"":
			RunState.add_relic(rid)
			var r: RelicData = GameData.get_relic(rid)
			parts.append("获得遗物 %s" % (r.name if r != null else String(rid)))
	if effects.get("add_potion", false):
		var pid: StringName = RewardBuilder.roll_potion(&"combat", true)
		if pid != &"" and RunState.add_potion(pid):
			var p = GameData.get_potion(pid)
			parts.append("获得药水 %s" % (p.name if p != null else String(pid)))
	if effects.get("add_enchant", false):
		var enc_ok := false
		for i in RunState.deck.size():
			var eentry = RunState.deck[i]
			var ecd = GameData.get_card(StringName(eentry["id"]))
			if ecd == null:
				continue
			var eeid: StringName = RewardBuilder.roll_enchant_for_card(ecd)
			if eeid != &"" and RunState.add_enchant_to_card_at(i, eeid):
				var eed = GameData.get_enchant(eeid)
				parts.append("卡牌 %s 附魔：%s" % [ecd.name, eed.name if eed != null else eeid])
				enc_ok = true
				break
		if not enc_ok:
			parts.append("（无可附魔的卡牌）")
	var msg: String = "（什么也没发生）" if parts.is_empty() else " · ".join(parts)
	_log(msg)
	_show_result(msg)


func _show_result(msg: String) -> void:
	for c in get_children():
		c.queue_free()

	var dim := _solid_bg(BG_DARK)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 700)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 24)
	v.add_theme_constant_override("margin_bottom", 24)
	v.add_theme_constant_override("separation", 24)
	panel.add_child(v)

	var res := _label(msg, 26, GREEN)
	res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(res)

	var btn := Button.new()
	btn.text = "继续"
	btn.custom_minimum_size = Vector2(300, 76)
	btn.add_theme_font_size_override("font_size", 26)
	btn.pressed.connect(_finish)
	v.add_child(btn)


func _finish() -> void:
	queue_free()
	if on_done.is_valid():
		on_done.call()


func _log(msg: String) -> void:
	print("[Event] " + msg)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
