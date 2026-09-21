extends Control
## 独立节点场景与验证用面板共用的转场基类；保留每个场景的正式主题。
var _closing := false

func can_interact() -> bool:
	return not _closing and not is_queued_for_deletion() and not TransitionManager.is_transitioning

func _finish_transition(on_closed: Callable, reward: bool = false) -> void:
	if not can_interact():
		return
	_closing = true
	var error: Error
	if self == get_tree().current_scene:
		error = TransitionManager.change_scene_to_file("res://scenes/map/MapPlay.tscn", _prepare_return.bind(reward))
	else:
		error = TransitionManager.close_panel(self, on_closed)
	if error != OK:
		_closing = false

func _prepare_return(reward: bool) -> Error:
	if reward:
		RunState.pending_post_reward = true
	else:
		RunState.pending_node_resolved = true
	return OK

func play_transition_entrance() -> Tween:
	var body := get_node_or_null("Dim/Center") as Control
	if body == null:
		body = get_node_or_null("Center") as Control
	if body == null:
		body = get_node_or_null("Layout") as Control
	if body == null:
		return null
	var home := body.position
	body.position += Vector2(0, 18)
	var tween := TransitionManager._new_tween()
	tween.tween_property(body, "position", home, 0.18)
	return tween

func focus_transition_target() -> void:
	TransitionManager.focus_panel(self)
