extends Node
## P1 节点内容验证：休息/商店/宝箱/事件 的底层逻辑（不需要真实点击）。

const RestUIScript := preload("res://scripts/map/RestUI.gd")
const ShopUIScript := preload("res://scripts/map/ShopUI.gd")
const TreasureUIScript := preload("res://scripts/map/TreasureUI.gd")
const EventUIScript := preload("res://scripts/map/EventUI.gd")

var pass_count := 0
var fail_count := 0
var done_reached := false

func _mark_done() -> void:
	done_reached = true


func _ready() -> void:
	RunState.start_new_run()
	verify_reward_builder_helpers()
	verify_rest_ui()
	verify_shop_ui()
	verify_treasure_ui()
	verify_event_ui()
	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		print("[PASS] %s%s" % [name, (" — " + detail) if detail != "" else ""])
	else:
		fail_count += 1
		print("[FAIL] %s%s" % [name, (" — " + detail) if detail != "" else ""])


func verify_reward_builder_helpers() -> void:
	var ok_card := true
	for i in 20:
		var cd: Dictionary = RewardBuilder.roll_single_card()
		if cd.is_empty() or not cd.has("id") or not cd.has("name"):
			ok_card = false
	check("RewardBuilder.roll_single_card 返回有效卡", ok_card)
	var rid: StringName = RewardBuilder.roll_shop_relic()
	check("RewardBuilder.roll_shop_relic 返回遗物", rid != &"")


func verify_rest_ui() -> void:
	RunState.start_new_run()
	RunState.take_damage(40)  # 先掉血，验证回血
	done_reached = false
	var ui = RestUIScript.new()
	ui.setup(_mark_done)
	add_child(ui)
	check("RestUI: 构建出界面", ui.get_child_count() > 0)
	var hp_before: int = RunState.hp
	ui._on_rest(int(RunState.max_hp * 0.3))
	check("RestUI: 休息回血生效", RunState.hp > hp_before, "hp %d -> %d" % [hp_before, RunState.hp])
	check("RestUI: done 回调触发", done_reached)
	ui.queue_free()


func verify_shop_ui() -> void:
	RunState.start_new_run()
	RunState.gold = 999
	done_reached = false
	var ui = ShopUIScript.new()
	ui.setup(_mark_done)
	add_child(ui)
	check("ShopUI: 生成卡牌货架", ui.card_stock.size() == 4, "n=%d" % ui.card_stock.size())
	var deck_before: int = RunState.deck.size()
	var gold_before: int = RunState.gold
	ui._on_buy_card(0)
	check("ShopUI: 购买卡牌入组", RunState.deck.size() == deck_before + 1, "deck %d -> %d" % [deck_before, RunState.deck.size()])
	check("ShopUI: 扣除金币", RunState.gold < gold_before, "gold %d -> %d" % [gold_before, RunState.gold])
	check("ShopUI: done 未误触发（仍购物中）", not done_reached)
	ui.queue_free()


func verify_treasure_ui() -> void:
	RunState.start_new_run()
	done_reached = false
	var ui = TreasureUIScript.new()
	ui.setup(_mark_done)
	add_child(ui)
	var deck_before: int = RunState.deck.size()
	ui._on_take_card()
	check("TreasureUI: 取卡入组", RunState.deck.size() == deck_before + 1, "deck %d -> %d" % [deck_before, RunState.deck.size()])
	check("TreasureUI: done 回调触发", done_reached)
	ui.queue_free()


func verify_event_ui() -> void:
	RunState.start_new_run()
	done_reached = false
	var ui = EventUIScript.new()
	ui.setup(_mark_done)
	add_child(ui)
	var gold_before: int = RunState.gold
	ui._on_choose({"gold": 30})
	check("EventUI: 选项加金币", RunState.gold == gold_before + 30, "gold %d -> %d" % [gold_before, RunState.gold])
	ui._finish()  # 模拟点击结果页「继续」
	check("EventUI: done 回调触发", done_reached)
	ui.queue_free()


func _print_report() -> void:
	print("[P1Verify] PASS=%d FAIL=%d" % [pass_count, fail_count])
	if fail_count == 0:
		print("[P1Verify] RESULT=PASS")
	else:
		print("[P1Verify] RESULT=FAIL")
