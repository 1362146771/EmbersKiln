extends Node
## 生成窑口镇 720×1280 运行时截图，供手机竖屏布局人工复核。

const OUTPUT_PATH := "res://Temp/town_stage2_capture.png"


func _ready() -> void:
	var packed := load("res://scenes/main/Town.tscn") as PackedScene
	if packed == null:
		push_error("[TownVisualCapture] 无法加载窑口镇场景")
		get_tree().quit(1)
		return
	add_child(packed.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	var texture := get_viewport().get_texture()
	if texture == null:
		print("TOWN_VISUAL_CAPTURE:FAIL:NO_RENDER_TEXTURE")
		get_tree().quit(1)
		return
	var image := texture.get_image()
	if image == null:
		print("TOWN_VISUAL_CAPTURE:FAIL:NO_RENDER_IMAGE")
		get_tree().quit(1)
		return
	var error := image.save_png(OUTPUT_PATH)
	print("TOWN_VISUAL_CAPTURE:%s:%s" % ["PASS" if error == OK else "FAIL", OUTPUT_PATH])
	get_tree().quit(0 if error == OK else 1)
