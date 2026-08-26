extends Node
## VFXVerify（依据 VFX_DESIGN.md §10）：在独立锚点上依次触发各 VFX，断言创建/释放/死亡回调。
## 通过 run_and_verify 指定 scene=res://scenes/VFXVerify.tscn 运行。输出 VFX_RESULT:PASS / FAIL。

var results: Array[String] = []
var pass_count := 0
var fail_count := 0


func _ready() -> void:
	await get_tree().process_frame
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
	if VFXSystem == null:
		check("VFXSystem autoload 可用", false, "autoload 为 null")
		return
	check("VFXSystem autoload 可用", true)

	# 伤害飘字（敌人）：创建后自动释放
	var a1 := Control.new()
	add_child(a1)
	var before := a1.get_child_count()
	VFXSystem.spawn_damage(a1, 12, false)
	await get_tree().create_timer(0.1).timeout
	var created := a1.get_child_count() > before
	await get_tree().create_timer(0.8).timeout
	var freed := a1.get_child_count() == before
	check("spawn_damage 创建飘字节点", created)
	check("spawn_damage 动画后自动释放", freed)

	# 治疗飘字：创建并释放
	var a2 := Control.new()
	add_child(a2)
	var b2 := a2.get_child_count()
	VFXSystem.spawn_heal(a2, 8)
	await get_tree().create_timer(0.1).timeout
	var c2 := a2.get_child_count() > b2
	await get_tree().create_timer(0.8).timeout
	check("spawn_heal 创建并释放", c2 and a2.get_child_count() == b2)

	# 格挡/状态/出牌闪光：仅验证不崩溃且锚点仍有效
	var a3 := Control.new()
	add_child(a3)
	VFXSystem.spawn_block(a3)
	VFXSystem.spawn_status(a3, true)
	VFXSystem.spawn_status(a3, false)
	VFXSystem.spawn_card_played(a3)
	await get_tree().create_timer(0.1).timeout
	check("spawn_block/status/card 不崩溃", is_instance_valid(a3))

	# 死亡：on_done 回调触发且锚点释放
	var a4 := Control.new()
	add_child(a4)
	var flag := {"done": false}
	VFXSystem.spawn_death(a4, func():
		flag.done = true
		a4.queue_free())
	await get_tree().create_timer(0.7).timeout
	check("spawn_death 回调触发", flag.done)
	check("spawn_death 释放锚点", not is_instance_valid(a4))

	# 大伤害震屏：不崩溃
	VFXSystem.screen_shake(5.0)
	await get_tree().create_timer(0.1).timeout
	check("screen_shake 不崩溃", true)

	# 玩家受击飘字（to_player=true，触发震屏路径）
	var a5 := Control.new()
	add_child(a5)
	var b5 := a5.get_child_count()
	VFXSystem.spawn_damage(a5, 20, true)
	await get_tree().create_timer(0.1).timeout
	var c5 := a5.get_child_count() > b5
	await get_tree().create_timer(0.8).timeout
	check("spawn_damage(玩家) 创建并释放", c5 and a5.get_child_count() == b5)


func _print_report() -> void:
	for r in results:
		print(r)
	var verdict := "PASS" if fail_count == 0 else "FAIL"
	print("VFX_RESULT:%s  (%d 项通过, %d 项失败)" % [verdict, pass_count, fail_count])
	get_tree().quit(0 if fail_count == 0 else 1)
