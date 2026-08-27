extends Panel
class_name CardView
## CardView —— 手牌中的单张卡（替代旧 Button）。自管指针，区分「拖拽」与「轻点」。
## 拖拽超过阈值进入 DRAGGING，广播 drag_started / drag_moved / drag_ended；
## 未达阈值松手视为轻点，广播 tapped。
## 自管指针，区分「拖拽」与「轻点」；由 CombatUI 直接 new() 并 build_visual()。
##
## ghost 模式：用于拖拽时跟随指针的半透明卡，不参与任何输入。
## 信号统一以 CardView 为类型，与 CombatUI 的 handler 契约一致。

signal drag_started(view: CardView)
signal drag_moved(view: CardView, global_pos: Vector2)
signal drag_ended(view: CardView, global_pos: Vector2)
signal tapped(view: CardView)

const DRAG_THRESHOLD := 14.0

var card_index: int = -1
var card_data: CardData
var enchants: Array = []

var _pressing := false
var _dragging := false
var _enabled := true
var _playable := true
var _ghost := false
var _start_global := Vector2.ZERO

# ---- 配色（与 CombatUI 保持一致）----
const CREAM := Color(0.984, 0.953, 0.894)
const ORANGE := Color(0.941, 0.600, 0.482)
const GREEN := Color(0.365, 0.792, 0.647)
const DARK := Color(0.18, 0.15, 0.13)
const PURPLE := Color(0.498, 0.467, 0.867)


func _ready() -> void:
	if _ghost:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_gui_input)


## 由 CombatUI 调用，填充卡面视觉与索引。ghost 卡传 idx=-1。
func build_visual(cd: CardData, idx: int, ench: Array) -> void:
	card_data = cd
	card_index = idx
	enchants = ench
	custom_minimum_size = Vector2(120, 180)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var body := ORANGE if cd.type == &"attack" else GREEN
	var style := _card_style(body)
	if not enchants.is_empty():
		style = _framed_card_style(body, _enchant_frame_color(enchants))
	add_theme_stylebox_override("panel", style)

	var txt := "%s\n[%d能]\n%s" % [cd.name, cd.cost, cd.get_description(false)]
	var badge := _enchant_badge_text(enchants)
	if badge != "":
		txt += "\n" + badge
	# 即时取子节点（不依赖 @onready 时机：build_visual 可能在 add_child 之前被调用）
	var body_l: Label = $Body
	body_l.text = txt

	var enchant_icon: TextureRect = $EnchantIcon
	if not enchants.is_empty():
		var eid: StringName = enchants[0]
		var ed: EnchantData = GameData.get_enchant(eid)
		if ed != null and ed.icon != "":
			enchant_icon.texture = GameData.icon_texture(ed.icon)
		enchant_icon.visible = true
	else:
		enchant_icon.visible = false


func set_ghost(v: bool) -> void:
	_ghost = v
	if _ghost:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_enabled(v: bool) -> void:
	_enabled = v
	if _ghost:
		return
	if _enabled:
		mouse_filter = Control.MOUSE_FILTER_STOP
		modulate.a = 1.0 if _playable else 0.65
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		modulate.a = 0.4
		_pressing = false
		_dragging = false


## 能量不足只禁出牌，不能禁拖拽弃牌。
func set_playable(v: bool) -> void:
	_playable = v
	tooltip_text = "" if v else "能量不足，仍可拖到弃牌堆弃置"
	set_enabled(_enabled)


## 全局接收移动/松手，使用事件坐标（兼容触摸模拟鼠标及输入回放）。
## _input 的位置是视口坐标；转为 canvas 全局坐标后与落点层一致。
func _input(ev: InputEvent) -> void:
	if not _enabled or not _pressing:
		return
	if ev is InputEventMouseMotion:
		_update_drag_position(get_canvas_transform().affine_inverse() * ev.position)
		if _dragging:
			get_viewport().set_input_as_handled()
	elif _dragging and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		_pressing = false
		_dragging = false
		drag_ended.emit(self, get_canvas_transform().affine_inverse() * ev.position)
		get_viewport().set_input_as_handled()


func _on_gui_input(ev: InputEvent) -> void:
	if not _enabled:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressing = true
			_dragging = false
			_start_global = get_global_transform() * mb.position
			get_viewport().set_input_as_handled()
		else:
			if _pressing:
				_pressing = false
				if _dragging:
					_dragging = false
					drag_ended.emit(self, get_global_transform() * mb.position)
				else:
					tapped.emit(self)
				get_viewport().set_input_as_handled()


func _update_drag_position(g: Vector2) -> void:
	if not _dragging:
		if g.distance_to(_start_global) >= DRAG_THRESHOLD:
			_dragging = true
			drag_started.emit(self)
	if _dragging:
		drag_moved.emit(self, g)


# ---- 卡面样式（与 CombatUI 同款，避免跨文件依赖）----
func _card_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	return s


func _framed_card_style(body: Color, frame: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = body
	s.border_color = frame
	s.set_border_width_all(4)
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	return s


func _enchant_frame_color(ench: Array) -> Color:
	for eid in ench:
		var ed: EnchantData = GameData.get_enchant(StringName(eid))
		if ed == null:
			continue
		match ed.rarity:
			&"rare": return PURPLE
			&"uncommon": return GREEN
			_: return CREAM
	return CREAM


static func _enchant_badge_text(ench: Array) -> String:
	var names: PackedStringArray = []
	for eid in ench:
		var ed: EnchantData = GameData.get_enchant(StringName(eid))
		if ed != null:
			names.append("✦ " + ed.name)
		elif eid != null and eid != &"":
			names.append("✦ " + String(eid))
	return "  ".join(names)
