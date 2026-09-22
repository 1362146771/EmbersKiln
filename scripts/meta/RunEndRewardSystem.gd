extends Node
## Autoload: RunEndRewardSystem —— 基础火种先结算，广告仅追加一次额外火种。

const PLACEMENT := &"run_end_currency"


func _ready() -> void:
	AdRewardCoordinator.register_placement_handler(PLACEMENT, _is_ad_bonus_eligible, _grant_ad_bonus)
	SignalBus.run_ended.connect(_on_run_ended)


func is_base_configured() -> bool:
	var config: Variant = GameData.meta_progression.get("run_end_rewards", {})
	if not config is Dictionary:
		return false
	for field in ["floor_index_offset", "per_floor", "per_defeated_enemy", "victory_bonus", "base_cap"]:
		var value: Variant = config.get(field, null)
		if value == null or not (value is int or value is float) or int(value) < 0:
			return false
	return true


func is_ad_bonus_configured() -> bool:
	var config := GameData.ad_placement_config(PLACEMENT)
	for field in ["bonus_multiplier", "bonus_cap"]:
		var value: Variant = config.get(field, null)
		if value == null or not (value is int or value is float) or float(value) < 0.0:
			return false
	return String(config.get("rounding", "")) in ["floor", "round", "ceil"]


func _on_run_ended(victory: bool) -> void:
	settle_base_reward(victory)


func settle_base_reward(victory: bool) -> bool:
	if RunState.run_id.is_empty() or RunState.run_end_base_settled or not is_base_configured():
		return false
	var amount := preview_base_reward(victory)
	var transaction_id := "%s:base" % RunState.run_id
	if not ProfileState.commit_fireseed_reward(transaction_id, amount, false):
		if not ProfileState.has_reward_transaction(transaction_id):
			return false
	RunState.run_end_base_fireseed = amount
	RunState.run_end_base_settled = true
	if amount > 0: SignalBus.sound_requested.emit(&"fireseed_gain")
	return true


func preview_base_reward(victory: bool) -> int:
	if RunState.hidden_act_state.has("ordinary_reward"):
		return int(RunState.hidden_act_state.ordinary_reward)
	if not is_base_configured(): return 0
	var config: Dictionary = GameData.meta_progression["run_end_rewards"]
	var reached_floors := _total_reached_floors(int(config["floor_index_offset"]))
	var amount := reached_floors * int(config["per_floor"])
	amount += RunState.defeated.size() * int(config["per_defeated_enemy"])
	if victory:
		amount += int(config["victory_bonus"])
	return mini(amount, int(config["base_cap"]))


## current_floor 会在跨幕时归零；结算必须把已经完成的前置幕层数一起计入。
func _total_reached_floors(floor_index_offset: int) -> int:
	var reached := maxi(0, RunState.current_floor + floor_index_offset)
	for act_index in mini(RunState.current_act, GameData.act_configs.size()):
		var act_config: Dictionary = GameData.act_configs[act_index]
		reached += maxi(0, int(act_config.get("floor_count", 0)))
	return reached


func can_offer_ad_bonus() -> bool:
	var context := _current_context()
	return AdRewardCoordinator.can_offer(PLACEMENT, context)


func preview_ad_bonus() -> int:
	if not is_ad_bonus_configured() or not RunState.run_end_base_settled:
		return 0
	var config := GameData.ad_placement_config(PLACEMENT)
	var raw_bonus := float(RunState.run_end_base_fireseed) * float(config["bonus_multiplier"])
	var bonus := 0
	match String(config["rounding"]):
		"floor": bonus = int(floor(raw_bonus))
		"round": bonus = int(round(raw_bonus))
		"ceil": bonus = int(ceil(raw_bonus))
	return mini(bonus, int(config["bonus_cap"]))


func request_ad_bonus() -> String:
	if RunState.run_id.is_empty():
		return ""
	return AdRewardCoordinator.request_reward(
		PLACEMENT,
		_current_context(),
		"%s:ad_bonus" % RunState.run_id
	)


func _current_context() -> Dictionary:
	return {
		"run_id": RunState.run_id,
		"base_fireseed": RunState.run_end_base_fireseed,
	}


func _is_ad_bonus_eligible(context: Dictionary) -> bool:
	if not is_ad_bonus_configured() or not RunState.run_end_base_settled:
		return false
	if String(context.get("run_id", "")) != RunState.run_id:
		return false
	if int(context.get("base_fireseed", -1)) != RunState.run_end_base_fireseed:
		return false
	return not ProfileState.has_reward_transaction("%s:ad_bonus" % RunState.run_id)


func _grant_ad_bonus(transaction_id: String, context: Dictionary) -> void:
	if not _is_ad_bonus_eligible(context):
		return
	var bonus := preview_ad_bonus()
	if ProfileState.commit_fireseed_reward(transaction_id, bonus, true):
		RunState.run_end_ad_bonus_fireseed = bonus
