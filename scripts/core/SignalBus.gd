extends Node
## Autoload: SignalBus —— 全局事件总线。
## 唯一的跨系统通信通道。禁止任何系统直接 get_node 另一个系统。

# ---------- 数据 / 启动 ----------
signal data_loaded()
signal data_load_failed(errors: Array)

# ---------- 永久档案 ----------
signal profile_loaded(created_new: bool)
signal profile_changed()
signal fireseed_changed(amount: int)
signal construction_started(project_id: StringName)
signal construction_ready(project_id: StringName)
signal construction_claimed(project_id: StringName)
signal card_discovered(card_id: StringName)

# ---------- 激励广告 ----------
signal ad_availability_changed(placement_id: StringName, available: bool)
signal ad_playback_started(request_id: String, placement_id: StringName)
signal ad_playback_finished(request_id: String, placement_id: StringName, result: StringName)
signal ad_reward_resolved(transaction_id: String, placement_id: StringName, result: StringName)
signal shop_inventory_changed(shop_id: String)
signal card_acquisition_blocked(acquisition: Dictionary)
signal card_acquisition_resolved(acquisition: Dictionary, result: StringName)
signal pre_run_buff_activated(buff_id: StringName, remaining_floors: int)
signal combat_death_pending()
signal combat_revive_ready()

# ---------- 局内流程 ----------
signal run_started()
signal run_loaded()
signal run_ended(victory: bool)
signal map_generated(map: Array)
# ---------- 多幕（P-A） ----------
signal act_changed(act_index: int)        # 进入新幕（含开局 act=0）
signal run_won()                           # 击败最后一幕 Boss（可选；也可复用 run_ended(true)）
signal floor_entered(floor_index: int, node_type: StringName)
signal floor_resolved(floor_index: int, node_type: StringName)

# ---------- 战斗流程 ----------
signal combat_started(enemy_ids: Array)
signal combat_ended(victory: bool)
signal turn_started(is_player: bool)
signal turn_ended(is_player: bool)
signal energy_changed(current: int, maximum: int)
signal kiln_heat_changed(current: int, threshold: int)

# ---------- 卡牌 ----------
signal card_drawn(card_id: StringName)
signal card_played(card_id: StringName, target_index: int)
signal card_discarded(card_id: StringName)
signal card_exhausted(card_id: StringName)
signal combat_card_choice_requested(title: String, entries: Array)
signal combat_card_choice_resolved()
signal deck_changed()

# ---------- 战斗单位 ----------
signal player_hp_changed(current: int, maximum: int)
signal player_block_changed(current: int)
signal enemy_hp_changed(index: int, current: int, maximum: int)
signal enemy_intent_changed(index: int, intent: StringName, value: int)
signal unit_died(is_player: bool, index: int)
signal damage_dealt(is_player_source: bool, target_index: int, amount: int)

# ---------- 状态 ----------
signal status_applied(is_player: bool, index: int, status_id: StringName, stacks: int)
signal status_removed(is_player: bool, index: int, status_id: StringName)

# ---------- 进度 ----------
signal gold_changed(amount: int)
signal relic_gained(relic_id: StringName)
signal reward_offered(kind: StringName, payload: Dictionary)
