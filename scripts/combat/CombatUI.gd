class_name CombatUI
extends Control
## 竖屏三段式战斗 UI（MVP）—— 门面（P4b 拆分后）。
## 编排骨架 + 节点持有 + 公开 API（被场景/各 verify 直接调用）+ 跨域 SignalBus 回调。
## 重逻辑已下放到助手类：CombatHUD / HandView / EnemyViewManager / LogView / TargetingController。
## 助手类通过 ui 引用本门面的节点字段与共享 helper（样式/格式化工厂）。零 preload 循环。

var controller: CombatController
var combat_over := false

## 进入战斗时由上层场景设置；默认打陶泥团（保持 CombatPlay.tscn 原行为）。
var pending_enemy_ids: Array = ["claylump"]

# 布局节点（场景内烘焙，见 CombatPlay.tscn）。@onready 在 .tscn 路径解析为真实节点，
# 在 .new() 路径（测试 / MapUI 叠加层）下为 null → 改走 _build_ui 代码生成后备。
# 用 get_node_or_null 避免 .new() 路径下因节点不存在而刷 "Node not found" 错误。
@onready var enemy_area: HBoxContainer = get_node_or_null("Safe/Layout/EnemyArea")
@onready var hand_container: HBoxContainer = get_node_or_null("Safe/Layout/HandArea/HandRow/CardHeightMargin/HandScroll/HandContainer")
@onready var discard_pile_view: PanelContainer = get_node_or_null("%DiscardPile")
@onready var draw_pile_button: Button = get_node_or_null("Safe/Layout/HandArea/EnergyRow/DrawPile")
@onready var end_turn_btn: Button = get_node_or_null("Safe/Layout/Bottom/EndTurnBtn")
@onready var potion_bar: HBoxContainer = get_node_or_null("Safe/Layout/PotionBar")
@onready var relic_bar = get_node_or_null("Safe/Layout/TopRow/RelicBar")
var potion_slots: Array = []
var potion_icons: Array = []    # 与 potion_slots 一一对应：每个槽的图标 TextureRect
@onready var log_label: Label = get_node_or_null("Safe/Layout/LogPanel/LogLabel")

# 玩家控件
@onready var player_hp: Label = get_node_or_null("Safe/Layout/Bottom/PlayerPanel/Phbox/Plv/PlayerHp")
@onready var player_hp_bar: ProgressBar = get_node_or_null("Safe/Layout/Bottom/PlayerPanel/Phbox/Plv/PlayerHpBar")
@onready var player_block: Label = get_node_or_null("Safe/Layout/Bottom/PlayerPanel/Phbox/Plv/PlayerBlock")
@onready var player_energy: Label = get_node_or_null("%PlayerEnergy")
@onready var player_status = get_node_or_null("Safe/Layout/Bottom/PlayerPanel/Phbox/Prv/PlayerStatus")
@onready var player_sprite: TextureRect = get_node_or_null("PlayerSprite")
@onready var player_panel: Panel = get_node_or_null("Safe/Layout/Bottom/PlayerPanel")

# VFX 相关（v2，见 VFX_DESIGN.md）：持久敌人面板映射，避免刷新误杀 VFX 子节点。
var unit_panels := {}      # CombatUnit -> EnemyPanel（持久，刷新只更新内容不销毁）
var _prev_php := -1        # 上一帧玩家 HP（检测治疗飘字）
var _prev_ehp := {}        # CombatUnit -> int（上一帧敌人 HP，检测治疗飘字）

## 当前选中的药水目标索引（-1 表示未选）；卡牌只由拖拽落点决定目标。
var selected_target: int = -1

# 拖拽 / 演出层（P1）
const CardViewScene := preload("res://scenes/combat/CardView.tscn")
const DropLayerScript := preload("res://scripts/combat/DropLayer.gd")
const EnemyPanelScene := preload("res://scenes/combat/EnemyPanel.tscn")
const ENEMY_PANEL_OFFSET_Y := 0   # 敌人信息从顶部开始；血条由 EnemyPanel 放在立绘脚下
const RelicBarScene := preload("res://scenes/combat/RelicBar.tscn")
const DiscardPileScene := preload("res://scenes/combat/DiscardPile.tscn")
const DrawPileScene := preload("res://scenes/combat/DrawPile.tscn")
const CardBrowserScript := preload("res://scripts/ui/CardBrowser.gd")
var _card_browser: CanvasLayer
var drop_layer: DropLayer
var drag_layer: Control
var _casting := false             # 仅非法落点回弹期间短暂锁定手牌
var _play_queue: Node
var _drag_active := false         # 拖拽手势进行中：锁 refresh（防手牌重建打断手势）
var _needs_refresh := false       # 锁定期内累计的刷新需求
var _ghost: CardView              # 拖拽中的幽灵卡
var _drag_card: CardView          # 正在拖拽的源卡

# 主题色
const CREAM := Color(0.984, 0.953, 0.894)
const ORANGE := Color(0.941, 0.600, 0.482)
const GREEN := Color(0.365, 0.792, 0.647)
const RED := Color(0.847, 0.353, 0.188)
const PURPLE := Color(0.498, 0.467, 0.867)
const DARK := Color(0.18, 0.15, 0.13)
const HILITE := Color(1.0, 0.92, 0.65)
const PANEL_BG := Color(0.22, 0.19, 0.17, 0.92)

# 攻击/受击由 PlayerCombatPortrait 的 SpriteFrames 播放完成后恢复静态立绘。
var _player_dead := false       # true 后立绘锁定 death，不再回 idle
var _revive_prompt: CanvasLayer

# 助手类（门面 + 助手类模式，P4b）
var _hud: CombatHUD
var _hand: HandView
var _enemy: EnemyViewManager
var _log_view: LogView
var _targeting: TargetingController


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	var formal_background := get_node_or_null("FormalBackground") as TextureRect
	if formal_background == null:
		formal_background = FormalUI.background(self, FormalUI.act_background())
		formal_background.name = "FormalBackground"
	formal_background.texture = load(FormalUI.act_background()) as Texture2D
	formal_background.z_index = -99
	formal_background.modulate = Color(0.85, 0.85, 0.85)
	FormalUI.combat_reward_pending = false
	FormalUI.combat_reward_backdrop = null
	PauseManager.show_pause_button()
	controller = CombatController.new()
	add_child(controller)
	# 实例化并挂载助手类（顺序无关，因 connect 发生在后续 refresh 调用时）
	_hud = CombatHUD.new()
	_hand = HandView.new()
	_enemy = EnemyViewManager.new()
	_log_view = LogView.new()
	_targeting = TargetingController.new()
	_hud.attach(self)
	_hand.attach(self)
	_enemy.attach(self)
	_log_view.attach(self)
	_targeting.attach(self)
	_play_queue = preload("res://scripts/combat/CardPlayQueue.gd").new()
	_play_queue.ui = self
	add_child(_play_queue)

	if enemy_area == null:
		_build_ui()            # .new() 路径（测试 / MapUI 叠加层）：代码生成全部 HUD
	else:
		_wire_ui_signals()     # .tscn 路径（CombatPlay）：节点已在场景烘焙，仅连信号
	var preview := get_node_or_null("FormalEditorPreview")
	if preview != null:
		remove_child(preview)
		preview.queue_free()
	_create_overlay_layers()
	draw_pile_button.pressed.connect(_open_draw_pile)
	discard_pile_view.gui_input.connect(_on_discard_pile_gui_input)
	_connect_signals()
	var feedback := preload("res://scripts/combat/CombatFeedback.gd").new()
	feedback.name = "CombatFeedback"
	add_child(feedback)
	# P1 场景化：敌人 id 优先取自 RunState（由地图写入），仅在直接启动 CombatPlay.tscn
	# （编辑器预览 / 旧 verify）且 RunState 未置时回退到默认 pending_enemy_ids。
	var launch_ids: Array = RunState.pending_combat_enemy_ids if RunState.pending_combat_enemy_ids.size() > 0 else pending_enemy_ids
	controller.start_combat(launch_ids)
	_refresh_all()
	print("[CombatUI] 界面构建完成，敌人=%d，手牌=%d" % [controller.enemies.size(), controller.hand.size()])


# =====================================================================
# 场景复用与信号绑定
# =====================================================================
func _build_ui() -> void:
	# .new() 入口也复用已保存的正式场景，防止出现第二套旧布局。
	var shell := (load("res://scenes/combat/CombatPlay.tscn") as PackedScene).instantiate()
	# Keep stable references before clearing scene owners during the transfer.
	discard_pile_view = shell.get_node("%DiscardPile")
	player_energy = shell.get_node("%PlayerEnergy")
	for child in shell.get_children():
		var existing := get_node_or_null(NodePath(child.name))
		if existing != null:
			remove_child(existing)
			existing.queue_free()
		FormalUI._clear_owner(child)
		shell.remove_child(child)
		add_child(child)
	shell.free()
	discard_pile_view.owner = self
	player_energy.owner = self
	enemy_area = get_node("Safe/Layout/EnemyArea")
	hand_container = get_node("Safe/Layout/HandArea/HandRow/CardHeightMargin/HandScroll/HandContainer")
	draw_pile_button = get_node("Safe/Layout/HandArea/EnergyRow/DrawPile")
	end_turn_btn = get_node("Safe/Layout/Bottom/EndTurnBtn")
	potion_bar = get_node("Safe/Layout/PotionBar")
	relic_bar = get_node("Safe/Layout/TopRow/RelicBar")
	log_label = get_node("Safe/Layout/LogPanel/LogLabel")
	player_hp = get_node("Safe/Layout/Bottom/PlayerPanel/Phbox/Plv/PlayerHp")
	player_hp_bar = get_node("Safe/Layout/Bottom/PlayerPanel/Phbox/Plv/PlayerHpBar")
	player_block = get_node("Safe/Layout/Bottom/PlayerPanel/Phbox/Plv/PlayerBlock")
	player_status = get_node("Safe/Layout/Bottom/PlayerPanel/Phbox/Prv/PlayerStatus")
	player_sprite = get_node("PlayerSprite")
	player_panel = get_node("Safe/Layout/Bottom/PlayerPanel")
	$FormalBackground.texture = load(FormalUI.act_background())
	_wire_ui_signals()


func _wire_ui_signals() -> void:
	if end_turn_btn != null and not end_turn_btn.pressed.is_connected(_targeting.on_end_turn):
		end_turn_btn.pressed.connect(_targeting.on_end_turn)
	_hud.collect_potion_slots()
	_hud.connect_potion_slots()


## 拖拽 / 落点层（P1 交互，置于最上层，均不拦截输入）。两路径共用。
func _create_overlay_layers() -> void:
	drop_layer = DropLayerScript.new()
	drop_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(drop_layer)

	drag_layer = Control.new()
	drag_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_layer.z_index = 500
	add_child(drag_layer)


## 编辑器预览：在 Godot 编辑器内打开 CombatPlay.tscn 时，用示例数据填充敌人/手牌/药水/立绘，
## 让 UI 布局与运行时一致。预览节点不会保存到 .tscn（add_child 不设置 owner）。
# =====================================================================
# 共享样式 / 格式化工厂（被 _build_ui、各助手类与场景共用，留门面避免跨文件依赖）
# =====================================================================
func _styled_panel(bg: Color) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_left = 14
	s.corner_radius_bottom_right = 14
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.border_color = Color(0.35, 0.30, 0.27)
	p.add_theme_stylebox_override("panel", s)
	return p


func _hp_fill_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = RED
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	return s


func _hp_bg_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.10, 0.10)
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_left = 6
	s.corner_radius_bottom_right = 6
	return s


func _btn_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.corner_radius_top_left = 16
	s.corner_radius_top_right = 16
	s.corner_radius_bottom_left = 16
	s.corner_radius_bottom_right = 16
	return s


func _card_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	return s


func _disabled_card_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.40, 0.37, 0.35)
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	return s


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _orb_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## 带彩色边框的卡面样式（附魔角标用，边框按附魔稀有度着色）。
func _framed_card_style(body: Color, frame: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = body
	s.border_color = frame
	s.set_border_width_all(4)
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	return s


## 取附魔数组对应的边框色（按首个附魔的稀有度：rare=PURPLE / uncommon=GREEN / 其他=CREAM）。
func _enchant_frame_color(enchants: Array) -> Color:
	for eid in enchants:
		var ed: EnchantData = GameData.get_enchant(StringName(eid))
		if ed == null:
			continue
		match ed.rarity:
			&"rare": return PURPLE
			&"uncommon": return GREEN
			_: return CREAM
	return CREAM


## 由 enchants 数组生成卡面角标文本（如 "✦ 烈焰"）；空数组返回 ""。
static func _enchant_badge_text(enchants: Array) -> String:
	var names: PackedStringArray = []
	for eid in enchants:
		var ed: EnchantData = GameData.get_enchant(StringName(eid))
		if ed != null:
			names.append("✦ " + ed.name)
		elif eid != null and eid != &"":
			names.append("✦ " + String(eid))
	return "  ".join(names)


func _status_text(unit: CombatUnit) -> String:
	var parts: PackedStringArray = []
	for sid in unit.status_ids():
		var sd: StatusData = GameData.get_status(sid)
		var nm := sd.name if sd != null else String(sid)
		parts.append("%s %d" % [nm, unit.get_status(sid)])
	return "  ".join(parts)


## 状态是否为增益（用于 VFX 配色）。未知按减益处理。
func _is_buff(status_id: StringName) -> bool:
	var sd: StatusData = GameData.get_status(status_id)
	if sd == null:
		return false
	return not sd.is_debuff()


func _intent_cn(kind: String) -> String:
	match kind:
		"attack": return "攻击"
		"defend": return "防御"
		"buff": return "增益"
		"debuff": return "减益"
		"charge": return "蓄力"
		_ : return kind


## 日志转发（门面保留方法名，供助手类通过 ui._log 调用）。
func _log(msg: String) -> void:
	_log_view.log(msg)


func _first_alive_index() -> int:
	for i in controller.enemies.size():
		if controller.enemies[i].is_alive():
			return i
	return -1


# =====================================================================
# 信号连接（全部连门面回调；跨域回调留门面，域内回调转助手类）
# =====================================================================
func _connect_signals() -> void:
	SignalBus.player_hp_changed.connect(_on_php)
	SignalBus.player_block_changed.connect(_on_pblock)
	SignalBus.energy_changed.connect(_on_energy)
	SignalBus.enemy_hp_changed.connect(_on_ehp)
	SignalBus.enemy_intent_changed.connect(_on_eintent)
	SignalBus.status_applied.connect(_on_status)
	SignalBus.kiln_heat_changed.connect(_on_kiln)
	SignalBus.combat_ended.connect(_on_combat_end)
	SignalBus.turn_started.connect(_on_turn_started)
	SignalBus.turn_ended.connect(_on_turn_ended)
	SignalBus.damage_dealt.connect(_on_damage)
	SignalBus.unit_died.connect(_on_unit_died)
	SignalBus.card_played.connect(_on_card_played)
	SignalBus.card_discarded.connect(_on_card_discarded)
	SignalBus.card_drawn.connect(_on_card_drawn)
	SignalBus.combat_card_choice_requested.connect(_on_combat_card_choice_requested)
	SignalBus.combat_death_pending.connect(_on_combat_death_pending)
	SignalBus.combat_revive_ready.connect(_on_combat_revive_ready)
	SignalBus.ad_reward_resolved.connect(_on_ad_reward_resolved)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if SignalBus.player_hp_changed.is_connected(_on_php):
		SignalBus.player_hp_changed.disconnect(_on_php)
	if SignalBus.player_block_changed.is_connected(_on_pblock):
		SignalBus.player_block_changed.disconnect(_on_pblock)
	if SignalBus.energy_changed.is_connected(_on_energy):
		SignalBus.energy_changed.disconnect(_on_energy)
	if SignalBus.enemy_hp_changed.is_connected(_on_ehp):
		SignalBus.enemy_hp_changed.disconnect(_on_ehp)
	if SignalBus.enemy_intent_changed.is_connected(_on_eintent):
		SignalBus.enemy_intent_changed.disconnect(_on_eintent)
	if SignalBus.status_applied.is_connected(_on_status):
		SignalBus.status_applied.disconnect(_on_status)
	if SignalBus.kiln_heat_changed.is_connected(_on_kiln):
		SignalBus.kiln_heat_changed.disconnect(_on_kiln)
	if SignalBus.combat_ended.is_connected(_on_combat_end):
		SignalBus.combat_ended.disconnect(_on_combat_end)
	if SignalBus.turn_started.is_connected(_on_turn_started):
		SignalBus.turn_started.disconnect(_on_turn_started)
	if SignalBus.turn_ended.is_connected(_on_turn_ended):
		SignalBus.turn_ended.disconnect(_on_turn_ended)
	if SignalBus.damage_dealt.is_connected(_on_damage):
		SignalBus.damage_dealt.disconnect(_on_damage)
	if SignalBus.unit_died.is_connected(_on_unit_died):
		SignalBus.unit_died.disconnect(_on_unit_died)
	if SignalBus.card_played.is_connected(_on_card_played):
		SignalBus.card_played.disconnect(_on_card_played)
	if SignalBus.card_discarded.is_connected(_on_card_discarded):
		SignalBus.card_discarded.disconnect(_on_card_discarded)
	if SignalBus.card_drawn.is_connected(_on_card_drawn):
		SignalBus.card_drawn.disconnect(_on_card_drawn)
	if SignalBus.combat_card_choice_requested.is_connected(_on_combat_card_choice_requested):
		SignalBus.combat_card_choice_requested.disconnect(_on_combat_card_choice_requested)
	if SignalBus.combat_death_pending.is_connected(_on_combat_death_pending):
		SignalBus.combat_death_pending.disconnect(_on_combat_death_pending)
	if SignalBus.combat_revive_ready.is_connected(_on_combat_revive_ready):
		SignalBus.combat_revive_ready.disconnect(_on_combat_revive_ready)
	if SignalBus.ad_reward_resolved.is_connected(_on_ad_reward_resolved):
		SignalBus.ad_reward_resolved.disconnect(_on_ad_reward_resolved)


# =====================================================================
# 刷新（编排）
# =====================================================================
func _refresh_all() -> void:
	_enemy.refresh_enemy()
	_hud.refresh_resources()
	_hand.refresh_hand()
	_hud.refresh_potions()


# =====================================================================
# SignalBus 回调（薄转发 + 跨域编排）
# =====================================================================
func _on_card_discarded(_card_id: StringName) -> void:
	_close_card_browser()
	_hand.refresh_hand()


func _on_card_drawn(_card_id: StringName) -> void:
	_close_card_browser()
	_hand.refresh_discard_pile()


func card_browser_open() -> bool:
	var potion_details := get_node_or_null("PotionDetails") as Control
	return (is_instance_valid(_card_browser) and not _card_browser.is_queued_for_deletion()) or (potion_details != null and potion_details.visible)


func _open_card_details(view: CardView) -> void:
	if card_browser_open() or _casting or _drag_active or BattleDirector.input_locked or combat_over or controller.phase != CombatController.Phase.PLAYER:
		return
	if not is_instance_valid(view) or view.card_index < 0 or view.card_index >= controller.hand.size():
		return
	var hint := "拖至玩家使用"
	match view.card_data.target:
		&"enemy": hint = "拖至目标敌人使用"
		&"all_enemies": hint = "拖至任一敌人，作用于全体"
	if not controller.can_play_more_cards():
		hint += "\n已达本回合出牌上限，仍可弃牌"
	elif not controller.can_play_card(view.card_index):
		hint += "\n当前无法打出，仍可弃牌"
	var browser := CardBrowserScript.new()
	if controller.turn_card_limit > 0:
		hint += "\n束火颈环：本回合已出 %d/%d 张牌" % [controller.cards_played_this_turn, controller.turn_card_limit]
	browser.setup_details(controller.hand[view.card_index], hint, view)
	_card_browser = browser
	browser.closed.connect(func(): _card_browser = null)
	add_child(browser)


func _open_draw_pile() -> void:
	if card_browser_open() or _casting or _drag_active or BattleDirector.input_locked or combat_over or controller.phase != CombatController.Phase.PLAYER:
		return
	# 保留真实抽取顺序，只查看深拷贝，不改变牌堆或随机数状态。
	var cards := controller.draw_pile.duplicate(true)
	var browser := CardBrowserScript.new()
	browser.setup("抽牌堆", "剩余 %d 张 · 按抽取顺序排列\n从左到右、从上到下；第一张为牌堆顶。" % cards.size(), cards)
	_card_browser = browser
	browser.closed.connect(func():
		_card_browser = null
		draw_pile_button.grab_focus()
	)
	add_child(browser)


func _on_discard_pile_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_open_discard_pile()
		if card_browser_open():
			discard_pile_view.accept_event()


func _open_discard_pile() -> void:
	if card_browser_open() or _casting or _drag_active or BattleDirector.input_locked or combat_over or controller.phase != CombatController.Phase.PLAYER:
		return
	var cards := controller.discard_pile.duplicate(true)
	_sort_pile_snapshot(cards)
	var browser := CardBrowserScript.new()
	browser.setup("弃牌堆", "当前 %d 张 · 仅供查看\n抽牌堆耗尽时，这些牌会洗回抽牌堆。" % cards.size(), cards)
	_card_browser = browser
	browser.closed.connect(func():
		_card_browser = null
	)
	add_child(browser)


func _sort_pile_snapshot(cards: Array) -> void:
	cards.sort_custom(func(a: Dictionary, b: Dictionary):
		var key_a := String(a.get("id", "")) + str(a.get("upgraded", false)) + str(a.get("enchants", []))
		var key_b := String(b.get("id", "")) + str(b.get("upgraded", false)) + str(b.get("enchants", []))
		return key_a < key_b
	)


func _close_card_browser() -> void:
	if card_browser_open():
		_card_browser.close()
	_card_browser = null


func _on_combat_card_choice_requested(title: String, entries: Array) -> void:
	if _drag_active and is_instance_valid(_drag_card):
		_targeting.on_card_drag_canceled(_drag_card)
	_close_card_browser()
	var browser := CardBrowserScript.new()
	browser.setup(title, "请选择一张牌以继续结算。", entries, true, "确认选择", "",
		"选择只作用于本场战斗中的对应卡牌实例。", true)
	_card_browser = browser
	browser.confirmed.connect(func(index: int, _snapshot: Dictionary):
		controller.resolve_card_choice(index)
		_card_browser = null
		_refresh_all()
	)
	add_child(browser)


func _on_php(cur: int, maxv: int) -> void:
	_hud.on_php(cur, maxv)


func _on_pblock(cur: int) -> void:
	_hud.on_pblock(cur)


func _on_energy(cur: int, maxv: int) -> void:
	_hud.on_energy(cur, maxv)


func _on_ehp(index: int, cur: int, maxv: int) -> void:
	_enemy.on_ehp(index, cur, maxv)


func _on_eintent(index: int, intent: StringName, value: int) -> void:
	_enemy.on_eintent(index, intent, value)


func _on_status(_is_player: bool, _index: int, _status_id: StringName, _stacks: int) -> void:
	# 出牌反制/全队强化发生在演出锁内；现有面板的威胁数值仍须立即刷新。
	for e in controller.enemies:
		if e.is_alive() and unit_panels.has(e):
			_enemy.update_enemy_panel(e, controller.enemies.find(e))
	_enemy.refresh_enemy()
	_hud.refresh_resources()


func _on_kiln(current: int, threshold: int) -> void:
	_hud.on_kiln(current, threshold)


func _on_turn_started(is_player: bool) -> void:
	_close_card_browser()
	if is_player:
		# 玩家回合开始：立绘回 idle（死亡锁定除外）
		if not _player_dead:
			_set_player_pose(&"idle")
		_hand.refresh_hand()
		_hud.refresh_resources()
		_enemy.refresh_enemy()


func _on_turn_ended(is_player: bool) -> void:
	if not is_player:
		return
	_close_card_browser()
	# 回合结束时控制器已完成批量弃置；即使已进入敌方阶段，也必须立即清空手牌视觉。
	_hand.refresh_hand(true)


func _on_combat_end(victory: bool) -> void:
	if TransitionManager.is_transitioning:
		return
	var gate := _transition_feedback_ready if victory else Callable()
	var error := TransitionManager.change_scene_to_file("res://scenes/map/MapPlay.tscn", Callable(), VFXSystem.DEATH_DUR if victory else 0.0, &"fade", gate)
	if error != OK:
		return
	FormalUI.combat_reward_pending = victory
	if victory and DisplayServer.get_name() != "headless":
		FormalUI.combat_reward_backdrop = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	_close_card_browser()
	combat_over = true
	_hand.refresh_hand()
	if victory:
		_log("战斗胜利！")
	else:
		_log("你倒下了…")
	# P1 场景化：不再由 MapUI 监听 combat_ended 做叠加层销毁，而是把战果写回 RunState，
	# 胜利等待死亡演出；最终战败进入死亡结算，由玩家确认后返回窑口镇。
	# combat_ended 仍由 CombatController 发出，SaveManager 的自动存档钩子照常生效。
	RunState.last_combat_victory = victory
	RunState.pending_post_combat = true


func _transition_feedback_ready() -> bool:
	var feedback := get_node("CombatFeedback")
	var enchant_fx := get_node_or_null("EnchantAttackFX")
	return not _play_queue.busy() and not BattleDirector.input_locked and not _casting and not feedback.playing_hits and (enchant_fx == null or enchant_fx.phase == "idle")



func _on_combat_death_pending() -> void:
	combat_over = true
	_close_card_browser()
	_set_player_pose(&"death")
	_show_revive_prompt()


func _show_revive_prompt() -> void:
	if is_instance_valid(_revive_prompt):
		_revive_prompt.queue_free()
	_revive_prompt = CanvasLayer.new()
	_revive_prompt.layer = 220
	add_child(_revive_prompt)
	var cover := ColorRect.new()
	cover.color = Color(0.04, 0.03, 0.03, 0.92)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_revive_prompt.add_child(cover)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_revive_prompt.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 560)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	panel.add_child(column)
	var title := _label("余火将熄", 48, RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var detail := _label("可观看广告，回到本场战斗开始时重新挑战。\n牌组、药水、金币和随机序列都会回滚。", 25, CREAM)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(detail)
	var revive := Button.new()
	revive.name = "ReviveAdButton"
	revive.text = "观看广告 · 重新挑战本场战斗"
	revive.custom_minimum_size = Vector2(540, 82)
	revive.add_theme_font_size_override("font_size", 24)
	revive.disabled = not CombatReviveSystem.can_offer_revive()
	revive.tooltip_text = "当前无可用广告" if revive.disabled else "本局唯一一次复燃"
	revive.pressed.connect(_on_revive_ad_pressed)
	column.add_child(revive)
	var finish := Button.new()
	finish.name = "EndRunButton"
	finish.text = "结束本局"
	finish.custom_minimum_size = Vector2(540, 76)
	finish.add_theme_font_size_override("font_size", 24)
	finish.pressed.connect(_on_decline_revive)
	column.add_child(finish)


func _on_revive_ad_pressed() -> void:
	var button := _revive_prompt.find_child("ReviveAdButton", true, false) as Button if is_instance_valid(_revive_prompt) else null
	if button != null:
		button.disabled = true
	if CombatReviveSystem.request_revive().is_empty() and button != null:
		button.disabled = not CombatReviveSystem.can_offer_revive()


func _on_decline_revive() -> void:
	if is_instance_valid(_revive_prompt):
		_revive_prompt.queue_free()
	_revive_prompt = null
	controller.finalize_player_death()


func _on_combat_revive_ready() -> void:
	if is_instance_valid(_revive_prompt):
		_revive_prompt.queue_free()
	_revive_prompt = null
	TransitionManager.change_scene_to_file.call_deferred("res://scenes/combat/CombatPlay.tscn")


func _on_ad_reward_resolved(_transaction_id: String, placement_id: StringName, result: StringName) -> void:
	if placement_id != CombatReviveSystem.PLACEMENT or result == &"granted":
		return
	var button := _revive_prompt.find_child("ReviveAdButton", true, false) as Button if is_instance_valid(_revive_prompt) else null
	if button != null:
		button.disabled = not CombatReviveSystem.can_offer_revive()


## ---------- VFX 回调（依据 VFX_DESIGN.md，由 SignalBus 事件驱动）----------

## 伤害飘字 + 玩家受击红闪。target_index<0=玩家；否则取 enemies[index] 对应持久面板（unit_panels 稳定解析，不靠子节点下标）。
func _on_damage(_is_player_source: bool, target_index: int, amount: int, presented_attack := false) -> void:
	if target_index >= 0 and controller.collecting_attack_hits and controller.presenting_direct_hit:
		return
	if amount <= 0:
		return
	var target: Control = null
	if target_index < 0:
		target = player_panel
	else:
		var e: CombatUnit = controller.enemies[target_index] if target_index < controller.enemies.size() else null
		target = unit_panels.get(e) if e != null else null
		if target == null:
			target = player_panel
	var to_player: bool = (target == player_panel)
	VFXSystem.spawn_damage(target, amount, to_player, get_node_or_null("DamageNumbers/Root"))
	if not to_player and not presented_attack:
		target.get_node("Inner/SpriteRect").play_hit(0.0, get_node("EnchantAttackFX").reduced_motion)
	if to_player:
		VFXSystem.spawn_hit_shake(player_panel)
		if target_index < 0:
			_set_player_pose(&"hit")


## 死亡淡出：动画播完才释放面板（解决旧方案野指针）。index 稳定（死亡敌人保留在 enemies 数组）。
func _on_unit_died(is_player: bool, index: int) -> void:
	if is_player:
		# 玩家死亡：立绘常驻 death 姿态
		_set_player_pose(&"death")
		return
	if index < 0 or index >= controller.enemies.size():
		return
	if controller.attack_receipts_pending:
		var feedback := get_node("CombatFeedback")
		if not feedback.pending_deaths.has(index): feedback.pending_deaths.append(index)
		return
	var e: CombatUnit = controller.enemies[index]
	var p: Panel = unit_panels.get(e)
	if p == null:
		return
	VFXSystem.spawn_death(p, func(): _enemy.free_enemy(e))


func _on_card_played(card_id: StringName, _target_index: int) -> void:
	_hand.on_card_played(card_id, _target_index)


## 纯视觉状态；重播会重置帧，回合刷新不截断动作，死亡停止并锁定。
func _set_player_pose(pose: StringName) -> void:
	if player_sprite == null:
		return
	if _player_dead and pose != &"death":
		return
	if pose == &"death":
		_player_dead = true
	player_sprite.call("play_pose", pose)
