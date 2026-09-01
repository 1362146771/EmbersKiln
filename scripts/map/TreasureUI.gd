extends Control
## 宝箱：卡牌 / 遗物 / 药水三选一，仅领取一次；独立场景或 done 回调回地图。
const CardBrowserScript := preload("res://scripts/ui/CardBrowser.gd")

const CREAM := Color(0.984, 0.953, 0.894)
const AMBER := Color(0.937, 0.624, 0.153)
const DARK := Color(0.25, 0.20, 0.18)
const PURPLE := Color(0.498, 0.467, 0.867)
const BG_DARK := Color(0.12, 0.10, 0.09)

var on_done: Callable = Callable()
var _claimed := false
var _finished := false
var _choice_buttons: Array[Button] = []
var _choice_panel: Panel
var _result_panel: PanelContainer
var _result_title: Label
var _result_icon: TextureRect
var _result_name: Label
var _result_description: Label
var _continue_button: Button
var _pending_card: Dictionary = {}
var _pending_card_mode := ""

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


## P2 场景化：作为独立场景加载时自构建。
func _ready() -> void:
	if not SignalBus.card_acquisition_resolved.is_connected(_on_card_acquisition_resolved):
		SignalBus.card_acquisition_resolved.connect(_on_card_acquisition_resolved)
	_build_main()


func _exit_tree() -> void:
	if SignalBus.card_acquisition_resolved.is_connected(_on_card_acquisition_resolved):
		SignalBus.card_acquisition_resolved.disconnect(_on_card_acquisition_resolved)


func _build_main() -> void:
	# setup() 与 _ready() 兼容同一实例，避免重复构建/留下待释放的旧按钮。
	if not _choice_buttons.is_empty():
		return
	for c in get_children():
		c.queue_free()

	var dim := _solid_bg(BG_DARK)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	_choice_panel = panel
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
	_choice_buttons.append(card_btn)
	v.add_child(card_btn)

	var relic_btn := Button.new()
	relic_btn.text = "取走一件遗物"
	relic_btn.custom_minimum_size = Vector2(560, 80)
	relic_btn.add_theme_font_size_override("font_size", 26)
	relic_btn.pressed.connect(_on_take_relic)
	_choice_buttons.append(relic_btn)
	v.add_child(relic_btn)
	var potion_btn := Button.new()
	potion_btn.text = "取走一瓶药水"
	potion_btn.custom_minimum_size = Vector2(560, 80)
	potion_btn.add_theme_font_size_override("font_size", 26)
	potion_btn.pressed.connect(_on_take_potion)
	_choice_buttons.append(potion_btn)
	v.add_child(potion_btn)
	_build_result(center)


func _build_result(center: CenterContainer) -> void:
	_result_panel = PanelContainer.new()
	_result_panel.custom_minimum_size = Vector2(620, 0)
	_result_panel.add_theme_stylebox_override("panel", CardBrowserScript.style(CardBrowserScript.SLATE))
	center.add_child(_result_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	_result_panel.add_child(column)
	_result_title = CardBrowserScript.label("获得遗物", 56)
	column.add_child(_result_title)
	_result_icon = TextureRect.new()
	_result_icon.custom_minimum_size = Vector2(128, 128)
	_result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_result_icon)
	_result_name = CardBrowserScript.label("", 32)
	column.add_child(_result_name)
	_result_description = CardBrowserScript.label("", 26)
	column.add_child(_result_description)
	_continue_button = CardBrowserScript.button("继续", _finish)
	column.add_child(_continue_button)
	_result_panel.hide()


func _show_result(title: String, reward_name: String, description: String, icon: String = "") -> void:
	_result_title.text = title
	_result_name.text = reward_name
	_result_description.text = description
	_result_icon.texture = GameData.icon_texture(icon)
	_result_icon.visible = _result_icon.texture != null
	_choice_panel.hide()
	_result_panel.show()
	_continue_button.grab_focus()


func _on_take_card() -> void:
	if not _begin_claim():
		return
	var card := _grant_card("take")
	if not card.get("_pending", false):
		_finish()


## 共用发卡逻辑：遗物池空时仍走当前领取，不再次进入带锁的按钮回调。
func _grant_card(mode: String = "fallback") -> Dictionary:
	var cd: Dictionary = RewardBuilder.roll_single_card()
	if cd.is_empty():
		_log("卡牌池为空")
		return {}
	var source_id := &"treasure" if mode == "take" else &"treasure_fallback"
	var result := CardAcquireService.acquire_free_card(StringName(cd.get("id", "")), false, source_id, {"card_name": cd.get("name", "")})
	if result == CardAcquireService.RESULT_FULL:
		_pending_card = cd.duplicate(true)
		_pending_card_mode = mode
		cd["_pending"] = true
		return cd
	if result != CardAcquireService.RESULT_ACQUIRED:
		return {}
	_log("宝箱获得卡牌：%s" % cd.get("name", ""))
	return cd


func _on_take_relic() -> void:
	if not _begin_claim():
		return
	var rid: StringName = RewardBuilder.roll_shop_relic()
	if rid == &"":
		_log("遗物已全部拥有，改发卡牌")
		var card := _grant_card()
		if card.get("_pending", false):
			return
		if card.is_empty():
			_show_result("宝箱已打开", "暂无可领取的奖励", "遗物已全部拥有，卡牌池为空。")
		else:
			_show_result("获得卡牌", String(card.get("name", "")), "遗物已全部拥有，改为获得卡牌。\n\n" + String(card.get("desc", "")))
	else:
		RunState.add_relic(rid)
		var relic: RelicData = GameData.get_relic(rid)
		var relic_name := relic.name if relic != null else String(rid)
		_log("宝箱获得遗物：%s" % relic_name)
		_show_result("获得遗物", relic_name, relic.description if relic != null else "遗物资料暂不可用。", relic.icon if relic != null else "")


func _on_take_potion() -> void:
	if not _begin_claim():
		return
	var pid: StringName = RewardBuilder.roll_potion(&"combat", true)
	if pid == &"":
		_log("药水背包已满")
		_finish()
		return
	RunState.add_potion(pid)
	var p = GameData.get_potion(pid)
	_log("宝箱获得药水：%s" % (p.name if p != null else pid))
	_finish()


func _begin_claim() -> bool:
	if _claimed or _finished or not is_inside_tree() or is_queued_for_deletion():
		return false
	# 发奖会发出同步信号，因此必须先锁定，防信号回调或跨按钮重复领取。
	_claimed = true
	_disable_choices()
	return true


func _disable_choices() -> void:
	for button in _choice_buttons:
		button.disabled = true


func _enable_choices() -> void:
	for button in _choice_buttons:
		button.disabled = false


func _on_card_acquisition_resolved(acquisition: Dictionary, result: StringName) -> void:
	var source_id := String(acquisition.get("source_id", ""))
	if source_id not in ["treasure", "treasure_fallback"]:
		return
	if result == CardAcquireService.RESULT_ACQUIRED:
		_log("扩容后获得卡牌：%s" % _pending_card.get("name", acquisition.get("card_id", "")))
		if _pending_card_mode == "fallback":
			_show_result("获得卡牌", String(_pending_card.get("name", "")), "遗物已全部拥有，改为获得卡牌。\n\n" + String(_pending_card.get("desc", "")))
		else:
			_finish()
	else:
		_claimed = false
		_enable_choices()
	_pending_card.clear()
	_pending_card_mode = ""


func _finish() -> void:
	if _finished or not _claimed or not is_inside_tree():
		return
	_finished = true
	_claimed = true
	_disable_choices()
	var tree := get_tree()
	if self == tree.current_scene:
		RunState.pending_node_resolved = true
		tree.change_scene_to_packed(load("res://scenes/map/MapPlay.tscn") as PackedScene)
	else:
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
