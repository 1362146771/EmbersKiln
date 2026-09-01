extends Node
## Autoload: AdRewardCoordinator —— 资格检查、播放请求、待发事务和启动补发。
## 实际奖励只能由每个 placement 注册的专属处理器结算。

var _eligibility_handlers: Dictionary = {}
var _reward_handlers: Dictionary = {}
var _active_requests: Dictionary = {}
var _request_serial := 0


func _ready() -> void:
	SignalBus.ad_playback_finished.connect(_on_ad_playback_finished)
	if ProfileManager.is_loaded:
		call_deferred("retry_pending_rewards")
	elif not SignalBus.profile_loaded.is_connected(_on_profile_loaded):
		SignalBus.profile_loaded.connect(_on_profile_loaded)


func _on_profile_loaded(_created_new: bool) -> void:
	call_deferred("retry_pending_rewards")


func register_placement_handler(
	placement_id: StringName,
	eligibility_handler: Callable,
	reward_handler: Callable
) -> bool:
	if not AdService.is_known_placement(placement_id) or not eligibility_handler.is_valid() or not reward_handler.is_valid():
		return false
	_eligibility_handlers[placement_id] = eligibility_handler
	_reward_handlers[placement_id] = reward_handler
	call_deferred("_retry_pending_placement", placement_id)
	return true


func unregister_placement_handler(placement_id: StringName) -> void:
	_eligibility_handlers.erase(placement_id)
	_reward_handlers.erase(placement_id)


func can_offer(placement_id: StringName, context: Dictionary = {}) -> bool:
	if AdService.is_busy() or not AdService.is_available(placement_id):
		return false
	var handler: Callable = _eligibility_handlers.get(placement_id, Callable())
	return handler.is_valid() and bool(handler.call(context.duplicate(true)))


## 返回请求 id；空字符串表示资格、广告可用性或播放启动失败。
func request_reward(placement_id: StringName, context: Dictionary = {}, transaction_id: String = "") -> String:
	if not can_offer(placement_id, context):
		return ""
	var request_id := _new_request_id(placement_id)
	var clean_transaction_id := transaction_id.strip_edges()
	if clean_transaction_id.is_empty():
		clean_transaction_id = request_id
	if ProfileState.has_reward_transaction(clean_transaction_id):
		return ""
	if ProfileState.has_pending_reward_transaction(clean_transaction_id):
		retry_pending_rewards()
		return ""
	_active_requests[request_id] = {
		"placement_id": String(placement_id),
		"context": context.duplicate(true),
		"transaction_id": clean_transaction_id,
	}
	if not AdService.show_rewarded(request_id, placement_id):
		_active_requests.erase(request_id)
		return ""
	return request_id


## 仅对已经落盘的 pending 事务重试；不会重新播放广告。
func retry_pending_rewards() -> int:
	var settled_count := 0
	var pending_copy: Array = ProfileState.pending_reward_transactions.duplicate(true)
	for entry in pending_copy:
		if entry is Dictionary and _settle_pending_transaction(entry):
			settled_count += 1
	return settled_count


func _retry_pending_placement(placement_id: StringName) -> int:
	var settled_count := 0
	var pending_copy: Array = ProfileState.pending_reward_transactions.duplicate(true)
	for entry in pending_copy:
		if entry is Dictionary and StringName(String(entry.get("placement_id", ""))) == placement_id:
			if _settle_pending_transaction(entry):
				settled_count += 1
	return settled_count


func _on_ad_playback_finished(request_id: String, placement_id: StringName, result: StringName) -> void:
	var request: Dictionary = _active_requests.get(request_id, {})
	_active_requests.erase(request_id)
	if request.is_empty() or StringName(String(request.get("placement_id", ""))) != placement_id:
		return
	var transaction_id := String(request.get("transaction_id", request_id))
	if result != AdService.RESULT_COMPLETED:
		SignalBus.ad_reward_resolved.emit(transaction_id, placement_id, result)
		return

	var context: Dictionary = request.get("context", {})
	if not ProfileState.has_reward_transaction(transaction_id) and not ProfileState.has_pending_reward_transaction(transaction_id):
		if not ProfileState.begin_reward_transaction(transaction_id, placement_id, context):
			SignalBus.ad_reward_resolved.emit(transaction_id, placement_id, &"pending_failed")
			return
	var entry := {
		"transaction_id": transaction_id,
		"placement_id": String(placement_id),
		"context": context,
	}
	_settle_pending_transaction(entry)


## 处理器必须在成功发奖时调用 ProfileState.complete_reward_transaction，
## 或使用未来各系统提供的“奖励 + 完成事务”原子提交 API。
func _settle_pending_transaction(entry: Dictionary) -> bool:
	var transaction_id := String(entry.get("transaction_id", ""))
	var placement_id := StringName(String(entry.get("placement_id", "")))
	if ProfileState.has_reward_transaction(transaction_id):
		return true
	var handler: Callable = _reward_handlers.get(placement_id, Callable())
	if not handler.is_valid():
		SignalBus.ad_reward_resolved.emit(transaction_id, placement_id, &"pending")
		return false
	handler.call(transaction_id, entry.get("context", {}).duplicate(true))
	if ProfileState.has_reward_transaction(transaction_id):
		SignalBus.ad_reward_resolved.emit(transaction_id, placement_id, &"granted")
		return true
	SignalBus.ad_reward_resolved.emit(transaction_id, placement_id, &"pending")
	return false


func _new_request_id(placement_id: StringName) -> String:
	_request_serial += 1
	return "%s:%d:%d:%d" % [
		String(placement_id),
		int(Time.get_unix_time_from_system()),
		Time.get_ticks_usec(),
		_request_serial,
	]
