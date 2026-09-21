class_name LogView
extends RefCounted
## 日志条。从 CombatUI 抽出（P4b）。零 preload。

var ui: CombatUI

func attach(ui_ref: CombatUI) -> void:
	ui = ui_ref


func log(msg: String) -> void:
	ui.log_label.text = msg
