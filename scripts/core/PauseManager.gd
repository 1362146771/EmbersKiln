extends Node
## Autoload: PauseManager —— 全局暂停菜单 + 退出（P4 退出UI）。
## 手机端竖屏：右上角常驻暂停按钮；暂停时弹出菜单（继续 / 保存并返回主菜单 / 保存并退出游戏）。
## 全游戏只有一个玩法场景 MapPlay（战斗为其叠加层），故用全局 autoload 覆盖最省事。

const MAIN_MENU := "res://scenes/main/MainMenu.tscn"

var _layer: CanvasLayer
var _btn: Button
var _overlay: Control = null
var _open := false


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时菜单仍可用
	_layer.name = "PauseLayer"
	add_child(_layer)   # 挂在 autoload 节点下，避免 root 忙碌期 add_child 失败

	_btn = Button.new()
	_btn.text = "❚❚"
	_btn.custom_minimum_size = Vector2(80, 80)
	_btn.add_theme_font_size_override("font_size", 30)
	_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_btn.position = Vector2(-96, 16)
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
	var cover := ColorRect.new()
	cover.color = Color(0.12, 0.10, 0.09, 0.82)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.process_mode = Node.PROCESS_MODE_ALWAYS
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	cover.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	col.process_mode = Node.PROCESS_MODE_ALWAYS
	center.add_child(col)
	col.add_child(_menu_btn("继续游戏", _close_pause))
	col.add_child(_menu_btn("保存并返回主菜单", _on_save_to_menu))
	col.add_child(_menu_btn("保存并退出游戏", _on_save_and_quit))
	return cover


func _menu_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 88)
	b.add_theme_font_size_override("font_size", 30)
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	b.pressed.connect(cb)
	return b


func _on_save_to_menu() -> void:
	SaveManager.save_game()
	_close_pause()
	get_tree().change_scene_to_file(MAIN_MENU)


func _on_save_and_quit() -> void:
	SaveManager.save_game()
	_close_pause()
	get_tree().quit()
