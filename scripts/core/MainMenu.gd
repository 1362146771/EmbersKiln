extends Control
## 单一游戏入口：进行中的单局显示继续，否则显示开始。
## 永久窑口镇档案始终保留；开始游戏不重置养成。

const TOWN_SCENE := "res://scenes/town/Town.tscn"
const COMBAT_SCENE := "res://scenes/combat/CombatPlay.tscn"
const CARD_COMPENDIUM := preload("res://scenes/ui/CardCompendium.tscn")

@onready var play_button: Button = %PlayButton


func _ready() -> void:
	if PauseManager != null:
		PauseManager.hide_pause_button()
	play_button.text = "继续游戏" if SaveManager.has_active_save() else "开始游戏"
	play_button.pressed.connect(_on_play)
	%CompendiumButton.pressed.connect(_on_compendium)
	%QuitButton.pressed.connect(_on_quit)


func _on_play() -> void:
	# 点击时重新检查，避免菜单打开后存档状态变化导致覆盖有效进度。
	var destination := _continue_destination() if SaveManager.has_active_save() else _start_destination()
	if not destination.is_empty():
		get_tree().change_scene_to_file(destination)


func _start_destination() -> String:
	# 只在无进行中的单局时进入；绝不清除永久城镇档案。
	RunState.is_active = false
	RunState.clear_combat_checkpoint()
	RunState.pending_combat_enemy_ids.clear()
	if ProfileState.first_battle_started:
		return TOWN_SCENE
	if not RunState.start_new_run():
		return ""
	RunState.pre_run_preparation_resolved = true
	var map := RunState.current_map()
	if map.is_empty() or map[0].is_empty():
		return ""
	var first_node = map[0][0]
	if not first_node.is_combat_like() or first_node.enemy_ids.is_empty():
		push_error("首个地图节点必须配置为战斗")
		return ""
	first_node.visited = true
	RunState.current_floor = first_node.floor
	RunState.current_node_type = first_node.type
	if not RunState.create_combat_checkpoint(first_node.enemy_ids) or not SaveManager.save_game():
		return ""
	ProfileState.first_battle_started = true
	SignalBus.profile_changed.emit()
	return COMBAT_SCENE


func _continue_destination() -> String:
	if SaveManager.has_save() and SaveManager.load_game():
		ProfileState.first_battle_started = true
		SignalBus.profile_changed.emit()
		if RunState.is_active and RunState.has_combat_checkpoint():
			if RunState.restore_combat_checkpoint():
				SaveManager.save_game()
				return COMBAT_SCENE
		return TOWN_SCENE
	# 仅有永久档案（例如刚战败）也能继续回镇；坏档不自动创建新局。
	RunState.is_active = false
	RunState.clear_combat_checkpoint()
	RunState.pending_combat_enemy_ids.clear()
	return TOWN_SCENE


func _on_quit() -> void:
	get_tree().quit()


func _on_compendium() -> void:
	add_child(CARD_COMPENDIUM.instantiate())
