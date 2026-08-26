class_name MapNode
extends RefCounted
## 地图节点：某一层的一个可选节点。
## 包含类型、敌人编成、指向下一层节点的连接（索引）。
## 纯数据承载，后续可序列化进存档。

var floor: int = 0
var index: int = 0
var type: StringName = &"combat"
var enemy_ids: Array = []
var links: Array[int] = []      # 指向下一层节点的 index
var visited: bool = false


func _to_string() -> String:
	return "MapNode[f%d i%d %s]" % [floor, index, type]


func is_combat_like() -> bool:
	return type == &"combat" or type == &"elite" or type == &"boss"
