extends Node
## Autoload: PreRunBuffSystem —— 局前 Buff 候选、广告领取与前十层生命周期。

const PLACEMENT := &"pre_run_buff"


func _ready() -> void:
	AdRewardCoordinator.register_placement_handler(PLACEMENT, _is_eligible, _grant_buff)


func is_configured() -> bool:
	var config := GameData.ad_placement_config(PLACEMENT)
	var choice_count: Variant = config.get("choice_count", null)
	var duration: Variant = config.get("duration_floors", null)
	var buff_ids: Variant = config.get("buff_ids", [])
	if choice_count == null or not (choice_count is int or choice_count is float) or int(choice_count) <= 0:
		return false
	if duration == null or not (duration is int or duration is float) or int(duration) <= 0:
		return false
	if not buff_ids is Array or buff_ids.is_empty():
		return false
	for buff_id in buff_ids:
		if GameData.get_pre_run_buff(StringName(String(buff_id))).is_empty():
			return false
	return true


func eligible_buff_ids() -> Array[StringName]:
	var output: Array[StringName] = []
	if not is_configured():
		return output
	for raw_id in GameData.ad_placement_config(PLACEMENT).get("buff_ids", []):
		var buff_id := StringName(String(raw_id))
		if ProfileState.unlocked_pre_run_buff_ids.has(buff_id) and not output.has(buff_id):
			output.append(buff_id)
	return output


func prepare_offer() -> Array[StringName]:
	if not RunState.is_active:
		return []
	if RunState.pre_run_preparation_resolved:
		return RunState.pre_run_buff_offer_ids.duplicate()
	if not RunState.pre_run_buff_offer_ids.is_empty():
		return RunState.pre_run_buff_offer_ids.duplicate()
	var candidates := eligible_buff_ids()
	if candidates.is_empty():
		# New runs still visit the bellows to choose difficulty without an ad offer.
		# Legacy runs without difficulty snapshots retain their original routing.
		if RunState.difficulty_snapshot.is_empty():
			RunState.pre_run_preparation_resolved = true
			SaveManager.save_game()
		return []
	candidates.shuffle()
	var choice_count := int(GameData.ad_placement_config(PLACEMENT)["choice_count"])
	RunState.pre_run_buff_offer_ids.assign(candidates.slice(0, mini(choice_count, candidates.size())))
	SaveManager.save_game()
	return RunState.pre_run_buff_offer_ids.duplicate()


func needs_preparation() -> bool:
	return GrannyStory.at_start() and not RunState.pre_run_preparation_resolved and (not RunState.pre_run_buff_offer_ids.is_empty() or not RunState.difficulty_snapshot.is_empty())


func request_buff(buff_id: StringName) -> String:
	if RunState.run_id.is_empty():
		return ""
	return AdRewardCoordinator.request_reward(
		PLACEMENT,
		{"run_id": RunState.run_id, "buff_id": String(buff_id)},
		"%s:pre_run_buff" % RunState.run_id
	)


func skip_preparation() -> bool:
	if not RunState.is_active or RunState.pre_run_preparation_resolved:
		return false
	var old_run := RunState.to_save_dict()
	RunState.pre_run_preparation_resolved = true
	RunState.pre_run_buff_offer_ids.clear()
	if SaveManager.save_game():
		return true
	RunState.from_save_dict(old_run)
	return false


func apply_combat_start(controller: CombatController) -> void:
	var buff := RunState.active_pre_run_buff()
	if buff.is_empty():
		return
	for effect in buff.get("effects", []):
		if effect is Dictionary and String(effect.get("kind", "")) == "combat_start_block":
			controller.grant_pre_run_combat_start_block(int(effect.get("value", 0)))


func _is_eligible(context: Dictionary) -> bool:
	if not is_configured() or not RunState.is_active or RunState.pre_run_preparation_resolved:
		return false
	if RunState.pre_run_buff_claimed or RunState.current_act != 0 or RunState.current_floor != 0:
		return false
	var buff_id := StringName(String(context.get("buff_id", "")))
	return String(context.get("run_id", "")) == RunState.run_id and RunState.pre_run_buff_offer_ids.has(buff_id)


func _grant_buff(transaction_id: String, context: Dictionary) -> void:
	if RunState.has_run_ad_transaction(transaction_id):
		ProfileState.complete_reward_transaction(transaction_id)
		return
	if not _is_eligible(context):
		return
	var old_run := RunState.to_save_dict()
	var buff_id := StringName(String(context["buff_id"]))
	RunState.pre_run_buff_id = buff_id
	RunState.pre_run_buff_remaining_floors = int(GameData.ad_placement_config(PLACEMENT)["duration_floors"])
	RunState.pre_run_buff_claimed = true
	RunState.pre_run_preparation_resolved = true
	RunState.pre_run_buff_offer_ids.clear()
	RunState.record_run_ad_transaction(transaction_id)
	if not SaveManager.save_game():
		RunState.from_save_dict(old_run)
		return
	ProfileState.complete_reward_transaction(transaction_id)
	SignalBus.pre_run_buff_activated.emit(buff_id, RunState.pre_run_buff_remaining_floors)
