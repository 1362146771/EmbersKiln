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
					var end := _position(f + 1, rows[f + 1][index].col, columns)
					if rows[f + 1][index].type == &"boss":
						end += (pos - end).normalized() * FormalUI.BOSS_NODE_SIZE * 0.5
					draw_dashed_line(pos, end, Color("70675b"), 4, 10)
			var tex := FormalUI.node_texture(node.type, node.visited)
			var icon_size := Vector2(76, 80)
			if node.type == &"boss":
				var boss := FormalUI.boss_map_texture(node.enemy_ids)
				if boss != null:
					tex = boss
					icon_size = Vector2.ONE * FormalUI.BOSS_NODE_SIZE
			var texture_size := tex.get_size()
			icon_size = texture_size * minf(icon_size.x / texture_size.x, icon_size.y / texture_size.y)
			draw_texture_rect(tex, Rect2(pos - icon_size * 0.5, icon_size), false)

func _position(floor_index: int, column: int, columns: int) -> Vector2:
	var floors := RunState.current_map().size()
	var canvas_height := FormalUI.MAP_TOP_MARGIN * 2.0 + (floors - 1) * 120.0 + FormalUI.MAP_BOSS_GAP
	var page := size.y - 106.0
	var player_y := FormalUI.MAP_TOP_MARGIN + (floors - 1 - RunState.current_floor) * 120.0 + (FormalUI.MAP_BOSS_GAP if RunState.current_floor < floors - 1 else 0.0)
	var scroll := clampf(player_y - page * 0.5, 0, maxf(0, canvas_height - page))
	var is_boss: bool = RunState.current_map()[floor_index][0].type == &"boss"
	var center := FormalUI.MAP_CANVAS_WIDTH * 0.5
	return Vector2(center if is_boss else center + (column - (columns - 1) * 0.5) * FormalUI.MAP_COLUMN_GAP,
		106 + FormalUI.MAP_TOP_MARGIN + (floors - 1 - floor_index) * 120 + (FormalUI.MAP_BOSS_GAP if floor_index < floors - 1 else 0.0) - scroll)
