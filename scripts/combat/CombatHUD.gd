class_name CombatHUD
extends RefCounted
## 玩家 + 友方（随从）HUD 刷新逻辑。从 CombatUI 抽出（P4b）。
## 通过 ui 引用门面 CombatUI 的节点字段与共享 helper（样式/格式化工厂）。
## 零 preload：所有跨文件类型走全局 class_name。

var ui: CombatUI

func attach(ui_ref: CombatUI) -> void:
	ui = ui_ref


# =====================================================================
# 玩家资源刷新
# =====================================================================
func refresh_resources() -> void:
	if ui._casting or ui._drag_active or BattleDirector.input_locked or ui.controller.phase != CombatController.Phase.PLAYER:
		ui._needs_refresh = true
		return
	if ui.player_sprite != null and ui.player_sprite.texture == null:
		if ui.controller.player != null and ui.controller.player.sprite != "":
			var ptex = load(ui.controller.player.sprite)
			if ptex != null:
				ui.player_sprite.texture = ptex
	ui.player_hp.text = "HP %d / %d" % [ui.controller.player.hp, ui.controller.player.max_hp]
	if ui.player_hp_bar != null:
		ui.player_hp_bar.max_value = ui.controller.player.max_hp
		ui.player_hp_bar.value = ui.controller.player.hp
	ui.player_block.text = "%d" % ui.controller.player.block
	_refresh_energy_badge(ui.controller.energy)
	ui.player_status.set_unit(ui.controller.player, ui.controller.kiln_heat, ui.controller._kiln_threshold())


func refresh_potions() -> void:
	if ui.potion_bar == null:
		return
	var inv: Array = RunState.potions
	for i in ui.potion_slots.size():
		var slot: Button = ui.potion_slots[i]
		var ic: TextureRect = ui.potion_icons[i] if i < ui.potion_icons.size() else null
		if i >= inv.size():
			slot.text = ""
			slot.disabled = true
			slot.tooltip_text = ""
			slot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			if ic != null:
				ic.texture = null
			continue
		var pid: StringName = inv[i]
		var pd: PotionData = GameData.get_potion(pid)
		if pd == null:
			slot.text = ""
			slot.disabled = true
			slot.tooltip_text = ""
			slot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			if ic != null:
				ic.texture = null
			continue
		slot.text = pd.name
		slot.disabled = ui.combat_over or ui.controller.phase != CombatController.Phase.PLAYER
		slot.tooltip_text = pd.description
		if ic != null:
			ic.texture = GameData.icon_texture(pd.icon)
		slot.add_theme_stylebox_override("normal", StyleBoxEmpty.new())


## .new() 路径：创建 3 个药水槽（VBox: Icon + SlotButton），挂到 potion_bar。
func spawn_potion_slots() -> void:
	ui.potion_slots.clear()
	ui.potion_icons.clear()
	for i in 3:
		var slot_box := preload("res://scenes/combat/PotionSlot.tscn").instantiate()
		ui.potion_bar.add_child(slot_box)



## 从 potion_bar 的 SlotBox 子节点读取 Icon / SlotButton，填充 potion_slots / potion_icons。
func collect_potion_slots() -> void:
	ui.potion_slots.clear()
	ui.potion_icons.clear()
	if ui.potion_bar == null:
		return
	for sb in ui.potion_bar.get_children():
		var ic: TextureRect = sb.get_node_or_null("Icon")
		var btn: Button = sb.get_node_or_null("SlotButton")
		if ic != null:
			ui.potion_icons.append(ic)
		if btn != null:
			ui.potion_slots.append(btn)


func connect_potion_slots() -> void:
	var interaction := preload("res://scripts/combat/PotionInteraction.gd").new()
	interaction.name = "PotionInteraction"
	interaction.ui = ui
	ui.add_child(interaction)
	for i in ui.potion_slots.size():
		interaction.connect_source(ui.potion_slots[i], i)
		if i < ui.potion_icons.size():
			interaction.connect_source(ui.potion_icons[i], i)


# =====================================================================
# 玩家资源 SignalBus 回调（薄转发目标）
# =====================================================================
func on_php(cur: int, maxv: int) -> void:
	ui.player_hp.text = "HP %d / %d" % [cur, maxv]
	if ui.player_hp_bar != null:
		ui.player_hp_bar.max_value = maxv
		ui.player_hp_bar.value = cur
	if ui._prev_php >= 0 and cur > ui._prev_php:
		VFXSystem.spawn_heal(ui.player_panel, cur - ui._prev_php)
	ui._prev_php = cur


func on_pblock(cur: int) -> void:
	ui.player_block.text = "%d" % cur
	VFXSystem.spawn_block(ui.player_panel)


func on_energy(cur: int, maxv: int) -> void:
	_refresh_energy_badge(cur)
	ui._hand.refresh_hand()


func on_kiln(current: int, threshold: int) -> void:
	ui.player_status.set_unit(ui.controller.player, current, threshold)


# =====================================================================
# 随从 / 召唤 UI（友方单位 chip，见 SUMMON_SYSTEM_DESIGN.md §6.1）
# =====================================================================

## 同步 chip 面板：为当前每个存活随从补建面板并重新布局。死亡由 on_ally_died 单独淡出。
func sync_ally_panels() -> void:
	for i in ui.controller.allies.size():
		var a: CombatUnit = ui.controller.allies[i]
		if not ui.ally_panels.has(a):
			create_ally_panel(a, i)
	reposition_allies()


## 创建随从 chip：青蓝底面板（AllyPanel.tscn 内含底色），挂在 root 上（与 player_sprite 同层），手动定位以支持 §6.1 遮挡层级。
func create_ally_panel(a: CombatUnit, index: int) -> void:
	var p = ui.AllyPanelScene.instantiate()
	p.custom_minimum_size = Vector2(ui.ALLY_CHIP_W, ui.ALLY_CHIP_H)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.z_index = ui.ALLY_DARK_Z          # 暗态：玩家立绘之下 → 被遮挡
	p.modulate = Color(1, 1, 1, 1)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(p)
	ui.ally_panels[a] = p
	p.build(a, index)
	reposition_allies()
	# §6.1 登场高亮：放大 + 全亮，随后回落到暗态（被玩家立绘遮挡）
	p.pivot_offset = Vector2(ui.ALLY_CHIP_W, ui.ALLY_CHIP_H)
	p.scale = Vector2(1.08, 1.08)
	var tw := ui.create_tween()
	tw.tween_property(p, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "modulate:a", ui.ALLY_DARK_ALPHA, 0.4).set_ease(Tween.EASE_OUT)


## 横向排布：起始 X 在屏幕右下（与玩家立绘左下对称），多随从向左排开（ALLY_STEP_X 为负）。
func reposition_allies() -> void:
	var i := 0
	for a in ui.controller.allies:
		var p: Panel = ui.ally_panels.get(a)
		if p == null or not is_instance_valid(p):
			continue
		p.position = Vector2(ui.ALLY_BASE_X + i * ui.ALLY_STEP_X, ui.ALLY_BASE_Y)
		i += 1


func format_ally_intent(a: CombatUnit) -> String:
	var kind: String = a.intent.get("intent", "未知")
	var val: int = int(a.intent.get("value", 0))
	var times: int = int(a.intent.get("times", 1))
	var t := "%s %d" % [ui._intent_cn(kind), val]
	if times > 1:
		t += " ×%d" % times
	return t


func ally_at(index: int) -> CombatUnit:
	if index < 0 or index >= ui.controller.allies.size():
		return null
	return ui.controller.allies[index]


func refresh_ally(index: int) -> void:
	var a := ally_at(index)
	if a == null:
		return
	var p = ui.ally_panels.get(a)
	if p != null:
		p.build(a, index)


# ---------- 随从 SignalBus 回调 ----------

func on_ally_hp(index: int, _cur: int, _maxv: int) -> void:
	refresh_ally(index)


func on_ally_block(index: int, _cur: int) -> void:
	refresh_ally(index)


func on_ally_intent(index: int, _intent: StringName, _value: int) -> void:
	refresh_ally(index)


func on_ally_status(index: int, _status_id: StringName, _stacks: int) -> void:
	refresh_ally(index)


func on_ally_lifetime(index: int, _lifetime: int) -> void:
	refresh_ally(index)


func on_allies_changed() -> void:
	sync_ally_panels()


## §6.1 行动态：亮度拉满 + 层级提到玩家立绘之上（盖住玩家）。
func on_ally_action_start(index: int) -> void:
	var a := ally_at(index)
	if a == null:
		return
	var p: Panel = ui.ally_panels.get(a)
	if p == null:
		return
	p.z_index = ui.ALLY_ACT_Z
	var tw := ui.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)


## §6.1 行动结束：恢复暗态亮度 + 层级落回玩家立绘之下（恢复被遮挡状态）。
func on_ally_action_end(index: int) -> void:
	var a := ally_at(index)
	if a == null:
		return
	var p: Panel = ui.ally_panels.get(a)
	if p == null:
		return
	p.z_index = ui.ALLY_DARK_Z
	var tw := ui.create_tween()
	tw.tween_property(p, "modulate:a", ui.ALLY_DARK_ALPHA, 0.18).set_ease(Tween.EASE_OUT)


## 死亡淡出：动画播完才释放面板，并让存活随从前移补位。
func on_ally_died(index: int) -> void:
	var a := ally_at(index)
	if a == null:
		return
	var p: Panel = ui.ally_panels.get(a)
	ui.ally_panels.erase(a)
	if p == null or not is_instance_valid(p):
		reposition_allies()
		return
	VFXSystem.spawn_death(p, func(): if is_instance_valid(p): p.queue_free())
	reposition_allies()


func _refresh_energy_badge(current: int) -> void:
	ui.player_energy.text = "%d" % current
	ui.player_energy.add_theme_color_override(
		"font_color",
		Color("7a1f1f") if current == 0 else ui.CREAM
	)
