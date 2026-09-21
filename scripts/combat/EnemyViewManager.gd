class_name EnemyViewManager
extends RefCounted
## 敌人面板视图管理（v2 in-place 持久面板）。从 CombatUI 抽出（P4b）。
## 通过 ui 引用门面 CombatUI 的节点字段与共享 helper。零 preload。

var ui: CombatUI
var _portrait_layout_queued := false
var _formation_fits: Dictionary = {}

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
	# 补兵后恢复固定槽位顺序，避免后创建的左翼被排到右翼后方。
	var order := 0
	for e in ui.controller.enemies:
		if e.is_alive() and ui.unit_panels.has(e):
			ui.enemy_area.move_child(ui.unit_panels[e].get_parent(), order)
			order += 1


func create_enemy_panel(e: CombatUnit, index: int) -> void:
	var p = ui.EnemyPanelScene.instantiate()
	p.portrait_layout_changed.connect(_queue_portrait_layout)
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
	p.build(e, index, sel, ui.controller.enemies.size(), ui.controller)
	_queue_portrait_layout()


func _queue_portrait_layout() -> void:
	if _portrait_layout_queued:
		return
	_portrait_layout_queued = true
	_fit_portraits.call_deferred()


func _fit_portraits() -> void:
	_portrait_layout_queued = false
	if not is_instance_valid(ui) or ui.is_queued_for_deletion():
		return
	var multi_scale := float(GameData.vfx["enemy_portrait"]["multi_enemy_scale"])
	# All static enemies use visible content, not the transparent source canvas.
	# State portraits retain their shared canvas registration (Sagger's five poses).
	for unit in ui.controller.enemies:
		var data := unit.data as EnemyData
		if not unit.is_alive() or data == null or unit.leader_index >= 0 or not data.escort_ids.is_empty() or not data.state_sprites.is_empty():
			continue
		var panel: EnemyPanel = ui.unit_panels.get(unit)
		if panel == null or panel.portrait_area.size.x <= 0.0:
			continue
		var cropped := data.cropped_sprite_texture(StringName(unit.intent.get("id", "")))
		if cropped == null:
			continue
		var room := panel.portrait_area
		var width := room.size.x * (multi_scale if ui.controller.enemies.size() > 1 else 1.0)
		var fit := minf(width / cropped.get_width(), room.size.y / cropped.get_height())
		panel.fit_portrait(cropped, fit, room.end.y)
	for leader in ui.controller.enemies:
		var ed := leader.data as EnemyData
		if ed == null or ed.escort_ids.is_empty():
			continue
		# Include the original formation even after a death, so survivors do not grow.
		var largest := ed.cropped_sprite_texture().get_size()
		for id in ed.escort_ids:
			largest = largest.max(GameData.get_enemy(StringName(id)).cropped_sprite_texture().get_size())
		var panels: Array[EnemyPanel] = []
		var textures: Array[AtlasTexture] = []
		var available_width := INF
		var top := -INF
		var baseline := INF
		var leader_index := ui.controller.enemies.find(leader)
		for unit in ui.controller.enemies:
			if not unit.is_alive() or (unit != leader and unit.leader_index != leader_index):
				continue
			var panel: EnemyPanel = ui.unit_panels.get(unit)
			if panel == null or panel.portrait_area.size.x <= 0.0:
				continue
			panels.append(panel)
			textures.append(unit.data.cropped_sprite_texture(StringName(unit.intent.get("id", ""))))
			available_width = minf(available_width, panel.portrait_area.size.x)
			top = maxf(top, panel.portrait_area.position.y)
			baseline = minf(baseline, panel.portrait_area.end.y)
		var fit := minf(available_width / largest.x, (baseline - top) / largest.y)
		fit *= multi_scale
		# Keep a single formation scale, limited by each member's own intent height.
		for index in panels.size():
			fit = minf(fit, (baseline - panels[index].portrait_top_limit()) / textures[index].get_height())
		if leader.is_alive():
			_formation_fits[leader] = fit
		elif _formation_fits.has(leader):
			# Removing the leader must not enlarge the surviving portraits.
			fit = minf(fit, float(_formation_fits[leader]))
		for index in panels.size():
			panels[index].fit_portrait(textures[index], fit, baseline)


func update_enemy_panel(e: CombatUnit, index: int) -> void:
	var p = ui.unit_panels.get(e)
	if p == null:
		create_enemy_panel(e, index)
		return
	var sel := (index == ui.selected_target)
	p.build(e, index, sel, ui.controller.enemies.size(), ui.controller)


# 敌人面板内层内容现由 EnemyPanel.build() 就地更新（见 scenes/combat/EnemyPanel.tscn），不再销毁重建。


func enemy_size() -> Vector2:
	var n := ui.controller.enemies.size()
	var pw := 720 if n <= 1 else (350 if n == 2 else 230)
	if n >= 3:
		# Fit all portrait slots inside the existing 10px side safe margins.
		var available_width := ui.get_viewport_rect().size.x - 20.0
		var separation := ui.enemy_area.get_theme_constant("separation")
		pw = mini(pw, int(floor((available_width - separation * (n - 1)) / n)))
	# 单敌区为顶部遗物栏让出空间，避免手牌下移到玩家立绘脸部。
	var ph := 640
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
	var scripted := EnemyPanel.format_scripted_intent(e, ui.controller)
	if not scripted.is_empty():
		return scripted
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
		var panel: EnemyPanel = ui.unit_panels.get(e)
		if is_instance_valid(panel):
			panel.update_vitals(cur, maxv, e.block)
		var prev: int = ui._prev_ehp.get(e, -1)
		if prev >= 0 and cur > prev:
			var p: Panel = ui.unit_panels.get(e)
			if p != null:
				VFXSystem.spawn_heal(p, cur - prev)
		ui._prev_ehp[e] = cur


func on_eintent(index: int, intent: StringName, value: int) -> void:
	# 破封可能发生在出牌动画期间；不等待全局重绘解锁才更新威胁提示。
	if index >= 0 and index < ui.controller.enemies.size():
		var e: CombatUnit = ui.controller.enemies[index]
		var ed := e.data as EnemyData
		if e.is_alive() and e.leader_index >= 0 and not ui.unit_panels.has(e):
			create_enemy_panel(e, index)
		if e.is_alive() and ed != null and ed.ai == &"scripted_cycle" and ui.unit_panels.has(e):
			update_enemy_panel(e, index)
	refresh_enemy()
