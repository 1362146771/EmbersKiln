class_name FormalUI
extends RefCounted
## 正式 UI 资源适配。只负责呈现，不生成奖励、地图或改变 Run 状态。

const ROOT := "res://art/ui/formal/"
const BACKGROUNDS := [
	"res://art/backgrounds/BG_Combat_KilnMouth.png",
	"res://art/backgrounds/BG_Combat_GlazeHalls.png",
	"res://art/backgrounds/BG_Combat_ColdKilnHeart.png",
]
const NODE_IMAGES := {
	&"combat": "Monster", &"elite": "eliteMonster", &"boss": "eliteMonster",
	&"event": "event", &"shop": "shop", &"treasure": "reward",
	&"rest": "intensify", &"altar": "intensify",
}
static var _textures: Dictionary = {}
# 战后过场仅保留一张视觉快照，不参与存档或奖励结算。
static var combat_reward_pending := false
static var combat_reward_backdrop: Texture2D

static func texture(file: String) -> Texture2D:
	# _draw 的纹理 RID 必须在绘制后仍持有资源引用。
	if not _textures.has(file):
		_textures[file] = load(ROOT + file) as Texture2D
	return _textures[file]

static func stone(file: String, edge: float = 32.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture(file)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, edge)
		box.set_content_margin(side, edge)
	return box

static func theme(button_file: String = "btn_event_normal.png") -> Theme:
	return load("res://themes/formal/" + button_file.get_basename() + ".tres") as Theme

static func button(control: Button, file: String = "btn_event_normal.png") -> void:
	control.theme = theme(file)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		control.remove_theme_stylebox_override(state)
	control.add_theme_color_override("font_color", Color.WHITE)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func picture(path: String) -> TextureRect:
	var view := TextureRect.new()
	view.texture = load(path) as Texture2D
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

static func restore_layout(parent: Control, scene_path: String) -> void:
	# 子页返回时复用同一份场景布局，避免重新生成旧版代码后备 UI。
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	var shell := (load(scene_path) as PackedScene).instantiate()
	for child in shell.get_children():
		_clear_owner(child)
		shell.remove_child(child)
		parent.add_child(child)
	shell.free()

static func _clear_owner(node: Node) -> void:
	node.owner = null
	for child in node.get_children():
		_clear_owner(child)

static func menu_background() -> TextureRect:
	var view := picture(BACKGROUNDS[0])
	view.material = load("res://themes/formal/MenuBackground.tres") as ShaderMaterial
	return view

static func background(parent: Control, path: String) -> TextureRect:
	var view := picture(path)
	parent.add_child(view)
	parent.move_child(view, 0)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return view

static func act_background() -> String:
	return BACKGROUNDS[clampi(RunState.current_act, 0, BACKGROUNDS.size() - 1)]

static func node_texture(kind: StringName, highlighted: bool = false) -> Texture2D:
	return texture("icon_stage_%s%s.png" % [NODE_IMAGES.get(kind, "event"), "_down" if highlighted else ""])

static func header(parent: Control, title: String) -> Control:
	var old := parent.get_node_or_null("FormalHeader")
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	var bar := Panel.new()
	bar.name = "FormalHeader"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", stone("bd_shop_btn.png", 18))
	parent.add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 102
	bar.theme = theme()
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.position = Vector2(30, 8)
	heading.size = Vector2(560, 40)
	heading.add_theme_font_size_override("font_size", 28)
	bar.add_child(heading)
	var stats := HBoxContainer.new()
	stats.position = Vector2(30, 52)
	stats.add_theme_constant_override("separation", 24)
	bar.add_child(stats)
	var values := ["%d/%d" % [RunState.hp, RunState.max_hp], str(RunState.gold), "第 %d 层" % RunState.current_floor]
	var files := ["icon_blood.png", "icon_gold(需ai改.png", "icon_stair.png"]
	var colors := [Color("ff6b70"), Color("edcc67"), Color("b8d7cf")]
	for i in values.size():
		var row := HBoxContainer.new()
		stats.add_child(row)
		var icon := picture(ROOT + files[i])
		icon.custom_minimum_size = Vector2(30, 30)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var label := Label.new()
		label.text = values[i]
		label.add_theme_color_override("font_color", colors[i])
		row.add_child(label)
	var buff := RunState.active_pre_run_buff()
	if not buff.is_empty():
		var buff_label := Label.new()
		buff_label.text = "%s · 剩余%d层" % [buff.get("name", "局前增益"), RunState.pre_run_buff_remaining_floors]
		buff_label.position = Vector2(408, 52)
		buff_label.size = Vector2(200, 46)
		buff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buff_label.add_theme_font_size_override("font_size", 16)
		bar.add_child(buff_label)
	return bar

static func map_backdrop(parent: Control) -> void:
	# 同一份地图的只读绘制：事件与奖励场景不实例化 MapUI，避免触发流程。
	var backdrop := parent.get_node_or_null("FormalMapBackdrop") as Control
	if backdrop == null:
		backdrop = load("res://scripts/ui/FormalMapBackdrop.gd").new() as Control
		backdrop.name = "FormalMapBackdrop"
		parent.add_child(backdrop)
		parent.move_child(backdrop, 0)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not parent.has_node("FormalDim"):
		var dim := ColorRect.new()
		dim.name = "FormalDim"
		dim.color = Color(0, 0, 0, 0.52)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(dim)
		parent.move_child(dim, 1)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header(parent, "第 %d 幕 · %s" % [RunState.current_act + 1, RunState.current_act_config().get("title", "")])


static func card_face(parent: Control, card: Dictionary) -> void:
	# 非战斗卡牌显示完整内容；输入仍由原有商品/奖励按钮处理。
	var cd := GameData.get_card(StringName(card.get("id", "")))
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 10
	body.offset_right = -10
	body.offset_top = 10
	body.offset_bottom = -10
	body.add_theme_constant_override("separation", 5)
	var title := Label.new()
	title.text = "%s  %s%s" % ["X" if int(card.get("cost", 0)) < 0 else str(card.get("cost", 0)), card.get("name", ""), "+" if card.get("upgraded", false) else ""]
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	var art_path := cd.art if cd != null else ""
	if not art_path.is_empty() and ResourceLoader.exists(art_path):
		var art := picture(art_path)
		art.name = "CardArt"
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(0, 100)
		body.add_child(art)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail_scroll)
	var desc := Label.new()
	var types := {&"attack": "攻击", &"skill": "技能", &"power": "能力", &"status": "状态"}
	var rarities := {"starter": "初始", "common": "普通", "uncommon": "精良", "rare": "稀有", "special": "特殊"}
	desc.text = "%s · %s\n%s" % [types.get(cd.type if cd != null else &"skill", "卡牌"), rarities.get(String(card.get("rarity", "common")), "普通"), card.get("desc", "")]
	desc.add_theme_font_size_override("font_size", 17)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(desc)
	for child in body.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent is Button:
		parent.text = ""
		parent.tooltip_text = "%s\n%s" % [card.get("name", ""), card.get("desc", "")]
	var box := stone("bd_zhanLiPin_card.png", 5)
	if parent is Button:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var state_box := box.duplicate() as StyleBoxTexture
			state_box.modulate_color = Color("b8c8d8") if state == "hover" else Color.WHITE
			parent.add_theme_stylebox_override(state, state_box)
	else:
		parent.add_theme_stylebox_override("panel", box)

static func reward_arrow(panel: Control, scroll: ScrollContainer) -> void:
	if panel.has_node("NextCards"):
		return
	var arrow := TextureButton.new()
	arrow.name = "NextCards"
	arrow.texture_normal = texture("btn_zhanLiPin_arrow.png")
	panel.add_child(arrow)
	arrow.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	arrow.offset_left = -40
	arrow.offset_right = -14
	arrow.offset_top = -24
	arrow.offset_bottom = 24
	arrow.pressed.connect(func(): scroll.scroll_horizontal += 180)
	var bar := scroll.get_h_scroll_bar()
	var refresh := func(): arrow.visible = bar.value + bar.page < bar.max_value
	bar.changed.connect(refresh)
	bar.value_changed.connect(func(_value: float): refresh.call())
	refresh.call_deferred()
