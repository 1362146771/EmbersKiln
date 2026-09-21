extends CanvasLayer
## 每战配印按永久卡牌实例选择；冻结期间只读。
const Browser := preload("res://scripts/ui/CardBrowser.gd")

func _ready() -> void:
	layer = 99
	RunState.pending_enchant_review = false
	if RunState.is_active: SaveManager.save_game()
	$Cover.theme = FormalUI.theme()
	$Cover/Panel/Body/Close.pressed.connect(queue_free)
	SignalBus.deck_changed.connect(refresh)
	refresh()

func refresh() -> void:
	RunState.normalize_enchant_selection()
	var frozen := RunState.has_combat_checkpoint()
	$Cover/Panel/Body/Title.text = "战斗配印 · %d / %d" % [RunState.selected_enchant_instance_ids.size(), RunState.enchant_limit()]
	$Cover/Panel/Body/Hint.text = "本场配印已锁定。消耗或打出能力牌不会腾出名额。" if frozen else "勾选下一场生效的附魔。满额时先取消一张，再选择新牌。\n每张同名牌分别占位；待命牌保留附魔，战斗中只结算原有效果。"
	var list := $Cover/Panel/Body/Scroll/Cards
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var count := 0
	for entry in RunState.deck:
		if entry.get("enchants", []).is_empty(): continue
		count += 1
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var toggle := CheckButton.new()
		toggle.text = "%s · 副本 %d" % [Browser.card_name(entry), count]
		toggle.custom_minimum_size.y = 58
		var iid := String(entry["instance_id"])
		toggle.button_pressed = RunState.selected_enchant_instance_ids.has(iid)
		toggle.disabled = frozen or (not toggle.button_pressed and RunState.selected_enchant_instance_ids.size() >= RunState.enchant_limit())
		toggle.toggled.connect(func(enabled): RunState.set_enchant_selected(iid, enabled))
		row.add_child(toggle)
		row.add_child(Browser.label(CardMutation.note(entry), 22))
		row.add_child(HSeparator.new())
	if count == 0: list.add_child(Browser.label("尚未获得附魔卡牌。\n在药釉坊研究窑变，或在本局祭坛、商店获得附魔。", 24))
