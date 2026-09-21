extends Node
## 图标实装校验：药水 / 附魔 / 遗物图标。
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
	var relic_icons := 0
	for r in GameData.relics.values():
		var t := GameData.icon_texture(r.icon)
		if t == null:
			fails.append("RELIC:" + r.icon)
		else:
			relic_icons += 1
	if GameData.icon_texture("ICO_Relic_MissingForVerify") != null:
		fails.append("RELIC: missing icon should return null")
	var total := GameData.potions.size() + GameData.enchants.size() + relic_icons
	if fails.is_empty():
		print("[ICON_VERIFY PASS] %d 图标加载成功（%d 药水 + %d 附魔 + %d 遗物）" % [total, GameData.potions.size(), GameData.enchants.size(), relic_icons])
	else:
		print("[ICON_VERIFY FAIL] 缺失图标: " + " | ".join(fails))
	get_tree().quit(0 if fails.is_empty() else 1)
