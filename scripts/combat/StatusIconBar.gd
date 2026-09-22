extends HFlowContainer
## 图片与真实层数共用视图；不改变状态规则或库存。
const BADGE := preload("res://scenes/combat/StatusBadge.tscn")
const ICON_INFO := preload("res://scripts/ui/CombatIconInfo.gd")
var _badges: Dictionary = {}
var _initialized := false

func set_unit(unit: CombatUnit, kiln_heat: int = 0, kiln_threshold: int = 0) -> void:
	if not _initialized:
		for child in get_children():
			remove_child(child)
			child.queue_free()
		_initialized = true
	var active: Array = unit.status_ids()
	if kiln_heat > 0:
		active.append(&"kiln_heat")
	for sid in _badges.keys():
		if sid not in active:
			var old: Control = _badges[sid]
			remove_child(old)
			old.queue_free()
			_badges.erase(sid)
	for sid in active:
		var stacks: int = kiln_heat if sid == &"kiln_heat" else unit.get_status(sid)
		if stacks == 0:
			continue
		var data := GameData.get_status(sid)
		if not _badges.has(sid):
			var badge := BADGE.instantiate()
			badge.name = String(sid)
			badge.set_meta("status_id", sid)
			add_child(badge)
			_badges[sid] = badge
			badge.get_node("Icon").texture = GameData.icon_texture(data.icon) if data != null else null
			if sid == &"kiln_heat":
				badge.get_node("Icon").texture = load("res://art/icons/intent/ICO_Intent_Kiln.png")
		var current: Control = _badges[sid]
		current.get_node("Stacks").text = str(stacks)
		current.get_node("Stacks").add_theme_font_size_override("font_size", 16 if str(stacks).length() > 2 else 18)
		var title: String = data.name if data != null else String(sid)
		var body := "当前层数：%d。\n%s" % [stacks, data.effect if data != null else ""]
		if sid == &"kiln_heat":
			title = "窑温"
			body = "当前窑温：%d。\n触发阈值：%d。" % [kiln_heat, kiln_threshold]
		ICON_INFO.configure(current, title, body, current.get_node("Icon").texture)
	visible = not _badges.is_empty()

func content_height(available_width: float) -> float:
	if get_child_count() == 0:
		return 0.0
	var columns := maxi(1, int((available_width + 4.0) / 44.0))
	var rows := ceili(float(get_child_count()) / columns)
	return rows * 34.0 + maxi(0, rows - 1) * 4.0
