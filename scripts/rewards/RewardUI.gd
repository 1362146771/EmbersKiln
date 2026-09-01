extends Control
## 战后奖励界面（MVP）。展示金币、遗物、3 选 1 卡牌；可选「升级一张已有卡牌」或「跳过」。
## 通过 setup(reward_data, done_callback) 注入数据；完成后调用 done_callback 交还控制权。

const CREAM := Color(0.984, 0.953, 0.894)
const ORANGE := Color(0.941, 0.600, 0.482)
const GREEN := Color(0.365, 0.792, 0.647)
const RED := Color(0.847, 0.353, 0.188)
const PURPLE := Color(0.498, 0.467, 0.867)
const DARK := Color(0.25, 0.20, 0.18)
const AMBER := Color(0.937, 0.624, 0.153)
const BG_DARK := Color(0.12, 0.10, 0.09)

var data: Dictionary = {}
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


## P2 场景化：作为独立场景加载时（生产路径），setup 不会被外部调用，奖励数据来自 RunState；
## 作为 verify overlay 时 setup 已注入 data，此处保留即用。
func _ready() -> void:
	if not SignalBus.card_acquisition_resolved.is_connected(_on_card_acquisition_resolved):
		SignalBus.card_acquisition_resolved.connect(_on_card_acquisition_resolved)
	if data.is_empty():
		data = RunState.pending_reward_data
	_build_main()


func _exit_tree() -> void:
	if SignalBus.card_acquisition_resolved.is_connected(_on_card_acquisition_resolved):
		SignalBus.card_acquisition_resolved.disconnect(_on_card_acquisition_resolved)


## 注入奖励数据并绑定完成回调；必须在 add_child 之前调用。
func setup(reward_data: Dictionary, done: Callable) -> void:
	data = reward_data
	on_done = done


func _build_main() -> void:
	for c in get_children():
		c.queue_free()

	var dim := _solid_bg(BG_DARK)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 1100)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 24)
	v.add_theme_constant_override("margin_bottom", 24)
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)

	v.add_child(_label("战  利  品", 40, DARK))

	var gold := int(data.get("gold", 0))
	v.add_child(_label("金币 +%d（共 %d）" % [gold, RunState.gold], 26, AMBER))

	var relic_id: StringName = data.get("relic_id", &"")
	if relic_id != &"":
		var rd: RelicData = GameData.get_relic(relic_id)
		var rname := rd.name if rd != null else String(relic_id)
		v.add_child(_label("获得遗物：%s" % rname, 26, PURPLE))
	var potion_id: StringName = data.get("potion_id", &"")
	if potion_id != &"":
		var pd: PotionData = GameData.get_potion(potion_id)
		var pname := pd.name if pd != null else String(potion_id)
		var phb := HBoxContainer.new()
		phb.alignment = BoxContainer.ALIGNMENT_CENTER
		phb.add_theme_constant_override("separation", 8)
		if pd != null and pd.icon != "":
			phb.add_child(GameData.icon_rect(pd.icon, 44))
		phb.add_child(_label("获得药水：%s" % pname, 26, ORANGE))
		v.add_child(phb)

	v.add_child(_label("选择一张卡牌加入牌组：", 24, DARK))

	# 卡牌三选一（横向滚动）
	var card_scroll := ScrollContainer.new()
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(card_scroll)

	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 14)
	card_scroll.add_child(cards_row)

	var cards: Array = data.get("cards", [])
	for i in cards.size():
		var cd: Dictionary = cards[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(180, 240)
		b.add_theme_color_override("font_color", DARK)
		var t := "%s\n[%d 能 · %s]\n%s" % [cd.get("name", ""), int(cd.get("cost", 0)), _rarity_cn(StringName(cd.get("rarity", "common"))), cd.get("desc", "")]
		b.text = t
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_on_choose_card.bind(i))
		cards_row.add_child(b)

	# 操作按钮
	var upgrade_btn := Button.new()
	upgrade_btn.text = "升级一张已有卡牌"
	upgrade_btn.custom_minimum_size = Vector2(300, 64)
	upgrade_btn.add_theme_font_size_override("font_size", 22)
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	v.add_child(upgrade_btn)

	var skip_btn := Button.new()
	skip_btn.text = "跳过"
	skip_btn.custom_minimum_size = Vector2(300, 64)
	skip_btn.add_theme_font_size_override("font_size", 22)
	skip_btn.pressed.connect(_on_skip)
	v.add_child(skip_btn)
	var rwtier: StringName = StringName(data.get("tier", "combat"))
	if (rwtier == &"elite" or rwtier == &"boss") and RewardBuilder.can_any_card_enchant():
		var enc_btn := Button.new()
		enc_btn.text = "为一张卡牌附魔"
		enc_btn.custom_minimum_size = Vector2(300, 64)
		enc_btn.add_theme_font_size_override("font_size", 22)
		enc_btn.pressed.connect(_on_enchant_pressed)
		v.add_child(enc_btn)


func _build_upgrade() -> void:
	for c in get_children():
		c.queue_free()

	var dim := _solid_bg(BG_DARK)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 1100)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 24)
	v.add_theme_constant_override("margin_bottom", 24)
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	v.add_child(_label("升级一张卡牌", 34, DARK))
	v.add_child(_label("选择要强化的卡牌（已升级的不可再选）", 20, DARK))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)

	var upgradable := false
	for i in RunState.deck.size():
		var entry: Dictionary = RunState.deck[i]
		var cd: CardData = GameData.get_card(StringName(entry["id"]))
		if cd == null or entry["upgraded"]:
			continue
		upgradable = true
		var b := Button.new()
		b.custom_minimum_size = Vector2(600, 64)
		b.add_theme_color_override("font_color", DARK)
		b.text = "%s → %s" % [cd.name, cd.get_description(true)]
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_on_upgrade_card.bind(i))
		col.add_child(b)

	if not upgradable:
		v.add_child(_label("（没有可升级的卡牌）", 22, RED))

	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(300, 60)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(_build_main)
	v.add_child(back)


func _on_choose_card(i: int) -> void:
	var cards: Array = data.get("cards", [])
	if i < 0 or i >= cards.size():
		return
	var cid: StringName = StringName(cards[i].get("id", ""))
	var result := CardAcquireService.acquire_free_card(cid, false, &"reward", {"card_name": cards[i].get("name", "")})
	if result == CardAcquireService.RESULT_ACQUIRED:
		_log_reward("已获得卡牌：%s" % cards[i].get("name", ""))
		_finish()
	elif result == CardAcquireService.RESULT_FULL:
		_log_reward("牌库已满，等待扩容或放弃这张卡。")


func _on_card_acquisition_resolved(acquisition: Dictionary, result: StringName) -> void:
	if String(acquisition.get("source_id", "")) != "reward":
		return
	if result == CardAcquireService.RESULT_ACQUIRED:
		_log_reward("扩容后已获得卡牌：%s" % acquisition.get("context", {}).get("card_name", acquisition.get("card_id", "")))
		_finish()
	elif result == CardAcquireService.RESULT_FAILED:
		_log_reward("容量已增加，但本次卡牌未领取。")


func _on_upgrade_pressed() -> void:
	_build_upgrade()


func _on_upgrade_card(i: int) -> void:
	if RunState.upgrade_card_at(i):
		_log_reward("卡牌已升级")
	_finish()


func _on_skip() -> void:
	_log_reward("跳过奖励")
	_finish()


func _finish() -> void:
	if self == get_tree().current_scene:
		RunState.pending_post_reward = true
		get_tree().change_scene_to_packed(load("res://scenes/map/MapPlay.tscn") as PackedScene)
	elif on_done.is_valid():
		on_done.call()


func _log_reward(msg: String) -> void:
	print("[Reward] " + msg)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _rarity_cn(r: StringName) -> String:
	match r:
		&"common": return "普通"
		&"uncommon": return "精良"
		&"rare": return "稀有"
		&"starter": return "初始"
		_: return String(r)


func _on_enchant_pressed() -> void:
	_build_enchant()


## 附魔套用后展示效果面板，玩家点「完成」再结算（避免看不到附魔效果）。
func _show_enchant_result(cd: CardData, ed: Variant) -> void:
	for c in get_children():
		c.queue_free()
	var dim := _solid_bg(BG_DARK)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 540)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 28)
	v.add_theme_constant_override("margin_right", 28)
	v.add_theme_constant_override("margin_top", 28)
	v.add_theme_constant_override("margin_bottom", 28)
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	v.add_child(_label("附魔完成", 38, DARK))
	v.add_child(_label("卡牌：%s" % cd.name, 24, DARK))
	if ed != null and ed.icon != "":
		v.add_child(GameData.icon_rect(ed.icon, 64))
	var ename: String = ed.name if ed != null else "?"
	var ename_l := _label("附魔：%s" % ename, 24, Color(0.30, 0.70, 0.35))
	v.add_child(ename_l)
	var desc: String = ed.description if (ed != null and ed.description != "") else "（无效果描述）"
	var dl := _label("效果：%s" % desc, 22, DARK)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(dl)
	var done := Button.new()
	done.text = "完成"
	done.custom_minimum_size = Vector2(300, 64)
	done.add_theme_font_size_override("font_size", 24)
	done.pressed.connect(_finish)
	v.add_child(done)


func _build_enchant() -> void:
	for c in get_children():
		c.queue_free()
	var dim := _solid_bg(BG_DARK)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 1100)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	v.add_theme_constant_override("margin_top", 24)
	v.add_theme_constant_override("margin_bottom", 24)
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_label("为一张卡牌附魔", 34, DARK))
	v.add_child(_label("选择要附魔的卡牌（附魔将永久生效）", 20, DARK))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)
	var any := false
	for i in RunState.deck.size():
		var entry: Dictionary = RunState.deck[i]
		var cd: CardData = GameData.get_card(StringName(entry["id"]))
		if cd == null or not entry.get("enchants", []).is_empty():
			continue
		var eid: StringName = RewardBuilder.roll_enchant_for_card(cd)
		if eid == &"":
			continue
		any = true
		var ed = GameData.get_enchant(eid)
		var ename: String = ed.name if ed != null else String(eid)
		var desc: String = ed.description if (ed != null and ed.description != "") else "（无效果描述）"
		var b := Button.new()
		b.custom_minimum_size = Vector2(600, 150)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_color_override("font_color", DARK)
		b.text = "%s\n附魔：%s\n效果：%s" % [cd.name, ename, desc]
		b.add_theme_font_size_override("font_size", 20)
		if ed != null and ed.icon != "":
			b.icon = GameData.icon_texture(ed.icon)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_enchant_card.bind(i))
		col.add_child(b)
	if not any:
		v.add_child(_label("（没有可附魔的卡牌）", 22, RED))
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(300, 60)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(_build_main)
	v.add_child(back)


func _on_enchant_card(i: int) -> void:
	if i < 0 or i >= RunState.deck.size():
		_finish()
		return
	var entry: Dictionary = RunState.deck[i]
	var cd: CardData = GameData.get_card(StringName(entry["id"]))
	if cd == null:
		_finish()
		return
	var eid: StringName = RewardBuilder.roll_enchant_for_card(cd)
	if eid == &"":
		_finish()
		return
	if RunState.add_enchant_to_card_at(i, eid):
		var ed = GameData.get_enchant(eid)
		_log_reward("卡牌 %s 已附魔：%s" % [cd.name, ed.name if ed != null else eid])
		_show_enchant_result(cd, ed)
	else:
		_finish()
