extends Node
## 图标实装校验：断言 23 个图标（13 药水 + 10 附魔）的纹理均能被 load 成功。
## 同时作为「全量编译」兜底层：run_and_verify 启动即编译整个项目，任何 .gd 语法错误都会在此暴露。

func _ready() -> void:
	var fails: PackedStringArray = []
	for p in GameData.potions.values():
		var t := GameData.icon_texture(p.icon)
		if t == null:
			fails.append("POTION:" + p.icon)
	for e in GameData.enchants.values():
		var t := GameData.icon_texture(e.icon)
		if t == null:
			fails.append("ENCHANT:" + e.icon)
	var total := GameData.potions.size() + GameData.enchants.size()
	if fails.is_empty():
		print("[ICON_VERIFY PASS] %d 图标全部加载成功（%d 药水 + %d 附魔）" % [total, GameData.potions.size(), GameData.enchants.size()])
	else:
		print("[ICON_VERIFY FAIL] 缺失图标: " + " | ".join(fails))
	get_tree().quit()
