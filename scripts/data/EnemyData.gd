class_name EnemyData
extends Resource
## 敌人数据。HP / 伤害的难度系数由 BalanceConfig 施加，不写死在此。

@export var id: StringName = &""
@export var name: String = ""
@export var tier: StringName = &"normal"   # normal / elite / boss
@export var base_hp: int = 10
@export var ai: StringName = &"weighted_random"
@export var sprite: String = ""
@export var description: String = ""
@export var combat_hint: String = ""
## scripted_cycle：首招以及 moves 内的 next / on_block_break 构成数据驱动循环。
@export var first_move: StringName = &""

## moves: Array[Dictionary] —— {id, intent, value, chance, times?, status?}
## intent ∈ attack / defend / buff / debuff / unknown
var moves: Array = []
## phases: Boss 分阶段脚本（可空）
var phases: Array = []


static func from_dict(d: Dictionary) -> EnemyData:
	var e := EnemyData.new()
	e.id = StringName(d.get("id", ""))
	e.name = d.get("name", "")
	e.tier = StringName(d.get("tier", "normal"))
	e.base_hp = int(d.get("hp", 10))
	e.ai = StringName(d.get("ai", "weighted_random"))
	e.sprite = d.get("sprite", "")
	e.description = d.get("description", "")
	e.combat_hint = d.get("combat_hint", "")
	e.first_move = StringName(d.get("first_move", ""))
	e.moves = d.get("moves", [])
	e.phases = d.get("phases", [])
	return e


func is_boss() -> bool:
	return tier == &"boss"


func is_elite() -> bool:
	return tier == &"elite"

## 返回 sprite 字段对应的敌人立绘纹理；无 sprite 或资源缺失时返回 null。
## 路径约定：res://art/enemies/<sprite>.png
func sprite_texture() -> Texture2D:
	if sprite.is_empty():
		return null
	var p := "res://art/enemies/%s.png" % sprite
	var t := load(p)
	if t == null:
		push_warning("EnemyData.sprite_texture: failed to load %s for enemy %s" % [p, String(id)])
		return null
	return t as Texture2D


## 在 moves 与所有 phases 的 moves 中按 id 查找 move。
## charge/telegraph 的「释放招式」用 next 指向它；UI 也要据此显示预告。
func find_move(mid: StringName) -> Dictionary:
	for m in moves:
		if StringName(m.get("id", "")) == mid:
			return m
	for ph in phases:
		for m in ph.get("moves", []):
			if StringName(m.get("id", "")) == mid:
				return m
	return {}


func cycle_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if ai != &"scripted_cycle":
		return errors
	if first_move == &"" or find_move(first_move).is_empty():
		errors.append("首招不存在")
	var ids: Dictionary = {}
	for mv in moves:
		var mid := StringName(mv.get("id", ""))
		if mid == &"" or ids.has(mid):
			errors.append("招式 id 为空或重复：%s" % mid)
		ids[mid] = true
		var nx := StringName(mv.get("next", ""))
		if nx == &"" or find_move(nx).is_empty():
			errors.append("招式 %s 的 next 不存在" % mid)
		var br := StringName(mv.get("on_block_break", ""))
		if br != &"":
			if find_move(br).is_empty():
				errors.append("招式 %s 的破封分支不存在" % mid)
			if mv.get("intent", "") != "charge" or int(mv.get("value", 0)) <= 0:
				errors.append("破封窗口必须由正格挡蓄力招式开启：%s" % mid)
	return errors
