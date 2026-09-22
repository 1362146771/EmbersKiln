extends Control
## 单一游戏入口：进行中的单局显示继续，否则显示开始。
## 永久窑口镇档案始终保留；开始游戏不重置养成。

const TOWN_SCENE := "res://scenes/town/Town.tscn"
const COMBAT_SCENE := "res://scenes/combat/CombatPlay.tscn"
const PREPARATION_SCENE := "res://scenes/main/PreRunPreparation.tscn"
const CARD_COMPENDIUM := preload("res://scenes/ui/CardCompendium.tscn")

@onready var play_button: Button = %PlayButton
var _menu_busy := false
var _settings_popup: CanvasLayer


func _ready() -> void:
	if PauseManager != null:
		PauseManager.hide_pause_button()
	play_button.text = "继续游戏" if SaveManager.has_active_save() else "开始游戏"
	play_button.pressed.connect(_activate_option.bind(play_button, _on_play))
	%CompendiumButton.pressed.connect(_activate_option.bind(%CompendiumButton, _on_compendium))
	%QuitButton.pressed.connect(_activate_option.bind(%QuitButton, _on_quit))
	%SettingsButton.pressed.connect(_activate_option.bind(%SettingsButton, _on_settings))


func _on_settings() -> void:
	if is_instance_valid(_settings_popup): return
	_settings_popup = preload("res://scenes/ui/AudioSettingsPopup.tscn").instantiate()
	for option in [play_button, %CompendiumButton, %SettingsButton, %QuitButton]:
		option.disabled = true
	_settings_popup.tree_exited.connect(func():
		for option in [play_button, %CompendiumButton, %SettingsButton, %QuitButton]:
			option.disabled = false
		%SettingsButton.grab_focus.call_deferred())
	add_child(_settings_popup)


func _activate_option(button: Button, action: Callable) -> void:
	if _menu_busy or is_instance_valid(_settings_popup):
		return
	_menu_busy = true
	for option in [play_button, %CompendiumButton, %SettingsButton, %QuitButton]:
		option.feedback_locked = true
	await button.confirm_feedback().finished
	action.call()
	# Keep navigation locked until the scene is replaced; the compendium stays here.
	if TransitionManager.is_transitioning:
		await TransitionManager.transition_finished
	if not is_inside_tree():
		return
	_menu_busy = false
	for option in [play_button, %CompendiumButton, %SettingsButton, %QuitButton]:
		option.reset_feedback()


func _on_play() -> void:
	TransitionManager.change_scene_resolved(_resolve_play_destination)

func _resolve_play_destination() -> String:
	return _continue_destination() if SaveManager.has_active_save() else _start_destination()


func _start_destination() -> String:
	# 只在无进行中的单局时进入；绝不清除永久城镇档案。
	RunState.is_active = false
	RunState.clear_combat_checkpoint()
	RunState.pending_combat_enemy_ids.clear()
	if ProfileState.first_battle_started:
		return TOWN_SCENE
	return PREPARATION_SCENE if RunState.start_new_run_and_save() else ""


func _continue_destination() -> String:
	if SaveManager.has_save() and SaveManager.load_game():
		ProfileState.first_battle_started = true
		SignalBus.profile_changed.emit()
		if RunState.is_active and RunState.has_combat_checkpoint():
			if RunState.restore_combat_checkpoint():
				SaveManager.save_game()
				return COMBAT_SCENE
		if RunState.pending_post_reward or HiddenActFlow.choice_pending():
			return "res://scenes/map/MapPlay.tscn"
		if not RunState.pending_reward_data.is_empty():
			return "res://scenes/rewards/RewardUI.tscn"
		if GrannyStory.needs_opening() or PreRunBuffSystem.needs_preparation():
			return PREPARATION_SCENE
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
