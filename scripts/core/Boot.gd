extends Control
## T1 冒烟验证场景脚本。
## 目的：在编辑器/运行期一眼确认「数据层 + Autoload 链路」是否真的通了。
## 输出：屏幕 + 控制台双份报告。这是 T1 的验收依据。

@onready var _out: RichTextLabel = $Panel/Report


func _ready() -> void:
	var lines: Array[String] = []
	lines.append("[b]《炽窑》T1 数据层冒烟测试[/b]")
	lines.append("")

	# --- 1. GameData 加载 ---
	if GameData.is_loaded:
		lines.append("[color=#5DCAA5]✓[/color] GameData 加载成功")
		lines.append("    卡牌 %d / 敌人 %d / 状态 %d / 遗物 %d" % [
			GameData.cards.size(), GameData.enemies.size(),
			GameData.statuses.size(), GameData.relics.size()
		])
	else:
		lines.append("[color=#D85A30]✗[/color] GameData 加载失败")
		for e in GameData.load_errors:
			lines.append("    [color=#D85A30]%s[/color]" % e)
		_render(lines)
		return

	# --- 2. 难度系数生效 ---
	var boss: EnemyData = GameData.get_enemy(&"chi_the_first")
	if boss != null:
		lines.append("[color=#5DCAA5]✓[/color] 难度系数生效")
		lines.append("    Boss「%s」原始 HP %d → 缩放后 %d（×%s）" % [
			boss.name, boss.base_hp, GameData.scaled_enemy_hp(boss.base_hp),
			str(GameData.balance.get("enemy_scaling", {}).get("hp_multiplier", 1.0))
		])
		lines.append("    单场敌人上限 %d" % GameData.max_enemies_per_combat())
	else:
		lines.append("[color=#D85A30]✗[/color] 找不到 Boss chi_the_first")

	# --- 3. 世界观 v2 命名已落地 ---
	var st := GameData.get_status(&"crazed")
	var card := GameData.get_card(&"bash")
	if st != null and card != null:
		lines.append("[color=#5DCAA5]✓[/color] v2 命名已落地")
		lines.append("    状态 crazed = 「%s」" % st.name)
		lines.append("    卡牌 bash = 「%s」：%s" % [card.name, card.description])
	else:
		lines.append("[color=#D85A30]✗[/color] 状态命名未生效（crazed / bash 缺失）")

	# --- 4. RunState 开局 ---
	if RunState.start_new_run():
		lines.append("[color=#5DCAA5]✓[/color] RunState 开局成功")
		lines.append("    HP %d/%d，金币 %d，层数 %d/%d" % [
			RunState.hp, RunState.max_hp, RunState.gold,
			RunState.current_floor, RunState.total_floors()
		])
		var names: Array[String] = []
		for entry in RunState.deck:
			var c: CardData = GameData.get_card(entry["id"])
			names.append(c.name if c != null else String(entry["id"]))
		lines.append("    起始牌组（%d）：%s" % [RunState.deck.size(), ", ".join(names)])
		lines.append("    持有遗物：%d 件（新局不发放遗物）" % RunState.relic_ids.size())
	else:
		lines.append("[color=#D85A30]✗[/color] RunState 开局失败")

	# --- 5. SignalBus 链路 ---
	var got_signal := [false]
	var probe := func(_a: int, _b: int) -> void: got_signal[0] = true
	SignalBus.player_hp_changed.connect(probe)
	RunState.take_damage(5)
	SignalBus.player_hp_changed.disconnect(probe)
	if got_signal[0]:
		lines.append("[color=#5DCAA5]✓[/color] SignalBus 链路通（受伤 5 → HP %d）" % RunState.hp)
	else:
		lines.append("[color=#D85A30]✗[/color] SignalBus 未收到 player_hp_changed")

	# --- 6. 遗物结算 ---
	RunState.add_gold(100)
	lines.append("[color=#5DCAA5]✓[/color] 遗物 trigger 查询可用（+100 金币 → %d）" % RunState.gold)

	lines.append("")
	lines.append("[color=#EF9F27]T1 冒烟测试结束。[/color]")
	_render(lines)


func _render(lines: Array[String]) -> void:
	var text := "\n".join(lines)
	_out.bbcode_enabled = true
	_out.text = text
	print("\n".join(lines).replace("[b]", "").replace("[/b]", ""))
