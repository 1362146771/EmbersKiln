extends Node

const Picker := preload("res://scripts/ui/CardUpgradePicker.gd")
var failures := 0
var commits := 0
var visual := false

class RestProbe extends "res://scripts/map/RestUI.gd":
	var finishes := 0
	func _finish() -> void:
		finishes += 1

class RewardProbe extends "res://scripts/rewards/RewardUI.gd":
	var finishes := 0
	func _finish() -> void:
		finishes += 1

func check(ok: bool, message: String) -> void:
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func card(id: String, level := 0) -> Dictionary:
	return {"id": StringName(id), "upgraded": level > 0, "upgrade_level": level, "enchants": []}

func settle() -> void:
	for i in 8: await get_tree().process_frame

func capture(name: String) -> void:
	if not visual: return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://Temp/" + name + ".png")

func _ready() -> void:
	if OS.get_environment("UPGRADE_VERIFY_ROOT").is_empty():
		get_tree().quit(2)
		return
	visual = OS.get_cmdline_user_args().has("--visual")
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/upgrade_save.json"
	RunState.start_new_run()
	RunState.relic_ids.clear()
	var repeat_id := ""
	var cost_id := ""
	for cd in GameData.cards.values():
		if cd.repeatable_upgrade: repeat_id = String(cd.id)
		if cd.upgrade_data.has("cost"): cost_id = String(cd.id)
	RunState.deck.assign([card("strike"), card("strike"), card("defend"), card("strike", 1), card("wound"), card(repeat_id, 2), card(cost_id)])
	var original := RunState.deck.duplicate(true)
	var picker := Picker.new()
	add_child(picker)
	await settle()
	check(picker._grid.get_child_count() == 5, "only eligible cards; repeated names remain separate")
	picker.select_card(1)
	await settle()
	check(RunState.deck == original, "opening preview never mutates deck")
	check(picker._pair.get_child(0).get_child(0).get_node("Description").text != picker._pair.get_child(2).get_child(0).get_node("Description").text, "before and after use different effect descriptions")
	for dimensions in [Vector2i(720, 1280), Vector2i(1080, 2400)]:
		get_tree().root.size = dimensions
		await settle()
		check(get_viewport().get_visible_rect().encloses(picker._confirm.get_global_rect()), "confirm stays on screen " + str(dimensions))
		check(picker._pair.size.x <= picker._pair.get_parent().size.x, "comparison fits horizontal viewport " + str(dimensions))
	picker._cancel_selection()
	check(RunState.deck == original and not picker._modal.visible, "cancel returns to grid without upgrading")
	picker.select_card(5)
	await settle()
	check(picker._pair.get_child(2).get_child(0).get_node("CardImage/CardTitle").text.ends_with("+3"), "repeatable card previews the next level")
	picker._cancel_selection()
	picker.select_card(6)
	await settle()
	var after_cost: String = picker._pair.get_child(2).get_child(0).get_node("CardImage/CardEnergyCost/Badge/Value").text
	check(after_cost == str(GameData.get_card(StringName(cost_id)).resolved_cost(1)), "preview includes upgraded energy cost")
	picker._cancel_selection()
	picker.select_card(1)
	picker.confirmed.connect(func(index, _snapshot):
		commits += 1
		RunState.upgrade_card_at(index))
	picker._confirm_selection()
	picker._confirm_selection()
	check(commits == 1 and not RunState.deck[0].upgraded and RunState.deck[1].upgraded, "confirm once upgrades exactly the selected duplicate")
	await settle()
	picker = Picker.new()
	add_child(picker)
	await settle()
	picker.select_card(0)
	RunState.deck[0] = card("strike")
	picker._confirm_selection()
	check(picker._confirm.disabled and not RunState.deck[0].upgraded, "replaced same-name instance invalidates preview")
	picker.close()
	await settle()
	var rest := RestProbe.new()
	add_child(rest)
	RunState.relic_ids.append(&"sealed_hammer")
	rest._build_forge()
	rest._on_upgrade_card(0)
	check(not is_instance_valid(rest._upgrade_picker) and rest.finishes == 0 and not RunState.deck[0].upgraded, "rest restriction still blocks upgrade")
	RunState.relic_ids.clear()
	rest._build_forge()
	await settle()
	rest._upgrade_picker.select_card(0)
	rest._upgrade_picker._confirm_selection()
	check(rest.finishes == 1 and RunState.deck[0].upgraded, "rest confirms and consumes one rest opportunity")
	await settle()
	rest.queue_free()
	await settle()
	var reward := RewardProbe.new()
	RunState.upgrade_shards = RunState.upgrade_shard_cost()
	reward.data = {"cards": [], "gold": 0}
	add_child(reward)
	reward._on_upgrade_card(-1)
	check(reward.finishes == 0, "failed upgrade does not consume reward")
	reward._build_upgrade()
	await settle()
	reward._upgrade_picker.select_card(2)
	reward._upgrade_picker._confirm_selection()
	check(reward.finishes == 1 and RunState.deck[2].upgraded, "reward confirms through existing completion flow")
	await settle()
	reward.queue_free()
	await settle()
	RunState.deck.assign([card("strike", 1), card("wound")])
	picker = Picker.new()
	add_child(picker)
	await settle()
	check(picker._grid.get_child_count() == 0 and not picker._back.disabled, "empty eligible pool has a working return")
	picker.close()
	await settle()
	var longest_id := ""
	var longest_size := 0
	for cd in GameData.cards.values():
		if cd.has_upgrade() and cd.get_description(1).length() > longest_size:
			longest_id = String(cd.id)
			longest_size = cd.get_description(1).length()
	RunState.deck.assign([card(longest_id)])
	picker = Picker.new()
	add_child(picker)
	picker.select_card(0)
	await settle()
	check(picker._pair.size.x <= picker._pair.get_parent().size.x and get_viewport().get_visible_rect().encloses(picker._confirm.get_global_rect()), "long card description wraps with accessible confirmation")
	picker.close()
	await settle()
	# Visual fixture: enough cards to exercise touch scrolling and the dimmed grid.
	RunState.deck.clear()
	for i in 5: RunState.deck.append(card("strike"))
	for i in 4: RunState.deck.append(card("defend"))
	RunState.deck.append(card(repeat_id, 1))
	get_tree().root.size = Vector2i(720, 1280)
	picker = Picker.new()
	add_child(picker)
	await settle()
	check(picker._grid.size.y > picker._scroll.size.y, "large deck scrolls vertically")
	await capture("upgrade_grid")
	picker.select_card(5)
	await settle()
	await capture("upgrade_comparison")
	print("UPGRADE_PICKER_RESULT:", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
