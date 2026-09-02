extends Node
## 生成窑口镇 720×1280 运行时截图，供手机竖屏布局人工复核。

const OUTPUT_PATH := "res://Temp/town_stage2_capture.png"
const DETAIL_OUTPUT_PATH := "res://Temp/town_detail_capture.png"


func _ready() -> void:
	var packed := load("res://scenes/town/Town.tscn") as PackedScene
	if packed == null:
		push_error("[TownVisualCapture] 无法加载窑口镇场景")
		get_tree().quit(1)
		return
	add_child(packed.instantiate())
	await get_tree().process_frame
	await get_tree().process_frame
	var overview_error := _capture(OUTPUT_PATH)
	var hearth := find_child("Hearth", true, false) as TextureButton
	if hearth == null:
		print("TOWN_VISUAL_CAPTURE:FAIL:NO_FACILITY_BUTTON")
		get_tree().quit(1)
		return
	hearth.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var detail_error := _capture(DETAIL_OUTPUT_PATH)
	var passed := overview_error == OK and detail_error == OK
	print("TOWN_VISUAL_CAPTURE:%s:%s:%s" % ["PASS" if passed else "FAIL", OUTPUT_PATH, DETAIL_OUTPUT_PATH])
	get_tree().quit(0 if passed else 1)


func _capture(path: String) -> Error:
	var texture := get_viewport().get_texture()
	if texture == null:
		return ERR_CANT_CREATE
	var image := texture.get_image()
	if image == null:
		return ERR_CANT_CREATE
	return image.save_png(path)
