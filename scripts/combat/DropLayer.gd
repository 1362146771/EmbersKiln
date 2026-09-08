extends Control
class_name DropLayer
## DropLayer —— 落点层：全屏覆盖、MOUSE_FILTER_IGNORE 的 Control。
## 自绘合法落点高亮环（不碰节点 modulate，避免与 selected_target 高亮冲突）。
## 只负责：持目标列表 / 命中测试 / 脉冲高亮。目标由 CombatUI 在每次拖拽开始时 set_targets 注入。
##
## 不写 class_name（避免与可能的 autoload 冲突）。

const C_VALID := Color(0.365, 0.792, 0.647)   # 绿：合法落点
const C_HOVER := Color(1.0, 0.92, 0.65)        # 金：悬停（指针所在落点）
const DISCARD_TARGET := -4                  # 独立于玩家(-1)、无落点(-2)、无悬停(-3)

const ARROW := preload("res://art/ui/formal/effrct_arrow.png")
var arrow_start := Vector2.ZERO
var arrow_end := Vector2.ZERO
var arrow_visible := false

var _targets: Array = []          # [{node:Control, types:Array[StringName], index:int, rect:Rect2}]
var _card_type: StringName = &""  # 当前拖拽卡的 target 类型，用于筛选合法落点
var _hover_index: int = -3        # 当前悬停目标 index（-3=无）


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 300


## 注入本次拖拽的合法落点。target = {node, types:Array[StringName], index:int}
func set_targets(targets: Array) -> void:
	_targets = targets
	_refresh_rects()
	queue_redraw()


func clear() -> void:
	arrow_visible = false
	_targets = []
	_card_type = &""
	_hover_index = -3
	queue_redraw()


## 设定当前卡类型，仅高亮 accept 该类型的落点。
func highlight(card_type: StringName) -> void:
	_card_type = card_type
	queue_redraw()


func _refresh_rects() -> void:
	var origin := get_global_position()
	for t in _targets:
		var n: Control = t.node
		if is_instance_valid(n):
			var g := n.get_global_rect()
			t.rect = Rect2(g.position - origin, g.size)


## 指针移动时更新悬停目标（用于加强高亮）。
func hover_update(global_pos: Vector2) -> void:
	var lp := global_pos - get_global_position()
	_hover_index = -3
	for t in _targets:
		if t.types.has(_card_type) and t.rect.has_point(lp):
			_hover_index = t.index
			break
	queue_redraw()


## 命中测试：返回目标 index（-1=玩家，>=0=敌人，-2=无落点，DISCARD_TARGET=弃牌）。
func hit_test(global_pos: Vector2) -> int:
	var lp := global_pos - get_global_position()
	for t in _targets:
		if not t.types.has(_card_type):
			continue
		if t.rect.has_point(lp):
			return t.index
	return -2


func set_arrow(start: Vector2, end: Vector2) -> void:
	arrow_start = start - global_position
	arrow_end = end - global_position
	arrow_visible = start.distance_to(end) > 40.0
	queue_redraw()


func _draw() -> void:
	if arrow_visible:
		var delta := arrow_end - arrow_start
		var count := maxi(1, int(delta.length() / 42.0))
		for i in range(1, count + 1):
			var point := arrow_start.lerp(arrow_end, float(i) / count)
			# 原图尖端朝左上：扣除贴图自身方向，让尖端沿引导线指向拖动卡牌。
			var texture_forward := Vector2(-33.0 * 44.0 / 113.0, -59.0 * 48.0 / 117.0)
			draw_set_transform(point, delta.angle() - texture_forward.angle(), Vector2.ONE)
			draw_texture_rect(ARROW, Rect2(-22, -24, 44, 48), false)
		draw_set_transform(Vector2.ZERO)
	if _card_type == &"":
		return
	for t in _targets:
		if not t.types.has(_card_type):
			continue
		var is_hover: bool = (t.index == _hover_index)
		var c := C_HOVER if is_hover else C_VALID
		var lw := 7.0 if is_hover else 4.0
		var rect := Rect2(t.rect)
		if t.index == DISCARD_TARGET:
			# 弃牌堆只描边，不用圆环遮住紧邻的手牌。使用 v3 米白/铁灰。
			c = Color("f2e8d5") if is_hover else Color("94826f")
			draw_rect(rect.grow(-2.0), c, false, lw)
			continue
		# 指向箭头承担主要反馈，仅描目标边缘，避免大圆环覆盖整个战场。
		if t.index >= 0:
			rect.position.y += 185.0
			rect.size.y = maxf(0.0, rect.size.y - 195.0)
		draw_rect(rect.grow(-5.0), Color(c, 0.65), false, 2.0)
