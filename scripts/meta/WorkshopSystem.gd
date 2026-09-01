extends Node
## Autoload: WorkshopSystem —— 工坊项目的资格检查、自然计时与领取。
## 成本、时长、队列容量和奖励全部来自 GameData.meta_progression；null 表示尚未确认。

const STATUS_UNCONFIGURED := &"unconfigured"
const STATUS_LOCKED := &"locked"
const STATUS_AVAILABLE := &"available"
const STATUS_BUILDING := &"building"
const STATUS_READY := &"ready"
const STATUS_COMPLETED := &"completed"
const SPEEDUP_PLACEMENT := &"workshop_speedup"


func _ready() -> void:
	AdRewardCoordinator.register_placement_handler(SPEEDUP_PLACEMENT, _is_speedup_eligible, _grant_speedup)
	if ProfileManager.is_loaded:
		refresh()
	elif not SignalBus.profile_loaded.is_connected(_on_profile_loaded):
		SignalBus.profile_loaded.connect(_on_profile_loaded)


func _on_profile_loaded(_created_new: bool) -> void:
	refresh()


func queue_capacity() -> int:
	var workshop: Variant = GameData.meta_progression.get("workshop", {})
	if not workshop is Dictionary:
		return -1
	var raw_capacity: Variant = workshop.get("queue_capacity", null)
	if raw_capacity == null or not (raw_capacity is int or raw_capacity is float):
		return -1
	return int(raw_capacity)


func is_project_configured(project_id: StringName) -> bool:
	var project: Dictionary = GameData.get_meta_project(project_id)
	if project.is_empty() or queue_capacity() <= 0:
		return false
	for field in ["fireseed_cost", "duration_seconds"]:
		var value: Variant = project.get(field, null)
		if value == null or not (value is int or value is float) or int(value) < 0:
			return false
	return true


func project_status(project_id: StringName, now_unix: int = -1) -> StringName:
	if ProfileState.completed_project_ids.has(project_id):
		return STATUS_COMPLETED
	var queue_index := ProfileState.construction_index(project_id)
	if queue_index >= 0:
		var entry: Dictionary = ProfileState.construction_queue[queue_index]
		var now := _resolved_time(now_unix)
		if String(entry.get("status", "building")) == "ready" or int(entry.get("finish_at", 0)) <= now:
			return STATUS_READY
		return STATUS_BUILDING
	if not is_project_configured(project_id):
		return STATUS_UNCONFIGURED
	if not _prerequisites_met(GameData.get_meta_project(project_id)):
		return STATUS_LOCKED
	return STATUS_AVAILABLE


func project_block_reason(project_id: StringName, now_unix: int = -1) -> String:
	match project_status(project_id, now_unix):
		STATUS_UNCONFIGURED:
			return "项目数值待确认"
		STATUS_LOCKED:
			return "前置项目尚未完成"
		STATUS_BUILDING:
			return "正在建造"
		STATUS_READY:
			return "可以领取"
		STATUS_COMPLETED:
			return "已经完成"
		STATUS_AVAILABLE:
			if ProfileState.construction_queue.size() >= queue_capacity():
				return "建造队列已满"
			var cost := int(GameData.get_meta_project(project_id).get("fireseed_cost", 0))
			if ProfileState.fireseed_balance < cost:
				return "火种不足"
	return ""


## 成功时由 ProfileState 一次性提交扣款和项目创建，避免中间状态被自动保存。
func start_project(project_id: StringName, now_unix: int = -1) -> bool:
	if project_status(project_id, now_unix) != STATUS_AVAILABLE:
		return false
	if ProfileState.construction_queue.size() >= queue_capacity():
		return false
	var project: Dictionary = GameData.get_meta_project(project_id)
	var cost := int(project["fireseed_cost"])
	if ProfileState.fireseed_balance < cost:
		return false
	var started_at := _resolved_time(now_unix)
	var finish_at := started_at + int(project["duration_seconds"])
	if not ProfileState.commit_construction_start(project_id, cost, started_at, finish_at, queue_capacity()):
		return false
	SignalBus.construction_started.emit(project_id)
	refresh(started_at)
	return true


## 现实时间到达 finish_at 即转为 ready；关闭游戏不会暂停。
func refresh(now_unix: int = -1) -> Array[StringName]:
	var ready_ids := ProfileState.mark_ready_projects(_resolved_time(now_unix))
	for project_id in ready_ids:
		SignalBus.construction_ready.emit(project_id)
	return ready_ids


func remaining_seconds(project_id: StringName, now_unix: int = -1) -> int:
	var index := ProfileState.construction_index(project_id)
	if index < 0:
		return 0
	var finish_at := int(ProfileState.construction_queue[index].get("finish_at", 0))
	return maxi(0, finish_at - _resolved_time(now_unix))


func is_speedup_configured() -> bool:
	var config := GameData.ad_placement_config(SPEEDUP_PLACEMENT)
	for field in ["seconds_reduced", "max_per_project", "max_per_day"]:
		var value: Variant = config.get(field, null)
		if value == null or not (value is int or value is float) or int(value) <= 0:
			return false
	return true


func can_offer_speedup(project_id: StringName) -> bool:
	return AdRewardCoordinator.can_offer(SPEEDUP_PLACEMENT, _speedup_context(project_id))


func request_speedup(project_id: StringName) -> String:
	return AdRewardCoordinator.request_reward(SPEEDUP_PLACEMENT, _speedup_context(project_id))


func speedup_seconds() -> int:
	if not is_speedup_configured():
		return 0
	return int(GameData.ad_placement_config(SPEEDUP_PLACEMENT)["seconds_reduced"])


func speedup_project_limit() -> int:
	return int(GameData.ad_placement_config(SPEEDUP_PLACEMENT).get("max_per_project", 0)) if is_speedup_configured() else 0


func speedup_day_limit() -> int:
	return int(GameData.ad_placement_config(SPEEDUP_PLACEMENT).get("max_per_day", 0)) if is_speedup_configured() else 0


func project_speedup_uses(project_id: StringName) -> int:
	var index := ProfileState.construction_index(project_id)
	return int(ProfileState.construction_queue[index].get("ad_speedup_count", 0)) if index >= 0 else 0


func speedup_block_reason(project_id: StringName) -> String:
	if not is_speedup_configured():
		return "广告减免时长、单项目次数或每日次数尚未配置"
	var index := ProfileState.construction_index(project_id)
	if index < 0 or project_status(project_id) != STATUS_BUILDING:
		return "项目当前不在建造中"
	if project_speedup_uses(project_id) >= speedup_project_limit():
		return "该项目的广告加速次数已用尽"
	var day_key := Time.get_date_string_from_system()
	if ProfileState.daily_ad_usage(SPEEDUP_PLACEMENT, day_key) >= speedup_day_limit():
		return "今天的工坊广告加速次数已用尽"
	if AdService.is_busy():
		return "正在播放其他广告"
	if not AdService.is_available(SPEEDUP_PLACEMENT):
		return "当前没有可用广告"
	return ""


func claim_project(project_id: StringName, now_unix: int = -1) -> bool:
	refresh(now_unix)
	if project_status(project_id, now_unix) != STATUS_READY:
		return false
	var project: Dictionary = GameData.get_meta_project(project_id)
	if project.is_empty():
		return false
	var grants: Variant = project.get("grants", {})
	if not grants is Dictionary or not ProfileState.commit_construction_claim(project_id, grants):
		return false
	SignalBus.construction_claimed.emit(project_id)
	return true


func _prerequisites_met(project: Dictionary) -> bool:
	var prerequisites: Variant = project.get("prerequisite_project_ids", [])
	if not prerequisites is Array:
		return false
	for prerequisite in prerequisites:
		if not ProfileState.completed_project_ids.has(StringName(String(prerequisite))):
			return false
	return true


func _speedup_context(project_id: StringName) -> Dictionary:
	return {
		"project_id": String(project_id),
		"day_key": Time.get_date_string_from_system(),
	}


func _is_speedup_eligible(context: Dictionary) -> bool:
	if not is_speedup_configured():
		return false
	var project_id := StringName(String(context.get("project_id", "")))
	var day_key := String(context.get("day_key", "")).strip_edges()
	var index := ProfileState.construction_index(project_id)
	if index < 0 or day_key.is_empty():
		return false
	var entry: Dictionary = ProfileState.construction_queue[index]
	if String(entry.get("status", "building")) != "building" or remaining_seconds(project_id) <= 0:
		return false
	var config := GameData.ad_placement_config(SPEEDUP_PLACEMENT)
	if int(entry.get("ad_speedup_count", 0)) >= int(config["max_per_project"]):
		return false
	return ProfileState.daily_ad_usage(SPEEDUP_PLACEMENT, day_key) < int(config["max_per_day"])


func _grant_speedup(transaction_id: String, context: Dictionary) -> void:
	var project_id := StringName(String(context.get("project_id", "")))
	var status := project_status(project_id)
	if status in [STATUS_READY, STATUS_COMPLETED]:
		ProfileState.complete_reward_transaction(transaction_id)
		return
	if not _is_speedup_eligible(context):
		return
	var config := GameData.ad_placement_config(SPEEDUP_PLACEMENT)
	ProfileState.commit_workshop_speedup(
		transaction_id,
		project_id,
		int(config["seconds_reduced"]),
		int(config["max_per_project"]),
		String(context["day_key"]),
		int(config["max_per_day"]),
		_resolved_time(-1)
	)


func _resolved_time(now_unix: int) -> int:
	return now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
