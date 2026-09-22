extends Node
## Autoload: PauseManager —— 全局暂停菜单 + 退出（P4 退出UI）。
## 手机端竖屏：全局暂停菜单，支持保存退出与确认后放弃本局。

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
const CARD_COMPENDIUM := preload("res://scenes/ui/CardCompendium.tscn")

var _layer: CanvasLayer
var _btn: Button
var _overlay: Control = null
var _compendium: CardCompendium = null
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 128
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时菜单仍可用
	_layer.name = "PauseLayer"
	add_child(_layer)   # 挂在 autoload 节点下，避免 root 忙碌期 add_child 失败

	_btn = Button.new()
	_btn.text = ""
	_btn.icon = preload("res://art/ui/formal/btn_battle_stop.png")
	_btn.expand_icon = true
	_btn.tooltip_text = "暂停"
	for state in ["normal", "hover", "pressed", "focus"]:
		_btn.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_btn.custom_minimum_size = Vector2(58, 58)
	_btn.add_theme_font_size_override("font_size", 26)
	_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_btn.position = Vector2(-82, 18)
	_btn.visible = false
	_btn.pressed.connect(_open_pause)
	_layer.add_child(_btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if TransitionManager.is_transitioning:
			return
		if is_instance_valid(_compendium):
			_close_compendium()
		elif _is_abandon_confirmation_open():
			_on_cancel_abandon()
		elif _open:
			_on_resume()
		elif is_instance_valid(_btn) and _btn.visible:
			_open_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if is_instance_valid(_btn) and _btn.visible and not _open:
			_open_pause()


# ---------- 供场景调用 ----------
func show_pause_button() -> void:
	if _btn != null:
		_btn.visible = true


func hide_pause_button() -> void:
	if _btn != null:
		_btn.visible = false
	if _open:
		_close_pause()
	_close_compendium()


# ---------- 暂停菜单 ----------
func _open_pause() -> void:
	if _open or TransitionManager.is_transitioning:
		return
	_open = true
	SignalBus.sound_requested.emit(&"pause_open")
	get_tree().paused = true
	_overlay = _build_overlay()
	TransitionManager.open_panel(_layer, _overlay, 0.12, 0.0)


func _close_pause() -> void:
	_open = false
	get_tree().paused = false
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _build_overlay() -> Control:
	var cover := (load("res://scenes/ui/PauseMenu.tscn") as PackedScene).instantiate() as Control
	cover.find_child("ResumeButton", true, false).pressed.connect(_on_resume)
	cover.find_child("CompendiumButton", true, false).pressed.connect(_open_compendium)
	cover.find_child("MainMenuButton", true, false).pressed.connect(_on_save_to_menu)
	cover.find_child("QuitButton", true, false).pressed.connect(_on_save_and_quit)
	cover.find_child("AbandonButton", true, false).pressed.connect(_on_request_abandon)
	cover.find_child("AbandonButton", true, false).disabled = not RunState.is_active
	cover.find_child("CancelAbandonButton", true, false).pressed.connect(_on_cancel_abandon)
	cover.find_child("ConfirmAbandonButton", true, false).pressed.connect(_on_confirm_abandon)
	return cover


func _is_abandon_confirmation_open() -> bool:
	return is_instance_valid(_overlay) and _overlay.find_child("AbandonConfirmation", true, false).visible


func _on_request_abandon() -> void:
	if TransitionManager.is_transitioning or not _open or not RunState.is_active:
		return
	_overlay.find_child("Buttons", true, false).hide()
	_overlay.find_child("AbandonConfirmation", true, false).show()
	_overlay.find_child("AbandonError", true, false).hide()
	_overlay.find_child("CancelAbandonButton", true, false).grab_focus()


func _on_cancel_abandon() -> void:
	if TransitionManager.is_transitioning or not _is_abandon_confirmation_open():
		return
	_overlay.find_child("AbandonConfirmation", true, false).hide()
	_overlay.find_child("Buttons", true, false).show()
	_overlay.find_child("AbandonButton", true, false).grab_focus()


func _on_confirm_abandon() -> void:
	if TransitionManager.is_transitioning or not _is_abandon_confirmation_open() or not RunState.is_active:
		return
	var error := TransitionManager.change_scene_to_file(MAIN_MENU, _prepare_abandon)
	if error != OK:
		_show_abandon_error()


func _prepare_abandon() -> Error:
	# 目标场景准备成功后才删档；删档失败保留本局与确认界面，允许重试。
	if not SaveManager.delete_save():
		_show_abandon_error()
		return ERR_FILE_CANT_WRITE
	RunState.abandon_run()
	return OK


func _show_abandon_error() -> void:
	if _is_abandon_confirmation_open():
		_overlay.find_child("AbandonError", true, false).show()


func _open_compendium() -> void:
	if is_instance_valid(_compendium):
		return
	_compendium = CARD_COMPENDIUM.instantiate() as CardCompendium
	_compendium.closed.connect(_on_compendium_closed)
	add_child(_compendium)


func _on_compendium_closed() -> void:
	_compendium = null


func _close_compendium() -> void:
	if is_instance_valid(_compendium):
		_compendium.close()
	_compendium = null


func _on_save_to_menu() -> void:
	if TransitionManager.is_transitioning:
		return
	SaveManager.save_game()
	TransitionManager.change_scene_to_file(MAIN_MENU)


func _on_save_and_quit() -> void:
	if TransitionManager.is_transitioning:
		return
	SaveManager.save_game()
	_close_pause()
	get_tree().quit()

func _on_resume() -> void:
	if not TransitionManager.is_transitioning and _overlay != null:
		TransitionManager.close_panel(_overlay, _close_pause, 0.10, 0.0)
