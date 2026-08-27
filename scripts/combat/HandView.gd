class_name HandView
extends RefCounted
## 手牌区渲染 + 卡牌打出 VFX 触发。从 CombatUI 抽出（P4b）。
## 通过 ui 引用门面 CombatUI 的节点字段与共享 helper。零 preload。

var ui: CombatUI

func attach(ui_ref: CombatUI) -> void:
	ui = ui_ref


func refresh_hand() -> void:
	refresh_discard_pile()
	if ui._casting or ui._drag_active or BattleDirector.input_locked or ui.controller.phase != CombatController.Phase.PLAYER:
		ui._needs_refresh = true
		return
	for c in ui.hand_container.get_children():
		ui.hand_container.remove_child(c)
		c.queue_free()
	for i in range(ui.controller.hand.size()):
		var entry: Dictionary = ui.controller.hand[i]
		var cd: CardData = GameData.get_card(StringName(entry["id"]))
		if cd == null:
			continue
		var enchants: Array = entry.get("enchants", [])
		var b := build_card_view(cd, i, enchants)
		ui.hand_container.add_child(b)


func build_card_view(cd: CardData, i: int, enchants: Array = []) -> CardView:
	var v := ui.CardViewScene.instantiate()
	v.build_visual(cd, i, enchants)
	v.set_playable(ui.controller.energy >= cd.cost)
	if ui.combat_over:
		v.set_enabled(false)
	v.drag_started.connect(ui._targeting.on_card_drag_started)
	v.drag_moved.connect(ui._targeting.on_card_drag_moved)
	v.drag_ended.connect(ui._targeting.on_card_drag_ended)
	v.tapped.connect(ui._targeting.on_card_tapped)
	return v


func refresh_discard_pile() -> void:
	if ui.draw_pile_button != null:
		ui.draw_pile_button.text = "抽牌堆 %d" % ui.controller.draw_pile.size()
	if ui.discard_pile_view != null:
		ui.discard_pile_view.get_node("Content/Labels/Count").text = "弃牌堆\n%d" % ui.controller.discard_pile.size()


func set_discard_hover(hovered: bool) -> void:
	if ui.discard_pile_view != null:
		ui.discard_pile_view.get_node("Content/Labels/Hint").text = "松手弃牌" if hovered else "拖到此处"


## 卡牌打出 VFX + 攻击牌立绘姿态（玩家受击/死亡锁定后不切）。
func on_card_played(card_id: StringName, _target_index: int) -> void:
	refresh_discard_pile()
	VFXSystem.spawn_card_played(ui.player_panel)
	if ui._player_dead:
		return
	var cd: CardData = GameData.get_card(card_id)
	if cd != null and cd.type == &"attack":
		ui._set_player_pose(&"attack", ui.PLAYER_POSE_HOLD)
