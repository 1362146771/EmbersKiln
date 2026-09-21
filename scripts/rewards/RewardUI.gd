extends "res://scripts/core/NodePanel.gd"
## 战后奖励界面。卡牌、升级碎片/碎片升级、附魔择一；金币与遗物独立入账。
## 通过 setup(reward_data, done_callback) 注入数据；完成后调用 done_callback 交还控制权。

const CREAM := Color(0.984, 0.953, 0.894)
const ORANGE := Color(0.941, 0.600, 0.482)
const GREEN := Color(0.365, 0.792, 0.647)
const RED := Color(0.847, 0.353, 0.188)
const PURPLE := Color(0.498, 0.467, 0.867)
const DARK := Color.WHITE
const AMBER := Color(0.937, 0.624, 0.153)
const BG_DARK := Color(0.12, 0.10, 0.09)

var _entrance_cards: Array[Control] = []
var _entrance_prepared := false
var _overview: Control
var data: Dictionary = {}
var on_done: Callable = Callable()
var _upgrade_picker: CanvasLayer

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
	if String(data.get("stage", "cards")) == "boss_relic":
		FormalUI.combat_reward_pending = false
		_show_boss_relic_choices()
		return
	if String(data.get("stage", "cards")) == "complete":
		_finish.call_deferred()
		return
	_build_main()
	if FormalUI.combat_reward_pending:
		FormalUI.combat_reward_pending = false
		var overview := preload("res://scenes/ui/BattleRewardOverview.tscn").instantiate()
		_overview = overview
		add_child(overview)
		overview.continued.connect(_on_overview_continued)
		overview.setup(data, FormalUI.combat_reward_backdrop)
		FormalUI.combat_reward_backdrop = null
	if TransitionManager.is_transitioning:
		prepare_entrance()


func _exit_tree() -> void:
	if SignalBus.card_acquisition_resolved.is_connected(_on_card_acquisition_resolved):
		SignalBus.card_acquisition_resolved.disconnect(_on_card_acquisition_resolved)


## 注入奖励数据并绑定完成回调；必须在 add_child 之前调用。
func setup(reward_data: Dictionary, done: Callable) -> void:
	data = reward_data
	on_done = done


func _build_main() -> void:
	_entrance_cards.clear()
	theme = FormalUI.theme("btn_zhanLiPin_normal.png")
	if not has_node("Dim/Center/MainPanel"):
		FormalUI.restore_layout(self, "res://scenes/rewards/RewardUI.tscn")
	var scene_panel: Panel = get_node_or_null("Dim/Center/MainPanel")
	if scene_panel != null:
		$Dim.color = Color.TRANSPARENT
		FormalUI.map_backdrop(self)
		scene_panel.add_theme_stylebox_override("panel", FormalUI.stone("bd_main_zhanLiPin.png"))
		scene_panel.get_node("Content/Title").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scene_panel.get_node("Content/Prompt").add_theme_font_size_override("font_size", 21)
		var card_area: ScrollContainer = scene_panel.get_node("Content/CardScroll")
		FormalUI.reward_arrow(scene_panel, card_area)
		card_area.add_theme_stylebox_override("panel", FormalUI.stone("bd_zhanLiPin_card.png", 4))
		var summary: VBoxContainer = scene_panel.get_node("Content/Summary")
		for child in summary.get_children():
			child.queue_free()
		var gold_value := int(data.get("gold", 0))
		summary.add_child(_label("金币 +%d（共 %d）" % [gold_value, RunState.gold], 26, AMBER))
		var scene_relic_id: StringName = data.get("relic_id", &"")
		if scene_relic_id != &"":
			var scene_relic: RelicData = GameData.get_relic(scene_relic_id)
			var relic_label := _label("获得遗物：%s" % (scene_relic.name if scene_relic != null else String(scene_relic_id)), 26, PURPLE)
			summary.add_child(relic_label)
			preload("res://scripts/ui/RelicInfo.gd").attach(relic_label, scene_relic_id)
		var scene_potion_id: StringName = data.get("potion_id", &"")
		if scene_potion_id != &"":
			var scene_potion: PotionData = GameData.get_potion(scene_potion_id)
			var potion_row := HBoxContainer.new()
			potion_row.alignment = BoxContainer.ALIGNMENT_CENTER
			potion_row.add_theme_constant_override("separation", 8)
			if scene_potion != null and scene_potion.icon != "":
				potion_row.add_child(GameData.icon_rect(scene_potion.icon, 44))
			potion_row.add_child(_label("获得药水：%s" % (scene_potion.name if scene_potion != null else String(scene_potion_id)), 26, ORANGE))
			summary.add_child(potion_row)
		var cards_row: HBoxContainer = scene_panel.get_node("Content/CardScroll/Cards")
		for child in cards_row.get_children():
			child.queue_free()
		var scene_cards: Array = data.get("cards", [])
		for i in scene_cards.size():
			var scene_card: Dictionary = scene_cards[i]
			var card_button := Button.new()
			card_button.custom_minimum_size = Vector2(180, 280)
			card_button.add_theme_color_override("font_color", DARK)
			var scene_name := String(scene_card.get("name", "")) + ("+" if bool(scene_card.get("upgraded", false)) else "")
			card_button.text = "%s\n[%d 能 · %s]\n%s" % [scene_name, int(scene_card.get("cost", 0)), _rarity_cn(StringName(scene_card.get("rarity", "common"))), scene_card.get("desc", "")]
			card_button.add_theme_font_size_override("font_size", 20)
			card_button.pressed.connect(_on_choose_card.bind(i))
			card_button.disabled = bool(data.get("upgrade_shards_collected", false))
			if card_button.disabled:
				card_button.modulate.a = 0.45
			cards_row.add_child(card_button)
			_entrance_cards.append(card_button)
			FormalUI.card_face(card_button, scene_card)
		var upgrade_button: Button = scene_panel.get_node("Content/Actions/UpgradeButton")
		var skip_button: Button = scene_panel.get_node("Content/Actions/SkipButton")
		var enchant_button: Button = scene_panel.get_node("Content/Actions/EnchantButton")
		upgrade_button.text = "升级卡牌" if RunState.can_spend_upgrade_shards() else "收集升级碎片（已有：%d）" % RunState.upgrade_shards
		upgrade_button.tooltip_text = "已有 %d 个升级碎片；每 %d 个可升级一张卡牌。" % [RunState.upgrade_shards, RunState.upgrade_shard_cost()]
		upgrade_button.disabled = bool(data.get("upgrade_shards_collected", false)) and not RunState.can_spend_upgrade_shards()
		enchant_button.disabled = bool(data.get("upgrade_shards_collected", false))
		if bool(data.get("upgrade_shards_collected", false)):
			scene_panel.get_node("Content/Prompt").text = "碎片已收集，可升级卡牌或保留碎片离开"
		else:
			scene_panel.get_node("Content/Prompt").text = "选择卡牌，或消耗碎片升级：" if RunState.can_spend_upgrade_shards() else "选择卡牌，或收集升级碎片："
		if not upgrade_button.pressed.is_connected(_on_upgrade_pressed):
			upgrade_button.pressed.connect(_on_upgrade_pressed)
		skip_button.text = "离开"
		if not skip_button.pressed.is_connected(_on_skip):
			skip_button.pressed.connect(_on_skip)
		var reward_tier: StringName = StringName(data.get("tier", "combat"))
		enchant_button.visible = (reward_tier == &"elite" or reward_tier == &"boss") and RewardBuilder.can_any_card_enchant()
		if enchant_button.visible and not enchant_button.pressed.is_connected(_on_enchant_pressed):
			enchant_button.pressed.connect(_on_enchant_pressed)
		_fit_main_panel.call_deferred()
		return


func _fit_main_panel() -> void:
	# 保留页头和按钮原尺寸，仅将原中间区缩短 40%。
	await get_tree().process_frame
	if not has_node("Dim/Center/MainPanel"):
		return
	var panel: Control = get_node("Dim/Center/MainPanel")
	var content: VBoxContainer = panel.get_node("Content")
	var cards: ScrollContainer = content.get_node("CardScroll")
	var other_height := 0.0
	var visible_count := 0
	for child in content.get_children():
		if child is Control and child.visible:
			visible_count += 1
			if child != cards:
				other_height += child.get_combined_minimum_size().y
	other_height += maxi(0, visible_count - 1) * content.get_theme_constant("separation")
	var margins := content.offset_top - content.offset_bottom
	var original_middle := maxf(480.0, 1140.0 - margins - other_height)
	cards.custom_minimum_size.y = original_middle * 0.6
	panel.custom_minimum_size.y = margins + other_height + cards.custom_minimum_size.y

func _build_upgrade() -> void:
	if not can_interact() or is_instance_valid(_overview) or is_instance_valid(_upgrade_picker): return
	if not RunState.can_spend_upgrade_shards(): return
	_upgrade_picker = preload("res://scripts/ui/CardUpgradePicker.gd").new()
	_upgrade_picker.confirmed.connect(_on_upgrade_card)
	add_child(_upgrade_picker)


func _on_choose_card(i: int) -> void:
	if not _can_choose_reward() or bool(data.get("upgrade_shards_collected", false)):
		return
	var cards: Array = data.get("cards", [])
	if i < 0 or i >= cards.size():
		return
	var cid: StringName = StringName(cards[i].get("id", ""))
	var upgraded := bool(cards[i].get("upgraded", false))
	var result := CardAcquireService.acquire_free_card(cid, upgraded, &"reward", {"card_name": cards[i].get("name", "")})
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
	if not _can_choose_reward():
		return
	if RunState.can_spend_upgrade_shards():
		_build_upgrade()
		return
	if bool(data.get("upgrade_shards_collected", false)):
		return
	var amount := RunState.collect_upgrade_shards()
	if amount <= 0:
		return
	data["upgrade_shards_collected"] = true
	_log_reward("升级碎片 +%d（已有：%d）" % [amount, RunState.upgrade_shards])
	if RunState.can_spend_upgrade_shards():
		RunState.pending_reward_data = data
		SaveManager.save_game()
		_build_main()
	else:
		_finish()


func _can_choose_reward() -> bool:
	return (can_interact() and not is_instance_valid(_overview)
		and not is_instance_valid(_upgrade_picker)
		and RunState.pending_card_acquisition.is_empty()
		and String(data.get("stage", "cards")) == "cards")


func _on_upgrade_card(i: int, snapshot: Dictionary = {}) -> void:
	if not can_interact() or is_instance_valid(_overview) or String(data.get("stage", "cards")) != "cards":
		return
	if not snapshot.is_empty() and (i < 0 or i >= RunState.deck.size() or RunState.deck[i] != snapshot):
		return
	if RunState.upgrade_card_with_shards_at(i):
		_log_reward("卡牌已升级")
		_finish()


func _on_skip() -> void:
	if not _can_choose_reward():
		return
	_log_reward("跳过奖励")
	_finish()


func _finish() -> void:
	if not can_interact(): return
	if data.has("boss_relic_choices") and String(data.get("stage", "cards")) == "cards":
		data["stage"] = "boss_relic"
		RunState.pending_reward_data = data
		SaveManager.save_game()
		_show_boss_relic_choices()
		return
	data["stage"] = "complete"
	RunState.pending_reward_data = data
	RunState.pending_post_reward = true
	SaveManager.save_game()
	_finish_transition(on_done, true)


func _show_boss_relic_choices() -> void:
	_entrance_cards.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var panel := preload("res://scenes/rewards/BossRelicChoice.tscn").instantiate()
	panel.setup(data.get("boss_relic_choices", []))
	panel.chosen.connect(_on_boss_relic_chosen)
	add_child(panel)


func _on_boss_relic_chosen(relic_id: StringName) -> void:
	if not can_interact() or String(data.get("stage", "")) != "boss_relic": return
	if relic_id != &"":
		if not data.get("boss_relic_choices", []).has(String(relic_id)): return
		if not RunState.add_relic(relic_id): return
	data["boss_relic_selected"] = String(relic_id)
	data["stage"] = "complete"
	_finish()


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
	if not _can_choose_reward() or bool(data.get("upgrade_shards_collected", false)):
		return
	_build_enchant()


## 附魔套用后展示效果面板，玩家点「完成」再结算（避免看不到附魔效果）。
func _show_enchant_result(cd: CardData, ed: Variant) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	FormalUI.map_backdrop(self)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 540)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 32
	v.offset_right = -32
	v.offset_top = 32
	v.offset_bottom = -32
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
		remove_child(c)
		c.queue_free()
	FormalUI.map_backdrop(self)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(620, 1000)
	panel.add_theme_stylebox_override("panel", FormalUI.stone("bd_main_zhanLiPin.png"))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 32
	v.offset_right = -32
	v.offset_top = 32
	v.offset_bottom = -32
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
		if cd == null or not RunState.can_receive_run_enchant(entry):
			continue
		var eid: StringName = RewardBuilder.roll_enchant_for_card(cd)
		if eid == &"":
			continue
		any = true
		var ed = GameData.get_enchant(eid)
		var ename: String = ed.name if ed != null else String(eid)
		var desc: String = ed.description if (ed != null and ed.description != "") else "（无效果描述）"
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 150)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_color_override("font_color", DARK)
		b.text = "%s\n附魔：%s\n效果：%s" % [cd.name, ename, desc]
		b.add_theme_font_size_override("font_size", 20)
		if ed != null and ed.icon != "":
			b.icon = GameData.icon_texture(ed.icon)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_enchant_card.bind(i, eid))
		col.add_child(b)
	if not any:
		v.add_child(_label("（没有可附魔的卡牌）", 22, RED))
	var back := Button.new()
	back.text = "返回"
	back.custom_minimum_size = Vector2(300, 60)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(_build_main)
	v.add_child(back)


func _on_enchant_card(i: int, eid: StringName) -> void:
	if not can_interact() or is_instance_valid(_overview):
		return
	CardMutation.confirm_run_replace(self, i, eid, _commit_enchant_card.bind(i, eid))

func _commit_enchant_card(i: int, eid: StringName) -> void:
	if i < 0 or i >= RunState.deck.size():
		_finish()
		return
	var entry: Dictionary = RunState.deck[i]
	var cd: CardData = GameData.get_card(StringName(entry["id"]))
	if cd == null:
		_finish()
		return
	if eid == &"":
		_finish()
		return
	if RunState.add_enchant_to_card_at(i, eid):
		var ed = GameData.get_enchant(eid)
		_log_reward("卡牌 %s 已附魔：%s" % [cd.name, ed.name if ed != null else eid])
		_show_enchant_result(cd, ed)
	else:
		_finish()


func prepare_entrance() -> void:
	_entrance_prepared = true
	for card in _entrance_cards:
		card.modulate.a = 0.0
		card.scale = Vector2(0.97, 0.97)

func play_entrance() -> Tween:
	if not _entrance_prepared or _entrance_cards.is_empty():
		return null
	_entrance_prepared = false
	var tween := create_tween().set_parallel(true)
	tween.set_ignore_time_scale(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in _entrance_cards.size():
		var card := _entrance_cards[i]
		card.pivot_offset = card.size * 0.5
		tween.tween_property(card, "modulate:a", 1.0, 0.16).set_delay(i * 0.03)
		tween.tween_property(card, "scale", Vector2.ONE, 0.16).set_delay(i * 0.03)
	return tween

func play_transition_entrance() -> Tween:
	if is_instance_valid(_overview):
		return null
	return play_entrance()

func focus_transition_target() -> void:
	TransitionManager.focus_panel(_overview if is_instance_valid(_overview) else self)

func _on_overview_continued() -> void:
	_overview = null
	prepare_entrance()
	TransitionManager.reveal_content(self)
