extends VBoxContainer
## 药釉坊原院落下的窑变页；结果收据随永久档案保存。

var card_ids: Array = []
var _revision := 0
var _busy := false
var _message := ""
var _selected_id := ""
var _tiles: Dictionary = {}
var _preview: Control

func _ready() -> void:
	$Scroll/Body.move_child($Scroll/Body/Result, 0)
	card_ids = CardMutation.config().get("card_directions", {}).keys()
	for cid in card_ids:
		var cd := GameData.get_card(StringName(cid))
		if cd == null: continue
		var tile := preload("res://scenes/town/MutationCardTile.tscn").instantiate()
		tile.get_node("Column/Preview").add_child(FormalUI.card_visual(_card_entry(String(cid))))
		tile.get_node("Select").pressed.connect(select_card.bind(String(cid)))
		$Gallery/Cards.add_child(tile)
		_tiles[String(cid)] = tile
	$Selection/Back.pressed.connect(show_gallery)
	$Actions/Fire.pressed.connect(_fire)
	$Actions/Accept.pressed.connect(_resolve.bind(true))
	$Actions/Keep.pressed.connect(_resolve.bind(false))
	SignalBus.profile_changed.connect(refresh)
	refresh()

func _card_entry(cid: String) -> Dictionary:
	var cd := GameData.get_card(StringName(cid))
	return {"id": cid, "display_name": cd.name, "cost": cd.cost, "enchants": [], "enchant_active": false}

func select_card(cid: String) -> void:
	if _busy or not CardMutation.pending().is_empty() or not card_ids.has(cid): return
	_selected_id = cid
	_message = ""
	$Scroll.scroll_vertical = 0
	refresh()
	$Selection/Back.grab_focus()

func show_gallery() -> void:
	if _busy or not CardMutation.pending().is_empty(): return
	var previous := _selected_id
	_selected_id = ""
	_message = ""
	refresh()
	if _tiles.has(previous): _tiles[previous].get_node("Select").grab_focus()

func _refresh_cards() -> void:
	for cid in _tiles:
		var tile: Control = _tiles[cid]
		var status: Label = tile.get_node("Column/Status")
		var error := CardMutation.research_error(cid)
		var current := CardMutation.pattern(cid)
		status.text = "可重铸" if current != "" else "可附魔"
		if not CardMutation.unlocked(): status.text = "需药釉研究 I"
		elif not GameData.is_card_unlocked(StringName(cid)): status.text = "配方未解锁"
		elif not ProfileState.is_card_discovered(StringName(cid)): status.text = "尚未获得"
		status.add_theme_color_override("font_color", Color("a8dbaa") if error.is_empty() else Color("bbb5aa"))
		tile.get_node("Column/Preview").modulate = Color.WHITE if error.is_empty() else Color(0.65, 0.65, 0.65)
		tile.get_node("Select").tooltip_text = error if error != "" else "点击查看附魔方向与费用"

func refresh() -> void:
	if not is_node_ready() or card_ids.is_empty(): return
	_revision = CardMutation.revision()
	var receipt := CardMutation.pending()
	if not receipt.is_empty():
		_selected_id = String(receipt.get("card_id", ""))
	_refresh_cards()
	var detail := _selected_id != ""
	$Gallery.visible = not detail
	$Selection.visible = detail
	$Scroll.visible = detail
	$Actions.visible = detail
	$Hint.text = "共 %d 张卡牌 · 点击卡面查看附魔\n暗色卡牌可查看条件，附魔需完成研究并获得过该牌。" % card_ids.size()
	if not detail: return
	var cid := _selected_id
	var cd := GameData.get_card(StringName(cid))
	var current := CardMutation.pattern(cid)
	var error := CardMutation.research_error(cid)
	$Selection/Back.disabled = not receipt.is_empty() or _busy
	$Selection/Title.text = cd.name if cd != null else cid
	if is_instance_valid(_preview):
		$Scroll/Body/Overview/Preview.remove_child(_preview)
		_preview.queue_free()
	_preview = FormalUI.card_visual(_card_entry(cid))
	$Scroll/Body/Overview/Preview.add_child(_preview)
	$Scroll/Body/Overview/Base.text = "%s · %d 费\n%s" % [cd.name, cd.cost, cd.description] if cd != null else "卡牌资料暂不可用"
	var descriptions: Array[String] = []
	var outcome_count := CardMutation.directions(cid).size() - (1 if current != "" else 0)
	for eid in CardMutation.directions(cid):
		var ed := GameData.get_enchant(StringName(eid))
		if ed != null: descriptions.append("%s%s\n%s" % ["● 当前 · " if String(eid) == current else "○ 概率 1/%d · " % outcome_count, ed.name, ed.description])
	$Scroll/Body/Directions.text = "\n\n".join(descriptions)
	$Scroll/Body/Status.text = _message if _message != "" else error
	$Scroll/Body/Status.visible = $Scroll/Body/Status.text != ""
	$Actions/Fire.visible = receipt.is_empty()
	$Actions/Fire.text = "%s · %d 火种" % ["献祭附魔" if current == "" else "重新附魔", CardMutation.price(cid)]
	$Actions/Fire.disabled = _busy or error != "" or ProfileState.fireseed_balance < CardMutation.price(cid)
	$Actions/Accept.visible = not receipt.is_empty()
	$Actions/Accept.text = "收下附魔" if String(receipt.get("old_id", "")) == "" else "采用新附魔"
	$Actions/Keep.visible = not receipt.is_empty() and String(receipt.get("old_id", "")) != ""
	$Actions/Accept.disabled = _busy
	$Actions/Keep.disabled = _busy
	$Scroll/Body/Result.visible = not receipt.is_empty()
	if not receipt.is_empty():
		var result := GameData.get_enchant(StringName(receipt.get("new_id", "")))
		$Scroll/Body/Result.text = "本炉结果 · %s\n%s\n火种已消耗。保留原附魔或采用新附魔均不退款。" % [result.name, result.description] if result != null else "结果资料暂不可用，已保留收据。"
		if result != null and String(receipt.get("old_id", "")) == "":
			$Scroll/Body/Result.text = "本炉结果 · %s\n%s\n已保存永久配方，下次新冒险获得本牌时继承。" % [result.name, result.description]
		$Scroll.set_deferred("scroll_vertical", 0)
	$Hint.text = "新冒险获得同名牌时自带附魔，每战最多配印 %d 张。\n重铸不重复当前方向；接受或保留均消耗火种。" % RunState.enchant_limit()

func _fire() -> void:
	if _busy or _selected_id == "": return
	_busy = true
	var reroll := CardMutation.pattern(_selected_id) != ""
	_message = CardMutation.begin(_selected_id, _revision)
	SignalBus.sound_requested.emit((&"town_reroll" if reroll else &"town_enchant") if _message.is_empty() else &"ui_deny")
	_busy = false
	refresh()

func _resolve(accept: bool) -> void:
	if _busy: return
	_busy = true
	_message = CardMutation.resolve(accept, _revision)
	if _message == "": _message = "配方已保存，下次出发后生效。"
	_busy = false
	refresh()
