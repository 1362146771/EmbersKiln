extends Control
## 事件：数据驱动于 res://data/events.json（经 GameData 加载）。
## 选项带后果网络（金币/回血/掉血/得卡/得遗物），由 _on_choose 解释执行。
## done 回调回地图。

const CREAM := Color(0.984, 0.953, 0.894)
const TEXT := Color("f2e8d5")
const RED := Color(0.847, 0.353, 0.188)
const AMBER := Color(0.937, 0.624, 0.153)
const PURPLE := Color(0.498, 0.467, 0.867)
const GREEN := Color(0.365, 0.792, 0.647)
const BG_DARK := Color(0.12, 0.10, 0.09)
const CardBrowserScript := preload("res://scripts/ui/CardBrowser.gd")

var on_done: Callable = Callable()
var _event: Dictionary = {}
var _resolved := false
var _finished := false
var _choosing := false
var _choice_buttons: Array[Button] = []
var _remove_browser: CanvasLayer
var _remove_sources: Array = []
var _pending_effects: Dictionary = {}
var _status: Label
var _pending_card_name := ""
var _pending_card_parts: Array[String] = []


## 用实色纹理贴图替代 ColorRect（避免渲染器 alpha 合成问题）
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


func _ready() -> void:
	if not SignalBus.card_acquisition_resolved.is_connected(_on_card_acquisition_resolved):
		SignalBus.card_acquisition_resolved.connect(_on_card_acquisition_resolved)
	_build_main()


func _exit_tree() -> void:
	if SignalBus.card_acquisition_resolved.is_connected(_on_card_acquisition_resolved):
		SignalBus.card_acquisition_resolved.disconnect(_on_card_acquisition_resolved)


func setup(done: Callable) -> void:
	on_done = done
	_build_main()


## 从 GameData 取一个随机事件；GameData 未就绪时退回一个兜底事件，避免空屏。
func _pick_event() -> Dictionary:
	if GameData.is_loaded and not GameData.events.is_empty():
		return GameData.random_event()
	return {
		"title": "岔路口",
		"desc": "前路不明，你原地整备。",
		"options": [
			{"label": "稍作休整（恢复 8 生命）", "effects": {"heal": 8}},
			{"label": "继续赶路", "effects": {}},
		],
	}


func _build_main() -> void:
	if _resolved:
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_choice_buttons.clear()

	var dim := _solid_bg(BG_DARK)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 1040)
	panel.add_theme_stylebox_override("panel", CardBrowserScript.style(Color("3a4554")))
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20
	v.offset_right = -20
	v.offset_top = 16
	v.offset_bottom = -16
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 22)
	v.add_theme_constant_override("margin_bottom", 22)
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)

	if _event.is_empty():
		_event = _pick_event()
	var ev: Dictionary = _event
	v.add_child(_label(ev["title"], 38, TEXT))
	var desc := _label(ev["desc"], 24, TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)

	for opt in ev["options"]:
		var b := Button.new()
		b.text = opt["label"]
		b.custom_minimum_size = Vector2(600, 72)
		b.add_theme_font_size_override("font_size", 22)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_on_choose.bind(opt["effects"]))
		b.set_meta("remove_card", opt["effects"].get("remove_card", false))
		_choice_buttons.append(b)
		v.add_child(b)
	_status = CardBrowserScript.label("", 22)
	v.add_child(_status)
	_refresh_choices()


func _on_choose(effects: Dictionary) -> void:
	if _resolved or _choosing or not is_inside_tree() or is_queued_for_deletion():
		return
	if effects.get("remove_card", false) and not RunState.can_remove_card():
		return
	_choosing = true
	_refresh_choices()
	if effects.get("remove_card", false):
		_open_remove(effects)
		return
	_resolved = true
	_apply_effects(effects)


func _refresh_choices() -> void:
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.disabled = _choosing or _resolved or (button.get_meta("remove_card", false) and not RunState.can_remove_card())
			if button.get_meta("remove_card", false) and not RunState.can_remove_card():
				button.tooltip_text = "牌组至少保留 %d 张卡" % int(GameData.balance["card_removal"]["minimum_remaining"])


func _open_remove(effects: Dictionary) -> void:
	_pending_effects = effects.duplicate(true)
	_remove_sources = RunState.deck.duplicate()
	var browser := CardBrowserScript.new()
	browser.setup("余烬焚牌", "%s · 事件选择\n不收取金币；与本事件其他奖励互斥。" % _event.get("title", "事件"),
		RunState.deck, true, "确认永久移除", "确认后完成这次事件选择，不能再领取其他选项的奖励。")
	_remove_browser = browser
	browser.confirmed.connect(_confirm_remove)
	browser.closed.connect(_cancel_remove)
	add_child(browser)


func _cancel_remove() -> void:
	_remove_browser = null
	_remove_sources.clear()
	_pending_effects.clear()
	_choosing = false
	_refresh_choices()


func _confirm_remove(i: int, snapshot: Dictionary) -> void:
	if _resolved or not _choosing or not _pending_effects.get("remove_card", false) or not is_inside_tree():
		return
	_resolved = true  # 发库存信号前锁定所有选项，避免重复奖励。
	var valid := i >= 0 and i < _remove_sources.size() and i < RunState.deck.size()
	if valid:
		valid = RunState.deck[i] == snapshot and is_same(RunState.deck[i], _remove_sources[i])
	if not valid or not RunState.try_remove_card(i, _remove_sources[i], 0):
		_resolved = false
		_cancel_remove()
		_status.text = "牌组已变化，本次未移除；请重新选择。"
		_log("牌组已变化，本次未移除；可重新选择。")
		return
	var effects := _pending_effects.duplicate(true)
	_remove_browser = null
	_pending_effects.clear()
	_remove_sources.clear()
	_apply_effects(effects, ["永久移除卡牌：%s" % CardBrowserScript.card_name(snapshot)])


func _apply_effects(effects: Dictionary, parts: Array[String] = []) -> void:
	if effects.get("add_card", false):
		var cd: Dictionary = RewardBuilder.roll_single_card()
		var remaining := effects.duplicate(true)
		remaining.erase("add_card")
		if not cd.is_empty():
			var result := CardAcquireService.acquire_free_card(
				StringName(String(cd.get("id", ""))),
				false,
				&"event",
				{"card_name": cd.get("name", "")}
			)
			if result == CardAcquireService.RESULT_FULL:
				_pending_effects = remaining
				_pending_card_name = String(cd.get("name", ""))
				_pending_card_parts = parts.duplicate()
				return
			if result == CardAcquireService.RESULT_ACQUIRED:
				parts.append("获得卡牌 %s" % cd.get("name", ""))
		effects = remaining
	if effects.has("gold"):
		var g: int = int(effects["gold"])
		RunState.add_gold(g)
		parts.append("金币 %+d" % g)
	if effects.has("heal"):
		var h: int = int(effects["heal"])
		RunState.heal(h)
		parts.append("恢复 %d 生命" % h)
	if effects.has("lose_hp"):
		var d: int = int(effects["lose_hp"])
		RunState.hp = maxi(1, RunState.hp - d)
		SignalBus.player_hp_changed.emit(RunState.hp, RunState.max_hp)
		parts.append("失去 %d 生命" % d)
	if effects.get("add_relic", false):
		var rid: StringName = RewardBuilder.roll_shop_relic()
		if rid != &"":
			RunState.add_relic(rid)
			var r: RelicData = GameData.get_relic(rid)
			parts.append("获得遗物 %s" % (r.name if r != null else String(rid)))
	if effects.get("add_potion", false):
		var pid: StringName = RewardBuilder.roll_potion(&"combat", true)
		if pid != &"" and RunState.add_potion(pid):
			var p = GameData.get_potion(pid)
			parts.append("获得药水 %s" % (p.name if p != null else String(pid)))
	if effects.get("add_enchant", false):
		var enc_ok := false
		for i in RunState.deck.size():
			var eentry = RunState.deck[i]
			var ecd = GameData.get_card(StringName(eentry["id"]))
			if ecd == null:
				continue
			var eeid: StringName = RewardBuilder.roll_enchant_for_card(ecd)
			if eeid != &"" and RunState.add_enchant_to_card_at(i, eeid):
				var eed = GameData.get_enchant(eeid)
				parts.append("卡牌 %s 附魔：%s" % [ecd.name, eed.name if eed != null else eeid])
				enc_ok = true
				break
		if not enc_ok:
			parts.append("（无可附魔的卡牌）")
	var msg: String = "（什么也没发生）" if parts.is_empty() else " · ".join(parts)
	_log(msg)
	_show_result(msg)


func _on_card_acquisition_resolved(acquisition: Dictionary, result: StringName) -> void:
	if String(acquisition.get("source_id", "")) != "event":
		return
	if result == CardAcquireService.RESULT_ACQUIRED:
		var parts := _pending_card_parts.duplicate()
		parts.append("获得卡牌 %s" % _pending_card_name)
		var effects := _pending_effects.duplicate(true)
		_pending_effects.clear()
		_pending_card_parts.clear()
		_pending_card_name = ""
		_apply_effects(effects, parts)
	else:
		_pending_effects.clear()
		_pending_card_parts.clear()
		_pending_card_name = ""
		_resolved = false
		_choosing = false
		_refresh_choices()


func _show_result(msg: String) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()

	var dim := _solid_bg(BG_DARK)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 700)
	panel.add_theme_stylebox_override("panel", CardBrowserScript.style(Color("3a4554")))
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 24)
	v.add_theme_constant_override("margin_bottom", 24)
	v.add_theme_constant_override("separation", 24)
	v.offset_left = 20
	v.offset_right = -20
	v.offset_top = 20
	v.offset_bottom = -20
	panel.add_child(v)

	var res := _label(msg, 26, TEXT)
	res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(res)

	var btn := Button.new()
	btn.text = "继续"
	btn.custom_minimum_size = Vector2(300, 76)
	btn.add_theme_font_size_override("font_size", 26)
	btn.pressed.connect(_finish)
	v.add_child(btn)


func _finish() -> void:
	if _finished or not _resolved or not is_inside_tree():
		return
	_finished = true
	var tree := get_tree()
	if self == tree.current_scene:
		RunState.pending_node_resolved = true
		tree.change_scene_to_packed(load("res://scenes/map/MapPlay.tscn") as PackedScene)
	elif on_done.is_valid():
		queue_free()
		on_done.call()


func _log(msg: String) -> void:
	print("[Event] " + msg)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
