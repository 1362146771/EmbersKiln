extends Node
## 第三阶段验证：六个广告位、Fake Provider、结果分流、幂等事务与启动补发。

var pass_count := 0
var fail_count := 0
var results: Array[String] = []
var original_profile: Dictionary
var original_autosave: bool
var original_provider: RewardedAdProvider
var fake: FakeRewardedAdProvider
var eligible := true
var handler_calls := 0
var last_context: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	original_autosave = ProfileManager.autosave_enabled
	ProfileManager.autosave_enabled = false
	original_profile = ProfileState.to_save_dict()
	original_provider = AdService.provider
	ProfileState.reset_to_defaults(false)
	fake = FakeRewardedAdProvider.new()
	AdService.set_provider(fake)

	_test_configuration_and_default_safety()
	_test_registration_and_eligibility()
	await _test_completed_reward()
	await _test_skipped_and_failed_results()
	await _test_busy_guard()
	await _test_pending_persistence_and_retry()

	AdRewardCoordinator.unregister_placement_handler(&"run_end_currency")
	AdService.set_provider(original_provider)
	ProfileState.from_save_dict(original_profile, false)
	ProfileManager.autosave_enabled = original_autosave
	_print_report()


func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		pass_count += 1
		results.append("[PASS] %s%s" % [name, (" — " + detail) if not detail.is_empty() else ""])
	else:
		fail_count += 1
		results.append("[FAIL] %s%s" % [name, (" — " + detail) if not detail.is_empty() else ""])


func _test_configuration_and_default_safety() -> void:
	check("六个广告位均已登记", AdService.PLACEMENTS.size() == 6)
	for placement_id in AdService.PLACEMENTS:
		check("广告位配置存在：%s" % placement_id, not GameData.ad_placement_config(placement_id).is_empty())
	check("已确认复活次数落入配置", int(GameData.ad_placement_config(&"death_revive").get("max_per_run", 0)) == 1)
	check("已确认局前 Buff 层数落入配置", int(GameData.ad_placement_config(&"pre_run_buff").get("duration_floors", 0)) == 10)
	check("六个广告位数值均已闭环", CardAcquireService.is_expand_configured() and WorkshopSystem.is_speedup_configured() and ShopInventorySystem.is_refresh_configured())
	check("Fake Provider 默认不提供广告", not fake.is_rewarded_available(&"run_end_currency"))
	check("替换 Provider 后自动预加载六个广告位", fake.preload_count == 6)


func _test_registration_and_eligibility() -> void:
	check("未知广告位不能注册处理器", not AdRewardCoordinator.register_placement_handler(&"unknown", _is_eligible, _complete_reward))
	check("合法广告位可注册专属处理器", AdRewardCoordinator.register_placement_handler(&"run_end_currency", _is_eligible, _complete_reward))
	var shows_before := fake.show_count
	check("广告不可用时不创建请求", AdRewardCoordinator.request_reward(&"run_end_currency") == "")
	check("不可用请求不会调用 Provider", fake.show_count == shows_before)
	fake.set_available(&"run_end_currency", true)
	eligible = false
	check("资格检查失败时不创建请求", AdRewardCoordinator.request_reward(&"run_end_currency") == "")
	check("资格失败不会调用 Provider", fake.show_count == shows_before)
	eligible = true


func _test_completed_reward() -> void:
	handler_calls = 0
	last_context.clear()
	fake.enqueue_result(AdService.RESULT_COMPLETED)
	var request_id := AdRewardCoordinator.request_reward(&"run_end_currency", {"run_id": "verify-run"})
	check("合格且可用时创建广告请求", not request_id.is_empty())
	var resolved: Array = await SignalBus.ad_reward_resolved
	check("完整观看进入 granted", resolved[0] == request_id and resolved[2] == &"granted")
	check("专属奖励处理器被调用一次", handler_calls == 1)
	check("上下文原样交给处理器", last_context.get("run_id", "") == "verify-run")
	check("完成事务进入防重记录", ProfileState.has_reward_transaction(request_id))
	check("完成事务不残留 pending", not ProfileState.has_pending_reward_transaction(request_id))


func _test_skipped_and_failed_results() -> void:
	var completed_before := ProfileState.reward_transaction_ids.size()
	var pending_before := ProfileState.pending_reward_transactions.size()
	for expected_result in [AdService.RESULT_SKIPPED, AdService.RESULT_FAILED, AdService.RESULT_CLOSED]:
		fake.enqueue_result(expected_result)
		var request_id := AdRewardCoordinator.request_reward(&"run_end_currency", {"case": String(expected_result)})
		var resolved: Array = await SignalBus.ad_reward_resolved
		check("%s 结果正确透传" % expected_result, resolved[0] == request_id and resolved[2] == expected_result)
	check("跳过、失败和关闭不创建完成事务", ProfileState.reward_transaction_ids.size() == completed_before)
	check("跳过、失败和关闭不创建待发事务", ProfileState.pending_reward_transactions.size() == pending_before)


func _test_busy_guard() -> void:
	fake.enqueue_result(AdService.RESULT_COMPLETED)
	var first_id := AdRewardCoordinator.request_reward(&"run_end_currency", {"case": "busy"})
	var shows_after_first := fake.show_count
	var second_id := AdRewardCoordinator.request_reward(&"run_end_currency", {"case": "duplicate"})
	check("播放中拒绝第二个广告请求", not first_id.is_empty() and second_id.is_empty())
	check("播放中不会二次调用 Provider", fake.show_count == shows_after_first)
	await SignalBus.ad_reward_resolved


func _test_pending_persistence_and_retry() -> void:
	AdRewardCoordinator.register_placement_handler(&"run_end_currency", _is_eligible, _leave_pending)
	fake.enqueue_result(AdService.RESULT_COMPLETED)
	var request_id := AdRewardCoordinator.request_reward(&"run_end_currency", {"run_id": "recover-me"})
	var resolved: Array = await SignalBus.ad_reward_resolved
	check("处理器未落账时事务保持 pending", resolved[2] == &"pending" and ProfileState.has_pending_reward_transaction(request_id))
	var saved := ProfileState.to_save_dict()
	ProfileState.reset_to_defaults(false)
	check("带 pending 的档案可恢复", ProfileState.from_save_dict(saved, false))
	check("恢复后 pending 上下文保留", ProfileState.pending_reward_transactions[0].get("context", {}).get("run_id", "") == "recover-me")
	handler_calls = 0
	AdRewardCoordinator.register_placement_handler(&"run_end_currency", _is_eligible, _complete_reward)
	await get_tree().process_frame
	check("处理器注册后自动补发", ProfileState.has_reward_transaction(request_id))
	check("自动补发只调用一次专属处理器", handler_calls == 1)
	check("补发后事务进入完成记录", ProfileState.has_reward_transaction(request_id))
	check("补发后移除 pending", not ProfileState.has_pending_reward_transaction(request_id))
	var completed_count := ProfileState.reward_transaction_ids.size()
	check("重复补发不会再次结算", AdRewardCoordinator.retry_pending_rewards() == 0 and ProfileState.reward_transaction_ids.size() == completed_count)


func _is_eligible(_context: Dictionary) -> bool:
	return eligible


func _complete_reward(transaction_id: String, context: Dictionary) -> void:
	handler_calls += 1
	last_context = context.duplicate(true)
	ProfileState.complete_reward_transaction(transaction_id)


func _leave_pending(_transaction_id: String, context: Dictionary) -> void:
	handler_calls += 1
	last_context = context.duplicate(true)


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== 广告基础设施验证 =====")
	for result in results:
		lines.append(result)
	lines.append("总计: %d PASS / %d FAIL" % [pass_count, fail_count])
	lines.append("AD_INFRA_RESULT:%s" % ("PASS" if fail_count == 0 else "FAIL"))
	print("\n".join(lines))
