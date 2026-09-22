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
signal drag_canceled(view: CardView)
signal tapped(view: CardView)

const DRAG_THRESHOLD := 14.0

var card_index: int = -1
var card_data: CardData
var enchants: Array = []
var entry_snapshot: Dictionary = {}
var upgraded := false
var resolved_cost := 0

var _pressing := false
var _dragging := false
var _enabled := true
var _playable := true
var _ghost := false
var _start_global := Vector2.ZERO
var _hand_scroll: ScrollContainer
var _scrolling_hand := false
var _scroll_origin := 0
var _touch_gesture := false

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
func build_visual(cd: CardData, idx: int, ench: Array, is_upgraded: bool = false, cost_override: int = -999, entry: Dictionary = {}) -> void:
	card_data = cd
	card_index = idx
	enchants = ench
	upgraded = is_upgraded
	resolved_cost = cd.cost if cost_override == -999 else cost_override
	custom_minimum_size = Vector2(136, 212)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	entry_snapshot = entry.duplicate(true)
	entry_snapshot.merge({"id":cd.id,"name":cd.name,"upgraded":upgraded,"cost":resolved_cost,"enchants":ench}, true)
	FormalUI.fill_card_visual(self, entry_snapshot)

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
		_scrolling_hand = false


## 不可出牌时仍允许点击详情；拖拽到任何落点都回弹。
func set_playable(v: bool) -> void:
	_playable = v
	tooltip_text = "" if v else "当前无法打出，点击查看详情"
	set_enabled(_enabled)


## 全局接收移动/松手，使用事件坐标（兼容触摸模拟鼠标及输入回放）。
## _input 的位置是视口坐标；转为 canvas 全局坐标后与落点层一致。
func _input(ev: InputEvent) -> void:
	if not _enabled or not _pressing:
		return
	if (ev is InputEventScreenTouch or ev is InputEventMouseButton) and ev.canceled:
		var was_dragging := _dragging
		_pressing = false
		_dragging = false
		_scrolling_hand = false
		if was_dragging: drag_canceled.emit(self)
		return
	if ev is InputEventMouseMotion:
		var point: Vector2 = get_canvas_transform().affine_inverse() * ev.position
		var delta: Vector2 = point - _start_global
		if not _dragging and not _scrolling_hand and _touch_gesture and is_instance_valid(_hand_scroll):
			var bar := _hand_scroll.get_h_scroll_bar()
			if bar.max_value > bar.page and delta.length() >= DRAG_THRESHOLD and absf(delta.x) > absf(delta.y):
				_scrolling_hand = true
		if _scrolling_hand:
			_hand_scroll.scroll_horizontal = _scroll_origin - roundi(delta.x)
		else:
			_update_drag_position(point)
		if _dragging or _scrolling_hand:
			get_viewport().set_input_as_handled()
	elif (_dragging or _scrolling_hand) and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		_pressing = false
		var was_scrolling := _scrolling_hand
		_scrolling_hand = false
		_dragging = false
		# Submission can synchronously remove this card from the scene tree.
		get_viewport().set_input_as_handled()
		if not was_scrolling:
			drag_ended.emit(self, get_canvas_transform().affine_inverse() * ev.position)


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
			_scrolling_hand = false
			_touch_gesture = DisplayServer.is_touchscreen_available()
			_hand_scroll = MobileScroll.parent_scroll(self)
			_scroll_origin = _hand_scroll.scroll_horizontal if _hand_scroll != null else 0
			_start_global = get_global_transform() * mb.position
			get_viewport().set_input_as_handled()
		else:
			if _pressing:
				_pressing = false
				get_viewport().set_input_as_handled()
				if _dragging:
					_dragging = false
					drag_ended.emit(self, get_global_transform() * mb.position)
				else:
					tapped.emit(self)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_PAUSED]:
		var was_dragging := _dragging
		_pressing = false
		_dragging = false
		_scrolling_hand = false
		if was_dragging:
			drag_canceled.emit(self)


func _update_drag_position(g: Vector2) -> void:
	if not _dragging:
		if g.distance_to(_start_global) >= DRAG_THRESHOLD:
			_dragging = true
			drag_started.emit(self)
	if _dragging:
		drag_moved.emit(self, g)


# ---- 卡面样式（与 CombatUI 同款，避免跨文件依赖）----
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
