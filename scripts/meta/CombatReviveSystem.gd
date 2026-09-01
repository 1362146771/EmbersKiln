extends Node
## Autoload: CombatReviveSystem —— 致命伤害待决、广告事务与战斗开始检查点恢复。

const PLACEMENT := &"death_revive"


func _ready() -> void:
	AdRewardCoordinator.register_placement_handler(PLACEMENT, _is_eligible, _grant_revive)
	if not SignalBus.run_loaded.is_connected(_on_run_loaded):
		SignalBus.run_loaded.connect(_on_run_loaded)


func max_per_run() -> int:
	var value: Variant = GameData.ad_placement_config(PLACEMENT).get("max_per_run", null)
	return int(value) if (value is int or value is float) and int(value) > 0 else 0


func can_enter_death_decision() -> bool:
	return RunState.is_active and RunState.has_combat_checkpoint() and RunState.revive_used_count < max_per_run()


func begin_death_decision() -> bool:
	if not can_enter_death_decision() or not RunState.mark_combat_death_pending():
		return false
	if not SaveManager.save_game():
		RunState.combat_death_pending = false
		return false
	SignalBus.combat_death_pending.emit()
	return true


func can_offer_revive() -> bool:
	return AdRewardCoordinator.can_offer(PLACEMENT, _context())


func request_revive() -> String:
	if RunState.run_id.is_empty():
		return ""
	return AdRewardCoordinator.request_reward(
		PLACEMENT,
		_context(),
		"%s:death_revive" % RunState.run_id
	)


func _context() -> Dictionary:
	return {
		"run_id": RunState.run_id,
		"act": RunState.current_act,
		"floor": RunState.current_floor,
		"combat_seed": RunState.combat_seed(),
	}


func _is_eligible(context: Dictionary) -> bool:
	if not RunState.combat_death_pending or not can_enter_death_decision():
		return false
	return (
		String(context.get("run_id", "")) == RunState.run_id
		and int(context.get("act", -1)) == RunState.current_act
		and int(context.get("floor", -1)) == RunState.current_floor
		and int(context.get("combat_seed", -1)) == RunState.combat_seed()
	)


func _grant_revive(transaction_id: String, context: Dictionary) -> void:
	if RunState.has_run_ad_transaction(transaction_id):
		if RunState.combat_death_pending:
			var old_run := RunState.to_save_dict()
			if not RunState.restore_combat_checkpoint() or not SaveManager.save_game():
				RunState.from_save_dict(old_run)
				return
		ProfileState.complete_reward_transaction(transaction_id)
		SignalBus.combat_revive_ready.emit()
		return
	if not _is_eligible(context):
		return
	var old_run := RunState.to_save_dict()
	RunState.revive_used_count += 1
	RunState.record_run_ad_transaction(transaction_id)
	if not RunState.restore_combat_checkpoint() or not SaveManager.save_game():
		RunState.from_save_dict(old_run)
		return
	ProfileState.complete_reward_transaction(transaction_id)
	SignalBus.combat_revive_ready.emit()


func _on_run_loaded() -> void:
	AdRewardCoordinator.retry_pending_rewards.call_deferred()
