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
	if ui.card_browser_open():
		return
	if ui._casting or ui._drag_active or BattleDirector.input_locked or ui.combat_over or ui.controller.phase != CombatController.Phase.PLAYER:
		return
	ui._drag_active = true
	ui._drag_card = view
	view.modulate.a = 0.3                       # 原卡淡出，由幽灵卡代为飞行
	build_drop_targets()
	ui.drop_layer.highlight(view.card_data.target)
	var gr := view.get_global_rect()
	ui._ghost = ui.CardViewScene.instantiate()
	ui._ghost.set_ghost(true)
	ui._ghost.build_visual(view.card_data, -1, view.enchants, view.upgraded, view.resolved_cost)
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
	var over_discard := ui.drop_layer.hit_test(gpos) == DropLayer.DISCARD_TARGET
	ui._hand.set_discard_hover(over_discard)
	if over_discard:
		# 提起卡牌，完整露出图标、数量和“松手弃牌”提示。
		ui._ghost.global_position.y = ui.discard_pile_view.global_position.y - ui._ghost.size.y - 12.0


func on_card_drag_ended(view: CardView, gpos: Vector2) -> void:
	if not ui._drag_active or ui._ghost == null or view != ui._drag_card:
		return
	if ui._casting or BattleDirector.input_locked or ui.combat_over or ui.controller.phase != CombatController.Phase.PLAYER:
		snap_back(view)
		return
	var idx := ui.drop_layer.hit_test(gpos)
	if idx == DropLayer.DISCARD_TARGET:
		discard_card(view)
		return
	if idx == -2:
		snap_back(view)
		return
	if not ui.controller.can_play_card(view.card_index):
		ui._log("能量不足，可拖到弃牌堆弃置")
		snap_back(view)
		return
	cast_card(view, idx)


## 注入本次拖拽的合法落点：玩家面板（self/none）+ 各存活敌人面板（enemy/all_enemies）。
func build_drop_targets() -> void:
	var targets := []
	if ui.discard_pile_view != null and ui._drag_card != null:
		targets.append({"node": ui.discard_pile_view, "types": [ui._drag_card.card_data.target], "index": DropLayer.DISCARD_TARGET})
	if ui._drag_card != null and not ui.controller.can_play_card(ui._drag_card.card_index):
		ui.drop_layer.set_targets(targets)
		return
	targets.append({"node": ui.player_panel, "types": [&"self", &"none"], "index": -1})
	if ui.player_sprite != null and ui.player_sprite.is_visible_in_tree():
		targets.append({"node": ui.player_sprite, "types": [&"self", &"none"], "index": -1})
	for i in ui.controller.enemies.size():
		var e: CombatUnit = ui.controller.enemies[i]
		if e.is_alive():
			var p: Panel = ui.unit_panels.get(e)
			if p != null:
				targets.append({"node": p, "types": [&"enemy", &"all_enemies"], "index": i})
	ui.drop_layer.set_targets(targets)


## 弃牌独立于 BattleDirector.play_card_cast，绝不触发卡牌效果或攻击演出。
func discard_card(view: CardView) -> void:
	ui._casting = true
	if not ui.controller.discard_card(view.card_index):
		snap_back(view)
		return
	ui._drag_active = false
	ui.drop_layer.clear()
	ui._hand.set_discard_hover(false)
	var ghost := ui._ghost
	view.modulate.a = 0.0
	var destination := ui.discard_pile_view.get_global_rect().get_center() - ghost.size * 0.1
	var tw := ui.create_tween().set_parallel(true)
	tw.tween_property(ghost, "global_position", destination, 0.18).set_ease(Tween.EASE_IN)
	tw.tween_property(ghost, "scale", Vector2(0.2, 0.2), 0.18)
	tw.tween_property(ghost, "modulate:a", 0.0, 0.18)
	await tw.finished
	if is_instance_valid(ghost):
		ghost.queue_free()
	ui._ghost = null
	ui._drag_card = null
	finish_cast_refresh()


## 施放演出：幽灵卡飞向目标，到达瞬间才真正结算（play_card），既有飘字/血条 VFX 自然接管。
## 飞行 + 到达结算 + 元素爆发 + 缓冲统一交给 BattleDirector.play_card_cast（await 编排）；
## 必须来自当前拖拽，不再保留点击施放或无拖拽直接施放路径。
func cast_card(view: CardView, target_index: int) -> void:
	if not ui._drag_active or ui._drag_card != view or ui._ghost == null:
		return
	ui._hand.set_discard_hover(false)
	ui._casting = true
	ui._drag_active = false
	var idx: int = view.card_index
	var cd: CardData = view.card_data

	var target_node: Control = ui.player_panel
	if target_index >= 0 and target_index < ui.controller.enemies.size():
		var e: CombatUnit = ui.controller.enemies[target_index]
		var p: Panel = ui.unit_panels.get(e)
		if p != null:
			target_node = p

	var ghost = ui._ghost

	# 演出（飞行 + 到达结算 + 爆发 + 缓冲）交由 BattleDirector 编排
	await BattleDirector.play_card_cast(ghost, target_node, cd, idx, target_index, ui.controller)

	ui.selected_target = -1
	if is_instance_valid(ghost):
		ghost.queue_free()
	ui._ghost = null
	ui._drag_card = null
	ui._casting = false
	ui.drop_layer.clear()
	finish_cast_refresh()


## 非法落点：幽灵卡弹回原位并释放，原卡恢复。
func snap_back(view: CardView) -> void:
	var gr := view.get_global_rect()
	var ghost = ui._ghost
	ui._ghost = null
	ui.drop_layer.clear()
	ui._hand.set_discard_hover(false)
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
			view.set_playable(ui.controller.can_play_card(view.card_index))
		finish_cast_refresh()
	)


## 解锁后统一刷新（演出期间累计的刷新需求在此一次性落地）。
func finish_cast_refresh() -> void:
	ui._casting = false
	ui._needs_refresh = false
	ui._refresh_all()


## 拒绝反馈：卡牌红色脉冲，并提示原因（不消耗牌）。
func reject_card(view: CardView, msg: String) -> void:
	ui._log(msg)
	var tw := ui.create_tween()
	tw.tween_property(view, "modulate", Color(1.0, 0.5, 0.5), 0.08)
	tw.tween_property(view, "modulate", Color(1.0, 1.0, 1.0), 0.22)


func on_end_turn() -> void:
	if ui.card_browser_open():
		return
	if ui._casting or ui._drag_active or BattleDirector.input_locked or ui.combat_over or ui.controller.phase != CombatController.Phase.PLAYER:
		return
	ui._log("结束回合 —— 召唤阶段 + 敌人行动中…")
	ui.controller.end_player_turn()
	# 阶段顺序：玩家结束回合 → 召唤物阶段（友色光弹攻击，带动画/VFX）→ 敌人回合。
	# 两者均由 BattleDirector 异步编排（input_locked 期间阻塞输入），"全播完才进下一回合"。
	# 先 await 召唤阶段，结束解锁后再驱动敌人回合（run_enemy_turn 自身再上锁）。
	var enemy_getter := func(e): return ui.unit_panels.get(e) if is_instance_valid(e) else null
	var ally_getter := func(a): return ui.ally_panels.get(a) if is_instance_valid(a) else null
	await BattleDirector.run_summon_turn(ui.controller, ui.player_panel, enemy_getter, ally_getter)
	BattleDirector.run_enemy_turn(ui.controller, ui.player_panel, enemy_getter)


func on_potion_pressed(i: int) -> void:
	if ui.card_browser_open():
		return
	if ui._casting or ui._drag_active or BattleDirector.input_locked or ui.combat_over or ui.controller.phase != CombatController.Phase.PLAYER:
		return
	if i < 0 or i >= RunState.potions.size():
		return
	var pid: StringName = RunState.potions[i]
	var pd: PotionData = GameData.get_potion(pid)
	if pd == null:
		return
	var target := -1
	if pd.target == &"enemy":
		if ui.selected_target >= 0 and ui.selected_target < ui.controller.enemies.size() and ui.controller.enemies[ui.selected_target].is_alive():
			target = ui.selected_target
		else:
			target = ui._first_alive_index()
	var ok := ui.controller.use_potion(i, target)
	if ok:
		ui._log("使用药水：%s" % pd.name)
		ui.selected_target = -1
		ui._hud.refresh_potions()
		ui._hud.refresh_resources()
		ui._enemy.refresh_enemy()
