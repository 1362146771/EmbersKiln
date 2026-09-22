extends Node
## Native drag/inertia and SCROLL_BEGIN cancel button presses during a swipe.
## Cover authored lists and their dynamically rebuilt descendants alike.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Control:
		_prepare.call_deferred(weakref(node))


func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.canceled:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is BaseButton and parent_scroll(focus) != null:
			# Godot 4.7's emulated mouse release otherwise treats cancellation as a tap.
			focus.notification(Control.NOTIFICATION_SCROLL_BEGIN)
			focus.notification(Control.NOTIFICATION_SCROLL_END)


func _prepare(reference: WeakRef) -> void:
	var control := reference.get_ref() as Control
	if control == null or not control.is_inside_tree(): return
	if parent_scroll(control) == null: return
	# These controls own their drag gestures rather than scrolling their parent.
	if control is Range or control is LineEdit or control is TextEdit or control is OptionButton or control is CardView:
		return
	if control.mouse_filter == Control.MOUSE_FILTER_STOP:
		control.mouse_filter = Control.MOUSE_FILTER_PASS
	if control is BaseButton:
		control.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE


func parent_scroll(control: Control) -> ScrollContainer:
	var node := control.get_parent()
	while node != null:
		# A popup in its own canvas must retain its input shield.
		if node is CanvasLayer or node is Window: return null
		if node is ScrollContainer: return node
		if node is Control and node.is_set_as_top_level(): return null
		node = node.get_parent()
	return null
