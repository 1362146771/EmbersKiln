class_name FakeRewardedAdProvider
extends RewardedAdProvider
## 本地与自动化测试用供应商；不会发起网络请求，也不会默认把广告判定为完成。

var default_available := false
var fallback_result: StringName = RESULT_FAILED
var availability_by_placement: Dictionary = {}
var queued_results: Array[StringName] = []
var show_count := 0
var preload_count := 0


func reset() -> void:
	default_available = false
	fallback_result = RESULT_FAILED
	availability_by_placement.clear()
	queued_results.clear()
	show_count = 0
	preload_count = 0


func set_available(placement_id: StringName, available: bool) -> void:
	availability_by_placement[placement_id] = available


func enqueue_result(result: StringName) -> bool:
	if result not in [RESULT_COMPLETED, RESULT_SKIPPED, RESULT_FAILED, RESULT_CLOSED]:
		return false
	queued_results.append(result)
	return true


func preload_rewarded(_placement_id: StringName) -> void:
	preload_count += 1


func is_rewarded_available(placement_id: StringName) -> bool:
	return bool(availability_by_placement.get(placement_id, default_available))


func show_rewarded(placement_id: StringName) -> bool:
	if not is_rewarded_available(placement_id):
		return false
	show_count += 1
	var result := fallback_result
	if not queued_results.is_empty():
		result = queued_results.pop_front()
	call_deferred("_finish", result)
	return true


func _finish(result: StringName) -> void:
	rewarded_finished.emit(result)
