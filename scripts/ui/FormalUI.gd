class_name FormalUI
extends RefCounted
## 正式 UI 资源适配。只负责呈现，不生成奖励、地图或改变 Run 状态。

const ROOT := "res://art/ui/formal/"
# 地图与只读底图共用的呈现尺寸，不影响层数或路径。
const MAP_TOP_MARGIN := 130.0
const MAP_BOSS_GAP := 102.0
const BOSS_NODE_SIZE := 240.0
const MAP_CANVAS_WIDTH := 510.0
const MAP_COLUMN_GAP := 82.0
const BACKGROUNDS := [
	"res://art/backgrounds/BG_Combat_KilnMouth.png",
	"res://art/backgrounds/BG_Combat_GlazeHalls.png",
	"res://art/backgrounds/BG_Combat_ColdKilnHeart.png",
]
const NODE_IMAGES := {
	&"combat": "Monster", &"elite": "eliteMonster", &"boss": "eliteMonster",
	&"event": "event", &"shop": "shop", &"treasure": "reward",
	&"rest": "campfire", &"altar": "intensify",
}
# 图例与地图共用图标：休息为篝火，祭坛保留强化图标。
const MAP_LEGEND := [
	[&"combat", "普通战斗", "遭遇普通敌人"],
	[&"elite", "精英战斗", "挑战强力敌人"],
	[&"boss", "首领", "本幕最终战斗"],
	[&"event", "事件", "遭遇随机事件"],
	[&"shop", "商店", "购买与调整卡组"],
	[&"rest", "休息", "休整或强化卡牌"],
	[&"treasure", "宝箱", "获取宝物"],
	[&"altar", "附魔祭坛", "为卡牌免费附魔"],
]
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
		box.set_texture_margin(side, 24.0 if file == "bd_stone_framed.png" else edge)
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
	if kind == &"rest":
		# 高亮由节点材质描边，同一素材避免两种状态形状不一致。
		return texture("icon_stage_campfire.png")
	return texture("icon_stage_%s%s.png" % [NODE_IMAGES.get(kind, "event"), "_down" if highlighted else ""])

static func boss_map_texture(enemy_ids: Array) -> Texture2D:
	if enemy_ids.is_empty():
		return null
	var enemy := GameData.get_enemy(StringName(enemy_ids[0]))
	return GameData.icon_texture(enemy.map_icon) if enemy != null else null

static func header(parent: Control, title: String) -> Control:
	var old := parent.get_node_or_null("FormalHeader")
	if old != null:
		parent.remove_child(old)
		old.queue_free()
	var bar := Panel.new()
	bar.name = "FormalHeader"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", stone("bd_stone_framed.png", 18))
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


static func card_frame(parent: Control, card_type: StringName) -> void:
	var frame := parent.get_node_or_null("DecorativeFrame") as NinePatchRect
	if frame == null:
		frame = NinePatchRect.new()
		frame.name = "DecorativeFrame"
		parent.add_child(frame)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var types := {&"attack": "Attack", &"skill": "Skill", &"power": "Power", &"status": "Status"}
	frame.texture = load("res://art/ui/cards/FRAME_%s.png" % types.get(card_type, "Status"))
	# 以主体直边内沿对齐统一内容区；尖角仅为外伸装饰，不参与卡面尺寸。
	# 原图 1024×1536，导入为 128×192；以下为原图四侧内沿距离。
	var interior: Vector4 = {&"attack": Vector4(108, 155, 108, 151),
		&"skill": Vector4(97, 106, 97, 117),
		&"power": Vector4(94, 125, 94, 138),
		&"status": Vector4(88, 113, 88, 134)}.get(card_type, Vector4(88, 113, 88, 134))
	var texture_scale := frame.texture.get_width() / 1024.0
	frame.offset_left = 12.0 - interior.x * texture_scale
	frame.offset_top = 12.0 - interior.y * texture_scale
	frame.offset_right = interior.z * texture_scale - 12.0
	frame.offset_bottom = interior.w * texture_scale - 12.0
	frame.patch_margin_left = 28
	frame.patch_margin_right = 28
	frame.patch_margin_top = 28
	frame.patch_margin_bottom = 28
	frame.draw_center = false
	parent.move_child(frame, parent.get_child_count() - 1)


static func card_energy(parent: Control, cost: int, playable: bool = true) -> void:
	var energy := parent.get_node_or_null("CardEnergyCost") as Control
	if energy == null:
		energy = preload("res://scenes/ui/CardEnergyCost.tscn").instantiate()
		parent.add_child(energy)
	energy.get_node("Badge/Value").text = "—" if not playable else ("X" if cost < 0 else str(cost))
	parent.move_child(energy, parent.get_child_count() - 1)


static func fill_card_visual(visual: Control, card: Dictionary, defer_art: bool = false) -> void:
	var cd := GameData.get_card(StringName(card.get("id", "")))
	visual.get_node("Body").text = String(card.get("display_name", String(card.get("name", "")) + ("+" if card.get("upgraded", false) else "")))
	visual.get_node("CardType").text = GameData.card_taxonomy_name(&"types", cd.type) if cd != null else "未发现"
	visual.get_node("Art").texture = GameData.icon_texture(cd.art) if cd != null and not defer_art else null
	for child in visual.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_frame(visual, cd.type if cd != null else &"status")
	card_energy(visual, int(card.get("cost", 0)), cd.playable if cd != null else true)


static func card_visual(card: Dictionary, defer_art: bool = false) -> Control:
	var visual := preload("res://scenes/ui/CardVisual.tscn").instantiate() as Control
	visual.name = "CardImage"
	visual.custom_minimum_size = Vector2.ZERO
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.fit_height_to_width = true
	fill_card_visual(visual, card, defer_art)
	visual.get_node("Body").name = "CardTitle"
	visual.get_node("Art").name = "CardArt"
	return visual


static func card_face(parent: Control, card: Dictionary, defer_art: bool = false) -> void:
	# 非战斗卡牌显示完整内容；输入仍由原有商品/奖励按钮处理。
	var cd := GameData.get_card(StringName(card.get("id", "")))
	var padding := MarginContainer.new()
	padding.name = "CardPadding"
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(padding)
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	padding.add_theme_constant_override("margin_left", 4)
	padding.add_theme_constant_override("margin_right", 4)
	padding.add_theme_constant_override("margin_top", 8)
	padding.add_theme_constant_override("margin_bottom", 8)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding.add_child(body)
	body.add_theme_constant_override("separation", 5)
	var visual := card_visual(card, defer_art)
	visual.get_node("CardTitle").add_theme_font_size_override("font_size", 16)
	body.add_child(visual)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "CardDescription"
	detail_scroll.custom_minimum_size.y = 48
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(detail_scroll)
	var desc := Label.new()
	var types := {&"attack": "攻击", &"skill": "技能", &"power": "能力", &"status": "状态"}
	var rarities := {"starter": "初始", "common": "普通", "uncommon": "精良", "rare": "稀有", "special": "特殊"}
	desc.text = "%s\n%s" % [rarities.get(String(card.get("rarity", "common")), "普通"), card.get("desc", "")]
	desc.add_theme_font_size_override("font_size", 17)
	desc.add_theme_color_override("font_color", Color("f2e8d5"))
	desc.add_theme_color_override("font_outline_color", Color("1b1612"))
	desc.add_theme_constant_override("outline_size", 5)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(desc)
	for child in body.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent is Button:
		parent.text = ""
		parent.tooltip_text = ""
	var box := StyleBoxEmpty.new()
	if parent is Button:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			parent.add_theme_stylebox_override(state, box)
	else:
		parent.add_theme_stylebox_override("panel", box)
	if not parent is Container:
		var minimum_height := parent.custom_minimum_size.y
		padding.minimum_size_changed.connect(func(): parent.custom_minimum_size.y = maxf(minimum_height, padding.get_combined_minimum_size().y))

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
