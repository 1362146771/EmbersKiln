extends Control
## 玩家与陶婆交谈、领取馈赠，告别后进入原风箱台广告准备页。
const MAP_PLAY := "res://scenes/map/MapPlay.tscn"
const MAIN_MENU := "res://scenes/main/MainMenu.tscn"
const AD_PREPARATION := "res://scenes/main/PreRunAdPreparation.tscn"
const Browser := preload("res://scripts/ui/CardBrowser.gd")
const UpgradePicker := preload("res://scripts/ui/CardUpgradePicker.gd")
var _talking := false
var _leaving := false
var _transition_destination: PackedScene
var _picker: CanvasLayer


func _ready() -> void:
	PauseManager.hide_pause_button()
	%SpeechBubble.resized.connect(_place_tail)
	_place_tail.call_deferred()
	%TalkButton.pressed.connect(_talk)
	%DepartButton.pressed.connect(_depart)
	%BackButton.pressed.connect(_back)
	%RetryButton.pressed.connect(_prepare)
	if not RunState.is_active:
		_route_scene(MAIN_MENU)
		return
	_prepare()


func _place_tail() -> void:
	%BubbleTail.position = Vector2(%SpeechBubble.size.x * 0.65, %SpeechBubble.size.y - 4.0)


func _prepare() -> void:
	if not GrannyStory.prepare():
		%Status.show()
		%Status.text = "无法保存开场奖励，请重试。"
		%RetryButton.show()
		%TalkButton.disabled = true
		%DepartButton.disabled = true
		return
	%RetryButton.hide()
	%TalkButton.disabled = false
	PreRunBuffSystem.prepare_offer()
	if not GrannyStory.needs_opening():
		_route_scene(AD_PREPARATION if PreRunBuffSystem.needs_preparation() else MAP_PLAY)
		return
	_talking = _talking or GrannyStory.chosen()
	_build()


func _talk() -> void:
	if _leaving: return
	SignalBus.sound_requested.emit(&"granny_dialogue")
	_talking = true
	_build()


func _build() -> void:
	for child in %RewardOptions.get_children():
		%RewardOptions.remove_child(child)
		child.queue_free()
	var chosen := GrannyStory.chosen()
	%Greeting.text = String(RunState.granny_opening.get("line", "选一样带上，路上用得着。")) if _talking else "你来了。\n又要往窑里去了？"
	%SectionTitle.text = "选择馈赠" if _talking and not chosen else "临行 · 陶婆"
	%TalkButton.visible = not _talking
	%RewardOptions.visible = _talking and not chosen
	%DepartButton.visible = chosen
	%DepartButton.disabled = not chosen or _leaving
	%Receipt.visible = chosen
	%Spacer.visible = not _talking or chosen
	%Status.text = ""
	%Status.visible = chosen
	if chosen:
		var receipt := GrannyStory.offer_for(String(RunState.granny_opening["chosen"]))
		%Greeting.text = "拿稳了。\n添些薪再走，路上小心。"
		# Old receipts may contain names; always render the current generic description.
		%Receipt.text = "已获得 · %s\n%s" % [receipt.get("title", "馈赠"), GrannyStory.describe(receipt)]
		%Status.text = "生命 %d/%d · 金币 %d" % [RunState.hp, RunState.max_hp, RunState.gold]
	elif _talking:
		for offer in RunState.granny_opening.get("offers", []):
			var button := Button.new()
			button.text = "[%s]\n%s" % [offer["title"], GrannyStory.describe(offer)]
			button.custom_minimum_size = Vector2(0, 116)
			button.size_flags_vertical = Control.SIZE_EXPAND_FILL
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.add_theme_font_size_override("font_size", 22)
			button.set_meta("reward_id", String(offer["id"]))
			var reason := GrannyStory.blocked_reason(offer)
			button.disabled = not reason.is_empty()
			button.tooltip_text = reason
			if not reason.is_empty(): button.text += "\n" + reason
			button.pressed.connect(_choose.bind(String(offer["id"])))
			%RewardOptions.add_child(button)


func _choose(id: String) -> void:
	if not _talking or _leaving or GrannyStory.chosen() or is_instance_valid(_picker): return
	var offer := GrannyStory.offer_for(id)
	var kind := String(offer.get("kind", ""))
	if kind == "upgrade":
		_picker = UpgradePicker.new()
		_picker.confirmed.connect(_confirm_target.bind(id))
		add_child(_picker)
	elif kind in ["remove", "transform"]:
		_picker = Browser.new()
		_picker.setup(String(offer["title"]), GrannyStory.describe(offer), RunState.deck, true,
			"确认选择", "确认后消耗本局免费馈赠机会；取消可重新选择其他奖励。",
			"原卡会替换为一张随机职业牌，不保留原卡升级与附魔。" if kind == "transform" else "该卡会从本局牌组中永久移除。")
		_picker.confirmed.connect(_confirm_target.bind(id))
		add_child(_picker)
	else:
		_apply(id)


func _confirm_target(index: int, snapshot: Dictionary, id: String) -> void:
	_apply(id, index, snapshot)


func _apply(id: String, index: int = -1, snapshot: Dictionary = {}) -> void:
	var granted := GrannyStory.claim(id, index, snapshot)
	_build()
	if not granted:
		%Status.show()
		%Status.text = "未能领取：存档或牌组发生变化，请重试。"


func _depart() -> void:
	if _leaving or TransitionManager.is_transitioning or is_instance_valid(_picker): return
	if not GrannyStory.chosen(): return
	if GrannyStory.finish():
		_leaving = true
		_route_scene(AD_PREPARATION)
	else:
		%Status.text = "保存失败，请重试。"


func _back() -> void:
	if _leaving or TransitionManager.is_transitioning: return
	if is_instance_valid(_picker):
		_picker.queue_free()
		return
	if SaveManager.save_game():
		_leaving = true
		_route_scene(MAIN_MENU)
	else:
		%Status.show()
		%Status.text = "保存失败，请重试。"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST: _back()


func _route_scene(path: String) -> void:
	if TransitionManager.is_transitioning: _transition_destination = load(path) as PackedScene
	else: TransitionManager.change_scene_to_file.call_deferred(path)


func take_transition_destination() -> PackedScene:
	var next := _transition_destination
	_transition_destination = null
	return next
