extends Node
## Autoload: AdService —— 对游戏层隐藏广告 SDK，只暴露统一激励广告结果。

const PLACEMENTS: Array[StringName] = [
	&"death_revive",
	&"pre_run_buff",
	&"shop_refresh",
	&"run_end_currency",
	&"workshop_speedup",
	&"deck_capacity_expand",
]

const RESULT_COMPLETED := RewardedAdProvider.RESULT_COMPLETED
const RESULT_SKIPPED := RewardedAdProvider.RESULT_SKIPPED
const RESULT_FAILED := RewardedAdProvider.RESULT_FAILED
const RESULT_CLOSED := RewardedAdProvider.RESULT_CLOSED

var provider: RewardedAdProvider
var active_request_id := ""
var active_placement_id: StringName = &""


func _ready() -> void:
	# 调试构建使用明确标记的模拟广告，方便在编辑器内验证完整玩法链路；
	# Release 构建在真实 SDK 适配器接入前仍保持全部不可用，绝不伪造线上广告完成事件。
	var fallback := FakeRewardedAdProvider.new()
	if OS.is_debug_build():
		fallback.default_available = true
		fallback.fallback_result = RESULT_COMPLETED
		print("[AdService] 调试构建已启用模拟激励广告；Release 不会使用该 Provider")
	set_provider(fallback)


func is_debug_simulation() -> bool:
	var fake := provider as FakeRewardedAdProvider
	return OS.is_debug_build() and fake != null and fake.default_available and fake.fallback_result == RESULT_COMPLETED


func set_provider(next_provider: RewardedAdProvider) -> bool:
	if next_provider == null or not active_request_id.is_empty():
		return false
	if provider != null and provider.rewarded_finished.is_connected(_on_provider_finished):
		provider.rewarded_finished.disconnect(_on_provider_finished)
	provider = next_provider
	provider.rewarded_finished.connect(_on_provider_finished)
	preload_all()
	for placement_id in PLACEMENTS:
		SignalBus.ad_availability_changed.emit(placement_id, is_available(placement_id))
	return true


func preload_all() -> void:
	if provider == null:
		return
	for placement_id in PLACEMENTS:
		if is_placement_enabled(placement_id):
			provider.preload_rewarded(placement_id)


func is_known_placement(placement_id: StringName) -> bool:
	return PLACEMENTS.has(placement_id)


func is_placement_enabled(placement_id: StringName) -> bool:
	if not is_known_placement(placement_id):
		return false
	return bool(GameData.ad_placement_config(placement_id).get("enabled", false))


func is_available(placement_id: StringName) -> bool:
	return provider != null and is_placement_enabled(placement_id) and provider.is_rewarded_available(placement_id)


func is_busy() -> bool:
	return not active_request_id.is_empty()


func show_rewarded(request_id: String, placement_id: StringName) -> bool:
	var clean_request_id := request_id.strip_edges()
	if clean_request_id.is_empty() or is_busy() or not is_available(placement_id):
		return false
	active_request_id = clean_request_id
	active_placement_id = placement_id
	if not provider.show_rewarded(placement_id):
		active_request_id = ""
		active_placement_id = &""
		return false
	SignalBus.ad_playback_started.emit(clean_request_id, placement_id)
	return true


func _on_provider_finished(result: StringName) -> void:
	if active_request_id.is_empty():
		return
	if result not in [RESULT_COMPLETED, RESULT_SKIPPED, RESULT_FAILED, RESULT_CLOSED]:
		result = RESULT_FAILED
	var request_id := active_request_id
	var placement_id := active_placement_id
	active_request_id = ""
	active_placement_id = &""
	SignalBus.ad_playback_finished.emit(request_id, placement_id, result)
