extends Panel
class_name EnemyPanel
## EnemyPanel —— 敌人战斗面板（可视化子场景）。
## 由 CombatUI 用 preload("res://scenes/combat/EnemyPanel.tscn").instantiate() 创建，
## 再调用 build(e, index, selected, enemy_count) 填充动态内容。
## 固定节点结构（IntentBar/SpriteRect/NameLabel/BlockShield/HpBar/StatusBar）定义在
## EnemyPanel.tscn 中，可直接在 Godot 编辑器可视化拖拽调位置/字号/配色，无需改代码。
##
## 注意：面板尺寸（随敌人数变化）仍由 CombatUI 设置；本组件只负责填充内容。

const CREAM := Color(0.984, 0.953, 0.894)
const GREEN := Color(0.365, 0.792, 0.647)
const RED := Color(0.847, 0.353, 0.188)
const HILITE := Color(1.0, 0.92, 0.65)

@onready var _intent_bar = $Inner/IntentBar
@onready var _sprite: TextureRect = $Inner/SpriteRect
@onready var _name_l: Label = $Inner/NameLabel
@onready var _block_l: Label = $Inner/BlockShield/BlockText
@onready var _hp_bar: ProgressBar = $Inner/HpBar
@onready var _status_bar = $Inner/StatusBar

var _index: int = -1


## 填充动态内容。enemy_count 用于收紧多怪时的血条字号，避免窄栏裁切数值。
func build(e: CombatUnit, index: int, selected: bool, enemy_count: int, controller: CombatController = null) -> void:
	_index = index
	_intent_bar.set_unit(e, controller, _format_intent(e, controller))
	var ed := e.data as EnemyData
	if ed != null:
		var tex := ed.sprite_texture(StringName(e.intent.get("id", "")))
		if tex != null:
			_sprite.texture = tex
	_sprite.custom_minimum_size = Vector2.ZERO
	var hp_text: Label = $Inner/HpText
	hp_text.text = "HP %d/%d" % [e.hp, e.max_hp]
	hp_text.add_theme_font_size_override("font_size", 21 if enemy_count <= 1 else (18 if enemy_count == 2 else 16))
	_name_l.text = e.unit_name + ("  ◀" if selected else "")
	_hp_bar.max_value = e.max_hp
	_hp_bar.value = e.hp
	_block_l.text = "%d" % e.block
	_status_bar.set_unit(e)
	_layout_statuses()
	_layout_statuses.call_deferred()
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
		if rel.get("intent", "") in ["attack", "aoe_debuff"] and e.data != null:
			rel_val = GameData.scaled_enemy_damage(rel_val, e.data.tier)
			if controller != null:
				rel_val = controller.enemy_outgoing(e, rel_val)
		var rel_times: int = int(rel.get("times", 1))
		var t := "蓄力→%s %d" % [rel_kind, rel_val]
		if rel_times > 1:
			t += " ×%d" % rel_times
		return t
	var val: int = int(e.intent.get("value", 0))
	if kind in ["attack", "aoe_debuff"] and controller != null:
		val = controller.enemy_outgoing(e, val)
	var times: int = int(e.intent.get("times", 1))
	var t := "%s %d" % [_intent_cn(kind), val]
	if times > 1:
		t += " ×%d" % times
	var gold_steal := int(e.intent.get("gold_steal", 0))
	if gold_steal > 0:
		t += " · 抢 %d 金币" % gold_steal
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
		var value := GameData.scaled_enemy_damage(int(release.get("value", 0)), ed.tier)
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


func _ready() -> void:
	resized.connect(_layout_statuses)
	_intent_bar.resized.connect(_layout_statuses)

func _layout_statuses() -> void:
	if not is_instance_valid(_status_bar):
		return
	var status_height: float = _status_bar.content_height(maxf(1.0, size.x - 16.0)) if _status_bar.visible else 0.0
	_status_bar.offset_top = 568.0 - status_height
	_status_bar.offset_bottom = 568.0
	_sprite.offset_bottom = _status_bar.offset_top - 6.0 if status_height > 0.0 else 574.0
	_sprite.offset_top = maxf(202.0, _intent_bar.offset_top + _intent_bar.size.y + 6.0)
