class_name TurnManager
extends Node
## 阶段协调器。UI 面向的薄层：持有 phase 状态并向 CombatController 转发玩家意图。
## 不重复战斗规则逻辑，规则全在 CombatController。
## MVP 为同步驱动；后续若需敌人行动带延时/动画，在此插入 await。

var controller: CombatController = null


func _ready() -> void:
	if controller == null:
		controller = get_node_or_null("../CombatController")


func is_player_turn() -> bool:
	if controller == null:
		return false
	return controller.phase == CombatController.Phase.PLAYER


func request_end_turn() -> void:
	if controller != null:
		controller.end_player_turn()


func play_card(hand_index: int, target_index: int = -1) -> bool:
	if controller == null:
		return false
	return controller.play_card(hand_index, target_index)


func current_phase() -> int:
	if controller == null:
		return CombatController.Phase.NONE
	return controller.phase
