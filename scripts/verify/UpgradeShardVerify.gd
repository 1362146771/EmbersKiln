extends Node

const RewardScene := preload("res://scenes/rewards/RewardUI.tscn")
const BUTTON := "Dim/Center/MainPanel/Content/Actions/UpgradeButton"
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[PASS] " if ok else "[FAIL] ", message)

func _ready() -> void:
	if OS.get_environment("BOSS_RELIC_TEST_ROOT").is_empty():
		get_tree().quit(2)
		return
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = "res://Temp/upgrade_shards_save.json"
	get_tree().create_timer(60).timeout.connect(func(): get_tree().quit(2))
	check(GameData.load_errors.is_empty(), "production data validates")
	var cost := RunState.upgrade_shard_cost()
	var amount := int(GameData.balance.rewards.get("upgrade_shards_per_reward", 0))
	check(cost == 4 and amount == 1, "production shard configuration: collect one, spend four")
	if amount <= 0:
		get_tree().quit(1)
		return
	fresh()
	check(RunState.upgrade_shards == 0, "new run starts without shards")
	var deck := RunState.deck.duplicate(true)
	check(not RunState.upgrade_card_with_shards_at(0) and RunState.deck == deck, "insufficient shards cannot upgrade")
	RunState.upgrade_shards = cost + amount
	check(not RunState.upgrade_card_with_shards_at(-1) and RunState.upgrade_shards == cost + amount, "invalid selection retains shards")
	check(RunState.upgrade_card_with_shards_at(0) and RunState.upgrade_shards == amount, "upgrade spends exact cost and preserves remainder")
	RunState.upgrade_shards = cost
	check(not RunState.upgrade_card_with_shards_at(0) and RunState.upgrade_shards == cost, "already upgraded card costs nothing")
	RunState.add_card(&"searing_blow")
	var repeat_index := RunState.deck.size() - 1
	for level in [1, 2]:
		RunState.upgrade_shards = cost
		check(RunState.upgrade_card_with_shards_at(repeat_index) and RunState.deck[repeat_index].upgrade_level == level, "repeatable upgrade level " + str(level))
	RunState.upgrade_shards = cost
	check(SaveManager.save_game(), "save shards to disk")
	RunState.upgrade_shards = 0
	check(SaveManager.load_game() and RunState.upgrade_shards == cost, "disk roundtrip retains shards")
	var old_save := RunState.to_save_dict()
	old_save.erase("upgrade_shards")
	check(RunState.from_save_dict(old_save) and RunState.upgrade_shards == 0, "old save defaults to zero shards")
	old_save["upgrade_shards"] = -10
	check(RunState.from_save_dict(old_save) and RunState.upgrade_shards == 0, "negative saved balance sanitized")
	await test_collection(cost, amount)
	await test_picker(cost)
	await test_boss(cost, amount)
	await test_alternatives(cost)
	GameData.balance.rewards.upgrade_shard_cost = cost + amount
	GameData.balance.rewards.upgrade_shards_per_reward = amount + amount
	fresh()
	check(RunState.collect_upgrade_shards() == amount + amount and RunState.upgrade_shard_cost() == cost + amount, "collection and cost read configuration")
	GameData.balance.rewards.upgrade_shard_cost = cost
	GameData.balance.rewards.upgrade_shards_per_reward = amount
	fresh()
	RunState.upgrade_shards = cost
	RunState.start_new_run()
	check(RunState.upgrade_shards == 0, "new run clears previous balance")
	print("UPGRADE_SHARD_RESULT:%s %d/%d" % ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(0 if failures == 0 else 1)

func fresh() -> void:
	RunState.start_new_run()
	RunState.pre_run_preparation_resolved = true
	FormalUI.combat_reward_pending = false

func reward(data: Dictionary = {}) -> Control:
	if data.is_empty():
		data = {"tier":"combat", "stage":"cards", "gold":0, "cards":RewardBuilder.roll_card_choices(int(GameData.balance.rewards.card_choice_count), &"combat")}
	RunState.pending_reward_data = data
	var panel := RewardScene.instantiate()
	panel.setup(data, func(): pass)
	add_child(panel)
	return panel

func settle() -> void:
	await get_tree().process_frame
	while TransitionManager.is_transitioning:
		await get_tree().process_frame
	await get_tree().process_frame

func capture(name: String, panel: Control) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var button: Button = panel.get_node(BUTTON)
	check(button.get_global_rect().end.x <= 720 and button.get_global_rect().end.y <= 1280, "button fits mobile viewport " + name)
	check(button.icon != null and button.icon.get_image().detect_alpha() != Image.ALPHA_NONE, "shard icon has transparency")
	check(get_viewport().get_texture().get_image().save_png("res://Temp/" + name + ".png") == OK, "capture " + name)

func test_collection(cost: int, amount: int) -> void:
	fresh()
	var panel := reward()
	await settle()
	check(panel.get_node(BUTTON).text == "收集升级碎片（已有：0）", "initial collection label")
	await capture("upgrade-shards-collect", panel)
	panel.get_node(BUTTON).pressed.emit()
	panel.get_node(BUTTON).pressed.emit()
	await settle()
	check(RunState.upgrade_shards == amount and RunState.pending_post_reward, "collection completes one reward exactly once")
	check(SaveManager.load_game() and RunState.upgrade_shards == amount, "collection and completion persist together")
	fresh()
	RunState.upgrade_shards = cost - amount
	panel = reward()
	await settle()
	panel.get_node(BUTTON).pressed.emit()
	await settle()
	check(RunState.upgrade_shards == cost and panel.get_node(BUTTON).text == "升级卡牌", "threshold immediately offers upgrade")
	var deck := RunState.deck.duplicate(true)
	panel._on_choose_card(0)
	panel._on_enchant_pressed()
	check(RunState.deck == deck and panel.has_node(BUTTON), "collection locks competing card and enchant rewards")
	await capture("upgrade-shards-ready", panel)
	check(SaveManager.load_game() and RunState.upgrade_shards == cost and RunState.pending_reward_data.upgrade_shards_collected, "threshold collection resumes without duplication")
	panel.queue_free()
	await settle()
	panel = reward(RunState.pending_reward_data)
	await settle()
	check(panel.get_node(BUTTON).text == "升级卡牌", "resumed label matches saved balance")
	panel._on_skip()
	await settle()
	check(RunState.upgrade_shards == cost and SaveManager.load_game() and RunState.upgrade_shards == cost, "leaving preserves saved shards")

func test_picker(cost: int) -> void:
	fresh()
	RunState.upgrade_shards = cost
	var panel := reward()
	await settle()
	panel._on_upgrade_pressed()
	var picker = panel._upgrade_picker
	picker.select_card(0)
	picker._cancel_selection()
	check(RunState.upgrade_shards == cost and not RunState.deck[0].upgraded, "cancel preview retains balance and card")
	picker.close()
	await settle()
	panel._on_upgrade_pressed()
	picker = panel._upgrade_picker
	picker.select_card(0)
	picker._confirm_selection()
	panel._on_upgrade_card(1)
	await settle()
	check(RunState.upgrade_shards == 0 and RunState.deck[0].upgraded and not RunState.deck[1].upgraded, "confirm upgrades selected copy once")
	check(SaveManager.load_game() and RunState.upgrade_shards == 0 and RunState.deck[0].upgraded and RunState.pending_post_reward, "upgrade transaction survives disk reload")
	fresh()
	RunState.upgrade_shards = cost
	panel = reward()
	await settle()
	panel._on_upgrade_pressed()
	picker = panel._upgrade_picker
	picker.select_card(0)
	RunState.deck[0] = RunState.deck[0].duplicate(true)
	picker._confirm_selection()
	check(RunState.upgrade_shards == cost and not RunState.deck[0].upgraded, "stale card instance cannot consume shards")
	picker.close()
	panel.queue_free()
	await settle()
	check(RunState.upgrade_card_at(0) and RunState.upgrade_shards == cost, "rest and other direct upgrades do not consume shards")

func test_boss(cost: int, amount: int) -> void:
	for starting in [0, cost - amount]:
		fresh()
		RunState.upgrade_shards = starting
		var choices := RewardBuilder.roll_boss_relic_choices()
		var panel := reward({"tier":"boss", "stage":"cards", "cards":[], "boss_relic_choices":choices})
		await settle()
		panel._on_upgrade_pressed()
		await settle()
		if RunState.can_spend_upgrade_shards():
			panel._on_skip()
			await settle()
		check(panel.data.stage == "boss_relic" and panel.has_node("BossRelicChoice"), "shard reward retains independent boss relic stage")
		panel._on_upgrade_pressed()
		check(RunState.upgrade_shards == starting + amount, "boss stage cannot collect shards again")
		panel.queue_free()
		await settle()

func test_alternatives(cost: int) -> void:
	fresh()
	RunState.upgrade_shards = cost
	var count := RunState.deck.size()
	var panel := reward()
	await settle()
	panel._on_choose_card(0)
	await settle()
	check(RunState.upgrade_shards == cost and RunState.deck.size() == count + 1, "choosing a card preserves collected shards")
	fresh()
	RunState.upgrade_shards = cost
	for i in RunState.deck.size(): RunState.upgrade_card_at(i)
	panel = reward()
	await settle()
	panel._on_upgrade_pressed()
	var picker = panel._upgrade_picker
	check(picker._grid.get_child_count() == 0 and RunState.upgrade_shards == cost, "empty upgrade pool does not spend shards")
	picker.close()
	await settle()
	panel._on_skip()
	await settle()
	check(RunState.upgrade_shards == cost and RunState.pending_post_reward, "empty upgrade pool can leave normally")
