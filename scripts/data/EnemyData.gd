class_name EnemyData
extends Resource
## 敌人数据。HP / 伤害的难度系数由 BalanceConfig 施加，不写死在此。

@export var id: StringName = &""
@export var name: String = ""
@export var tier: StringName = &"normal"   # normal / elite / boss
@export var base_hp: int = 10
@export var ai: StringName = &"weighted_random"
@export var sprite: String = ""

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
