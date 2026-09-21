extends "res://scripts/core/NodePanel.gd"
## 休息点：回血 或 升级一张卡（二选一）。done 回调交还控制权回地图。

const CREAM := Color(0.984, 0.953, 0.894)
const GREEN := Color(0.365, 0.792, 0.647)
const TEXT_COLOR := Color("F2E8D5")
const RED := Color(0.847, 0.353, 0.188)
const PURPLE := Color(0.498, 0.467, 0.867)
const BG_DARK := Color(0.12, 0.10, 0.09)

var on_done: Callable = Callable()
var _upgrade_picker: CanvasLayer

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
		_apply_relic_restriction(rest_button, &"no_rest_heal", "长明炉芯：无法休息回血")
		if not rest_button.pressed.is_connected(_on_rest.bind(heal_amt)):
			rest_button.pressed.connect(_on_rest.bind(heal_amt))
		var forge_button: Button = scene_panel.get_node("Content/ForgeButton")
		_apply_relic_restriction(forge_button, &"no_rest_upgrade", "封釉重锤：无法锻造升级")
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

	v.add_child(_label("休 息 点", 40, TEXT_COLOR))

	v.add_child(_label("炉火尚温，稍作休整。", 24, TEXT_COLOR))

	var rest_btn := Button.new()
	rest_btn.text = "休息（恢复 %d 生命）" % heal_amt
	rest_btn.custom_minimum_size = Vector2(560, 80)
	rest_btn.add_theme_font_size_override("font_size", 26)
	rest_btn.pressed.connect(_on_rest.bind(heal_amt))
	_apply_relic_restriction(rest_btn, &"no_rest_heal", "长明炉芯：无法休息回血")
	v.add_child(rest_btn)

	var forge_btn := Button.new()
	forge_btn.text = "锻造（升级一张卡）"
	forge_btn.custom_minimum_size = Vector2(560, 80)
	forge_btn.add_theme_font_size_override("font_size", 26)
	forge_btn.pressed.connect(_on_forge)
	_apply_relic_restriction(forge_btn, &"no_rest_upgrade", "封釉重锤：无法锻造升级")
	v.add_child(forge_btn)

	var leave_btn := Button.new()
	leave_btn.text = "离开"
	leave_btn.custom_minimum_size = Vector2(560, 64)
	leave_btn.add_theme_font_size_override("font_size", 22)
	leave_btn.pressed.connect(_finish)
	v.add_child(leave_btn)


func _on_rest(heal_amt: int) -> void:
	if not can_interact() or RunState.has_relic_drawback(&"no_rest_heal"):
		return
	RunState.heal(heal_amt)
	# 补陶泥遗物：休息额外回血
	for rid in RunState.relic_ids:
		var r: RelicData = GameData.get_relic(rid)
		if r != null and r.effect == &"heal_bonus":
			RunState.heal(r.value)
	_log("休息恢复 %d 生命（HP %d/%d）" % [heal_amt, RunState.hp, RunState.max_hp])
	_finish()


func _on_forge() -> void:
	if not can_interact() or RunState.has_relic_drawback(&"no_rest_upgrade"):
		return
	_build_forge()


func _build_forge() -> void:
	if not can_interact() or RunState.has_relic_drawback(&"no_rest_upgrade") or is_instance_valid(_upgrade_picker): return
	_upgrade_picker = preload("res://scripts/ui/CardUpgradePicker.gd").new()
	_upgrade_picker.confirmed.connect(_on_upgrade_card)
	add_child(_upgrade_picker)


func _on_upgrade_card(i: int, snapshot: Dictionary = {}) -> void:
	if not can_interact() or RunState.has_relic_drawback(&"no_rest_upgrade"):
		return
	if not snapshot.is_empty() and (i < 0 or i >= RunState.deck.size() or RunState.deck[i] != snapshot):
		return
	if RunState.upgrade_card_at(i):
		_log("卡牌已升级")
		_finish()


func _finish() -> void:
	if not can_interact() or not is_inside_tree():
		return
	_finish_transition(on_done)


func _apply_relic_restriction(button: Button, kind: StringName, reason: String) -> void:
	button.disabled = RunState.has_relic_drawback(kind)
	button.tooltip_text = reason if button.disabled else ""
	if button.disabled: button.text = reason


func _log(msg: String) -> void:
	print("[Rest] " + msg)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
