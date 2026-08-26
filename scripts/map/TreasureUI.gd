extends Control
## 宝箱：二选一拿随机卡 或 随机遗物。done 回调回地图。

const CREAM := Color(0.984, 0.953, 0.894)
const AMBER := Color(0.937, 0.624, 0.153)
const DARK := Color(0.25, 0.20, 0.18)
const PURPLE := Color(0.498, 0.467, 0.867)
const BG_DARK := Color(0.12, 0.10, 0.09)

var on_done: Callable = Callable()

func _solid_bg(color: Color) -> TextureRect:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	return tr


func setup(done: Callable) -> void:
	on_done = done
	_build_main()


func _build_main() -> void:
	for c in get_children():
		c.queue_free()

	var dim := _solid_bg(BG_DARK)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 980)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 24)
	v.add_theme_constant_override("margin_bottom", 24)
	v.add_theme_constant_override("separation", 22)
	panel.add_child(v)

	v.add_child(_label("宝 箱", 40, DARK))
	v.add_child(_label("一只陶土封存的旧箱，微微透出窑火余温。", 24, DARK))

	var card_btn := Button.new()
	card_btn.text = "取走一张卡牌"
	card_btn.custom_minimum_size = Vector2(560, 80)
	card_btn.add_theme_font_size_override("font_size", 26)
	card_btn.pressed.connect(_on_take_card)
	v.add_child(card_btn)

	var relic_btn := Button.new()
	relic_btn.text = "取走一件遗物"
	relic_btn.custom_minimum_size = Vector2(560, 80)
	relic_btn.add_theme_font_size_override("font_size", 26)
	relic_btn.pressed.connect(_on_take_relic)
	v.add_child(relic_btn)
	var potion_btn := Button.new()
	potion_btn.text = "取走一瓶药水"
	potion_btn.custom_minimum_size = Vector2(560, 80)
	potion_btn.add_theme_font_size_override("font_size", 26)
	potion_btn.pressed.connect(_on_take_potion)
	v.add_child(potion_btn)


func _on_take_card() -> void:
	var cd: Dictionary = RewardBuilder.roll_single_card()
	if cd.is_empty():
		_log("卡牌池为空")
		_finish()
		return
	RunState.add_card(StringName(cd.get("id", "")), false)
	_log("宝箱获得卡牌：%s" % cd.get("name", ""))
	_finish()


func _on_take_relic() -> void:
	var rid: StringName = RewardBuilder.roll_shop_relic()
	if rid == &"":
		_log("遗物已全部拥有，改发卡牌")
		_on_take_card()
		return
	RunState.add_relic(rid)
	_log("宝箱获得遗物：%s" % rid)


func _on_take_potion() -> void:
	var pid: StringName = RewardBuilder.roll_potion(&"combat", true)
	if pid == &"":
		_log("药水背包已满")
		_finish()
		return
	RunState.add_potion(pid)
	var p = GameData.get_potion(pid)
	_log("宝箱获得药水：%s" % (p.name if p != null else pid))
	_finish()
	_finish()


func _finish() -> void:
	queue_free()
	if on_done.is_valid():
		on_done.call()


func _log(msg: String) -> void:
	print("[Treasure] " + msg)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
