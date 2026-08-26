extends Node
## PoseVerify：验证玩家立绘姿态切换（v3.2 窑面全套实装）
##  - 开局立绘 = Idle 纹理
##  - 攻击牌（SignalBus.card_played, type=attack）→ attack 姿态，到时自动回 idle
##  - 玩家受击（SignalBus.damage_dealt 目标 -1）→ hit 姿态
##  - 玩家死亡（SignalBus.unit_died true）→ death 姿态常驻，后续切姿/回合开始均被锁
## 输出 POSE_RESULT:PASS / FAIL

const IDLE_TEX := preload("res://art/player/SPR_Player_Tannaro_Idle.png")
const ATTACK_TEX := preload("res://art/player/SPR_Player_Tannaro_Attack.png")
const HIT_TEX := preload("res://art/player/SPR_Player_Tannaro_Hit.png")
const DEATH_TEX := preload("res://art/player/SPR_Player_Tannaro_Death.png")

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

	# 1) 开局立绘为 Idle
	check("开局立绘 = Idle", cui.player_sprite != null and cui.player_sprite.texture == IDLE_TEX,
		"tex=%s" % (cui.player_sprite.texture.resource_path if cui.player_sprite != null and cui.player_sprite.texture != null else "null"))

	# 2) 攻击牌 → attack 姿态，到时回 idle
	var atk_id := _find_attack_card()
	check("牌组数据中存在攻击牌", atk_id != &"", "atk_id=%s" % atk_id)
	SignalBus.card_played.emit(atk_id, 0)
	await get_tree().process_frame
	check("出攻击牌后立绘 = Attack", cui.player_sprite.texture == ATTACK_TEX,
		"tex=%s" % cui.player_sprite.texture.resource_path)
	await get_tree().create_timer(0.9).timeout
	check("Attack 姿态到时自动回 Idle", cui.player_sprite.texture == IDLE_TEX,
		"tex=%s" % cui.player_sprite.texture.resource_path)

	# 3) 玩家受击 → hit 姿态
	SignalBus.damage_dealt.emit(false, -1, 5)
	await get_tree().process_frame
	check("玩家受击后立绘 = Hit", cui.player_sprite.texture == HIT_TEX,
		"tex=%s" % cui.player_sprite.texture.resource_path)
	await get_tree().create_timer(0.9).timeout

	# 4) 玩家死亡 → death 常驻且锁定
	SignalBus.unit_died.emit(true, -1)
	await get_tree().process_frame
	check("玩家死亡后立绘 = Death", cui.player_sprite.texture == DEATH_TEX,
		"tex=%s" % cui.player_sprite.texture.resource_path)
	cui._set_player_pose(&"attack", 0.1)
	await get_tree().process_frame
	check("死亡锁定：切 attack 被忽略", cui.player_sprite.texture == DEATH_TEX,
		"tex=%s" % cui.player_sprite.texture.resource_path)
	cui._on_turn_started(true)
	await get_tree().process_frame
	check("死亡锁定：回合开始不回 idle", cui.player_sprite.texture == DEATH_TEX,
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
