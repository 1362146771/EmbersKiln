extends Node
## P1 验证：战斗场景化（地图↔战斗独立场景切换）后的同步契约。
## 1) CombatUI 进入战斗时从 RunState.pending_combat_enemy_ids 取敌人启动（取代原 overlay 传参）。
## 2) CombatUI._on_combat_end 在 combat_ended 后把战果写回 RunState，供 MapPlay._ready 结算分支使用。

func _ready() -> void:
	await get_tree().process_frame

	# 模拟真实入口：先确保一局已开始（RunState.is_active），否则 start_combat 内部会触发
	# start_new_run() 重置 pending_combat_enemy_ids，导致敌人落空。真实游戏里战斗总在跑局内，
	# is_active 恒为 true，不会走这条路。
	if not RunState.is_active:
		RunState.start_new_run()
	# 模拟「从地图进入战斗」：把敌人 id 放进 RunState（原由 MapUI._start_combat_node 写入）。
	# 必须在 start_new_run() 之后设置，否则会被重置清空。
	RunState.pending_combat_enemy_ids = ["claylump"]

	# 直接实例化 CombatPlay.tscn（与真实入口一致，只是不经过 MapUI.change_scene）
	var combat = preload("res://scenes/combat/CombatPlay.tscn").instantiate()
	combat.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(combat)

	await get_tree().process_frame

	var ok := combat.controller != null
	var n := 0
	if ok:
		n = combat.controller.enemies.size()
		ok = n == 1
	if ok:
		print("[PASS] CombatPlay 从 RunState.pending_combat_enemy_ids 启动，敌人=%d" % n)
	else:
		print("[FAIL] controller=%s 敌人=%d（期望 1）" % [combat.controller, n])

	# 验证战后标记契约：直接驱动 CombatUI 结束回调（与真实战斗结束一致）。
	# _on_combat_end 中 flag 赋值在 await 之前同步执行，故调用后即可断言；
	# 随后把 pending_post_combat 复位，避免 0.35s 后的切场景把验证节点带进地图流程。
	if ok and combat.has_method("_on_combat_end"):
		combat._on_combat_end(true)
		var ok_flags := RunState.pending_post_combat and RunState.last_combat_victory
		RunState.pending_post_combat = false   # 中和延迟的 change_scene 副作用
		if ok_flags:
			print("[PASS] combat_ended 后 RunState.pending_post_combat / last_combat_victory 已置位")
		else:
			print("[FAIL] 战后标记未置位")
			ok = false

	print("MAP_SYNC_RESULT:%s" % ("PASS" if ok else "FAIL"))
