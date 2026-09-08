extends Node
## Autoload: PauseManager —— 全局暂停菜单 + 退出（P4 退出UI）。
## 手机端竖屏：右上角常驻暂停按钮；暂停时弹出菜单（继续 / 保存并返回主菜单 / 保存并退出游戏）。
## 全游戏只有一个玩法场景 MapPlay（战斗为其叠加层），故用全局 autoload 覆盖最省事。

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
const CARD_COMPENDIUM := preload("res://scenes/ui/CardCompendium.tscn")

var _layer: CanvasLayer
var _btn: Button
var _overlay: Control = null
var _compendium: CardCompendium = null
var _open := false


func _ready() -> void:
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
	if _open:
		return
	_open = true
	get_tree().paused = true
	_overlay = _build_overlay()
	_layer.add_child(_overlay)


func _close_pause() -> void:
	_open = false
	get_tree().paused = false
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


func _build_overlay() -> Control:
	var cover := (load("res://scenes/ui/PauseMenu.tscn") as PackedScene).instantiate() as Control
	cover.find_child("ResumeButton", true, false).pressed.connect(_close_pause)
	cover.find_child("CompendiumButton", true, false).pressed.connect(_open_compendium)
	cover.find_child("MainMenuButton", true, false).pressed.connect(_on_save_to_menu)
	cover.find_child("QuitButton", true, false).pressed.connect(_on_save_and_quit)
	return cover


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
	SaveManager.save_game()
	_close_pause()
	get_tree().change_scene_to_file(MAIN_MENU)


func _on_save_and_quit() -> void:
	SaveManager.save_game()
	_close_pause()
	get_tree().quit()
