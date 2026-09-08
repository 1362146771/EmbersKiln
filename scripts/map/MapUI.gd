extends Control
## T3-UI：地图可视化 + 节点进入体验。
## 读取 RunState.current_map() 绘制当前幕地图（f0 在底、Boss 在顶），节点按类型着色，
## 连线显示可达路径；仅当前前沿节点可点。战斗类节点复用 CombatUI 叠加层进入战斗，
## 胜利后返回地图刷新可达；非战斗节点给简单效果后继续。
## 美术为占位级（代码内建控件），后续由美术设计师细化。

const CombatPlayScene := preload("res://scenes/combat/CombatPlay.tscn")
const RestScene := preload("res://scenes/map/RestUI.tscn")
const ShopScene := preload("res://scenes/map/ShopUI.tscn")
const TreasureScene := preload("res://scenes/map/TreasureUI.tscn")
const EventScene := preload("res://scenes/map/EventUI.tscn")
const AltarScene := preload("res://scenes/map/AltarUI.tscn")
const RewardScene := preload("res://scenes/rewards/RewardUI.tscn")
const PreRunPreparationScene := preload("res://scenes/main/PreRunPreparation.tscn")
const TownScene := preload("res://scenes/town/Town.tscn")

# ART_STYLE 限制色板
const CREAM := Color(0.984, 0.953, 0.894)
const ORANGE := Color(0.941, 0.600, 0.482)
const GREEN := Color(0.365, 0.792, 0.647)
const RED := Color(0.847, 0.353, 0.188)
const AMBER := Color(0.937, 0.624, 0.153)
const PURPLE := Color(0.498, 0.467, 0.867)
const DARK := Color.WHITE
const LINE := Color("70675b")
const BG_DARK := Color(0.12, 0.10, 0.09)
const BG_CREAM := CREAM

func _solid_bg(color: Color) -> TextureRect:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	return tr

# 类型 → 颜色 / 短标
const TYPE_COLOR := {
	&"combat": ORANGE,
	&"elite": RED,
	&"boss": PURPLE,
	&"event": GREEN,
	&"shop": AMBER,
	&"rest": GREEN,
	&"treasure": AMBER,
	&"altar": Color(0.45, 0.72, 0.85),
}
const TYPE_SHORT := {
	&"combat": "怪物",
	&"elite": "精英怪",
	&"boss": "首领",
	&"event": "事",
	&"shop": "商",
	&"rest": "休",
	&"treasure": "宝",
	&"altar": "坛",
}

# 布局（虚拟画布宽 680；高度随幕内层数动态，外层 ScrollContainer 纵向滚动）
const CANVAS_W := 680.0
const MARGIN_TOP := 48.0
const FLOOR_GAP := 120.0
const COL_GAP := 110.0
const NODE_SIZE := 76

@onready var map_area: Control = get_node_or_null("MapScroller/MapArea")
@onready var map_scroller: ScrollContainer = get_node_or_null("MapScroller")
var _map_view_revision := 0
@onready var topbar: HBoxContainer = get_node_or_null("Topbar")
@onready var top_act: Label = get_node_or_null("Topbar/Act")
@onready var top_hp: Label = get_node_or_null("Topbar/HP")
@onready var top_gold: Label = get_node_or_null("Topbar/Gold")
@onready var top_floor: Label = get_node_or_null("Topbar/Floor")
@onready var top_buff: Label = get_node_or_null("Topbar/Buff")

# 每局选择记录：chosen[floor] = index，未选为 -1
var chosen: Array[int] = []
var node_pos: Dictionary = {}
@onready var _bg: ColorRect = get_node_or_null("Background")  # 全屏背景：P1 起战斗改为独立场景切换，不再需要隐藏/恢复
var _result_fireseed_label: Label
var _result_ad_button: Button


func _ready() -> void:
	if not GameData.is_loaded:
		push_error("[MapUI] GameData 未就绪")
		return
	if not SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.connect(_on_ad_reward_resolved)
	theme = FormalUI.theme()
	_build_static_ui()
	_bg.hide()
	if not has_node("FormalBackground"):
		FormalUI.background(self, FormalUI.ROOT + "bgIMG_stage.png").name = "FormalBackground"
	map_scroller.offset_top = 106
	topbar.hide()
	if not RunState.pre_run_preparation_resolved:
		PreRunBuffSystem.prepare_offer()
	if PreRunBuffSystem.needs_preparation():
		get_tree().call_deferred("change_scene_to_packed", PreRunPreparationScene)
		return
	if RunState.has_combat_checkpoint() and not RunState.pending_combat_enemy_ids.is_empty():
		get_tree().call_deferred("change_scene_to_packed", CombatPlayScene)
		return
	# —— 场景化回程分支（P1+P2）：地图每次重入重建，靠 RunState 瞬时标记区分来源 ——
	# 1) 奖励界面返回：走 _on_reward_done（boss→幕转场/通关，普通→继续面板）
	if RunState.pending_post_reward:
		RunState.pending_post_reward = false
		_resolve_current_floor()
		start_new_map()
		_on_reward_done()
		return
	# 2) 战斗返回：胜利发奖励（场景切到 RewardUI），失败弹结算屏
	if RunState.pending_post_combat:
		RunState.pending_post_combat = false
		var victory := RunState.last_combat_victory
		if not victory:
			# 失败时 RunState 已结束；不得在结算面板出现前调用 start_new_map，
			# 否则会重置本局 run_id 与火种结算字段，并偷偷预创建下一局。
			_refresh_topbar()
			_show_result(false)
			return
		start_new_map()
		_grant_reward()
		return
	# 3) 非战斗节点返回：弹「行动完成」面板
	if RunState.pending_node_resolved:
		RunState.pending_node_resolved = false
		_resolve_current_floor()
		start_new_map()
		_show_continue_panel("行动完成", "继续前进")
		return
	start_new_map()


func _exit_tree() -> void:
	if SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.disconnect(_on_ad_reward_resolved)


## 开新的一局地图（或续玩已载入的运行态）
func start_new_map() -> void:
	var resumed := RunState.is_active
	if not resumed:
		if not RunState.start_new_run():
			return
		PreRunBuffSystem.prepare_offer()
		if PreRunBuffSystem.needs_preparation():
			get_tree().call_deferred("change_scene_to_packed", PreRunPreparationScene)
			return
	chosen.clear()
	for f in RunState.current_map().size():
		chosen.append(-1)
	# 续玩：依据已访问节点重建已选路径
	for f in RunState.current_map().size():
		var row: Array = RunState.current_map()[f]
		for node in row:
			if node.visited:
				chosen[f] = node.index
	_build_map_view()
	_refresh_topbar()
	if PauseManager != null:
		PauseManager.show_pause_button()
	print("[MapUI] 地图已就绪，共 %d 层（%s）" % [RunState.current_map().size(), "续玩" if resumed else "新开"])


# =====================================================================
# 静态 UI
# =====================================================================
func _build_static_ui() -> void:
	# 正式场景已烘焙静态布局；.new() 验证路径继续使用代码后备。
	if map_area != null:
		if not map_area.gui_input.is_connected(_on_map_gui_input):
			map_area.gui_input.connect(_on_map_gui_input)
		if not map_area.draw.is_connected(_on_map_draw):
			map_area.draw.connect(_on_map_draw)
		return
	_bg = ColorRect.new()
	_bg.color = CREAM
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# 顶部状态栏
	topbar = HBoxContainer.new()
	topbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	topbar.set_offsets_preset(Control.PRESET_TOP_WIDE)
	topbar.add_theme_constant_override("separation", 40)
	add_child(topbar)
	top_act = _label("第 1 幕", 26, PURPLE)
	top_hp = _label("HP", 26, DARK)
	top_gold = _label("金币 0", 26, AMBER)
	top_floor = _label("第 0 层", 26, DARK)
	top_buff = _label("", 20, GREEN)
	topbar.add_child(top_act)
	topbar.add_child(top_hp)
	topbar.add_child(top_gold)
	topbar.add_child(top_floor)
	topbar.add_child(top_buff)

	# 地图画布容器（纵向滚动，承载 StS 式高地图）
	map_scroller = ScrollContainer.new()
	map_scroller.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_scroller.offset_top = 40
	map_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(map_scroller)
	map_area = Control.new()
	map_area.set_meta("draw", true)
	map_area.gui_input.connect(_on_map_gui_input)
	map_scroller.add_child(map_area)
	# 让 map_area 自身负责绘制连线
	map_area.draw.connect(_on_map_draw)


func _on_map_gui_input(_ev: InputEvent) -> void:
	pass


func _on_map_draw() -> void:
	# 连线：每个节点 → 下一层 links
	for f in RunState.current_map().size():
		var row: Array = RunState.current_map()[f]
		for node in row:
			var k1 := "%d_%d" % [f, node.index]
			if not node_pos.has(k1):
				continue
			var p1: Vector2 = node_pos[k1]
			for j in node.links:
				var k2 := "%d_%d" % [f + 1, j]
				if node_pos.has(k2):
					map_area.draw_dashed_line(p1, node_pos[k2], LINE, 4.0, 10.0)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# =====================================================================
# 构建地图节点
# =====================================================================
func _build_map_view() -> void:
	_map_view_revision += 1
	# 清空旧节点（保留 map_area 本身）
	for c in map_area.get_children():
		c.queue_free()
	node_pos.clear()

	var floor_count: int = RunState.current_map().size()
	var width: int = int(RunState.current_act_config().get("columns", 6))
	var canvas_h: float = MARGIN_TOP * 2.0 + float(floor_count - 1) * FLOOR_GAP
	map_area.custom_minimum_size = Vector2(CANVAS_W, canvas_h)
	for f in floor_count:
		var row: Array = RunState.current_map()[f]
		var n: int = row.size()
		var y: float = MARGIN_TOP + (floor_count - 1 - f) * FLOOR_GAP
		for i in n:
			var node = row[i]
			var x: float = CANVAS_W * 0.5 + (node.col - (width - 1) / 2.0) * COL_GAP
			node_pos["%d_%d" % [f, i]] = Vector2(x, y)
			_add_node_button(node, f, i, x, y)

	map_area.queue_redraw()
	if floor_count > 0:
		var player_floor := clampi(RunState.current_floor, 0, floor_count - 1)
		var player_index := maxi(0, chosen[player_floor])  # 新局/新幕未选节点时定位首层。
		var key := "%d_%d" % [player_floor, player_index]
		if node_pos.has(key):
			var player_position: Vector2 = node_pos[key]
			_focus_player_position.call_deferred(player_position.y, _map_view_revision)


## 等容器完成布局后按实际可视高度居中；到首尾时由滚动范围夹取。
## 只在地图重建时执行，用户之后可自由滚动，不每帧追踪或抢回视角。
func _focus_player_position(player_y: float, revision: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or revision != _map_view_revision:
		return
	await get_tree().process_frame
	# 回程可能立即切奖励场景，或同一帧推进新幕；废弃旧布局的定位请求。
	if not is_inside_tree() or is_queued_for_deletion() or revision != _map_view_revision:
		return
	var bar := map_scroller.get_v_scroll_bar()
	var max_scroll := maxf(0.0, bar.max_value - bar.page)
	map_scroller.scroll_vertical = roundi(clampf(player_y - bar.page * 0.5, 0.0, max_scroll))


func _add_node_button(node, f: int, i: int, x: float, y: float) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	b.position = Vector2(x - NODE_SIZE / 2.0, y - NODE_SIZE / 2.0)
	var col: Color = TYPE_COLOR.get(node.type, ORANGE)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var enemy_hint := ""
	var label_txt: String = TYPE_SHORT.get(node.type, "?")
	if node.type == &"boss":
		if node.enemy_ids.size() > 0:
			var ed: EnemyData = GameData.get_enemy(StringName(node.enemy_ids[0]))
			if ed != null:
				enemy_hint = ed.combat_hint
	b.text = label_txt
	b.add_theme_font_size_override("font_size", 20)
	# 地图只揭示节点类型；具体敌人身份留到进入战斗后显示。
	b.tooltip_text = "第 %d 层 · %s" % [f, label_txt]
	if not enemy_hint.is_empty():
		b.tooltip_text += "\n" + enemy_hint
		# 手机端不能依赖悬停：Boss节点下直接显示数据中的机制提示。
		var hint := _label(enemy_hint, 20, DARK)
		hint.name = "BossCombatHint"
		hint.position = Vector2(10, y + NODE_SIZE * 0.5 + 4)
		hint.size = Vector2(CANVAS_W - 20, 30)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_area.add_child(hint)

	var reachable: bool = _is_reachable(f, i)
	b.disabled = not reachable
	if chosen[f] == i:
		# 已选：变暗
		b.modulate = Color(0.6, 0.6, 0.6, 1.0)
	elif reachable:
		b.modulate = Color(1.3, 1.3, 1.3, 1.0)
	else:
		b.modulate = Color(0.85, 0.85, 0.85, 1.0)
	# 同一节点保留点击/可达逻辑，仅使用正式普通态与描边高亮态。
	b.text = ""
	b.size = Vector2(100, 80)
	b.position = Vector2(x - 50, y - 40)
	b.modulate = Color.WHITE if reachable or chosen[f] == i else Color(0.72, 0.72, 0.72)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var skin := StyleBoxTexture.new()
		skin.texture = FormalUI.node_texture(node.type, reachable or chosen[f] == i or state == "hover")
		b.add_theme_stylebox_override(state, skin)
	if node.type in [&"boss", &"rest", &"altar"]:
		var caption := _label("首领" if node.type == &"boss" else "休息" if node.type == &"rest" else "祭坛", 17, Color.WHITE)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		caption.offset_top = -4
		caption.offset_bottom = 20
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(_on_node_pressed.bind(f, i))
	map_area.add_child(b)


func _rounded_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(12)
	s.set_content_margin_all(4)
	return s


# =====================================================================
# 可达判定
# =====================================================================
func _highest_chosen() -> int:
	var hi := -1
	for f in chosen.size():
		if chosen[f] >= 0:
			hi = f
	return hi


func _is_reachable(f: int, i: int) -> bool:
	if chosen[f] == i:
		return false
	var hi := _highest_chosen()
	if hi < 0:
		return f == 0  # 未选任何 → 仅第 0 层可达
	# 已选最高层 hi，下一层 f == hi+1 且其 index 在 links 内
	if f != hi + 1:
		return false
	var cur_node = RunState.current_map()[hi][chosen[hi]]
	return cur_node.links.has(i)


# =====================================================================
# 进入节点
# =====================================================================
func _on_node_pressed(f: int, i: int) -> void:
	if not _is_reachable(f, i):
		return
	var node = RunState.current_map()[f][i]
	chosen[f] = i
	node.visited = true
	RunState.current_floor = f
	RunState.current_node_type = node.type
	SignalBus.floor_entered.emit(f, node.type)
	_refresh_topbar()

	if node.is_combat_like():
		_start_combat_node(node)
	else:
		_start_noncombat(node)


func _start_combat_node(node) -> void:
	# P1 场景化：不再把战斗当 MapPlay 子节点 overlay，而是切到独立 CombatPlay 场景。
	# 敌人 id 经 RunState 跨场景传递；当前节点类型已写入 RunState.current_node_type，
	# 战后结算据此判定 tier / 是否 boss。
	RunState.pending_combat_enemy_ids = node.enemy_ids.duplicate()
	RunState.create_combat_checkpoint(node.enemy_ids)
	SaveManager.save_game()
	get_tree().change_scene_to_packed(CombatPlayScene)
	print("[MapUI] 进入战斗节点：%s，敌人=%s" % [node.type, node.enemy_ids])


func _start_noncombat(node) -> void:
	# P2 场景化：非战斗节点改为独立场景切换（不再 add_child 叠加到 MapPlay，避免层级冲突）。
	# 子屏 _finish 置 pending_node_resolved 后切回本场景，由 _ready 的对应分支重建地图并弹面板。
	match node.type:
		&"rest":
			get_tree().change_scene_to_packed(RestScene)
		&"treasure":
			get_tree().change_scene_to_packed(TreasureScene)
		&"shop":
			get_tree().change_scene_to_packed(ShopScene)
		&"event":
			get_tree().change_scene_to_packed(EventScene)
		&"altar":
			get_tree().change_scene_to_packed(AltarScene)
		_:
			_refresh_topbar()
			_show_continue_panel("未知节点", "继续前进")


## 战斗结束流程已移到 _ready 的 pending_post_combat 分支驱动：
## CombatUI 在 combat_ended 后写 RunState.last_combat_victory/pending_post_combat 并切回 MapPlay，
## 本场景 _ready 据此重建地图并走奖励/结算/幕转场。combat_ended 信号仅剩 SaveManager 自动存档监听。

## 战斗胜利后发放奖励（金币立即入账、遗物立即获得、卡牌三选一由 RewardUI 处理），结束后回地图或通关。
func _grant_reward() -> void:
	var tier: StringName = RunState.current_node_type
	var gold := RewardBuilder.roll_gold(tier)
	RunState.add_gold(gold)
	var relic_id: StringName = RewardBuilder.roll_relic(tier)
	if relic_id != &"":
		RunState.add_relic(relic_id)
	var cards := RewardBuilder.roll_card_choices(
		int(GameData.balance.get("rewards", {}).get("card_choice_count", 3)),
		tier
	)
	var potion_id: StringName = RewardBuilder.roll_potion(tier)
	if potion_id != &"":
		RunState.add_potion(potion_id)
	var rw_data := {"tier": tier, "gold": gold, "relic_id": relic_id, "potion_id": potion_id, "cards": cards}
	# P2 场景化：奖励界面改为独立场景。先把数据交给 RunState，再切场景；
	# RewardUI._finish 置 pending_post_reward 后切回本场景，_ready 走 _on_reward_done。
	RunState.pending_reward_data = rw_data
	print("[MapUI] 发放奖励 tier=%s 金币+%d 遗物=%s 药水=%s 卡牌%d张" % [tier, gold, relic_id, potion_id, cards.size()])
	get_tree().call_deferred("change_scene_to_packed", RewardScene)


func _on_reward_done() -> void:
	_refresh_topbar()
	if RunState.current_node_type == &"boss":
		if RunState.is_last_act():
			RunState.end_run(true)
			SignalBus.run_won.emit()
			_show_result(true)
		else:
			RunState.advance_act()
			_show_act_transition(RunState.current_act)
		return
	_show_continue_panel("战斗胜利！获得战利品。", "继续前进")


## 幕间转场屏：击败非终幕 Boss 后展示，点击「进入第 N 幕」重建本幕地图。
func _show_act_transition(act_idx: int) -> void:
	var panel: Control = _overlay_panel()
	var col := panel.get_child(0).get_child(0) as VBoxContainer
	var title := _label("第 %d 幕" % (act_idx + 1), 64, PURPLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var ctitle := _label(String(RunState.current_act_config().get("title", "")), 34, DARK)
	ctitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ctitle)
	var sub := _label("幕间休整 · HP %d / %d" % [RunState.hp, RunState.max_hp], 28, GREEN)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var btn := Button.new()
	btn.text = "进入第 %d 幕" % (act_idx + 1)
	btn.custom_minimum_size = Vector2(280, 90)
	btn.add_theme_font_size_override("font_size", 30)
	btn.pressed.connect(_on_enter_act.bind(panel))
	col.add_child(btn)
	add_child(panel)


func _on_enter_act(panel: Control) -> void:
	panel.queue_free()
	start_new_map()


# =====================================================================
# 覆盖面板（继续 / 结算）
# =====================================================================
func _show_continue_panel(title: String, btn_text: String) -> void:
	var panel: Control = _overlay_panel()
	var label := _label(title, 40, DARK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.get_child(0).get_child(0).add_child(label)
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(327, 100)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(_on_continue.bind(panel))
	panel.get_child(0).get_child(0).add_child(btn)
	add_child(panel)


func _on_continue(panel: Control) -> void:
	panel.queue_free()
	_build_map_view()  # 刷新可达


func _show_result(victory: bool) -> void:
	var panel := (load("res://scenes/ui/RunResult.tscn") as PackedScene).instantiate() as Control
	PauseManager.hide_pause_button()
	var content := panel.get_node("Center/Content")
	content.get_node("Emblem/Title").text = "胜利" if victory else "你倒下了"
	content.get_node("Floor").text = "抵达第 %d 层" % RunState.current_floor
	_result_fireseed_label = content.get_node("Fireseed")
	_result_ad_button = content.get_node("AdButton")
	_result_ad_button.hide()
	if RunState.run_end_base_settled:
		_result_fireseed_label.text = "基础火种 +%d（已到账）" % RunState.run_end_base_fireseed
		_result_fireseed_label.add_theme_color_override("font_color", AMBER)
		if RunEndRewardSystem.is_ad_bonus_configured() and RunState.run_end_ad_bonus_fireseed <= 0:
			_result_ad_button.show()
			_result_ad_button.text = "观看广告 · 额外获得 %d 火种" % RunEndRewardSystem.preview_ad_bonus()
			_result_ad_button.disabled = not RunEndRewardSystem.can_offer_ad_bonus()
			_result_ad_button.tooltip_text = "当前无可用广告" if _result_ad_button.disabled else "基础火种已经到账"
			_result_ad_button.pressed.connect(_on_run_end_ad_pressed)
	else:
		_result_fireseed_label.text = "火种暂未结算：正式投放数值尚未配置"
		_result_fireseed_label.add_theme_color_override("font_color", RED)
	content.get_node("RestartButton").pressed.connect(_on_restart.bind(panel))
	content.get_node("ReturnTownButton").pressed.connect(_on_return_town.bind(panel))
	add_child(panel)


func _on_restart(panel: Control) -> void:
	_on_return_town(panel)


func _on_return_town(panel: Control) -> void:
	panel.queue_free()
	get_tree().change_scene_to_packed(TownScene)


func _on_run_end_ad_pressed() -> void:
	if _result_ad_button != null:
		_result_ad_button.disabled = true
	if RunEndRewardSystem.request_ad_bonus().is_empty() and _result_ad_button != null:
		_result_ad_button.disabled = not RunEndRewardSystem.can_offer_ad_bonus()


func _on_ad_reward_resolved(_transaction_id: String, placement_id: StringName, result: StringName) -> void:
	if placement_id != RunEndRewardSystem.PLACEMENT:
		return
	if result == &"granted":
		if _result_fireseed_label != null:
			_result_fireseed_label.text = "基础火种 +%d · 广告额外 +%d（均已到账）" % [RunState.run_end_base_fireseed, RunState.run_end_ad_bonus_fireseed]
		if _result_ad_button != null:
			_result_ad_button.hide()
	elif _result_ad_button != null:
		_result_ad_button.disabled = not RunEndRewardSystem.can_offer_ad_bonus()


func _overlay_panel() -> Control:
	var cover := FormalUI.menu_background()
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.theme = FormalUI.theme("btn_hall_normal_small.png")
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 480
	col.add_theme_constant_override("separation", 24)
	center.add_child(col)
	return cover


# =====================================================================
# 顶部状态刷新
# =====================================================================
func _refresh_topbar() -> void:
	if top_hp == null:
		return
	var old_header := get_node_or_null("FormalHeader")
	if old_header != null:
		remove_child(old_header)
		old_header.queue_free()
	FormalUI.header(self, "第 %d 幕 · %s" % [RunState.current_act + 1, RunState.current_act_config().get("title", "")])
	var act_cfg: Dictionary = RunState.current_act_config()
	top_act.text = "第 %d 幕 · %s" % [RunState.current_act + 1, String(act_cfg.get("title", ""))]
	top_hp.text = "HP %d / %d" % [RunState.hp, RunState.max_hp]
	top_gold.text = "金币 %d" % RunState.gold
	top_floor.text = "第 %d / %d 层" % [RunState.current_floor, RunState.total_floors()]
	if top_buff != null:
		var buff := RunState.active_pre_run_buff()
		top_buff.text = "%s · 剩余%d层" % [buff.get("name", "局前增益"), RunState.pre_run_buff_remaining_floors] if not buff.is_empty() else ""


func _resolve_current_floor() -> void:
	if RunState.resolve_current_floor():
		SaveManager.save_game()
