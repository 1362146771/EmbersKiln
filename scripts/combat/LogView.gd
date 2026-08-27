class_name LogView
extends RefCounted
## 日志条 + 提示横幅。从 CombatUI 抽出（P4b）。零 preload。

var ui: CombatUI

func attach(ui_ref: CombatUI) -> void:
	ui = ui_ref


func log(msg: String) -> void:
	ui.log_label.text = msg


## 满场提示：横幅淡入 1.2s 后淡出。
func on_summon_rejected(cap: int) -> void:
	if ui.toast_label == null:
		return
	ui.toast_label.text = "召唤栏已满（上限 %d）" % cap
	ui.toast_label.modulate.a = 1.0
	ui.toast_label.visible = true
	var tw := ui.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(ui.toast_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): ui.toast_label.visible = false)
