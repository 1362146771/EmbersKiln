extends "res://scripts/core/NodePanel.gd"
## 点击木箱后随机领取一件奖励；动画与领取共用一次性锁。

const OPEN_TEXTURE := preload("res://art/ui/formal/chest_open.png")
var on_done: Callable
var _claimed := false
var _finished := false
var _reward_ready := false
var _built := false
var _chest: TextureButton
var _hint: Label
var _result_panel: VBoxContainer
var _result_title: Label
var _result_icon: TextureRect
var _result_card: Control
var _result_name: Label
var _result_description: Label
var _continue_button: Button
var _pending_card: Dictionary = {}
var _tween: Tween


func setup(done: Callable) -> void:
	on_done = done
	_build_main()


func _ready() -> void:
	SignalBus.card_acquisition_resolved.connect(_on_card_acquisition_resolved)
	_build_main()


func _exit_tree() -> void:
	if SignalBus.card_acquisition_resolved.is_connected(_on_card_acquisition_resolved):
		SignalBus.card_acquisition_resolved.disconnect(_on_card_acquisition_resolved)
	if _tween != null:
		_tween.kill()


func _build_main() -> void:
	if _built:
		return
	_built = true
	if not has_node("Layout"):
		FormalUI.restore_layout(self, "res://scenes/map/TreasureUI.tscn")
	_chest = get_node("Layout/Chest")
	_hint = get_node("Layout/Panel/Content/Hint")
	_result_panel = get_node("Layout/Panel/Content/Result")
	_result_title = _result_panel.get_node("Title")
	_result_icon = _result_panel.get_node("Icon")
	_result_name = _result_panel.get_node("Name")
	_result_description = _result_panel.get_node("Description")
	_continue_button = _result_panel.get_node("Continue")
	_chest.resized.connect(_update_pivot)
	_chest.button_down.connect(_on_chest_down)
	_chest.button_up.connect(_on_chest_up)
	_chest.pressed.connect(_on_open)
	_continue_button.pressed.connect(_finish)
	_update_pivot()


func _update_pivot() -> void:
	_chest.pivot_offset = Vector2(_chest.size.x * 0.5, _chest.size.y * 0.9)


func _on_chest_down() -> void:
	if not can_interact():
		return
	if not _claimed:
		_scale_to(Vector2(1.06, 0.93), 0.10)


func _on_chest_up() -> void:
	if not can_interact():
		return
	if not _claimed:
		_scale_to(Vector2.ONE, 0.16)


func _scale_to(value: Vector2, duration: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_chest, "scale", value, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_open() -> void:
	if not can_interact():
		return
	if _claimed or _finished or not is_inside_tree() or is_queued_for_deletion():
		return
	if GameData.balance.get("treasure", {}).get("reward_weights", {}).is_empty():
		_hint.text = "暂时无法打开宝箱。"
		return
	_claimed = true
	_chest.disabled = true
	_hint.text = "正在打开……"
	_scale_to(Vector2(1.08, 0.88), 0.12)
	_tween.tween_callback(func(): _chest.texture_normal = OPEN_TEXTURE)
	_tween.tween_property(_chest, "scale", Vector2(0.94, 1.08), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_chest, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_grant_random_reward)


func _grant_random_reward() -> void:
	_grant_kind(String(RewardBuilder.roll_treasure_kind()))


func _grant_kind(kind: String) -> void:
	match kind:
		"relic":
			var rid: StringName = RewardBuilder.roll_treasure_relic()
			if rid == &"":
				_grant_card("遗物已全部拥有，改为获得卡牌。")
				return
			RunState.add_relic(rid)
			var relic := GameData.get_relic(rid)
			_show_result("获得遗物", relic.name, relic.description, relic.icon)
			preload("res://scripts/ui/RelicInfo.gd").attach(_result_icon, rid)
			preload("res://scripts/ui/RelicInfo.gd").attach(_result_name, rid)
		"potion":
			var pid: StringName = RewardBuilder.roll_treasure_potion()
			if pid == &"":
				_grant_card("药水槽已满或暂无可用药水，改为获得卡牌。")
				return
			RunState.add_potion(pid)
			var potion := GameData.get_potion(pid)
			_show_result("获得药水", potion.name, potion.description, potion.icon)
		"card":
			_grant_card()
		"gold":
			var before := RunState.gold
			RunState.add_gold(RewardBuilder.roll_treasure_gold())
			_show_result("获得金币", "%d 金币" % (RunState.gold - before), "金币已放入钱袋，可在商店购买物品。", "res://art/ui/formal/icon_gold(需ai改.png")
		_:
			_show_result("宝箱已打开", "暂无可领取的奖励", "宝箱奖励类型暂不可用。")


func _grant_card(reason: String = "") -> void:
	var source := StringName(GameData.balance.get("treasure", {}).get("card_source", "treasure"))
	_pending_card = RewardBuilder.roll_single_card(source)
	if _pending_card.is_empty():
		_show_result("宝箱已打开", "暂无可领取的奖励", reason + "\n卡牌池为空。")
		return
	_pending_card["reason"] = reason
	var result := CardAcquireService.acquire_free_card(StringName(_pending_card.id), bool(_pending_card.get("upgraded", false)), &"treasure", {"card_name": _pending_card.get("name", "")})
	if result == CardAcquireService.RESULT_FULL:
		_hint.text = "牌库已满，请先处理卡牌领取。"
	elif result == CardAcquireService.RESULT_ACQUIRED:
		_show_card_result()
	else:
		_show_result("宝箱已打开", "卡牌未领取", "当前无法领取这张卡牌。")


func _show_card_result() -> void:
	var card := GameData.get_card(StringName(_pending_card.get("id", "")))
	var upgraded := bool(_pending_card.get("upgraded", false))
	_show_result("获得卡牌", card.name + ("+" if upgraded else ""), String(_pending_card.get("reason", "")) + "\n" + card.get_description(upgraded), card.art)
	_result_icon.hide()
	_result_name.hide()
	_result_card = FormalUI.card_visual({"id": card.id, "name": card.name,
		"upgraded": upgraded, "cost": card.resolved_cost(1 if upgraded else 0)})
	_result_card.custom_minimum_size = Vector2(224, 300)
	_result_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_result_card.get_node("CardTitle").add_theme_font_size_override("font_size", 20)
	_result_panel.add_child(_result_card)
	_result_panel.move_child(_result_card, 1)
	_chest.custom_minimum_size = Vector2(340, 340)
	_pending_card.clear()


func _on_card_acquisition_resolved(acquisition: Dictionary, result: StringName) -> void:
	if acquisition.get("source_id", "") != "treasure" or _pending_card.is_empty():
		return
	if result == CardAcquireService.RESULT_ACQUIRED:
		_show_card_result()
	else:
		_show_result("宝箱已打开", "已放弃卡牌", "这只宝箱已经打开，继续探索吧。")
	_pending_card.clear()


func _show_result(title: String, reward_name: String, description: String, icon: String = "") -> void:
	if is_instance_valid(_result_card):
		_result_card.hide()
		_result_card.queue_free()
	_result_name.show()
	_result_title.text = title
	_result_name.text = reward_name
	_result_description.text = description.strip_edges()
	_result_icon.texture = GameData.icon_texture(icon)
	_result_icon.visible = _result_icon.texture != null
	_hint.hide()
	_result_panel.show()
	_reward_ready = true
	_continue_button.grab_focus()
	if RunState.is_active:
		SaveManager.save_game()


func _finish() -> void:
	if not can_interact() or not is_inside_tree():
		return
	if _finished or not _reward_ready:
		return
	_finished = true
	_finish_transition(on_done)
