extends "res://scripts/core/NodePanel.gd"
var _choice_made := false
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
	if not has_node("Dim/Center/MainPanel"):
		FormalUI.restore_layout(self, "res://scenes/map/AltarUI.tscn")
	theme = FormalUI.theme()
	var panel: Panel = get_node("Dim/Center/MainPanel")
	panel.add_theme_stylebox_override("panel", FormalUI.stone("bd_stone_framed.png", 20))
	var list: VBoxContainer = panel.get_node("Content/CardScroll/Choices")
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	choices.clear()
	for i in RunState.deck.size():
		var entry: Dictionary = RunState.deck[i]
		if not RunState.can_receive_run_enchant(entry): continue
		var cd := GameData.get_card(StringName(entry["id"]))
		if cd == null: continue
		var eid := RewardBuilder.roll_enchant_for_card(cd)
		if eid == &"": continue
		var ed := GameData.get_enchant(eid)
		var card_name := preload("res://scripts/ui/CardBrowser.gd").card_name(entry)
		var ch := {"index": i, "eid": eid, "card": card_name, "enchant": ed.name, "effect": ed.description}
		choices.append(ch)
		list.add_child(_choice_button(ch, entry, cd))
	panel.get_node("Content/EmptyHint").visible = choices.is_empty()
	var skip: Button = panel.get_node("Content/SkipButton")
	if not skip.pressed.is_connected(_finish): skip.pressed.connect(_finish)


func _choice_button(ch: Dictionary, entry: Dictionary, cd: CardData) -> Button:
	var button := Button.new()
	button.name = "CardChoice_%d" % int(ch.index)
	button.custom_minimum_size = Vector2(0, 208)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_pick.bind(ch))
	var margin := MarginContainer.new()
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	var level := maxi(int(entry.get("upgrade_level", 0)), 1 if entry.get("upgraded", false) else 0)
	var preview := entry.duplicate(true)
	preview.merge({"display_name": ch.card, "cost": cd.resolved_cost(level)}, true)
	var card := FormalUI.card_visual(preview)
	card.fit_height_to_width = false
	card.custom_minimum_size = Vector2(112, 180)
	row.add_child(card)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 9)
	row.add_child(text)
	var title := _label("%s  ·  牌组第 %d 张" % [ch.card, int(ch.index) + 1], 21, AMBER if level > 0 else TEXT_COLOR)
	title.name = "InstanceTitle"
	title.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	text.add_child(title)
	var state := "已升级" if level > 0 else "未升级"
	text.add_child(_label(state + " · 仅为这张卡附魔", 17, CREAM))
	var enchant_row := HBoxContainer.new()
	enchant_row.add_theme_constant_override("separation", 10)
	var ed := GameData.get_enchant(StringName(ch.eid))
	if ed != null and ed.icon != "": enchant_row.add_child(GameData.icon_rect(ed.icon, 30))
	enchant_row.add_child(_label("附魔：%s" % ch.enchant, 21, ALTAR))
	text.add_child(enchant_row)
	var effect := _label(ch.effect, 19, TEXT_COLOR)
	effect.language = "zh_CN"
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(effect)
	_ignore_pointer(margin)
	margin.minimum_size_changed.connect(func(): button.custom_minimum_size.y = maxf(208, margin.get_combined_minimum_size().y))
	return button


func _ignore_pointer(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: _ignore_pointer(child)


func _on_pick(ch: Dictionary) -> void:
	if not can_interact() or _choice_made:
		return
	CardMutation.confirm_run_replace(self, int(ch["index"]), StringName(ch["eid"]), _commit_pick.bind(ch))

func _commit_pick(ch: Dictionary) -> void:
	if _choice_made or not can_interact():
		return
	_choice_made = true
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
	if not can_interact() or not is_inside_tree():
		return
	_finish_transition(on_done)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
