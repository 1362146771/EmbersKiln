class_name CombatHUD
extends RefCounted
## 玩家 HUD 刷新逻辑。从 CombatUI 抽出（P4b）。
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


func _refresh_energy_badge(current: int) -> void:
	ui.player_energy.text = "%d" % current
	ui.player_energy.add_theme_color_override(
		"font_color",
		Color("7a1f1f") if current == 0 else ui.CREAM
	)
