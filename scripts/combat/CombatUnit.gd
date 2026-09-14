class_name CombatUnit
extends RefCounted
## 战斗单位模型（玩家与敌人通用）。仅持有本场战斗的瞬时状态：
## 生命、格挡、状态层数、临时意图。不直接读 Autoload，所有数值由调用方注入。
## 伤害修正（力量/虚弱/易伤）由 CombatController 在调用 apply_damage 前计算好，
## 此处只负责「先扣格挡、溢出扣血」的纯逻辑，保持单一职责。

var id: StringName = &""
var unit_name: String = ""
var is_player: bool = false
var data: Variant = null          # 敌人持有 EnemyData；玩家为 null
var sprite: String = ""

var hp: int = 0
var max_hp: int = 0
var block: int = 0

## 状态层数：status_id -> int
var statuses: Dictionary = {}

## 敌人意图：{ id, intent, value, times, status, target, ... }，由 EnemyAI 填充
var intent: Dictionary = {}

## 蓄力招式（charge/telegraph）释放后要强制打出的招式 id。
## 非空时，下一回合 _roll_enemy_intent 会跳过随机、直接打出该招，给玩家决策窗口。
var charge_next: StringName = &""
## 仅由蓄力实际生效开启；由真实伤害耗尽格挡触发，回合自然清盾不触发。
var block_break_next: StringName = &""

## 当前所处阶段索引（仅 Boss 等 scripted_phases 敌人使用，-1 表示尚未初始化）。
## 用于检测阶段切换并触发该阶段的 on_enter（如觉醒自身加力量）。
var phase_index: int = -1

## 本场战斗中由该敌人实际偷走、尚待胜利结算的金币。
var stolen_gold: int = 0
## 当前攻击意图的偷金是否已结算，确保多段攻击只偷一次。
var gold_steal_resolved: bool = false

## 随从（召唤物）专用字段。
var lifetime: int = 0            # 存活剩余回合（玩家回合开始时 -1，≤0 消失）
var move_cursor: int = 0         # fixed AI 循环 moves 的游标（随从意图用）


func setup(p_is_player: bool, p_id: StringName, p_name: String, p_hp: int, p_sprite: String = "") -> void:
	is_player = p_is_player
	id = p_id
	unit_name = p_name
	max_hp = p_hp
	hp = p_hp
	block = 0
	sprite = p_sprite
	statuses.clear()
	# 非伤害意图可能引用 EnemyData 的招式；重置单元不能清空配置字典。
	intent = {}
	charge_next = &""
	block_break_next = &""
	stolen_gold = 0
	gold_steal_resolved = false


# ---------- 生命 / 格挡 ----------
## 应用已经过攻击方/防御方修正后的最终伤害：先扣格挡，溢出扣血。
## 返回实际损失的 HP（用于反馈）。
func apply_damage(final_amount: int) -> int:
	var dmg := maxi(0, final_amount)
	if block > 0:
		var absorbed := mini(block, dmg)
		block -= absorbed
		dmg -= absorbed
	var before := hp
	hp = maxi(0, hp - dmg)
	return before - hp


## 直接扣血（无视格挡，用于燃烧等 DOT）。返回实际损失。
func lose_hp_direct(amount: int) -> int:
	var before := hp
	hp = maxi(0, hp - maxi(0, amount))
	return before - hp


func heal(amount: int) -> int:
	var before := hp
	hp = mini(max_hp, hp + maxi(0, amount))
	return hp - before


func add_block(amount: int) -> void:
	block = maxi(0, block + amount)


func is_alive() -> bool:
	return hp > 0


# ---------- 状态 ----------
func add_status(status_id: StringName, amount: int) -> void:
	var cur := int(statuses.get(status_id, 0))
	cur += amount
	var allows_negative := status_id in [&"heat", &"temper"]
	if cur == 0 or cur < 0 and not allows_negative:
		statuses.erase(status_id)
	else:
		statuses[status_id] = cur


func get_status(status_id: StringName) -> int:
	return int(statuses.get(status_id, 0))


func has_status(status_id: StringName) -> bool:
	return get_status(status_id) != 0 if status_id in [&"heat", &"temper"] else get_status(status_id) > 0


func status_ids() -> Array[StringName]:
	return statuses.keys()
