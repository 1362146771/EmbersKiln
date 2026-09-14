class_name EnemyData
extends Resource
## 敌人数据。HP / 伤害的难度系数由 BalanceConfig 施加，不写死在此。

@export var id: StringName = &""
@export var name: String = ""
@export var tier: StringName = &"normal"   # normal / elite / boss
@export var base_hp: int = 10
@export var ai: StringName = &"weighted_random"
@export var sprite: String = ""
## 可选：招式 id -> 完整立绘路径；未配置的状态回退到默认 sprite。
@export var state_sprites: Dictionary = {}
var _sprite_cache: Dictionary = {}
@export var map_icon: String = ""
@export var description: String = ""
@export var combat_hint: String = ""
## 普通战组队元数据：strong / medium / weak；精英与 Boss 为 solo_only。
@export var encounter_class: StringName = &""
## 目标敌人数 -> 被选入该规模战斗的权重。键使用 JSON 字符串 "1" / "2" / "3"。
var encounter_weights: Dictionary = {}
## 同一个敌人 id 在一场普通战中的最多副本数。
@export var max_copies_per_encounter: int = 0
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
	e.state_sprites = d.get("state_sprites", {}).duplicate(true)
	e.map_icon = d.get("map_icon", "")
	e.description = d.get("description", "")
	e.combat_hint = d.get("combat_hint", "")
	e.encounter_class = StringName(d.get("encounter_class", ""))
	e.encounter_weights = d.get("encounter_weights", {}).duplicate(true)
	e.max_copies_per_encounter = int(d.get("max_copies_per_encounter", 0))
	e.first_move = StringName(d.get("first_move", ""))
	e.moves = d.get("moves", [])
	e.phases = d.get("phases", [])
	return e


func is_boss() -> bool:
	return tier == &"boss"


func is_elite() -> bool:
	return tier == &"elite"


func encounter_weight(enemy_count: int) -> float:
	return float(encounter_weights.get(str(enemy_count), 0.0))

## 传入招式 id 时优先返回状态立绘，否则使用默认 sprite。
## 缺失状态图回退默认图；默认 sprite 为空或资源缺失时返回 null。
## 路径约定：res://art/enemies/<sprite>.png
func sprite_texture(move_id: StringName = &"") -> Texture2D:
	var state_path: String = state_sprites.get(String(move_id), "")
	if not state_path.is_empty():
		if _sprite_cache.has(state_path):
			return _sprite_cache[state_path]
		if ResourceLoader.exists(state_path):
			var state_texture := load(state_path) as Texture2D
			if state_texture != null:
				_sprite_cache[state_path] = state_texture
				return state_texture
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
