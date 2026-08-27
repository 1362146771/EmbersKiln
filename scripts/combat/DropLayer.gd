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


func _draw() -> void:
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
		var center: Vector2 = rect.get_center()
		var r := minf(rect.size.x, rect.size.y) * 0.55 + 10.0
		# 外环
		draw_arc(center, r, 0.0, TAU, 48, c, lw, true)
		# 矩形描边
		draw_rect(rect.grow(-3.0), c, false, lw)
