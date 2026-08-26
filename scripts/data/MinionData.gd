class_name MinionData
extends Resource
## 随从（召唤物）数据。复用敌人意图 schema（moves: intent/value/chance/times/status）。
## 与 EnemyData 区别：额外有 lifetime（以玩家回合计的存活回合）。

@export var id: StringName = &""
@export var name: String = ""
@export var hp: int = 10
@export var block: int = 0
@export var lifetime: int = 3
@export var ai: StringName = &"fixed"      # v1 仅 fixed（循环 moves）
@export var sprite: String = ""
@export var tier: StringName = &"summon"

## moves: Array[Dictionary] —— {id, intent, value, chance, times?, status?}
## intent ∈ attack / defend / buff / debuff / unknown（复用敌人意图体系）
var moves: Array = []


## 返回 sprite 字段对应的随从立绘纹理；无 sprite 或资源缺失时返回 null。
## 路径约定：res://art/minions/<sprite>.png（素材缺失时 UI 优雅降级为纯文字面板）。
func sprite_texture() -> Texture2D:
	if sprite.is_empty():
		return null
	var p := "res://art/minions/%s.png" % sprite
	var t := load(p)
	if t == null:
		push_warning("MinionData.sprite_texture: failed to load %s for minion %s" % [p, String(id)])
		return null
	return t as Texture2D


static func from_dict(d: Dictionary) -> MinionData:
	var m := MinionData.new()
	m.id = StringName(d.get("id", ""))
	m.name = d.get("name", "")
	m.hp = int(d.get("hp", 10))
	m.block = int(d.get("block", 0))
	m.lifetime = int(d.get("lifetime", 3))
	m.ai = StringName(d.get("ai", "fixed"))
	m.sprite = d.get("sprite", "")
	m.tier = StringName(d.get("tier", "summon"))
	m.moves = d.get("moves", [])
	return m
