extends Control
## 主菜单（P4 退出UI）：新游戏 / 继续游戏 / 退出游戏。
## 启动时检测 SaveManager.has_save() 决定「继续游戏」是否可用。

const MAP_PLAY := "res://scenes/map/MapPlay.tscn"
const TOWN_SCENE := "res://scenes/town/Town.tscn"
const PRE_RUN_PREPARATION := "res://scenes/main/PreRunPreparation.tscn"

@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	if PauseManager != null:
		PauseManager.hide_pause_button()
	continue_button.disabled = not SaveManager.has_save()
	continue_button.tooltip_text = "暂无存档" if continue_button.disabled else ""
	%NewGameButton.pressed.connect(_on_new_game)
	continue_button.pressed.connect(_on_continue)
	%TownButton.pressed.connect(_on_town)
	%QuitButton.pressed.connect(_on_quit)


func _on_new_game() -> void:
	# 新游戏：清掉旧存档，避免误续玩上一局
	if SaveManager.has_save():
		SaveManager.delete_save()
	if RunState.start_new_run():
		PreRunBuffSystem.prepare_offer()
		get_tree().change_scene_to_file(PRE_RUN_PREPARATION if PreRunBuffSystem.needs_preparation() else MAP_PLAY)


func _on_continue() -> void:
	if not SaveManager.has_save():
		return
	if not SaveManager.load_game():
		# 读档失败则退回到新游戏
		RunState.start_new_run()
	if not RunState.pre_run_preparation_resolved:
		PreRunBuffSystem.prepare_offer()
	get_tree().change_scene_to_file(PRE_RUN_PREPARATION if PreRunBuffSystem.needs_preparation() else MAP_PLAY)


func _on_quit() -> void:
	get_tree().quit()


func _on_town() -> void:
	get_tree().change_scene_to_file(TOWN_SCENE)
