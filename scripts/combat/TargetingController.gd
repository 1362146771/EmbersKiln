class_name TargetingController
extends RefCounted
## 目标选择 + 拖拽出牌演出 + 顶层交互入口（结束回合 / 药水）。从 CombatUI 抽出（P4b）。
## 通过 ui 读写门面 CombatUI 的交互状态字段（_casting / _drag_active / _needs_refresh / _ghost / _drag_card / selected_target 等）。
## 零 preload。

var ui: CombatUI

func attach(ui_ref: CombatUI) -> void:
	ui = ui_ref


func on_enemy_gui_input(ev: InputEvent, index: int) -> void:
	if ui.card_browser_open():
		return
	if ui.combat_over or ui.controller.phase != CombatController.Phase.PLAYER:
		return
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		if index < ui.controller.enemies.size() and ui.controller.enemies[index].is_alive():
			ui.selected_target = index
			ui._enemy.refresh_enemy()
			ui._log("已选中目标：%s" % ui.controller.enemies[index].unit_name)


# =====================================================================
# 拖拽出牌（P1）：CardView 广播手势 → 解算落点 → 播放 cast 动画 + VFX → 结算
# =====================================================================

## 轻点只查看详情，不消耗能量、不选取默认目标、不结算卡牌。
func on_card_tapped(view: CardView) -> void:
	ui._open_card_details(view)


func on_card_drag_started(view: CardView) -> void:
	SignalBus.sound_requested.emit(&"card_pickup")
	if ui.card_browser_open():
		return
	if ui._casting or ui._drag_active or ui.combat_over or ui.controller.phase != CombatController.Phase.PLAYER:
		return
	ui._drag_active = true
	ui._drag_card = view
	view.modulate.a = 0.3                       # 原卡淡出，由幽灵卡代为飞行
	build_drop_targets()
	ui.drop_layer.highlight(view.card_data.target)
	var gr := view.get_global_rect()
	ui._ghost = ui.CardViewScene.instantiate()
	ui._ghost.set_ghost(true)
	ui._ghost.build_visual(view.card_data, -1, view.enchants, view.upgraded, view.resolved_cost, view.entry_snapshot)
	ui._ghost.custom_minimum_size = gr.size
	ui.drag_layer.add_child(ui._ghost)
	ui._ghost.global_position = gr.position
	ui._ghost.size = gr.size
	ui._ghost.scale = Vector2(1.0, 1.0)


func on_card_drag_moved(view: CardView, gpos: Vector2) -> void:
	if ui._ghost == null or view != ui._drag_card:
		return
	# 卡牌浮在手指上方一点，避免被手指遮挡
	ui._ghost.global_position = gpos - ui._ghost.size * 0.5 - Vector2(0, ui._ghost.size.y * 0.25)
	ui.drop_layer.hover_update(gpos)
	ui.drop_layer.set_arrow(view.get_global_rect().get_center(), gpos)


func on_card_drag_canceled(view: CardView) -> void:
	if view != ui._drag_card or not ui._drag_active:
		return
	if is_instance_valid(ui._ghost):
		ui._ghost.queue_free()
	ui._ghost = null
	ui._drag_card = null
	ui._drag_active = false
	ui.drop_layer.clear()
	view.set_playable(ui._play_queue.can_submit(view.get_meta("hand_entry", {})))
	# Pause notifications traverse the tree: rebuild only after that traversal ends.
	_refresh_after_drag_cancel.call_deferred()


func _refresh_after_drag_cancel() -> void:
	if is_instance_valid(ui) and ui.is_inside_tree() and not ui.is_queued_for_deletion():
		ui._hand.refresh_hand()


func on_card_drag_ended(view: CardView, gpos: Vector2) -> void:
	if not ui._drag_active or ui._ghost == null or view != ui._drag_card:
		return
	if ui._casting or ui.card_browser_open() or ui.combat_over or ui.controller.phase != CombatController.Phase.PLAYER:
		snap_back(view)
		return
	var idx := ui.drop_layer.hit_test(gpos)
	if idx == -2:
		snap_back(view)
		return
	if not ui._play_queue.can_submit(view.get_meta("hand_entry", {})):
		ui._log("当前无法打出这张牌")
		snap_back(view)
		return
	cast_card(view, idx)


## 注入本次拖拽的合法落点：玩家面板（self/none）+ 各存活敌人面板（enemy/all_enemies）。
func build_drop_targets(check_card_playability: bool = true) -> void:
	var targets := []
	if check_card_playability and ui._drag_card != null and not ui._play_queue.can_submit(ui._drag_card.get_meta("hand_entry", {})):
		ui.drop_layer.set_targets(targets)
		return
	var player_outline: Control = ui.player_sprite if ui.player_sprite != null and ui.player_sprite.is_visible_in_tree() else ui.player_panel
	targets.append({"outline_node": player_outline, "node": ui.player_panel, "types": [&"self", &"none"], "index": -1})
	if ui.player_sprite != null and ui.player_sprite.is_visible_in_tree():
		targets.append({"node": ui.player_sprite, "types": [&"self", &"none"], "index": -1})
	for i in ui.controller.enemies.size():
		var e: CombatUnit = ui.controller.enemies[i]
		if e.is_alive():
			var p: Panel = ui.unit_panels.get(e)
			if p != null:
				targets.append({"outline_node": p.get_node("Inner/SpriteRect"), "node": p, "types": [&"enemy", &"all_enemies"], "index": i})
	ui.drop_layer.set_targets(targets)


## 施放演出：幽灵卡飞向目标，到达瞬间才真正结算（play_card），既有飘字/血条 VFX 自然接管。
## 提交后手牌视图立即移除，由 CardPlayQueue 顺序调用 BattleDirector；收牌飞行独立进行。
## 必须来自当前拖拽，不再保留点击施放或无拖拽直接施放路径。
func cast_card(view: CardView, target_index: int) -> void:
	if not ui._drag_active or ui._drag_card != view or ui._ghost == null:
		return
	var ghost: Control = ui._ghost
	ghost.set_meta("discard_target", weakref(ui.discard_pile_view))
	if not ui._play_queue.submit(view.get_meta("hand_entry", {}), target_index, ghost):
		snap_back(view)
		return
	# Detach the pointer gesture before rebuilding; the queue owns this ghost now.
	ui._drag_active = false
	ui._ghost = null
	ui._drag_card = null
	ui.selected_target = -1
	ui.drop_layer.clear()
	ui._hand.refresh_hand()


## 非法落点：幽灵卡弹回原位并释放，原卡恢复。
func snap_back(view: CardView) -> void:
	SignalBus.sound_requested.emit(&"card_return")
	var gr := view.get_global_rect()
	var ghost = ui._ghost
	ui._ghost = null
	ui.drop_layer.clear()
	ui._drag_active = false
	ui._drag_card = null
	ui._casting = true  # 回弹完再重建手牌，避免回弹中快速重复拖拽留下幽灵卡。
	if ghost == null:
		finish_cast_refresh()
		return
	var tw := ui.create_tween()
	tw.tween_property(ghost, "global_position", gr.position, 0.16).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ghost, "scale", Vector2(1.0, 1.0), 0.16)
	tw.tween_callback(func():
		if is_instance_valid(ghost):
			ghost.queue_free()
		if is_instance_valid(view):
			view.set_playable(ui._play_queue.can_submit(view.get_meta("hand_entry", {})))
		finish_cast_refresh()
	)


## 解锁后统一刷新（演出期间累计的刷新需求在此一次性落地）。
func finish_cast_refresh() -> void:
	ui._casting = false
	ui._needs_refresh = false
	ui._refresh_all()


## 拒绝反馈：卡牌红色脉冲，并提示原因（不消耗牌）。
func reject_card(view: CardView, msg: String) -> void:
	SignalBus.sound_requested.emit(&"ui_deny")
	ui._log(msg)
	var tw := ui.create_tween()
	tw.tween_property(view, "modulate", Color(1.0, 0.5, 0.5), 0.08)
	tw.tween_property(view, "modulate", Color(1.0, 1.0, 1.0), 0.22)


func on_end_turn() -> void:
	if ui.card_browser_open():
		return
	if ui._casting or ui._drag_active or ui._play_queue.busy() or BattleDirector.input_locked or ui.combat_over or ui.controller.phase != CombatController.Phase.PLAYER:
		return
	ui._log("结束回合 —— 敌人行动中…")
	ui.controller.end_player_turn()
	var enemy_getter := func(e): return ui.unit_panels.get(e) if is_instance_valid(e) else null
	BattleDirector.run_enemy_turn(ui.controller, ui.player_panel, enemy_getter)


## 点击药水只显示说明；使用由 PotionInteraction 的拖拽松手入口处理。
func on_potion_pressed(i: int) -> void:
	if ui.card_browser_open() or ui._casting or ui._drag_active:
		return
	if i < 0 or i >= RunState.potions.size():
		return
	var pd := GameData.get_potion(RunState.potions[i])
	if pd != null:
		ui.get_node("PotionDetails").present(pd, ui.potion_icons[i].get_global_rect())
