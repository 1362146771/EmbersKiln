@tool
extends Control
## 竖屏三段式战斗 UI（MVP）。
## 布局：顶部敌人卡片区 + 中部手牌区 + 底部玩家状态/结束回合。
## 代码全部动态构建，桥接 CombatController + SignalBus。

var controller: CombatController
var combat_over := false

## 进入战斗时由上层场景设置；默认打陶泥团（保持 CombatPlay.tscn 原行为）。
var pending_enemy_ids: Array = ["claylump"]

# 布局节点（场景内烘焙，见 CombatPlay.tscn）。@onready 在 .tscn 路径解析为真实节点，
# 在 .new() 路径（测试 / MapUI 叠加层）下为 null → 改走 _build_ui 代码生成后备。
# 用 get_node_or_null 避免 .new() 路径下因节点不存在而刷 "Node not found" 错误。
@onready var enemy_area: HBoxContainer = get_node_or_null("Safe/Layout/EnemyArea")
@onready var hand_container: HBoxContainer = get_node_or_null("Safe/Layout/HandArea/HandScroll/HandContainer")
@onready var end_turn_btn: Button = get_node_or_null("Safe/Layout/Bottom/EndTurnBtn")
@onready var potion_bar: HBoxContainer = get_node_or_null("Safe/Layout/PotionBar")
var potion_slots: Array = []
var potion_icons: Array = []    # 与 potion_slots 一一对应：每个槽的图标 TextureRect
@onready var result_label: Label = get_node_or_null("ResultLabel")
@onready var log_label: Label = get_node_or_null("Safe/Layout/LogPanel/LogLabel")

# 玩家控件
@onready var player_hp: Label = get_node_or_null("Safe/Layout/Bottom/PlayerPanel/Phbox/Plv/PlayerHp")
@onready var player_hp_bar: ProgressBar = get_node_or_null("Safe/Layout/Bottom/PlayerPanel/Phbox/Plv/PlayerHpBar")
@onready var player_block: Label = get_node_or_null("Safe/Layout/Bottom/PlayerPanel/Phbox/Plv/PlayerBlock")
@onready var player_energy: Label = get_node_or_null("Safe/Layout/HandArea/EnergyRow/PlayerEnergy")
@onready var player_kiln: Label = get_node_or_null("Safe/Layout/Bottom/PlayerPanel/Phbox/Prv/PlayerKiln")
@onready var player_status: Label = get_node_or_null("Safe/Layout/Bottom/PlayerPanel/Phbox/Prv/PlayerStatus")
@onready var player_sprite: TextureRect = get_node_or_null("PlayerSprite")
@onready var player_panel: Panel = get_node_or_null("Safe/Layout/Bottom/PlayerPanel")

# 随从 / 召唤 UI：chip 面板持久映射（按 CombatUnit 键，避免索引漂移导致野指针）
var ally_panels := {}        # CombatUnit -> AllyPanel

# 提示横幅（满场/拒绝召唤等），场景内烘焙
@onready var toast_label: Label = get_node_or_null("ToastLabel")

# VFX 相关（v2，见 VFX_DESIGN.md）：持久敌人面板映射，避免刷新误杀 VFX 子节点。
var unit_panels := {}      # CombatUnit -> EnemyPanel（持久，刷新只更新内容不销毁）
var _prev_php := -1        # 上一帧玩家 HP（检测治疗飘字）
var _prev_ehp := {}        # CombatUnit -> int（上一帧敌人 HP，检测治疗飘字）

## 当前选中的攻击目标索引（-1 表示未选，出牌时自动取首个存活敌）
var selected_target: int = -1

# 拖拽 / 演出层（P1）
const CardViewScene := preload("res://scenes/combat/CardView.tscn")
const DropLayerScript := preload("res://scripts/combat/DropLayer.gd")
const EnemyPanelScene := preload("res://scenes/combat/EnemyPanel.tscn")
const ENEMY_PANEL_OFFSET_Y := 30   # 敌人框整体垂直下偏移（像素，720×1280 基准）
const AllyPanelScene := preload("res://scenes/combat/AllyPanel.tscn")
const MapPlayScene := preload("res://scenes/map/MapPlay.tscn")   # P1：战斗结束切回地图（重入重建）
var drop_layer: DropLayer
var drag_layer: Control
var _casting := false             # 出牌演出进行中：锁 refresh 与输入
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

# 玩家立绘姿态（v3.2 窑面全套，ART_PROMPT_PLAYER.md）：attack/hit 短暂展示后回 idle，death 常驻。
const PLAYER_POSE_TEX := {
	&"idle": preload("res://art/player/SPR_Player_Tannaro_Idle.png"),
	&"attack": preload("res://art/player/SPR_Player_Tannaro_Attack.png"),
	&"hit": preload("res://art/player/SPR_Player_Tannaro_Hit.png"),
	&"death": preload("res://art/player/SPR_Player_Tannaro_Death.png"),
}
const PLAYER_POSE_HOLD := 0.7   # attack / hit 姿态保持秒数
var _player_dead := false       # true 后立绘锁定 death，不再回 idle

# 随从 / 召唤 UI 主题与 §6.1 遮挡/亮度层级
const CYAN := Color(0.40, 0.80, 0.95)            # 友方意图（区分敌人红/橙）
const ALLY_BG := Color(0.20, 0.32, 0.40, 0.92)   # 友方青蓝底
const PLAYER_Z := -50                            # 玩家立绘层级：背景之上、HUD/提示框/随从之下（背景 -100，HUD 0，Toast 200）
const ALLY_DARK_Z := 50                           # 暗态：在玩家立绘之下 → 被遮挡
const ALLY_ACT_Z := 150                           # 行动态：在玩家立绘之上 → 盖住玩家
const ALLY_DARK_ALPHA := 1.0                      # 常驻亮度：随从已移至屏幕右下，不再躲在玩家立绘后，故常显满亮（§6.1 遮挡暗态已停用）
const ALLY_BASE_X := 500                          # 随从 chip 起始 X（屏幕右下，与玩家立绘左下对称：右缘贴右边界）
const ALLY_BASE_Y := 820                          # 随从 chip 起始 Y（与玩家立绘 Y 对齐，落在屏幕底部）
const ALLY_STEP_X := -290                         # 多随从向左排开（从右缘往中心方向，贴近右边界）
const ALLY_CHIP_W := 280                          # 放大 100%（原 140 → 280）
const ALLY_CHIP_H := 300                          # 放大 100%（原 150 → 300）


func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_preview()
		return

	controller = CombatController.new()
	add_child(controller)
	if enemy_area == null:
		_build_ui()            # .new() 路径（测试 / MapUI 叠加层）：代码生成全部 HUD
	else:
		_wire_ui_signals()     # .tscn 路径（CombatPlay）：节点已在场景烘焙，仅连信号
	_create_overlay_layers()
	_connect_signals()
	# P1 场景化：敌人 id 优先取自 RunState（由地图写入），仅在直接启动 CombatPlay.tscn
	# （编辑器预览 / 旧 verify）且 RunState 未置时回退到默认 pending_enemy_ids。
	var launch_ids: Array = RunState.pending_combat_enemy_ids if RunState.pending_combat_enemy_ids.size() > 0 else pending_enemy_ids
	controller.start_combat(launch_ids)
	_refresh_all()
	print("[CombatUI] 界面构建完成，敌人=%d，手牌=%d" % [controller.enemies.size(), controller.hand.size()])


# =====================================================================
# 构建 UI（全部用代码，避免手写 .tscn 锚点出错）
# =====================================================================
func _build_ui() -> void:
	# 深色战斗背景
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.08, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 全局安全边距容器
	var safe := MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 10)
	safe.add_theme_constant_override("margin_right", 10)
	safe.add_theme_constant_override("margin_top", 10)
	safe.add_theme_constant_override("margin_bottom", 10)
	add_child(safe)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	safe.add_child(layout)

	# --- 顶部：敌人区（横向卡片，尽可能占满竖向空间）---
	enemy_area = HBoxContainer.new()
	enemy_area.alignment = BoxContainer.ALIGNMENT_CENTER
	enemy_area.add_theme_constant_override("separation", 10)
	enemy_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_area.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # 改：不再霸占剩余空间，敌区高度=框 420，卡牌才能上移
	enemy_area.size_flags_stretch_ratio = 3
	layout.add_child(enemy_area)

	# --- 中部：日志条 ---
	var log_panel := _styled_panel(Color(0.15, 0.12, 0.11, 0.75))
	log_panel.custom_minimum_size = Vector2(0, 28)
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label = _label("", 20, CREAM)
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	log_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	log_panel.add_child(log_label)
	layout.add_child(log_panel)

	# --- 手牌区（占剩余竖向空间的小头）---
	var hand_area := VBoxContainer.new()
	hand_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_area.size_flags_stretch_ratio = 2.6
	hand_area.alignment = BoxContainer.ALIGNMENT_BEGIN  # 改：手牌区顶部贴齐（替代居中）→ 卡牌紧贴能量条下方
	hand_area.add_theme_constant_override("separation", 6)
	layout.add_child(hand_area)

	# 能量球（手牌上方）
	var energy_row := HBoxContainer.new()
	energy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	player_energy = _orb_label("能量 3 / 3", 26, ORANGE)
	energy_row.add_child(player_energy)
	hand_area.add_child(energy_row)

	var hand_scroll := ScrollContainer.new()
	hand_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_area.add_child(hand_scroll)

	hand_container = HBoxContainer.new()
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_container.add_theme_constant_override("separation", 8)
	hand_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # 改：卡牌贴 ScrollContainer 顶部 → 卡牌整体上移
	hand_scroll.add_child(hand_container)

	# --- 药水槽行（战斗中携带 3 格，Free Action 使用，位于底部操作条上方）---
	potion_bar = HBoxContainer.new()
	potion_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	potion_bar.add_theme_constant_override("separation", 8)
	potion_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	potion_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.add_child(potion_bar)
	_spawn_potion_slots()
	_collect_potion_slots()
	_connect_potion_slots()

	# --- 底部：玩家状态 + 结束回合 ---
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(bottom)

	player_panel = _styled_panel(PANEL_BG)
	player_panel.custom_minimum_size = Vector2(430, 110)
	player_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(player_panel)

	var phbox := HBoxContainer.new()
	phbox.add_theme_constant_override("separation", 14)
	phbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	player_panel.add_child(phbox)

	# 玩家立绘：直接挂在 root(self) 上，避开所有 Container 的尺寸挤压与重排覆盖。
	# 位置/尺寸由 position + custom_minimum_size 完全手控（720×1280 基准）。
	# 想要上下移就改 position.y：负值=上移，正值=下移，单位 px。
	player_sprite = TextureRect.new()
	player_sprite.name = "PlayerSprite"
	player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_sprite.custom_minimum_size = Vector2(390, 390)
	player_sprite.set_anchors_preset(Control.PRESET_TOP_LEFT)
	player_sprite.z_index = PLAYER_Z   # §6.1 基准层级：随从暗态在其下、行动态在其上
	player_sprite.position = Vector2(-60, 820)   # 立绘区域 ≈ (0,900)-(300,1200)，底部靠左
	add_child(player_sprite)

	# 左侧：HP 条 + 名字
	var plv := VBoxContainer.new()
	plv.add_theme_constant_override("separation", 4)
	plv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plv.alignment = BoxContainer.ALIGNMENT_CENTER
	plv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phbox.add_child(plv)

	player_hp = _label("玩家 炭  HP 80 / 80", 28, CREAM)
	plv.add_child(player_hp)

	player_hp_bar = ProgressBar.new()
	# start_combat 前 player 可能尚未创建，先给默认值，_refresh_resources 会覆盖
	player_hp_bar.max_value = controller.player.max_hp if controller.player != null else 80
	player_hp_bar.value = controller.player.hp if controller.player != null else 80
	player_hp_bar.show_percentage = false
	player_hp_bar.custom_minimum_size = Vector2(0, 16)
	player_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_hp_bar.add_theme_stylebox_override("fill", _hp_fill_style())
	player_hp_bar.add_theme_stylebox_override("background", _hp_bg_style())
	plv.add_child(player_hp_bar)

	player_block = _label("格挡 0", 20, GREEN)
	plv.add_child(player_block)

	# 右侧：窑温 + 状态
	var prv := VBoxContainer.new()
	prv.add_theme_constant_override("separation", 4)
	prv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prv.alignment = BoxContainer.ALIGNMENT_CENTER
	phbox.add_child(prv)

	player_kiln = _label("窑温 0 / 5", 20, RED)
	prv.add_child(player_kiln)

	player_status = _label("", 28, PURPLE)
	prv.add_child(player_status)

	# 结束回合按钮
	end_turn_btn = Button.new()
	end_turn_btn.text = "结束回合"
	end_turn_btn.custom_minimum_size = Vector2(200, 100)
	end_turn_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	end_turn_btn.add_theme_font_size_override("font_size", 28)
	end_turn_btn.add_theme_color_override("font_color", Color.WHITE)
	end_turn_btn.add_theme_stylebox_override("normal", _btn_style(ORANGE))
	end_turn_btn.add_theme_stylebox_override("hover", _btn_style(ORANGE.lightened(0.12)))
	end_turn_btn.add_theme_stylebox_override("pressed", _btn_style(ORANGE.darkened(0.15)))
	end_turn_btn.add_theme_stylebox_override("disabled", _btn_style(Color(0.45, 0.42, 0.40)))
	end_turn_btn.pressed.connect(_on_end_turn)
	bottom.add_child(end_turn_btn)

	# --- 胜负面板（全屏覆盖）---
	result_label = Label.new()
	result_label.text = ""
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_label.visible = false
	result_label.add_theme_font_size_override("font_size", 86)
	add_child(result_label)

	# 提示横幅（满场/拒绝召唤等），顶部居中，默认隐藏
	toast_label = Label.new()
	toast_label.text = ""
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	toast_label.position = Vector2(20, 12)
	toast_label.size = Vector2(680, 44)
	toast_label.z_index = 200   # 始终置顶，不被敌人卡/玩家立绘遮挡
	toast_label.add_theme_font_size_override("font_size", 26)
	toast_label.add_theme_color_override("font_color", ORANGE)
	toast_label.modulate.a = 0.0
	toast_label.visible = false
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_label)

	# 拖拽层 / 落点层改为 _create_overlay_layers() 统一创建（.tscn 与 .new() 两路径共用）。


## .tscn 路径：HUD 节点已在 CombatPlay.tscn 烘焙，这里只做运行时信号接线。
## 样式（面板/血条/按钮底色）由场景自带，无需在此重设。
func _wire_ui_signals() -> void:
	if end_turn_btn != null and not end_turn_btn.pressed.is_connected(_on_end_turn):
		end_turn_btn.pressed.connect(_on_end_turn)
	_collect_potion_slots()
	_connect_potion_slots()


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
func _editor_preview() -> void:
	if enemy_area == null or hand_container == null:
		push_warning("[CombatUI] 编辑器预览：缺少场景节点，跳过")
		return

	# 清理上次编译遗留的预览节点
	for c in enemy_area.get_children():
		c.queue_free()
	for c in hand_container.get_children():
		c.queue_free()

	# 玩家立绘
	if player_sprite != null:
		var tex: Texture2D = PLAYER_POSE_TEX.get(&"idle")
		if tex != null:
			player_sprite.texture = tex

	if not GameData.is_loaded:
		push_warning("[CombatUI] 编辑器预览：GameData 未加载，仅显示 HUD 骨架")
		return

	# 示例敌人：陶泥团
	var ed: EnemyData = GameData.enemies.get(&"claylump") as EnemyData
	if ed != null:
		var e := CombatUnit.new()
		var ehp := int(ed.hp)
		e.setup(false, &"claylump", ed.name, ehp, ed.sprite)
		e.max_hp = ehp
		e.hp = maxi(1, int(ehp * 0.6))
		e.intent = {"intent": "attack", "value": 8, "times": 1}
		var p = EnemyPanelScene.instantiate()
		p.custom_minimum_size = Vector2(480, 600)
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var holder := MarginContainer.new()
		holder.add_theme_constant_override("margin_top", ENEMY_PANEL_OFFSET_Y)
		holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		holder.add_child(p)
		enemy_area.add_child(holder)
		p.build(e, 0, false, 1)

	# 示例手牌：5 张（劈薪/护坯交替）
	var hand_ids: Array = [&"strike", &"defend", &"strike", &"defend", &"strike"]
	for i in range(hand_ids.size()):
		var cd: CardData = GameData.cards.get(hand_ids[i]) as CardData
		if cd == null:
			continue
		var v = CardViewScene.instantiate()
		v.build_visual(cd, i, [])
		hand_container.add_child(v)

	# 示例药水：第一格放「灰疗膏」
	var pd: PotionData = GameData.potions.get(&"ash_salve") as PotionData
	if pd != null and potion_slots.size() >= 1:
		var slot: Button = potion_slots[0]
		var ic: TextureRect = potion_icons[0] if potion_icons.size() > 0 else null
		slot.text = pd.name
		if ic != null and pd.icon != "":
			ic.texture = GameData.icon_texture(pd.icon)


## .new() 路径：创建 3 个药水槽（VBox: Icon + SlotButton），挂到 potion_bar。
## .tscn 路径则直接烘焙这 3 个槽，无需此函数（由 _collect_potion_slots 读取场景节点）。
func _spawn_potion_slots() -> void:
	potion_slots.clear()
	potion_icons.clear()
	for i in 3:
		var slot_box := VBoxContainer.new()
		slot_box.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_box.add_theme_constant_override("separation", 2)
		slot_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ic := TextureRect.new()
		ic.name = "Icon"
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(56, 56)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot_box.add_child(ic)
		var slot := Button.new()
		slot.name = "SlotButton"
		slot.custom_minimum_size = Vector2(72, 28)
		slot.add_theme_font_size_override("font_size", 14)
		slot.text = "空"
		slot_box.add_child(slot)
		potion_bar.add_child(slot_box)


## 从 potion_bar 的 SlotBox 子节点读取 Icon / SlotButton，填充 potion_slots / potion_icons。
## 两条路径共用：代码路径由 _spawn_potion_slots 生成、.tscn 路径由场景烘焙。
func _collect_potion_slots() -> void:
	potion_slots.clear()
	potion_icons.clear()
	if potion_bar == null:
		return
	for sb in potion_bar.get_children():
		var ic: TextureRect = sb.get_node_or_null("Icon")
		var btn: Button = sb.get_node_or_null("SlotButton")
		if ic != null:
			potion_icons.append(ic)
		if btn != null:
			potion_slots.append(btn)


func _connect_potion_slots() -> void:
	for i in potion_slots.size():
		var slot: Button = potion_slots[i]
		if slot != null and not slot.pressed.is_connected(_on_potion_pressed.bind(i)):
			slot.pressed.connect(_on_potion_pressed.bind(i))


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


# =====================================================================
# 信号连接
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
	SignalBus.damage_dealt.connect(_on_damage)
	SignalBus.unit_died.connect(_on_unit_died)
	SignalBus.card_played.connect(_on_card_played)
	# 随从 / 召唤（友方单位）
	SignalBus.ally_hp_changed.connect(_on_ally_hp)
	SignalBus.ally_block_changed.connect(_on_ally_block)
	SignalBus.ally_intent_changed.connect(_on_ally_intent)
	SignalBus.ally_status_applied.connect(_on_ally_status)
	SignalBus.ally_lifetime_changed.connect(_on_ally_lifetime)
	SignalBus.ally_action_start.connect(_on_ally_action_start)
	SignalBus.ally_action_end.connect(_on_ally_action_end)
	SignalBus.ally_died.connect(_on_ally_died)
	SignalBus.allies_changed.connect(_on_allies_changed)
	SignalBus.summon_rejected.connect(_on_summon_rejected)


func _exit_tree() -> void:
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
	if SignalBus.damage_dealt.is_connected(_on_damage):
		SignalBus.damage_dealt.disconnect(_on_damage)
	if SignalBus.unit_died.is_connected(_on_unit_died):
		SignalBus.unit_died.disconnect(_on_unit_died)
	if SignalBus.card_played.is_connected(_on_card_played):
		SignalBus.card_played.disconnect(_on_card_played)
	if SignalBus.ally_hp_changed.is_connected(_on_ally_hp):
		SignalBus.ally_hp_changed.disconnect(_on_ally_hp)
	if SignalBus.ally_block_changed.is_connected(_on_ally_block):
		SignalBus.ally_block_changed.disconnect(_on_ally_block)
	if SignalBus.ally_intent_changed.is_connected(_on_ally_intent):
		SignalBus.ally_intent_changed.disconnect(_on_ally_intent)
	if SignalBus.ally_status_applied.is_connected(_on_ally_status):
		SignalBus.ally_status_applied.disconnect(_on_ally_status)
	if SignalBus.ally_lifetime_changed.is_connected(_on_ally_lifetime):
		SignalBus.ally_lifetime_changed.disconnect(_on_ally_lifetime)
	if SignalBus.ally_action_start.is_connected(_on_ally_action_start):
		SignalBus.ally_action_start.disconnect(_on_ally_action_start)
	if SignalBus.ally_action_end.is_connected(_on_ally_action_end):
		SignalBus.ally_action_end.disconnect(_on_ally_action_end)
	if SignalBus.ally_died.is_connected(_on_ally_died):
		SignalBus.ally_died.disconnect(_on_ally_died)
	if SignalBus.allies_changed.is_connected(_on_allies_changed):
		SignalBus.allies_changed.disconnect(_on_allies_changed)
	if SignalBus.summon_rejected.is_connected(_on_summon_rejected):
		SignalBus.summon_rejected.disconnect(_on_summon_rejected)


# =====================================================================
# 刷新
# =====================================================================
func _refresh_all() -> void:
	_refresh_enemy()
	_refresh_resources()
	_refresh_hand()
	_refresh_potions()
	_sync_ally_panels()


## 重绘敌人区（v2 in-place）：存活敌人首次创建面板并存 unit_panels；之后只更新内容，不销毁面板。
## 面板持久化使 VFX 子节点不被刷新误杀（见 VFX_DESIGN.md）。死亡敌人由 _on_unit_died 延后释放。
func _refresh_enemy() -> void:
	if _casting or _drag_active or BattleDirector.input_locked or controller.phase != CombatController.Phase.PLAYER:
		_needs_refresh = true
		return
	for i in controller.enemies.size():
		var e: CombatUnit = controller.enemies[i]
		if not e.is_alive():
			continue
		if not unit_panels.has(e):
			_create_enemy_panel(e, i)
		else:
			_update_enemy_panel(e, i)


func _create_enemy_panel(e: CombatUnit, index: int) -> void:
	var p = EnemyPanelScene.instantiate()
	p.custom_minimum_size = _enemy_size()
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(_on_enemy_gui_input.bind(index))
	# 用 MarginContainer 承载垂直偏移：HBox 每帧重排会覆盖直接设的 position.y
	var holder := MarginContainer.new()
	holder.add_theme_constant_override("margin_top", ENEMY_PANEL_OFFSET_Y)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(p)
	enemy_area.add_child(holder)
	unit_panels[e] = p
	_prev_ehp[e] = e.hp
	var sel := (index == selected_target)
	p.build(e, index, sel, controller.enemies.size())


func _update_enemy_panel(e: CombatUnit, index: int) -> void:
	var p = unit_panels.get(e)
	if p == null:
		_create_enemy_panel(e, index)
		return
	var sel := (index == selected_target)
	p.build(e, index, sel, controller.enemies.size())


# 敌人面板内层内容现由 EnemyPanel.build() 就地更新（见 scenes/combat/EnemyPanel.tscn），不再销毁重建。


func _enemy_size() -> Vector2:
	var n := controller.enemies.size()
	var pw := 480 if n <= 1 else (330 if n == 2 else 230)
	var ph := 540 if n <= 1 else (380 if n == 2 else 340)
	return Vector2(pw, ph)


func _free_enemy(e: CombatUnit) -> void:
	if unit_panels.has(e):
		var p: Panel = unit_panels[e]
		unit_panels.erase(e)
		if is_instance_valid(p):
			var parent = p.get_parent()
			if parent != null and parent != enemy_area:
				parent.queue_free()   # 连带包裹的 MarginContainer 一起释放（避免残留空壳）
			else:
				p.queue_free()
	if _prev_ehp.has(e):
		_prev_ehp.erase(e)


func _format_intent(e: CombatUnit) -> String:
	var kind: String = e.intent.get("intent", "未知")
	if kind == "charge":
		var nx := StringName(e.intent.get("next", ""))
		var rel: Dictionary = {}
		if e.data != null:
			rel = e.data.find_move(nx)
		var rel_kind: String = _intent_cn(String(rel.get("intent", "未知")))
		var rel_val: int = int(rel.get("value", 0))
		var rel_times: int = int(rel.get("times", 1))
		var t := "蓄力→%s %d" % [rel_kind, rel_val]
		if rel_times > 1:
			t += " ×%d" % rel_times
		return t
	else:
		var val: int = int(e.intent.get("value", 0))
		var times: int = int(e.intent.get("times", 1))
		var t := "%s %d" % [_intent_cn(kind), val]
		if times > 1:
			t += " ×%d" % times
		return t


func _refresh_resources() -> void:
	if _casting or _drag_active or BattleDirector.input_locked or controller.phase != CombatController.Phase.PLAYER:
		_needs_refresh = true
		return
	if player_sprite != null and player_sprite.texture == null:
		if controller.player != null and controller.player.sprite != "":
			var ptex = load(controller.player.sprite)
			if ptex != null:
				player_sprite.texture = ptex
	player_hp.text = "玩家 炭  HP %d / %d" % [controller.player.hp, controller.player.max_hp]
	if player_hp_bar != null:
		player_hp_bar.max_value = controller.player.max_hp
		player_hp_bar.value = controller.player.hp
	player_block.text = "格挡 %d" % controller.player.block
	player_energy.text = "能量 %d / %d" % [controller.energy, controller.max_energy]
	player_kiln.text = "窑温 %d / %d" % [controller.kiln_heat, controller._kiln_threshold()]
	player_status.text = _status_text(controller.player)


func _refresh_hand() -> void:
	if _casting or _drag_active or BattleDirector.input_locked or controller.phase != CombatController.Phase.PLAYER:
		_needs_refresh = true
		return
	for c in hand_container.get_children():
		c.queue_free()
	for i in range(controller.hand.size()):
		var entry: Dictionary = controller.hand[i]
		var cd: CardData = GameData.get_card(StringName(entry["id"]))
		if cd == null:
			continue
		var enchants: Array = entry.get("enchants", [])
		var b := _build_card_view(cd, i, enchants)
		hand_container.add_child(b)


func _refresh_potions() -> void:
	if potion_bar == null:
		return
	var inv: Array = RunState.potions
	for i in potion_slots.size():
		var slot: Button = potion_slots[i]
		var ic: TextureRect = potion_icons[i] if i < potion_icons.size() else null
		if i >= inv.size():
			slot.text = "空"
			slot.disabled = true
			slot.tooltip_text = ""
			slot.add_theme_stylebox_override("normal", _disabled_card_style())
			if ic != null:
				ic.texture = null
			continue
		var pid: StringName = inv[i]
		var pd: PotionData = GameData.get_potion(pid)
		if pd == null:
			slot.text = "?"
			slot.disabled = true
			slot.tooltip_text = ""
			slot.add_theme_stylebox_override("normal", _disabled_card_style())
			if ic != null:
				ic.texture = null
			continue
		slot.text = pd.name
		slot.disabled = combat_over or controller.phase != CombatController.Phase.PLAYER
		slot.tooltip_text = pd.description
		if ic != null:
			ic.texture = GameData.icon_texture(pd.icon)
		var col := CREAM
		match pd.rarity:
			&"common": col = CREAM
			&"uncommon": col = GREEN
			&"rare": col = PURPLE
			_: col = CREAM
		slot.add_theme_stylebox_override("normal", _card_style(col))


func _build_card_view(cd: CardData, i: int, enchants: Array = []) -> CardView:
	var v := CardViewScene.instantiate()
	v.build_visual(cd, i, enchants)
	if controller.energy < cd.cost or combat_over:
		v.set_enabled(false)
	v.drag_started.connect(_on_card_drag_started)
	v.drag_moved.connect(_on_card_drag_moved)
	v.drag_ended.connect(_on_card_drag_ended)
	v.tapped.connect(_on_card_tapped)
	return v


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


func _log(msg: String) -> void:
	log_label.text = msg


func _first_alive_index() -> int:
	for i in controller.enemies.size():
		if controller.enemies[i].is_alive():
			return i
	return -1


# =====================================================================
# 交互
# =====================================================================
func _on_enemy_gui_input(ev: InputEvent, index: int) -> void:
	if combat_over or controller.phase != CombatController.Phase.PLAYER:
		return
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		if index < controller.enemies.size() and controller.enemies[index].is_alive():
			selected_target = index
			_refresh_enemy()
			_log("已选中目标：%s" % controller.enemies[index].unit_name)


# =====================================================================
# 拖拽出牌（P1）：CardView 广播手势 → CombatUI 解算落点 → 播放 cast 动画 + VFX → 结算
# =====================================================================

## 轻点：self/none/all_enemies 卡 → 直接对自己（玩家面板）释放并播动画；
## enemy 卡 → 若有已选/存活目标则对其放，否则拒绝提示。
func _on_card_tapped(view: CardView) -> void:
	if _casting or _drag_active or BattleDirector.input_locked or combat_over or controller.phase != CombatController.Phase.PLAYER:
		return
	var cd: CardData = view.card_data
	if cd.target == &"enemy":
		var tgt := -1
		if selected_target >= 0 and selected_target < controller.enemies.size() and controller.enemies[selected_target].is_alive():
			tgt = selected_target
		else:
			tgt = _first_alive_index()
		if tgt < 0:
			_reject_card(view, "没有可攻击的目标")
			return
		_cast_card(view, tgt)
	else:
		# self / none / all_enemies：轻点即对自己释放（仍播动画 + VFX）
		_cast_card(view, -1)


func _on_card_drag_started(view: CardView) -> void:
	if _casting or _drag_active or BattleDirector.input_locked or combat_over or controller.phase != CombatController.Phase.PLAYER:
		return
	_drag_active = true
	_drag_card = view
	view.modulate.a = 0.3                       # 原卡淡出，由幽灵卡代为飞行
	_build_drop_targets()
	drop_layer.highlight(view.card_data.target)
	var gr := view.get_global_rect()
	_ghost = CardViewScene.instantiate()
	_ghost.set_ghost(true)
	_ghost.build_visual(view.card_data, -1, view.enchants)
	_ghost.custom_minimum_size = gr.size
	drag_layer.add_child(_ghost)
	_ghost.global_position = gr.position
	_ghost.size = gr.size
	_ghost.scale = Vector2(1.0, 1.0)


func _on_card_drag_moved(view: CardView, gpos: Vector2) -> void:
	if _ghost == null:
		return
	# 卡牌浮在手指上方一点，避免被手指遮挡
	_ghost.global_position = gpos - _ghost.size * 0.5 - Vector2(0, _ghost.size.y * 0.25)
	drop_layer.hover_update(gpos)


func _on_card_drag_ended(view: CardView, gpos: Vector2) -> void:
	if _ghost == null:
		return
	var idx := drop_layer.hit_test(gpos)
	if idx == -2:
		_snap_back(view)
		return
	_cast_card(view, idx)


## 注入本次拖拽的合法落点：玩家面板（self/none）+ 各存活敌人面板（enemy/all_enemies）。
func _build_drop_targets() -> void:
	var targets := []
	targets.append({"node": player_panel, "types": [&"self", &"none"], "index": -1})
	for i in controller.enemies.size():
		var e: CombatUnit = controller.enemies[i]
		if e.is_alive():
			var p: Panel = unit_panels.get(e)
			if p != null:
				targets.append({"node": p, "types": [&"enemy", &"all_enemies"], "index": i})
	drop_layer.set_targets(targets)


## 施放演出：幽灵卡飞向目标，到达瞬间才真正结算（play_card），既有飘字/血条 VFX 自然接管。
## 轻点路径无幽灵卡，此处现建一张从原卡位置起飞。
## 飞行 + 到达结算 + 元素爆发 + 缓冲统一交给 BattleDirector.play_card_cast（await 编排）；
## 本方法只负责幽灵卡创建/清理与演出后的刷新解锁。
func _cast_card(view: CardView, target_index: int) -> void:
	_casting = true
	_drag_active = false
	var idx: int = view.card_index
	var cd: CardData = view.card_data

	var target_node: Control = player_panel
	if target_index >= 0 and target_index < controller.enemies.size():
		var e: CombatUnit = controller.enemies[target_index]
		var p: Panel = unit_panels.get(e)
		if p != null:
			target_node = p

	var ghost = _ghost
	if ghost == null:
		var gr := view.get_global_rect()
		ghost = CardViewScene.instantiate()
		ghost.set_ghost(true)
		ghost.build_visual(cd, -1, view.enchants)
		ghost.custom_minimum_size = gr.size
		drag_layer.add_child(ghost)
		ghost.global_position = gr.position
		ghost.size = gr.size
		_ghost = ghost
		view.modulate.a = 0.0                          # 隐藏原卡（轻点路径）

	# 演出（飞行 + 到达结算 + 爆发 + 缓冲）交由 BattleDirector 编排
	await BattleDirector.play_card_cast(ghost, target_node, cd, idx, target_index, controller)

	selected_target = -1
	if is_instance_valid(ghost):
		ghost.queue_free()
	_ghost = null
	_drag_card = null
	_casting = false
	drop_layer.clear()
	_finish_cast_refresh()


## 非法落点：幽灵卡弹回原位并释放，原卡恢复。
func _snap_back(view: CardView) -> void:
	var gr := view.get_global_rect()
	var ghost = _ghost
	_ghost = null
	drop_layer.clear()
	_drag_active = false
	_drag_card = null
	if ghost == null:
		view.modulate.a = 1.0
		return
	var tw := create_tween()
	tw.tween_property(ghost, "global_position", gr.position, 0.16).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ghost, "scale", Vector2(1.0, 1.0), 0.16)
	tw.tween_callback(func():
		if is_instance_valid(ghost):
			ghost.queue_free()
		view.modulate.a = 1.0
	)


## 解锁后统一刷新（演出期间累计的刷新需求在此一次性落地）。
func _finish_cast_refresh() -> void:
	_casting = false
	_needs_refresh = false
	_refresh_all()


## 拒绝反馈：卡牌红色脉冲，并提示原因（不消耗牌）。
func _reject_card(view: CardView, msg: String) -> void:
	_log(msg)
	var tw := create_tween()
	tw.tween_property(view, "modulate", Color(1.0, 0.5, 0.5), 0.08)
	tw.tween_property(view, "modulate", Color(1.0, 1.0, 1.0), 0.22)


func _on_end_turn() -> void:
	if _casting or _drag_active or BattleDirector.input_locked or combat_over or controller.phase != CombatController.Phase.PLAYER:
		return
	_log("结束回合 —— 召唤阶段 + 敌人行动中…")
	controller.end_player_turn()
	# 阶段顺序：玩家结束回合 → 召唤物阶段（友色光弹攻击，带动画/VFX）→ 敌人回合。
	# 两者均由 BattleDirector 异步编排（input_locked 期间阻塞输入），"全播完才进下一回合"。
	# 先 await 召唤阶段，结束解锁后再驱动敌人回合（run_enemy_turn 自身再上锁）。
	var enemy_getter := func(e): return unit_panels.get(e) if is_instance_valid(e) else null
	var ally_getter := func(a): return ally_panels.get(a) if is_instance_valid(a) else null
	await BattleDirector.run_summon_turn(controller, player_panel, enemy_getter, ally_getter)
	BattleDirector.run_enemy_turn(controller, player_panel, enemy_getter)


func _on_potion_pressed(i: int) -> void:
	if _casting or _drag_active or BattleDirector.input_locked or combat_over or controller.phase != CombatController.Phase.PLAYER:
		return
	if i < 0 or i >= RunState.potions.size():
		return
	var pid: StringName = RunState.potions[i]
	var pd: PotionData = GameData.get_potion(pid)
	if pd == null:
		return
	var target := -1
	if pd.target == &"enemy":
		if selected_target >= 0 and selected_target < controller.enemies.size() and controller.enemies[selected_target].is_alive():
			target = selected_target
		else:
			target = _first_alive_index()
	var ok := controller.use_potion(i, target)
	if ok:
		_log("使用药水：%s" % pd.name)
		selected_target = -1
		_refresh_potions()
		_refresh_resources()
		_refresh_enemy()


# =====================================================================
# 随从 / 召唤 UI（友方单位 chip，见 SUMMON_SYSTEM_DESIGN.md §6.1）
# =====================================================================

## 同步 chip 面板：为当前每个存活随从补建面板并重新布局。死亡由 _on_ally_died 单独淡出。
func _sync_ally_panels() -> void:
	for i in controller.allies.size():
		var a: CombatUnit = controller.allies[i]
		if not ally_panels.has(a):
			_create_ally_panel(a, i)
	_reposition_allies()


## 创建随从 chip：青蓝底面板（AllyPanel.tscn 内含底色），挂在 root 上（与 player_sprite 同层），手动定位以支持 §6.1 遮挡层级。
func _create_ally_panel(a: CombatUnit, index: int) -> void:
	var p = AllyPanelScene.instantiate()
	p.custom_minimum_size = Vector2(ALLY_CHIP_W, ALLY_CHIP_H)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.z_index = ALLY_DARK_Z          # 暗态：玩家立绘之下 → 被遮挡
	p.modulate = Color(1, 1, 1, 1)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	ally_panels[a] = p
	p.build(a, index)
	_reposition_allies()
	# §6.1 登场高亮：放大 + 全亮，随后回落到暗态（被玩家立绘遮挡）
	p.scale = Vector2(1.15, 1.15)
	var tw := create_tween()
	tw.tween_property(p, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "modulate:a", ALLY_DARK_ALPHA, 0.4).set_ease(Tween.EASE_OUT)


## 横向排布：起始 X 在屏幕右下（与玩家立绘左下对称），多随从向左排开（ALLY_STEP_X 为负）。
func _reposition_allies() -> void:
	var i := 0
	for a in controller.allies:
		var p: Panel = ally_panels.get(a)
		if p == null or not is_instance_valid(p):
			continue
		p.position = Vector2(ALLY_BASE_X + i * ALLY_STEP_X, ALLY_BASE_Y)
		i += 1


# 随从面板内层内容现由 AllyPanel.build() 就地更新（见 scenes/combat/AllyPanel.tscn），不再销毁重建。


func _format_ally_intent(a: CombatUnit) -> String:
	var kind: String = a.intent.get("intent", "未知")
	var val: int = int(a.intent.get("value", 0))
	var times: int = int(a.intent.get("times", 1))
	var t := "%s %d" % [_intent_cn(kind), val]
	if times > 1:
		t += " ×%d" % times
	return t


func _ally_at(index: int) -> CombatUnit:
	if index < 0 or index >= controller.allies.size():
		return null
	return controller.allies[index]


func _refresh_ally(index: int) -> void:
	var a := _ally_at(index)
	if a == null:
		return
	var p = ally_panels.get(a)
	if p != null:
		p.build(a, index)


# ---------- 随从 SignalBus 回调 ----------

func _on_ally_hp(index: int, _cur: int, _maxv: int) -> void:
	_refresh_ally(index)


func _on_ally_block(index: int, _cur: int) -> void:
	_refresh_ally(index)


func _on_ally_intent(index: int, _intent: StringName, _value: int) -> void:
	_refresh_ally(index)


func _on_ally_status(index: int, _status_id: StringName, _stacks: int) -> void:
	_refresh_ally(index)


func _on_ally_lifetime(index: int, _lifetime: int) -> void:
	_refresh_ally(index)


func _on_allies_changed() -> void:
	_sync_ally_panels()


## §6.1 行动态：亮度拉满 + 层级提到玩家立绘之上（盖住玩家）。
func _on_ally_action_start(index: int) -> void:
	var a := _ally_at(index)
	if a == null:
		return
	var p: Panel = ally_panels.get(a)
	if p == null:
		return
	p.z_index = ALLY_ACT_Z
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)


## §6.1 行动结束：恢复暗态亮度 + 层级落回玩家立绘之下（恢复被遮挡状态）。
func _on_ally_action_end(index: int) -> void:
	var a := _ally_at(index)
	if a == null:
		return
	var p: Panel = ally_panels.get(a)
	if p == null:
		return
	p.z_index = ALLY_DARK_Z
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", ALLY_DARK_ALPHA, 0.18).set_ease(Tween.EASE_OUT)


## 死亡淡出：动画播完才释放面板，并让存活随从前移补位。
func _on_ally_died(index: int) -> void:
	var a := _ally_at(index)
	if a == null:
		return
	var p: Panel = ally_panels.get(a)
	ally_panels.erase(a)
	if p == null or not is_instance_valid(p):
		_reposition_allies()
		return
	VFXSystem.spawn_death(p, func(): if is_instance_valid(p): p.queue_free())
	_reposition_allies()


## 满场提示：横幅淡入 1.2s 后淡出。
func _on_summon_rejected(cap: int) -> void:
	if toast_label == null:
		return
	toast_label.text = "召唤栏已满（上限 %d）" % cap
	toast_label.modulate.a = 1.0
	toast_label.visible = true
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(toast_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): toast_label.visible = false)


# =====================================================================
# SignalBus 回调
# =====================================================================
func _on_php(cur: int, maxv: int) -> void:
	player_hp.text = "玩家 炭  HP %d / %d" % [cur, maxv]
	if player_hp_bar != null:
		player_hp_bar.max_value = maxv
		player_hp_bar.value = cur
	if _prev_php >= 0 and cur > _prev_php:
		VFXSystem.spawn_heal(player_panel, cur - _prev_php)
	_prev_php = cur


func _on_pblock(cur: int) -> void:
	player_block.text = "格挡 %d" % cur
	VFXSystem.spawn_block(player_panel)


func _on_energy(cur: int, maxv: int) -> void:
	player_energy.text = "能量 %d / %d" % [cur, maxv]
	_refresh_hand()


func _on_ehp(index: int, cur: int, maxv: int) -> void:
	_refresh_enemy()
	if index >= 0 and index < controller.enemies.size():
		var e: CombatUnit = controller.enemies[index]
		var prev: int = _prev_ehp.get(e, -1)
		if prev >= 0 and cur > prev:
			var p: Panel = unit_panels.get(e)
			if p != null:
				VFXSystem.spawn_heal(p, cur - prev)
		_prev_ehp[e] = cur


func _on_eintent(index: int, intent: StringName, value: int) -> void:
	_refresh_enemy()


func _on_status(is_player: bool, index: int, status_id: StringName, _stacks: int) -> void:
	_refresh_enemy()
	_refresh_resources()
	var is_buff: bool = _is_buff(status_id)
	if is_player:
		VFXSystem.spawn_status(player_panel, is_buff)
	elif index >= 0 and index < controller.enemies.size():
		var e: CombatUnit = controller.enemies[index]
		var p: Panel = unit_panels.get(e)
		if p != null:
			VFXSystem.spawn_status(p, is_buff)


func _on_kiln(current: int, threshold: int) -> void:
	player_kiln.text = "窑温 %d / %d" % [current, threshold]
	# threshold 参数来自 SignalBus，与 controller._kiln_threshold() 一致


func _on_turn_started(is_player: bool) -> void:
	if is_player:
		# 玩家回合开始：立绘回 idle（死亡锁定除外）
		if not _player_dead:
			_set_player_pose(&"idle")
		_refresh_hand()
		_refresh_resources()
		_refresh_enemy()


func _on_combat_end(victory: bool) -> void:
	combat_over = true
	_refresh_hand()
	result_label.visible = true
	if victory:
		result_label.text = "胜  利  !"
		result_label.add_theme_color_override("font_color", GREEN)
		_log("战斗胜利！")
	else:
		result_label.text = "失  败  …"
		result_label.add_theme_color_override("font_color", RED)
		_log("你倒下了…")
	# P1 场景化：不再由 MapUI 监听 combat_ended 做叠加层销毁，而是把战果写回 RunState，
	# 等死亡演出播完再切回地图（MapPlay._ready 据此走结算/奖励/幕转场分支）。
	# combat_ended 仍由 CombatController 发出，SaveManager 的自动存档钩子照常生效。
	RunState.last_combat_victory = victory
	RunState.pending_post_combat = true
	await get_tree().create_timer(VFXSystem.DEATH_DUR + 0.35).timeout
	get_tree().change_scene_to_packed(MapPlayScene)


## ---------- VFX 回调（依据 VFX_DESIGN.md，由 SignalBus 事件驱动）----------

## 伤害飘字 + 玩家受击红闪。target_index<0=玩家；否则取 enemies[index] 对应持久面板（unit_panels 稳定解析，不靠子节点下标）。
func _on_damage(_is_player_source: bool, target_index: int, amount: int) -> void:
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
	VFXSystem.spawn_damage(target, amount, to_player)
	if to_player:
		VFXSystem.spawn_hit_shake(player_panel)
		# 玩家受击：立绘短暂切 hit 姿态
		_set_player_pose(&"hit", PLAYER_POSE_HOLD)


## 死亡淡出：动画播完才释放面板（解决旧方案野指针）。index 稳定（死亡敌人保留在 enemies 数组）。
func _on_unit_died(is_player: bool, index: int) -> void:
	if is_player:
		# 玩家死亡：立绘常驻 death 姿态
		_set_player_pose(&"death")
		return
	if index < 0 or index >= controller.enemies.size():
		return
	var e: CombatUnit = controller.enemies[index]
	var p: Panel = unit_panels.get(e)
	if p == null:
		return
	VFXSystem.spawn_death(p, func(): _free_enemy(e))


func _on_card_played(card_id: StringName, _target_index: int) -> void:
	VFXSystem.spawn_card_played(player_panel)
	# 攻击牌：立绘短暂切 attack 姿态
	if _player_dead:
		return
	var cd: CardData = GameData.get_card(card_id)
	if cd != null and cd.type == &"attack":
		_set_player_pose(&"attack", PLAYER_POSE_HOLD)


## 切换玩家立绘姿态。hold_sec > 0 时到时自动回 idle（死亡锁定后忽略一切非 death 切换）。
func _set_player_pose(pose: StringName, hold_sec: float = 0.0) -> void:
	if player_sprite == null:
		return
	if _player_dead and pose != &"death":
		return
	if pose == &"death":
		_player_dead = true
	var tex: Texture2D = PLAYER_POSE_TEX.get(pose)
	if tex == null:
		return
	player_sprite.texture = tex
	if hold_sec > 0.0 and not _player_dead:
		var tween := create_tween()
		tween.tween_interval(hold_sec)
		tween.tween_callback(_pose_back_to_idle)


func _pose_back_to_idle() -> void:
	if not _player_dead:
		_set_player_pose(&"idle")
