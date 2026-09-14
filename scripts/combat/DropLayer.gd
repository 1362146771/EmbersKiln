extends Control
class_name DropLayer
## DropLayer —— 落点层：全屏覆盖、MOUSE_FILTER_IGNORE 的 Control。
## 只负责：目标列表 / 命中测试 / 指向箭头 / 弃牌堆高亮。
## 人物和敌人仅在合法悬停时沿透明图片轮廓描白。

const DISCARD_TARGET := -4                  # 独立于玩家(-1)、无落点(-2)、无悬停(-3)

const ARROW := preload("res://art/ui/formal/effrct_arrow.png")
const OUTLINE := preload("res://art/ui/formal/TargetOutline.gdshader")
var _outlined_portrait: TextureRect
var _previous_material: Material
var _outline_material: ShaderMaterial
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
	_clear_outline()
	_targets = targets
	_refresh_rects()
	queue_redraw()


func clear() -> void:
	_clear_outline()
	arrow_visible = false
	_targets = []
	_card_type = &""
	_hover_index = -3
	queue_redraw()


## 设定当前卡类型，用于合法落点判定和弃牌堆高亮。
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
	_update_outline()
	queue_redraw()


func _update_outline() -> void:
	var portrait: TextureRect
	for t in _targets:
		if t.index == _hover_index and t.index != DISCARD_TARGET and t.types.has(_card_type):
			portrait = t.get("outline_node", t.node) as TextureRect
			break
	if portrait == _outlined_portrait:
		return
	_clear_outline()
	if is_instance_valid(portrait):
		if _outline_material == null:
			_outline_material = ShaderMaterial.new()
			_outline_material.shader = OUTLINE
		_outlined_portrait = portrait
		_previous_material = portrait.material
		portrait.material = _outline_material


func _clear_outline() -> void:
	if is_instance_valid(_outlined_portrait) and _outlined_portrait.material == _outline_material:
		_outlined_portrait.material = _previous_material
	_outlined_portrait = null
	_previous_material = null


func _exit_tree() -> void:
	_clear_outline()


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
		if t.index != DISCARD_TARGET or not t.types.has(_card_type):
			continue
		var is_hover: bool = (t.index == _hover_index)
		var c := Color("f2e8d5") if is_hover else Color("94826f")
		var lw := 7.0 if is_hover else 4.0
		var rect := Rect2(t.rect)
		# 弃牌堆只描边，不用圆环遮住紧邻的手牌。使用 v3 米白/铁灰。
		draw_rect(rect.grow(-2.0), c, false, lw)
