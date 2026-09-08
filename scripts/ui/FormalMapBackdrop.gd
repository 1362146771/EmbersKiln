extends Control
## 只读地图底图，供独立事件/奖励页面保留当前位置的空间上下文。

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not has_node("Background"):
		var art := FormalUI.background(self, FormalUI.ROOT + "bgIMG_stage.png")
		art.name = "Background"
		art.show_behind_parent = true
	resized.connect(queue_redraw)

func _draw() -> void:
	var rows := RunState.current_map()
	var columns := int(RunState.current_act_config().get("columns", 6))
	for f in rows.size():
		for node in rows[f]:
			var pos := _position(f, node.col, columns)
			for index in node.links:
				if f + 1 < rows.size() and index < rows[f + 1].size():
					draw_dashed_line(pos, _position(f + 1, rows[f + 1][index].col, columns), Color("70675b"), 4, 10)
			var tex := FormalUI.node_texture(node.type, node.visited)
			draw_texture_rect(tex, Rect2(pos - Vector2(45, 37), Vector2(90, 74)), false)

func _position(floor_index: int, column: int, columns: int) -> Vector2:
	var floors := RunState.current_map().size()
	var canvas_height := 96.0 + (floors - 1) * 120.0
	var page := size.y - 106.0
	var player_y := 48.0 + (floors - 1 - RunState.current_floor) * 120.0
	var scroll := clampf(player_y - page * 0.5, 0, maxf(0, canvas_height - page))
	return Vector2(340 + (column - (columns - 1) * 0.5) * 110, 106 + 48 + (floors - 1 - floor_index) * 120 - scroll)
