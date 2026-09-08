extends Panel
class_name AllyPanel
## AllyPanel —— 友方随从战斗 chip（可视化子场景）。
## 由 CombatUI 用 preload("res://scenes/combat/AllyPanel.tscn").instantiate() 创建，
## 再调用 build(a, index) 填充动态内容。
## 固定节点结构（Inner/VBox + 各 Label/TextureRect/ProgressBar）定义在 AllyPanel.tscn 中，
## 可直接在 Godot 编辑器可视化拖拽调位置/字号/配色，无需改代码。
##
## 面板底色/尺寸/定位/入场与行动动画由 CombatUI 负责（见 _create_ally_panel 等）。

const CREAM := Color(0.984, 0.953, 0.894)
const GREEN := Color(0.365, 0.792, 0.647)
const RED := Color(0.847, 0.353, 0.188)
const HILITE := Color(1.0, 0.92, 0.65)
const PURPLE := Color(0.498, 0.467, 0.867)
const CYAN := Color(0.40, 0.80, 0.95)

@onready var _intent_l: Label = $Inner/IntentLabel
@onready var _sprite: TextureRect = $Inner/SpriteRect
@onready var _name_l: Label = $Inner/NameLabel
@onready var _hp_bar: ProgressBar = $Inner/HpBar
@onready var _hpblk_l: Label = $Inner/HpBlockLabel
@onready var _life_l: Label = $Inner/LifetimeLabel
@onready var _status_l: Label = $Inner/StatusLabel

var _index: int = -1


func build(a: CombatUnit, index: int) -> void:
	_index = index
	_intent_l.text = _format_ally_intent(a)
	var md := a.data as MinionData
	if md != null:
		var tex := md.sprite_texture()
		if tex != null:
			_sprite.texture = tex
	_name_l.text = a.unit_name
	_hp_bar.max_value = a.max_hp
	_hp_bar.value = a.hp
	_hpblk_l.text = "HP %d/%d  格 %d" % [a.hp, a.max_hp, a.block]
	_life_l.text = "寿命 %d" % a.lifetime
	var st := _status_text(a)
	_status_l.text = st
	_status_l.visible = not st.is_empty()


func _format_ally_intent(a: CombatUnit) -> String:
	var kind: String = a.intent.get("intent", "未知")
	var val: int = int(a.intent.get("value", 0))
	var times: int = int(a.intent.get("times", 1))
	var t := "%s %d" % [_intent_cn(kind), val]
	if times > 1:
		t += " ×%d" % times
	return t


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
