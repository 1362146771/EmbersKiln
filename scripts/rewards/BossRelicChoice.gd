extends Control
## Read-only offers until an explicit take/skip; RewardUI owns the transaction.
signal chosen(relic_id: StringName)
var choices: Array = []
var _submitted := false

func setup(ids: Array) -> void:
	choices = ids.duplicate()

func _ready() -> void:
	for i in %Offers.get_child_count():
		var row := %Offers.get_child(i)
		row.visible = i < choices.size()
		if not row.visible: continue
		var relic := GameData.get_relic(StringName(choices[i]))
		if relic == null:
			row.hide()
			continue
		row.get_node("Content/Icon").texture = GameData.icon_texture(relic.icon)
		row.get_node("Content/Copy/Name").text = relic.name
		row.get_node("Content/Copy/Benefit").text = "每回合能量 +%d" % relic.energy_bonus
		row.get_node("Content/Copy/Cost").text = relic.description.get_slice("。", 1).strip_edges() + "。"
		row.get_node("Content/Take").pressed.connect(_choose.bind(relic.id))
	%Skip.text = "继续前进" if choices.is_empty() else "跳过遗物"
	%Skip.pressed.connect(_choose.bind(&""))
	if choices.is_empty(): %Prompt.text = "已无可领取的首领遗物。"

func _choose(id: StringName) -> void:
	if _submitted or TransitionManager.is_transitioning: return
	if id != &"" and not choices.has(String(id)): return
	_submitted = true
	chosen.emit(id)
