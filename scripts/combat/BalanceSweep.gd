extends Node
## 战斗平衡 Sweep Harness（数据驱动，零硬编码数值）。
## 多 build × 当前正式数据中的全部分幕遭遇模拟，输出胜率/均回合/终局HP，并标记离群：
##   严重(FAIL)：某 encounter 所有 build 皆败（可能不可战胜）/ Boss 被秒杀（平衡崩坏）。
##   提示(WARN)：某 build 对某敌过难/秒杀/拖沓/过易（需数值策划复核）。
## 全部参数来自 data/balance_sweep.json（数值规范：提案→确认→写入→回填，见 NUMERIC_LEDGER.md）。
## 复用 PlaythroughTest 的自动战斗启发式；本脚本不写死任何玩法数值。

const CONFIG_PATH := "res://data/balance_sweep.json"
const TEST_SAVE_PATH := "res://Temp/balance_sweep_save.json"

var _cfg: Dictionary = {}
var results: Array[String] = []
var _report_lines: Array[String] = []
var pass_count := 0
var fail_count := 0
var warn_count := 0
var _original_profile_autosave := true
var _original_save_path := ""


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	if not GameData.is_loaded:
		_fail("GameData 未加载，无法运行 sweep")
		_print_report()
		return
	_cfg = _load_config()
	if _cfg.is_empty():
		_print_report()
		return
	_original_profile_autosave = ProfileManager.autosave_enabled
	_original_save_path = SaveManager.runtime_save_path
	ProfileManager.autosave_enabled = false
	SaveManager.runtime_save_path = TEST_SAVE_PATH
	SaveManager.delete_save()
	await run()
	SaveManager.delete_save()
	SaveManager.runtime_save_path = _original_save_path
	ProfileManager.autosave_enabled = _original_profile_autosave
	_print_report()


func _load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		_fail("找不到配置 %s" % CONFIG_PATH)
		return {}
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	var p := JSON.new()
	var err: int = p.parse(txt)
	if err != OK:
		_fail("JSON 解析失败: %s" % p.get_error_message())
		return {}
	return p.data


func _log_filter(keep: Array) -> void:
	print("[BalanceSweep] 分 build 隔离运行，仅跑: %s" % keep)


# =====================================================================
# 主流程
# =====================================================================
func run() -> void:
	if not (_cfg.has("sim") and _cfg.has("builds") and _cfg.has("outlier")):
		_fail("配置结构缺失 sim/builds/outlier 之一")
		return
	var encounters := _build_encounters()
	if encounters.is_empty():
		_fail("没有可测试的遭遇")
		return

	# ---- build 过滤（分 build 回归用；不写此字段则全量）----
	var builds: Array = _cfg["builds"]
	if _cfg.has("filter_builds") and not (_cfg["filter_builds"] as Array).is_empty():
		var keep: Array = _cfg["filter_builds"]
		builds = builds.filter(func(b): return keep.has(b["id"]))
		if builds.is_empty():
			_fail("filter_builds 未匹配到任何 build: %s" % keep)
			return
		_log_filter(keep)

	# ---- id 校验（未知卡/敌 → FAIL）----
	var bad: Array[String] = []
	for b in builds:
		for cid in b["cards"]:
			if GameData.get_card(StringName(cid)) == null:
				bad.append("build=%s 未知卡=%s" % [b["id"], cid])
	for e in encounters:
		if bool(e.get("generated", false)):
			continue
		for eid in e["enemies"]:
			if GameData.get_enemy(StringName(eid)) == null:
				bad.append("enc=%s 未知敌=%s" % [e["id"], eid])
	if not bad.is_empty():
		for s in bad:
			_fail("未知 id: %s" % s)
		return
	_pass("当前数据与 id 校验通过（cards=%d, enemies=%d, acts=%d, builds=%d, encounters=%d）" % [
		GameData.cards.size(), GameData.enemies.size(), GameData.act_configs.size(), builds.size(), encounters.size()
	])

	var cc := CombatController.new()
	add_child(cc)
	var attempts: int = int(_cfg["sim"]["attempts_per_match"])
	var ol: Dictionary = _cfg["outlier"]

	for enc in encounters:
		var is_boss := String(enc.get("tier", "")) == "boss"
		var per_build_wr: Array = []
		var lines: Array[String] = []
		for b in builds:
			var wins: int = 0
			var turn_sum: int = 0
			var hp_sum: int = 0
			for a in range(attempts):
				var r: Dictionary = await _simulate(cc, enc, b["cards"])
				if r["win"]:
					wins += 1
					turn_sum += int(r["turns"])
					hp_sum += int(r["hp_left"])
			var wr: float = float(wins) / float(attempts)
			per_build_wr.append(wr)
			var avg_t: float = float(turn_sum) / float(maxi(1, wins))
			var avg_hp: float = float(hp_sum) / float(maxi(1, wins)) / float(RunState.max_hp)
			var tag: String = ""
			if wr < float(ol["win_rate_floor"]):
				tag += " [过难]"
				_warn("enc=%s build=%s 胜率%.2f<%.2f" % [enc["id"], b["name"], wr, float(ol["win_rate_floor"])])
			if wr >= 1.0 and avg_t <= float(ol["trivial_win_turns"]):
				tag += " [秒杀]"
				_warn("enc=%s build=%s 均回合%.1f<=%.0f 过于trivial" % [enc["id"], b["name"], avg_t, float(ol["trivial_win_turns"])])
			elif wr >= 1.0 and avg_t > float(ol["grind_turn_cap"]):
				tag += " [拖沓]"
				_warn("enc=%s build=%s 均回合%.1f>%.0f 过于拖沓" % [enc["id"], b["name"], avg_t, float(ol["grind_turn_cap"])])
			if wr >= 1.0 and avg_hp >= float(ol["too_easy_hp_ratio"]):
				tag += " [过易]"
				_warn("enc=%s build=%s 终局HP比%.2f>=%.2f 过易" % [enc["id"], b["name"], avg_hp, float(ol["too_easy_hp_ratio"])])
			if is_boss and wr >= 1.0 and avg_t <= float(ol["boss_one_shot_turns"]):
				tag += " [BOSS秒杀]"
				_fail("enc=%s BOSS被build=%s秒杀(均回合%.1f)——平衡崩坏" % [enc["id"], b["name"], avg_t])
			lines.append("    %s: 胜率%.2f 均回合%.1f 终局HP比%.2f%s" % [b["name"], wr, avg_t, avg_hp, tag])
		# 严重离群：所有 build 皆败（单 build 回归时降级为 WARN，需跨 build 复核）
		var max_wr: float = 0.0
		for w in per_build_wr:
			max_wr = maxf(max_wr, float(w))
		if max_wr <= 0.0:
			if builds.size() > 1:
				_fail("enc=%s 所有build胜率=0（敌人不可战胜？需人工复核）" % enc["id"])
			else:
				_warn("enc=%s build=%s 胜率=0（单build回归，需跨build复核是否不可战胜）" % [enc["id"], builds[0]["name"]])
		_report_lines.append("enc %s (%s):" % [enc["id"], _encounter_label(enc)])
		for l in lines:
			_report_lines.append(l)

	cc.queue_free()


## 单次模拟：重置 RunState 为该 build 满血牌组，开战，自动战斗，返回结果。
func _simulate(cc: CombatController, encounter: Dictionary, build_cards: Array) -> Dictionary:
	_reset_run_for(build_cards)
	var act_index := clampi(int(encounter.get("act_index", 0)), 0, maxi(0, GameData.act_configs.size() - 1))
	RunState.current_act = act_index
	var enemy_ids: Array = encounter.get("enemies", []).duplicate()
	if bool(encounter.get("generated", false)):
		var act_config: Dictionary = GameData.act_configs[act_index]
		var pool := MapGenerator._pool_enemies(act_config, &"normal")
		enemy_ids.assign(MapGenerator._pick_weighted_enemies(pool, int(encounter.get("enemy_count", 1))))
	if enemy_ids.is_empty():
		return {"win": false, "turns": 0, "hp_left": 0}
	cc.start_combat(enemy_ids)
	await _auto_battle(cc)
	var win: bool = cc.phase == CombatController.Phase.ENDED and cc.player.is_alive()
	return {"win": win, "turns": cc.turn, "hp_left": cc.player.hp}


## 从当前 map/enemy 数据派生覆盖矩阵，避免敌人扩充后测试夹具继续停留在旧固定编成。
func _build_encounters() -> Array:
	var coverage: Dictionary = _cfg.get("coverage", {})
	if not bool(coverage.get("derive_from_current_acts", false)):
		return _cfg.get("encounters", []).duplicate(true)
	var out: Array = []
	for act_index in GameData.act_configs.size():
		var act_config: Dictionary = GameData.act_configs[act_index]
		var act_number := act_index + 1
		for tier in [&"normal", &"elite"]:
			for enemy in MapGenerator._pool_enemies(act_config, tier):
				var ed := enemy as EnemyData
				if ed == null:
					continue
				out.append({
					"id": "act%d_%s_%s" % [act_number, String(tier), String(ed.id)],
					"act_index": act_index,
					"tier": String(tier),
					"enemies": [ed.id],
				})
		var boss_id := StringName(String(act_config.get("boss_id", "")))
		if boss_id != &"" and GameData.get_enemy(boss_id) != null:
			out.append({
				"id": "act%d_boss_%s" % [act_number, String(boss_id)],
				"act_index": act_index,
				"tier": "boss",
				"enemies": [boss_id],
			})
		if bool(coverage.get("include_weighted_encounters", true)):
			for enemy_count in range(1, GameData.max_enemies_per_combat() + 1):
				out.append({
					"id": "act%d_weighted_%d" % [act_number, enemy_count],
					"act_index": act_index,
					"tier": "normal",
					"generated": true,
					"enemy_count": enemy_count,
				})
	return out


func _encounter_label(encounter: Dictionary) -> String:
	var act_number := int(encounter.get("act_index", 0)) + 1
	if bool(encounter.get("generated", false)):
		return "第%d幕/动态%d敌/每次按正式权重重抽" % [act_number, int(encounter.get("enemy_count", 1))]
	var names: Array[String] = []
	for raw_id in encounter.get("enemies", []):
		var enemy := GameData.get_enemy(StringName(String(raw_id)))
		names.append(enemy.name if enemy != null else String(raw_id))
	return "第%d幕/%s/%s" % [act_number, String(encounter.get("tier", "")), ",".join(names)]


## 隔离 build：满血、清遗物、用 build 牌组覆盖 RunState.deck（不重新生成地图，省开销）。
func _reset_run_for(build_cards: Array) -> void:
	RunState.is_active = true
	var pc: Dictionary = GameData.player_config()
	RunState.max_hp = int(pc.get("max_hp", 80))
	RunState.hp = RunState.max_hp
	RunState.deck.clear()
	for cid in build_cards:
		# Sweep 牌组是瞬时测试夹具，不应触发永久牌库容量、发现记录或档案写入。
		RunState.deck.append({
			"id": StringName(cid),
			"upgraded": false,
			"upgrade_level": 0,
			"enchants": [],
		})
	RunState.defeated.clear()
	if not bool(_cfg["player"].get("use_relics", false)):
		RunState.relic_ids.clear()


# =====================================================================
# 自动战斗启发式（复用 PlaythroughTest 模式；无魔法数值）
# =====================================================================
func _auto_battle(cc: CombatController) -> void:
	var guard: int = 0
	var max_t: int = int(_cfg["sim"]["max_turns"])
	var get_panel := func(_unit): return null
	while cc.phase != CombatController.Phase.ENDED and guard < max_t:
		guard += 1
		var safety: int = 0
		var max_plays: int = int(_cfg["sim"]["max_card_plays"])
		while safety < max_plays:
			safety += 1
			if cc.phase != CombatController.Phase.PLAYER:
				break
			var idx: int = _choose_card(cc)
			if idx < 0:
				break
			var ti: int = _target_for(cc, idx)
			if not cc.play_card(idx, ti):
				break
		if cc.phase == CombatController.Phase.ENDED:
			break
		cc.end_player_turn()
		# CombatController 只负责锁定回合；敌方行动由 BattleDirector 异步编排。
		await BattleDirector.run_enemy_turn(cc, null, get_panel)


func _choose_card(cc: CombatController) -> int:
	var incoming: int = _incoming_damage(cc)
	var block_needed: bool = incoming > cc.player.block
	var best_block: int = -1
	var best_attack: int = -1
	var best_any: int = -1
	for i in range(cc.hand.size()):
		var entry: Dictionary = cc.hand[i]
		var cd: CardData = GameData.get_card(entry["id"])
		if cd == null or cc.energy < cd.cost:
			continue
		if best_any < 0:
			best_any = i
		var has_block: bool = false
		for eff in cd.get_effects(entry["upgraded"]):
			if eff is Dictionary and String(eff.get("kind", "")) == "block":
				has_block = true
		if has_block and best_block < 0:
			best_block = i
		if cd.type == &"attack" and best_attack < 0:
			best_attack = i
	if block_needed and best_block >= 0:
		return best_block
	if best_attack >= 0:
		return best_attack
	if best_block >= 0:
		return best_block
	return best_any


func _target_for(cc: CombatController, idx: int) -> int:
	var cd: CardData = GameData.get_card(cc.hand[idx]["id"])
	if cd != null and cd.target == &"enemy":
		var best: int = -1
		var best_hp: int = 1000000
		for i in range(cc.enemies.size()):
			if cc.enemies[i].is_alive() and cc.enemies[i].hp < best_hp:
				best_hp = cc.enemies[i].hp
				best = i
		return best if best >= 0 else 0
	return -1


func _incoming_damage(cc: CombatController) -> int:
	var sum: int = 0
	for e in cc.enemies:
		if not e.is_alive():
			continue
		var it: Dictionary = e.intent
		var kind: String = String(it.get("intent", String(it.get("kind", ""))))
		if kind == "attack":
			sum += int(it.get("value", 0)) * int(it.get("times", 1))
	return sum


# =====================================================================
# 记录与报告
# =====================================================================
func _pass(msg: String) -> void:
	pass_count += 1
	results.append("[PASS] %s" % msg)


func _fail(msg: String) -> void:
	fail_count += 1
	results.append("[FAIL] %s" % msg)


func _warn(msg: String) -> void:
	warn_count += 1
	results.append("[WARN] %s" % msg)


func _print_report() -> void:
	var lines := PackedStringArray()
	lines.append("===== 战斗平衡 Sweep（BalanceSweep）=====")
	for l in _report_lines:
		lines.append(l)
	lines.append("----- 判定 -----")
	for r in results:
		lines.append(r)
	lines.append("总计: %d PASS / %d FAIL / %d WARN" % [pass_count, fail_count, warn_count])
	var verdict := "FAIL" if fail_count > 0 else ("REVIEW_REQUIRED" if warn_count > 0 else "PASS")
	lines.append("BALANCE_SWEEP_RESULT:%s" % verdict)
	print("\n".join(lines))
