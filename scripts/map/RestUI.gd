extends Control
## 休息点：回血 或 升级一张卡（二选一）。done 回调交还控制权回地图。

const CREAM := Color(0.984, 0.953, 0.894)
const GREEN := Color(0.365, 0.792, 0.647)
const DARK := Color(0.25, 0.20, 0.18)
const RED := Color(0.847, 0.353, 0.188)
const PURPLE := Color(0.498, 0.467, 0.867)
const BG_DARK := Color(0.12, 0.10, 0.09)

var on_done: Callable = Callable()

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


func setup(done: Callable) -> void:
	on_done = done
	_build_main()


## P2 场景化：作为独立场景被 change_scene_to_packed 加载时，自构建界面（不依赖外部 setup）。
func _ready() -> void:
	_build_main()


func _build_main() -> void:
	var heal_pct: float = float(GameData.balance.get("rest", {}).get("heal_percent", 0.3))
	var heal_amt: int = int(RunState.max_hp * heal_pct)
	var scene_panel: Panel = get_node_or_null("Dim/Center/MainPanel")
	if scene_panel != null:
		var rest_button: Button = scene_panel.get_node("Content/RestButton")
		rest_button.text = "休息（恢复 %d 生命）" % heal_amt
		if not rest_button.pressed.is_connected(_on_rest.bind(heal_amt)):
			rest_button.pressed.connect(_on_rest.bind(heal_amt))
		var forge_button: Button = scene_panel.get_node("Content/ForgeButton")
		if not forge_button.pressed.is_connected(_on_forge):
			forge_button.pressed.connect(_on_forge)
		var leave_button: Button = scene_panel.get_node("Content/LeaveButton")
		if not leave_button.pressed.is_connected(_finish):
			leave_button.pressed.connect(_finish)
		return
	for c in get_children():
		c.queue_free()

	var dim := _solid_bg(BG_DARK)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 1000)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 24)
	v.add_theme_constant_override("margin_bottom", 24)
	v.add_theme_constant_override("separation", 22)
	panel.add_child(v)

	v.add_child(_label("休 息 点", 40, DARK))

	v.add_child(_label("炉火尚温，稍作休整。", 24, DARK))

	var rest_btn := Button.new()
	rest_btn.text = "休息（恢复 %d 生命）" % heal_amt
	rest_btn.custom_minimum_size = Vector2(560, 80)
	rest_btn.add_theme_font_size_override("font_size", 26)
	rest_btn.pressed.connect(_on_rest.bind(heal_amt))
	v.add_child(rest_btn)

	var forge_btn := Button.new()
	forge_btn.text = "锻造（升级一张卡）"
	forge_btn.custom_minimum_size = Vector2(560, 80)
	forge_btn.add_theme_font_size_override("font_size", 26)
	forge_btn.pressed.connect(_on_forge)
	v.add_child(forge_btn)

	var leave_btn := Button.new()
	leave_btn.text = "离开"
	leave_btn.custom_minimum_size = Vector2(560, 64)
	leave_btn.add_theme_font_size_override("font_size", 22)
	leave_btn.pressed.connect(_finish)
	v.add_child(leave_btn)


func _on_rest(heal_amt: int) -> void:
	RunState.heal(heal_amt)
	# 补陶泥遗物：休息额外回血
	for rid in RunState.relic_ids:
		var r: RelicData = GameData.get_relic(rid)
		if r != null and r.effect == &"heal_bonus":
			RunState.heal(r.value)
	_log("休息恢复 %d 生命（HP %d/%d）" % [heal_amt, RunState.hp, RunState.max_hp])
	_finish()


func _on_forge() -> void:
	_build_forge()


func _build_forge() -> void:
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
	v.add_theme_constant_override("margin_top", 24)
	v.add_theme_constant_override("margin_bottom", 24)
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	v.add_child(_label("锻造台", 34, DARK))
	v.add_child(_label("选择要强化的卡牌（灼热攻击可重复升级）", 20, DARK))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)

	var upgradable := false
	for i in RunState.deck.size():
		var entry: Dictionary = RunState.deck[i]
		var cd: CardData = GameData.get_card(StringName(entry["id"]))
		var level := int(entry.get("upgrade_level", 1 if bool(entry.get("upgraded", false)) else 0))
		if cd == null or level > 0 and not cd.repeatable_upgrade:
			continue
		upgradable = true
		var b := Button.new()
		b.custom_minimum_size = Vector2(600, 64)
		b.add_theme_color_override("font_color", DARK)
		b.text = "%s%s → %s" % [cd.name, "+" + str(level) if level > 1 else "+" if level == 1 else "", cd.get_description(level + 1)]
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_on_upgrade_card.bind(i))
		col.add_child(b)

	if not upgradable:
		v.add_child(_label("（没有可升级的卡牌）", 22, RED))

	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(300, 60)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(_build_main)
	v.add_child(back)


func _on_upgrade_card(i: int) -> void:
	if RunState.upgrade_card_at(i):
		_log("卡牌已升级")
	_finish()


func _finish() -> void:
	# 双模兼容：作为独立场景（生产）时置标记并切回地图；作为 verify 的 overlay 子节点时走 on_done 回调。
	if self == get_tree().current_scene:
		RunState.pending_node_resolved = true
		get_tree().change_scene_to_packed(load("res://scenes/map/MapPlay.tscn") as PackedScene)
	elif on_done.is_valid():
		on_done.call()


func _log(msg: String) -> void:
	print("[Rest] " + msg)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
