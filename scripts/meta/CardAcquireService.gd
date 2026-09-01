extends Node
## Autoload: CardAcquireService —— 所有永久卡牌获取共用容量预检查与满库事务。

const PLACEMENT := &"deck_capacity_expand"
const RESULT_ACQUIRED := &"acquired"
const RESULT_FULL := &"full"
const RESULT_ABANDONED := &"abandoned"
const RESULT_FAILED := &"failed"
const RESULT_INVALID := &"invalid"

var _prompt: CanvasLayer


func _ready() -> void:
	AdRewardCoordinator.register_placement_handler(PLACEMENT, _is_expand_eligible, _grant_capacity_expand)
	SignalBus.ad_reward_resolved.connect(_on_ad_reward_resolved)
	SignalBus.run_loaded.connect(_on_run_loaded)


func acquire_free_card(
	card_id: StringName,
	upgraded: bool,
	source_id: StringName,
	context: Dictionary = {}
) -> StringName:
	if not _valid_card(card_id) or source_id == &"" or not RunState.pending_card_acquisition.is_empty():
		return RESULT_INVALID
	if RunState.can_add_permanent_card():
		if not RunState.add_card(card_id, upgraded):
			return RESULT_FAILED
		if RunState.is_active:
			SaveManager.save_game()
		return RESULT_ACQUIRED
	return _begin_pending({
		"kind": "free",
		"card_id": String(card_id),
		"upgraded": upgraded,
		"source_id": String(source_id),
		"context": context.duplicate(true),
	})


func acquire_shop_card(
	shop_id: String,
	slot_index: int,
	card_id: StringName,
	price: int
) -> StringName:
	if shop_id.is_empty() or slot_index < 0 or price < 0 or not _valid_card(card_id):
		return RESULT_INVALID
	if not RunState.pending_card_acquisition.is_empty():
		return RESULT_INVALID
	if RunState.can_add_permanent_card():
		return RESULT_ACQUIRED if ShopInventorySystem.commit_card_purchase(shop_id, slot_index, card_id, price) else RESULT_FAILED
	return _begin_pending({
		"kind": "shop",
		"card_id": String(card_id),
		"upgraded": false,
		"source_id": "shop",
		"context": {
			"shop_id": shop_id,
			"slot_index": slot_index,
			"price": price,
		},
	})


func is_expand_configured() -> bool:
	var config := GameData.ad_placement_config(PLACEMENT)
	for field in ["slots_per_view", "max_per_run"]:
		var value: Variant = config.get(field, null)
		if value == null or not (value is int or value is float) or int(value) <= 0:
			return false
	return true


func can_offer_expand() -> bool:
	return AdRewardCoordinator.can_offer(PLACEMENT, _pending_context())


func request_expand() -> String:
	var request_id := AdRewardCoordinator.request_reward(PLACEMENT, _pending_context())
	if request_id.is_empty():
		show_pending_prompt()
	else:
		_set_prompt_buttons_disabled(true)
	return request_id


func abandon_pending() -> bool:
	if RunState.pending_card_acquisition.is_empty():
		return false
	var acquisition := RunState.pending_card_acquisition.duplicate(true)
	RunState.pending_card_acquisition.clear()
	if RunState.is_active:
		SaveManager.save_game()
	_close_prompt()
	SignalBus.card_acquisition_resolved.emit(acquisition, RESULT_ABANDONED)
	return true


func show_pending_prompt() -> void:
	if RunState.pending_card_acquisition.is_empty() or get_tree().current_scene == null:
		return
	_close_prompt()
	_prompt = CanvasLayer.new()
	_prompt.layer = 180
	_prompt.name = "CardCapacityPrompt"
	get_tree().current_scene.add_child(_prompt)
	var cover := ColorRect.new()
	cover.color = Color(0.04, 0.03, 0.03, 0.88)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_prompt.add_child(cover)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prompt.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 520)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	var acquisition: Dictionary = RunState.pending_card_acquisition
	var card: CardData = GameData.get_card(StringName(String(acquisition.get("card_id", ""))))
	var title := _prompt_label("牌库已满", 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var capacity := _prompt_label(
		"当前牌库：%d / %d" % [RunState.deck.size(), RunState.current_deck_capacity()],
		28
	)
	capacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(capacity)
	var detail := _prompt_label(
		"观看广告可增加本局牌库容量，\n然后继续获得「%s」。" % (card.name if card != null else acquisition.get("card_id", "")),
		26
	)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	var watch := Button.new()
	watch.name = "WatchAdButton"
	watch.text = "观看广告 · 增加容量并领取"
	watch.custom_minimum_size = Vector2(540, 78)
	watch.add_theme_font_size_override("font_size", 24)
	watch.disabled = not can_offer_expand()
	watch.tooltip_text = "当前无可用广告或本局扩容次数已用尽" if watch.disabled else "扩容量只在当前 Run 有效"
	watch.pressed.connect(request_expand)
	column.add_child(watch)
	var abandon := Button.new()
	abandon.name = "AbandonButton"
	abandon.text = "放弃这张卡"
	abandon.custom_minimum_size = Vector2(540, 72)
	abandon.add_theme_font_size_override("font_size", 24)
	abandon.pressed.connect(abandon_pending)
	column.add_child(abandon)


func _begin_pending(acquisition: Dictionary) -> StringName:
	acquisition["token"] = "%s:card:%d" % [RunState.run_id, Time.get_ticks_usec()]
	RunState.pending_card_acquisition = acquisition
	if RunState.is_active and not SaveManager.save_game():
		RunState.pending_card_acquisition.clear()
		return RESULT_FAILED
	SignalBus.card_acquisition_blocked.emit(acquisition.duplicate(true))
	show_pending_prompt.call_deferred()
	return RESULT_FULL


func _pending_context() -> Dictionary:
	return {
		"run_id": RunState.run_id,
		"acquisition_token": String(RunState.pending_card_acquisition.get("token", "")),
	}


func _is_expand_eligible(context: Dictionary) -> bool:
	if not is_expand_configured() or not RunState.is_active or RunState.pending_card_acquisition.is_empty():
		return false
	if String(context.get("run_id", "")) != RunState.run_id:
		return false
	if String(context.get("acquisition_token", "")) != String(RunState.pending_card_acquisition.get("token", "")):
		return false
	var config := GameData.ad_placement_config(PLACEMENT)
	return not RunState.can_add_permanent_card() and RunState.deck_capacity_ad_uses < int(config["max_per_run"])


func _grant_capacity_expand(transaction_id: String, context: Dictionary) -> void:
	if RunState.has_run_ad_transaction(transaction_id):
		_resume_pending_after_expand()
		ProfileState.complete_reward_transaction(transaction_id)
		return
	if not _is_expand_eligible(context):
		return
	var config := GameData.ad_placement_config(PLACEMENT)
	var old_bonus := RunState.run_ad_deck_capacity_bonus
	var old_uses := RunState.deck_capacity_ad_uses
	var old_transactions := RunState.ad_reward_transaction_ids.duplicate()
	RunState.run_ad_deck_capacity_bonus += int(config["slots_per_view"])
	RunState.deck_capacity_ad_uses += 1
	RunState.record_run_ad_transaction(transaction_id)
	if not SaveManager.save_game():
		RunState.run_ad_deck_capacity_bonus = old_bonus
		RunState.deck_capacity_ad_uses = old_uses
		RunState.ad_reward_transaction_ids.assign(old_transactions)
		return
	_resume_pending_after_expand()
	ProfileState.complete_reward_transaction(transaction_id)


func _resume_pending_after_expand() -> void:
	if RunState.pending_card_acquisition.is_empty():
		return
	var acquisition := RunState.pending_card_acquisition.duplicate(true)
	var card_id := StringName(String(acquisition.get("card_id", "")))
	var acquired := false
	match String(acquisition.get("kind", "")):
		"free":
			acquired = RunState.add_card(card_id, bool(acquisition.get("upgraded", false)))
		"shop":
			var context: Dictionary = acquisition.get("context", {})
			acquired = ShopInventorySystem.commit_card_purchase(
				String(context.get("shop_id", "")),
				int(context.get("slot_index", -1)),
				card_id,
				int(context.get("price", -1))
			)
	RunState.pending_card_acquisition.clear()
	if RunState.is_active:
		SaveManager.save_game()
	_close_prompt()
	SignalBus.card_acquisition_resolved.emit(acquisition, RESULT_ACQUIRED if acquired else RESULT_FAILED)


func _on_ad_reward_resolved(_transaction_id: String, placement_id: StringName, result: StringName) -> void:
	if placement_id == PLACEMENT and result in [AdService.RESULT_SKIPPED, AdService.RESULT_FAILED, AdService.RESULT_CLOSED, &"pending"]:
		show_pending_prompt.call_deferred()


func _on_run_loaded() -> void:
	if RunState.pending_card_acquisition.is_empty():
		return
	await get_tree().process_frame
	show_pending_prompt()


func _set_prompt_buttons_disabled(disabled: bool) -> void:
	if not is_instance_valid(_prompt):
		return
	for button_name in ["WatchAdButton", "AbandonButton"]:
		var button := _prompt.find_child(button_name, true, false) as Button
		if button != null:
			button.disabled = disabled


func _close_prompt() -> void:
	if is_instance_valid(_prompt):
		_prompt.queue_free()
	_prompt = null


func _valid_card(card_id: StringName) -> bool:
	return card_id != &"" and GameData.get_card(card_id) != null


func _prompt_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	return label
