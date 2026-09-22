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
signal portrait_layout_changed
var portrait_area := Rect2()


## 填充动态内容。enemy_count 用于收紧多怪时的血条字号，避免窄栏裁切数值。
func build(e: CombatUnit, index: int, selected: bool, enemy_count: int, controller: CombatController = null) -> void:
	_index = index
	_intent_bar.set_unit(e, controller, _format_intent(e, controller))
	var ed := e.data as EnemyData
	if ed != null:
		var tex := ed.sprite_texture(StringName(e.intent.get("id", "")))
		if tex != null:
			_sprite.texture = tex
		_sprite.configure(ed.id)
	_sprite.custom_minimum_size = Vector2.ZERO
	var hp_text: Label = $Inner/HpText
	update_vitals(e.hp, e.max_hp, e.block)
	hp_text.add_theme_font_size_override("font_size", 21 if enemy_count <= 1 else (18 if enemy_count == 2 else 16))
	_name_l.text = e.unit_name + ("  ◀" if selected else "")
	_name_l.tooltip_text = ed.combat_hint if ed != null else ""
	if ed != null and ed.ai == &"phased_cycle":
		_name_l.text += " · 阶段%d" % (e.phase_index + 1)
		_name_l.tooltip_text = ed.combat_hint
	_status_bar.set_unit(e)
	_layout_statuses()
	_layout_statuses.call_deferred()
	self_modulate = HILITE if selected else Color.WHITE


## 仅更新数值，不重排节点、不重置立绘/受击动画；演出锁内也可安全调用。
func update_vitals(hp: int, max_hp: int, block: int) -> void:
	$Inner/HpText.text = "HP %d/%d" % [hp, max_hp]
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_block_l.text = str(block)


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
			if not e.data.effective_stats and not bool(rel.get("effective_stats", false)):
				rel_val = GameData.scaled_enemy_damage(rel_val, e.data.tier)
			rel_val += DifficultyRules.attack_bonus(e.data.tier, rel)
			if controller != null:
				rel_val = controller.enemy_preview_outgoing(e, rel_val)
		var rel_times: int = int(rel.get("times", 1))
		var t := "蓄力→%s %d" % [rel_kind, rel_val]
		if rel_times > 1:
			t += " ×%d" % rel_times
		return t
	var val: int = int(e.intent.get("value", 0))
	if kind in ["attack", "aoe_debuff"] and controller != null:
		val = controller.enemy_preview_outgoing(e, val)
	var times: int = int(e.intent.get("times", 1))
	var title := _intent_cn(kind)
	if e.data != null and e.data.ai == &"phased_cycle":
		title = String(e.intent.get("name", title))
	var t := "%s %d" % [title, val]
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
		var value := int(release.get("value", 0))
		if not ed.effective_stats and not bool(release.get("effective_stats", false)):
			value = GameData.scaled_enemy_damage(value, ed.tier)
		value += DifficultyRules.attack_bonus(ed.tier, release)
		if controller != null:
			value = controller.enemy_preview_outgoing(e, value)
		return "%s 格挡 %d\n下回合喷火 %d" % [title, int(mv.get("value", 0)), value]
	if kind == "attack":
		var value := int(mv.get("value", 0))
		if controller != null:
			value = controller.enemy_preview_outgoing(e, value)
		var text := "%s %d" % [title, value]
		if int(mv.get("times", 1)) > 1:
			text += " ×%d" % int(mv.times)
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
	_sprite.begin_layout()
	_sprite.anchor_left = 0.0
	_sprite.anchor_right = 1.0
	_sprite.offset_left = 8.0
	_sprite.offset_right = -8.0
	var status_height: float = _status_bar.content_height(maxf(1.0, size.x - 16.0)) if _status_bar.visible else 0.0
	_status_bar.offset_top = 568.0 - status_height
	_status_bar.offset_bottom = 568.0
	_sprite.offset_bottom = _status_bar.offset_top - 6.0 if status_height > 0.0 else 574.0
	_sprite.offset_top = maxf(202.0, _intent_bar.offset_top + _intent_bar.size.y + 6.0)
	# get_rect() includes the active hit transform; layout must use the rest size.
	portrait_area = Rect2(_sprite.position, _sprite.size)
	_sprite.end_layout()
	portrait_layout_changed.emit()


func portrait_top_limit() -> float:
	return _intent_bar.offset_top + _intent_bar.size.y + 6.0


func fit_portrait(cropped: AtlasTexture, fit: float, baseline: float) -> void:
	_sprite.begin_layout()
	_sprite.texture = cropped
	_sprite.sync_hit_texture()
	_sprite.anchor_right = 0.0
	_sprite.size = cropped.get_size() * fit
	_sprite.position = Vector2(portrait_area.get_center().x - _sprite.size.x / 2.0, baseline - _sprite.size.y)
	# Enlarged formations may cross their slots, but remain inside the battlefield.
	var viewport := get_viewport_rect()
	var edge := portrait_area.position.x
	_sprite.position.x = clampf(_sprite.position.x, viewport.position.x + edge - global_position.x, viewport.end.x - edge - global_position.x - _sprite.size.x)
	_sprite.end_layout()
