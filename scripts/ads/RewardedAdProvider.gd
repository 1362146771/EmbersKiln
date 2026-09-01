class_name RewardedAdProvider
extends RefCounted
## 激励广告供应商接口。真实 SDK 适配器与 Fake Provider 均实现此契约。

signal rewarded_finished(result: StringName)

const RESULT_COMPLETED := &"completed"
const RESULT_SKIPPED := &"skipped"
const RESULT_FAILED := &"failed"
const RESULT_CLOSED := &"closed"


func preload_rewarded(_placement_id: StringName) -> void:
	pass


func is_rewarded_available(_placement_id: StringName) -> bool:
	return false


func show_rewarded(_placement_id: StringName) -> bool:
	return false
