extends Node
## PoseVerify：验证玩家动作状态切换。当前四种状态共用同一张正式立绘，
## 状态计时和死亡锁定逻辑继续保留，方便以后直接补入独立动作图。
## 输出 POSE_RESULT:PASS / FAIL

const IDLE_TEX := preload("res://art/player/SPR_Player_Tannaro.png")
const ATTACK_TEX := preload("res://art/player/SPR_Player_Tannaro.png")
const HIT_TEX := preload("res://art/player/SPR_Player_Tannaro.png")
const DEATH_TEX := preload("res://art/player/SPR_Player_Tannaro.png")

var results: Array[String] = []
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
	if not GameData.is_loaded:
		GameData.load_all()
	if not RunState.is_active:
		RunState.start_new_run()
	await run()
	_print_report()


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		pass_count += 1
		results.append("[PASS] " + name)
	else:
		fail_count += 1
		results.append("[FAIL] " + name + "  " + detail)


func run() -> void:
	var cui = preload("res://scripts/combat/CombatUI.gd").new()
	cui.pending_enemy_ids = ["claylump"]
	add_child(cui)
	# 等 CombatUI._ready + 首帧构建完成
	await get_tree().process_frame
	await get_tree().process_frame

	# 1) 开局加载共用正式立绘
	check("开局加载共用正式立绘", cui.player_sprite != null and cui.player_sprite.texture == IDLE_TEX,
		"tex=%s" % (cui.player_sprite.texture.resource_path if cui.player_sprite != null and cui.player_sprite.texture != null else "null"))

	# 2) 攻击状态保持共用立绘，计时结束后仍可正常使用
	var atk_id := _find_attack_card()
	check("牌组数据中存在攻击牌", atk_id != &"", "atk_id=%s" % atk_id)
	SignalBus.card_played.emit(atk_id, 0)
	await get_tree().process_frame
	check("攻击状态使用共用立绘", cui.player_sprite.texture == ATTACK_TEX and not cui._player_dead,
		"tex=%s" % cui.player_sprite.texture.resource_path)
	await get_tree().create_timer(0.9).timeout
	check("攻击状态计时结束仍使用共用立绘", cui.player_sprite.texture == IDLE_TEX and not cui._player_dead,
		"tex=%s" % cui.player_sprite.texture.resource_path)

	# 3) 受击状态使用共用立绘
	SignalBus.damage_dealt.emit(false, -1, 5)
	await get_tree().process_frame
	check("受击状态使用共用立绘", cui.player_sprite.texture == HIT_TEX and not cui._player_dead,
		"tex=%s" % cui.player_sprite.texture.resource_path)
	await get_tree().create_timer(0.9).timeout

	# 4) 玩家死亡后仍锁定状态，立绘继续共用
	SignalBus.unit_died.emit(true, -1)
	await get_tree().process_frame
	check("死亡状态使用共用立绘并锁定", cui.player_sprite.texture == DEATH_TEX and cui._player_dead,
		"tex=%s" % cui.player_sprite.texture.resource_path)
	cui._set_player_pose(&"attack", 0.1)
	await get_tree().process_frame
	check("死亡锁定：切 attack 被忽略", cui.player_sprite.texture == DEATH_TEX and cui._player_dead,
		"tex=%s" % cui.player_sprite.texture.resource_path)
	cui._on_turn_started(true)
	await get_tree().process_frame
	check("死亡锁定：回合开始不解锁", cui.player_sprite.texture == DEATH_TEX and cui._player_dead,
		"tex=%s" % cui.player_sprite.texture.resource_path)

	cui.queue_free()


func _find_attack_card() -> StringName:
	for cid in GameData.cards.keys():
		var cd: CardData = GameData.get_card(cid)
		if cd != null and cd.type == &"attack":
			return cid
	return &""


func _print_report() -> void:
	for r in results:
		print(r)
	var verdict := "PASS" if fail_count == 0 else "FAIL"
	print("POSE_RESULT:%s  (%d 项通过, %d 项失败)" % [verdict, pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)
