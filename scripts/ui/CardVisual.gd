extends Panel
## 卡图比例更新在下一帧执行，避免容器排序期间反改最小尺寸。

var fit_height_to_width := false


func _ready() -> void:
	set_process(fit_height_to_width)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and fit_height_to_width:
		set_process(true)


func _process(_delta: float) -> void:
	set_process(false)
	if fit_height_to_width and size.x > 0:
		var height := size.x + 76.0
		if not is_equal_approx(custom_minimum_size.y, height):
			custom_minimum_size.y = height
