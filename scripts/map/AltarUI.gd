extends Control
## 附魔祭坛（免费附魔节点，方案B）。
## 玩家从牌组中选一张未附魔的卡牌，免费永久套用一个合法附魔。
## setup(done) 由 verify 直接调用（overlay 模式）；生产路径下本脚本作为独立场景被
## change_scene_to_packed 加载，_ready 自构建，_finish 经 RunState 标记切回地图。

const CREAM := Color(0.984, 0.953, 0.894)
const ORANGE := Color(0.941, 0.600, 0.482)
const GREEN := Color(0.365, 0.792, 0.647)
const RED := Color(0.847, 0.353, 0.188)
const PURPLE := Color(0.498, 0.467, 0.867)
const TEXT_COLOR := Color("F2E8D5")
const AMBER := Color(0.937, 0.624, 0.153)
const ALTAR := Color(0.45, 0.72, 0.85)
const BG_DARK := Color(0.12, 0.10, 0.09)

var on_done: Callable = Callable()
var choices: Array = []   # Array of Dictionary {index, eid, card, enchant}


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


## 由 verify 直接调用（done 为可选的 overlay 完成回调）；生产路径不调用，改由 _ready 自构建。
func setup(done: Callable) -> void:
	on_done = done


func _ready() -> void:
	_build()


func _build() -> void:
	var scene_panel: Panel = get_node_or_null("Dim/Center/MainPanel")
	if scene_panel != null:
		choices = []
		var choice_list: VBoxContainer = scene_panel.get_node("Content/CardScroll/Choices")
		for child in choice_list.get_children():
			child.queue_free()
		for i in RunState.deck.size():
			var entry: Dictionary = RunState.deck[i]
			if not entry.get("enchants", []).is_empty():
				continue
			var card_data: CardData = GameData.get_card(StringName(entry["id"]))
			if card_data == null:
				continue
			var enchant_id: StringName = RewardBuilder.roll_enchant_for_card(card_data)
			if enchant_id == &"":
				continue
			var enchant_data = GameData.get_enchant(enchant_id)
			var enchant_name: String = enchant_data.name if enchant_data != null else String(enchant_id)
			var enchant_effect: String = enchant_data.description if enchant_data != null else ""
			var choice := {"index": i, "eid": enchant_id, "card": card_data.name, "enchant": enchant_name, "effect": enchant_effect}
			choices.append(choice)
			var choice_button := Button.new()
			choice_button.custom_minimum_size = Vector2(600, 150)
			choice_button.add_theme_color_override("font_color", TEXT_COLOR)
			choice_button.text = "%s\n附魔：%s\n%s" % [choice["card"], choice["enchant"], choice["effect"]]
			choice_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			choice_button.add_theme_font_size_override("font_size", 20)
			if enchant_data != null and enchant_data.icon != "":
				choice_button.icon = GameData.icon_texture(enchant_data.icon)
				choice_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
			choice_button.pressed.connect(_on_pick.bind(choice))
			choice_list.add_child(choice_button)
		scene_panel.get_node("Content/EmptyHint").visible = choices.is_empty()
		var skip_button: Button = scene_panel.get_node("Content/SkipButton")
		if not skip_button.pressed.is_connected(_finish):
			skip_button.pressed.connect(_finish)
		return
	for c in get_children():
		c.queue_free()

	add_child(_solid_bg(BG_DARK))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 1100)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 24)
	v.add_theme_constant_override("margin_bottom", 24)
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)

	v.add_child(_label("附 魔 祭 坛", 40, ALTAR))
	v.add_child(_label("选择一张未附魔的卡牌，免费获得一个附魔", 22, TEXT_COLOR))

	# 预滚每个合法卡牌的附魔，保证「展示的附魔」与「实际套用的附魔」一致。
	choices = []
	for i in RunState.deck.size():
		var entry: Dictionary = RunState.deck[i]
		if not entry.get("enchants", []).is_empty():
			continue
		var cd: CardData = GameData.get_card(StringName(entry["id"]))
		if cd == null:
			continue
		var eid: StringName = RewardBuilder.roll_enchant_for_card(cd)
		if eid == &"":
			continue
		var ed = GameData.get_enchant(eid)
		var ename: String = ed.name if ed != null else String(eid)
		var effect: String = ed.description if ed != null else ""
		choices.append({"index": i, "eid": eid, "card": cd.name, "enchant": ename, "effect": effect})

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)

	for ch in choices:
		var b := Button.new()
		b.custom_minimum_size = Vector2(600, 150)
		b.add_theme_color_override("font_color", TEXT_COLOR)
		var effect: String = ch.get("effect", "")
		b.text = "%s\n附魔：%s\n%s" % [ch["card"], ch["enchant"], effect]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 20)
		var ed := GameData.get_enchant(StringName(ch["eid"]))
		if ed != null and ed.icon != "":
			b.icon = GameData.icon_texture(ed.icon)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_pick.bind(ch))
		col.add_child(b)

	if choices.is_empty():
		v.add_child(_label("（当前没有可附魔的卡牌）", 22, RED))

	var skip := Button.new()
	skip.text = "跳过祭坛"
	skip.custom_minimum_size = Vector2(300, 64)
	skip.add_theme_font_size_override("font_size", 22)
	skip.pressed.connect(_finish)
	v.add_child(skip)


func _on_pick(ch: Dictionary) -> void:
	var i: int = ch["index"]
	var eid: StringName = ch["eid"]
	if i < 0 or i >= RunState.deck.size():
		_finish()
		return
	var applied := false
	if RunState.add_enchant_to_card_at(i, eid):
		applied = true
		var cd: CardData = GameData.get_card(StringName(RunState.deck[i]["id"]))
		print("[Altar] 卡牌 %s 免费附魔：%s" % [cd.name if cd != null else "?", eid])
	_show_result(ch, applied)


## 套用后展示「附魔完成」面板，明确给出附魔效果文本，再点完成结算。
func _show_result(ch: Dictionary, applied: bool) -> void:
	for c in get_children():
		c.queue_free()
	add_child(_solid_bg(BG_DARK))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 1100)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 24)
	v.add_theme_constant_override("margin_bottom", 24)
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)

	v.add_child(_label("附 魔 完 成", 40, ALTAR))
	v.add_child(_label("卡牌：%s" % ch["card"], 26, TEXT_COLOR))
	var red := GameData.get_enchant(StringName(ch["eid"]))
	if red != null and red.icon != "":
		v.add_child(GameData.icon_rect(red.icon, 64))
	v.add_child(_label("获得附魔：%s" % ch["enchant"], 26, GREEN))

	var effect: String = ch.get("effect", "")
	var el := _label(effect if effect != "" else "（无效果描述）", 22, TEXT_COLOR)
	el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	el.custom_minimum_size = Vector2(0, 200)
	v.add_child(el)

	if not applied:
		v.add_child(_label("（附魔未生效：卡牌已持有附魔或不满足条件）", 20, RED))

	var done := Button.new()
	done.text = "完成"
	done.custom_minimum_size = Vector2(300, 72)
	done.add_theme_font_size_override("font_size", 24)
	done.pressed.connect(_finish)
	v.add_child(done)


func _finish() -> void:
	if self == get_tree().current_scene:
		RunState.pending_node_resolved = true
		get_tree().change_scene_to_packed(load("res://scenes/map/MapPlay.tscn") as PackedScene)
	elif on_done.is_valid():
		on_done.call()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
