class_name EnemyViewManager
extends RefCounted
## 敌人面板视图管理（v2 in-place 持久面板）。从 CombatUI 抽出（P4b）。
## 通过 ui 引用门面 CombatUI 的节点字段与共享 helper。零 preload。

var ui: CombatUI

func attach(ui_ref: CombatUI) -> void:
	ui = ui_ref


## 重绘敌人区（v2 in-place）：存活敌人首次创建面板并存 unit_panels；之后只更新内容，不销毁面板。
## 面板持久化使 VFX 子节点不被刷新误杀（见 VFX_DESIGN.md）。死亡敌人由 _on_unit_died 延后释放。
func refresh_enemy() -> void:
	if ui._casting or ui._drag_active or BattleDirector.input_locked or ui.controller.phase != CombatController.Phase.PLAYER:
		ui._needs_refresh = true
		return
	for i in ui.controller.enemies.size():
		var e: CombatUnit = ui.controller.enemies[i]
		if not e.is_alive():
			continue
		if not ui.unit_panels.has(e):
			create_enemy_panel(e, i)
		else:
			update_enemy_panel(e, i)


func create_enemy_panel(e: CombatUnit, index: int) -> void:
	var p = ui.EnemyPanelScene.instantiate()
	p.custom_minimum_size = enemy_size()
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(ui._targeting.on_enemy_gui_input.bind(index))
	# 用 MarginContainer 承载垂直偏移：HBox 每帧重排会覆盖直接设的 position.y
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_top", ui.ENEMY_PANEL_OFFSET_Y)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(p)
	ui.enemy_area.add_child(holder)
	ui.unit_panels[e] = p
	ui._prev_ehp[e] = e.hp
	var sel := (index == ui.selected_target)
	p.build(e, index, sel, ui.controller.enemies.size())


func update_enemy_panel(e: CombatUnit, index: int) -> void:
	var p = ui.unit_panels.get(e)
	if p == null:
		create_enemy_panel(e, index)
		return
	var sel := (index == ui.selected_target)
	p.build(e, index, sel, ui.controller.enemies.size())


# 敌人面板内层内容现由 EnemyPanel.build() 就地更新（见 scenes/combat/EnemyPanel.tscn），不再销毁重建。


func enemy_size() -> Vector2:
	var n := ui.controller.enemies.size()
	var pw := 480 if n <= 1 else (330 if n == 2 else 230)
	# 单敌区为顶部遗物栏让出空间，避免手牌下移到玩家立绘脸部。
	var ph := 460 if n <= 1 else (380 if n == 2 else 340)
	return Vector2(pw, ph)


func free_enemy(e: CombatUnit) -> void:
	if ui.unit_panels.has(e):
		var p: Panel = ui.unit_panels[e]
		ui.unit_panels.erase(e)
		if is_instance_valid(p):
			var parent = p.get_parent()
			if parent != null and parent != ui.enemy_area:
				parent.queue_free()   # 连带包裹的 MarginContainer 一起释放（避免残留空壳）
			else:
				p.queue_free()
	if ui._prev_ehp.has(e):
		ui._prev_ehp.erase(e)


func format_intent(e: CombatUnit) -> String:
	var kind: String = e.intent.get("intent", "未知")
	if kind == "charge":
		var nx := StringName(e.intent.get("next", ""))
		var rel: Dictionary = {}
		if e.data != null:
			rel = e.data.find_move(nx)
		var rel_kind: String = ui._intent_cn(String(rel.get("intent", "未知")))
		var rel_val: int = int(rel.get("value", 0))
		var rel_times: int = int(rel.get("times", 1))
		var t := "蓄力→%s %d" % [rel_kind, rel_val]
		if rel_times > 1:
			t += " ×%d" % rel_times
		return t
	else:
		var val: int = int(e.intent.get("value", 0))
		var times: int = int(e.intent.get("times", 1))
		var t := "%s %d" % [ui._intent_cn(kind), val]
		if times > 1:
			t += " ×%d" % times
		return t


# ---------- 敌人 SignalBus 回调 ----------

func on_ehp(index: int, cur: int, maxv: int) -> void:
	refresh_enemy()
	if index >= 0 and index < ui.controller.enemies.size():
		var e: CombatUnit = ui.controller.enemies[index]
		var prev: int = ui._prev_ehp.get(e, -1)
		if prev >= 0 and cur > prev:
			var p: Panel = ui.unit_panels.get(e)
			if p != null:
				VFXSystem.spawn_heal(p, cur - prev)
		ui._prev_ehp[e] = cur


func on_eintent(index: int, intent: StringName, value: int) -> void:
	refresh_enemy()
