extends Panel
class_name EnemyPanel
## EnemyPanel —— 敌人战斗面板（可视化子场景）。
## 由 CombatUI 用 preload("res://scenes/combat/EnemyPanel.tscn").instantiate() 创建，
## 再调用 build(e, index, selected, enemy_count) 填充动态内容。
## 固定节点结构（Inner/VBox + IntentLabel/SpriteRect/NameLabel/HpBar/StatusLabel）定义在
## EnemyPanel.tscn 中，可直接在 Godot 编辑器可视化拖拽调位置/字号/配色，无需改代码。
##
## 注意：面板尺寸（随敌人数变化）仍由 CombatUI 设置；本组件只负责填充内容。

const CREAM := Color(0.984, 0.953, 0.894)
const GREEN := Color(0.365, 0.792, 0.647)
const RED := Color(0.847, 0.353, 0.188)
const HILITE := Color(1.0, 0.92, 0.65)

@onready var _intent_l: Label = $Inner/IntentLabel
@onready var _sprite: TextureRect = $Inner/SpriteRect
@onready var _name_l: Label = $Inner/NameLabel
@onready var _hp_bar: ProgressBar = $Inner/HpBar
@onready var _status_l: Label = $Inner/StatusLabel

var _index: int = -1


## 填充动态内容。enemy_count 用于决定立绘尺寸（1 个大、2 个中、3+ 个小）。
func build(e: CombatUnit, index: int, selected: bool, enemy_count: int, controller: CombatController = null) -> void:
	_index = index
	# 单敌面板已收紧高度以容纳顶部遗物栏；图片仍保持原始比例。
	var ic_sz := 280 if enemy_count <= 1 else (300 if enemy_count == 2 else 260)
	_intent_l.text = _format_intent(e, controller)
	var ed := e.data as EnemyData
	if ed != null:
		var tex := ed.sprite_texture()
		if tex != null:
			_sprite.texture = tex
	_sprite.custom_minimum_size = Vector2(ic_sz, ic_sz)
	_name_l.text = e.unit_name + ("  ◀" if selected else "")
	_hp_bar.max_value = e.max_hp
	_hp_bar.value = e.hp
	_status_l.text = "格挡 %d    %s" % [e.block, _status_text(e)]
	if e.block_break_next != &"":
		_status_l.text = "封匣格挡 %d    %s" % [e.block, _status_text(e)]
	self_modulate = HILITE if selected else Color.WHITE


func _format_intent(e: CombatUnit, controller: CombatController = null) -> String:
	var scripted := format_scripted_intent(e, controller)
	if not scripted.is_empty():
		return scripted
	var kind: String = e.intent.get("intent", "未知")
	if kind == "charge":
		var nx := StringName(e.intent.get("next", ""))
		var rel: Dictionary = {}
		if e.data != null:
			rel = e.data.find_move(nx)
		var rel_kind: String = _intent_cn(String(rel.get("intent", "未知")))
		var rel_val: int = int(rel.get("value", 0))
		var rel_times: int = int(rel.get("times", 1))
		var t := "蓄力→%s %d" % [rel_kind, rel_val]
		if rel_times > 1:
			t += " ×%d" % rel_times
		return t
	var val: int = int(e.intent.get("value", 0))
	var times: int = int(e.intent.get("times", 1))
	var t := "%s %d" % [_intent_cn(kind), val]
	if times > 1:
		t += " ×%d" % times
	return t


## 新循环 Boss 的双行提示；复用真实 outgoing 计算，不另写伤害倍率。
static func format_scripted_intent(e: CombatUnit, controller: CombatController = null) -> String:
	var ed := e.data as EnemyData
	if ed == null or ed.ai != &"scripted_cycle":
		return ""
	var mv := e.intent
	var title: String = mv.get("name", mv.get("id", ""))
	var kind: String = mv.get("intent", "unknown")
	if kind == "charge":
		var release := ed.find_move(StringName(mv.get("next", "")))
		var value := GameData.scaled_enemy_damage(int(release.get("value", 0)))
		if controller != null:
			value = controller.enemy_outgoing(e, value)
		return "%s 格挡 %d\n下回合喷火 %d" % [title, int(mv.get("value", 0)), value]
	if kind == "attack":
		var value := int(mv.get("value", 0))
		if controller != null:
			value = controller.enemy_outgoing(e, value)
		var text := "%s %d" % [title, value]
		if e.block_break_next != &"":
			text += "\n打掉格挡可打断"
		return text
	return "%s · 不攻击" % title


func _intent_cn(kind: String) -> String:
	match kind:
		"attack": return "攻击"
		"defend": return "防御"
		"buff": return "增益"
		"debuff": return "减益"
		"charge": return "蓄力"
		_: return kind


func _status_text(unit: CombatUnit) -> String:
	var parts: PackedStringArray = []
	for sid in unit.status_ids():
		var sd: StatusData = GameData.get_status(sid)
		var nm := sd.name if sd != null else String(sid)
		parts.append("%s %d" % [nm, unit.get_status(sid)])
	return "  ".join(parts)
