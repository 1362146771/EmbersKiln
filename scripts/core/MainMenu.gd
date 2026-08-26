extends Control
## 主菜单（P4 退出UI）：新游戏 / 继续游戏 / 退出游戏。
## 启动时检测 SaveManager.has_save() 决定「继续游戏」是否可用。

const MAP_PLAY := "res://scenes/map/MapPlay.tscn"

const CREAM := Color(0.984, 0.953, 0.894)
const ORANGE := Color(0.941, 0.600, 0.482)
const DARK := Color(0.25, 0.20, 0.18)
const AMBER := Color(0.937, 0.624, 0.153)


func _ready() -> void:
	if PauseManager != null:
		PauseManager.hide_pause_button()
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	center.add_child(col)

	# 标题
	var title := Label.new()
	title.text = "炽  窑"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", ORANGE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var sub := Label.new()
	sub.text = "陶原 · 爬塔"
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", DARK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	# 新游戏
	var b_new := _big_btn("新游戏")
	b_new.pressed.connect(_on_new_game)
	col.add_child(b_new)

	# 继续游戏（有存档才可用）
	var b_cont := _big_btn("继续游戏")
	b_cont.disabled = not SaveManager.has_save()
	if b_cont.disabled:
		b_cont.tooltip_text = "暂无存档"
	b_cont.pressed.connect(_on_continue)
	col.add_child(b_cont)

	# 退出游戏
	var b_quit := _big_btn("退出游戏")
	b_quit.pressed.connect(_on_quit)
	col.add_child(b_quit)


func _big_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 96)
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", DARK)
	return b


func _on_new_game() -> void:
	# 新游戏：清掉旧存档，避免误续玩上一局
	if SaveManager.has_save():
		SaveManager.delete_save()
	RunState.start_new_run()
	get_tree().change_scene_to_file(MAP_PLAY)


func _on_continue() -> void:
	if not SaveManager.has_save():
		return
	if not SaveManager.load_game():
		# 读档失败则退回到新游戏
		RunState.start_new_run()
	get_tree().change_scene_to_file(MAP_PLAY)


func _on_quit() -> void:
	get_tree().quit()
