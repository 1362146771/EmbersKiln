extends Control
## 只读展示已由 MapUI 生成的奖励；继续后进入原有选牌流程。
signal continued

func setup(data: Dictionary, backdrop: Texture2D) -> void:
	$Background.texture = backdrop
	$Background.visible = backdrop != null
	var items: GridContainer = $Panel/Items/Scroll/Grid
	for child in items.get_children():
		items.remove_child(child)
		child.queue_free()
	_add_item(items, "金币\n+%d" % int(data.get("gold", 0)), FormalUI.texture("icon_gold(需ai改.png"))
	var relic_id := StringName(data.get("relic_id", ""))
	if relic_id != &"":
		var relic := GameData.get_relic(relic_id)
		_add_item(items, relic.name if relic else String(relic_id), GameData.icon_texture(relic.icon) if relic else null)
	var potion_id := StringName(data.get("potion_id", ""))
	if potion_id != &"":
		var potion := GameData.get_potion(potion_id)
		_add_item(items, potion.name if potion else String(potion_id), GameData.icon_texture(potion.icon) if potion else null)
	if not data.get("cards", []).is_empty():
		_add_item(items, "卡牌\n待选择", null)
	$Panel/Continue.pressed.connect(func():
		continued.emit()
		queue_free()
	)

func _add_item(grid: GridContainer, title: String, icon: Texture2D) -> void:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(82, 122)
	tile.add_theme_stylebox_override("panel", FormalUI.stone("bd_common_rewardFrame.png", 5))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	tile.add_child(column)
	if icon != null:
		var picture := TextureRect.new()
		picture.texture = icon
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(56, 48)
		column.add_child(picture)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	column.add_child(label)
	grid.add_child(tile)
