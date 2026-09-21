class_name HandView
extends RefCounted
## 手牌区渲染 + 卡牌打出 VFX 触发。从 CombatUI 抽出（P4b）。
## 通过 ui 引用门面 CombatUI 的节点字段与共享 helper。零 preload。

var ui: CombatUI
var _pile_counts: Dictionary = {}
var _pile_tweens: Dictionary = {}

func attach(ui_ref: CombatUI) -> void:
	ui = ui_ref


func refresh_hand(force_phase_sync := false) -> void:
	refresh_discard_pile()
	if ui._casting or ui._drag_active or (not force_phase_sync and ui.controller.phase != CombatController.Phase.PLAYER):
		ui._needs_refresh = true
		return
	ui._needs_refresh = false
	for c in ui.hand_container.get_children():
		ui.hand_container.remove_child(c)
		c.queue_free()
	for i in range(ui.controller.hand.size()):
		var entry: Dictionary = ui.controller.hand[i]
		if ui._play_queue.contains(entry): continue
		var cd: CardData = GameData.get_card(StringName(entry["id"]))
		if cd == null:
			continue
		var enchants: Array = entry.get("enchants", [])
		var level := ui.controller._card_upgrade_state(entry)
		var b := build_card_view(cd, i, enchants, level > 0, ui.controller.card_cost(entry, cd), entry)
		ui.hand_container.add_child(b)


func build_card_view(cd: CardData, i: int, enchants: Array = [], upgraded: bool = false, resolved_cost: int = -999, entry: Dictionary = {}) -> CardView:
	var v := ui.CardViewScene.instantiate()
	v.build_visual(cd, i, enchants, upgraded, resolved_cost, entry)
	v.set_meta("hand_entry", entry)
	v.set_playable(ui._play_queue.can_submit(entry))
	if ui.combat_over:
		v.set_enabled(false)
	v.drag_started.connect(ui._targeting.on_card_drag_started)
	v.drag_moved.connect(ui._targeting.on_card_drag_moved)
	v.drag_ended.connect(ui._targeting.on_card_drag_ended)
	v.drag_canceled.connect(ui._targeting.on_card_drag_canceled)
	v.tapped.connect(ui._targeting.on_card_tapped)
	return v


func refresh_discard_pile() -> void:
	if ui.draw_pile_button != null:
		_update_pile_count(ui.draw_pile_button.get_node("Count"), ui.controller.draw_pile.size())
	if ui.discard_pile_view != null:
		_update_pile_count(ui.discard_pile_view.get_node("Content/Labels/Count"), ui.controller.discard_pile.size())


func _update_pile_count(label: Label, count: int) -> void:
	var key := label.get_instance_id()
	label.text = str(count)
	var changed: bool = _pile_counts.has(key) and _pile_counts[key] != count
	_pile_counts[key] = count
	if not changed:
		return
	var previous: Tween = _pile_tweens.get(key)
	if previous != null and previous.is_valid():
		previous.kill()
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE
	var config: Dictionary = GameData.vfx["card_presentation"]
	var tween := label.create_tween()
	_pile_tweens[key] = tween
	tween.tween_property(label, "scale", Vector2.ONE * float(config["count_peak_scale"]), float(config["count_expand_seconds"])).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, float(config["count_restore_seconds"])).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 卡牌打出 VFX + 攻击牌立绘姿态（玩家受击/死亡锁定后不切）。
func on_card_played(_card_id: StringName, _target_index: int) -> void:
	refresh_hand()
	VFXSystem.spawn_card_played(ui.player_panel)
	if ui._player_dead:
		return
	# CombatFeedback starts one attack pose per card before its first hit.
