extends Node
## 全局转场入口。请求同步返回 Error；接受后立即锁输入，由本单例持有异步流程。
## 场景：遮住旧场景 -> 实例化并准备数据 -> 切换 -> 等待界面布局 -> 揭幕。
## 面板：淡入淡出 + 内容轻移；全屏底板始终贴合画布，不切换 SceneTree。

signal transition_started(kind: StringName)
signal transition_finished(kind: StringName, error: int)
signal scene_revealing(scene: Node)

const FADE_OUT := 0.12
const FADE_IN := 0.18
const CLAY_OUT := 0.18
const CLAY_IN := 0.20
const CLAY_SHADER := preload("res://art/shaders/clay_wipe.gdshader")
const KILN_SHADER := preload("res://art/shaders/kiln_transition.gdshader")
const SPECIAL_TIMINGS := {&"boss": Vector2(0.28, 0.34), &"chapter": Vector2(0.30, 0.38)}
const PANEL_DURATION := 0.18
const PANEL_DISTANCE := 18.0
const COVER_COLOR := Color(0.12, 0.10, 0.09)

var is_transitioning := false
var _layer: CanvasLayer
var _cover: ColorRect
var _previous_focus: WeakRef
var _clay_material: ShaderMaterial
var _kiln_material: ShaderMaterial
var _sound: AudioStreamPlayer
var _boss_sound: AudioStream
var _chapter_sound: AudioStream
var _resolver := Callable()
var _ready_gate := Callable()
var _effect: StringName = &"fade"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.name = "TransitionLayer"
	_layer.layer = 256  # 高于 PauseManager 的 128，包含暂停按钮和菜单。
	add_child(_layer)
	_cover = ColorRect.new()
	_cover.name = "InputShield"
	_cover.color = COVER_COLOR
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_cover.focus_mode = Control.FOCUS_ALL
	_cover.hide()
	_layer.add_child(_cover)
	_clay_material = ShaderMaterial.new()
	_clay_material.shader = CLAY_SHADER
	_kiln_material = ShaderMaterial.new()
	_kiln_material.shader = KILN_SHADER
	_sound = AudioStreamPlayer.new()
	# 在导入完成后的运行期加载，避免全新工程首次扫描 autoload 早于 WAV 导入。
	_boss_sound = AudioManager.stream_for(&"transition_boss")
	_chapter_sound = AudioManager.stream_for(&"transition_chapter")
	_sound.name = "TransitionSound"
	_sound.volume_db = 0.0
	_sound.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(_sound)
	set_process_input(false)


func _input(_event: InputEvent) -> void:
	# 同时拦截键盘、手柄与触摸；透明遮罩仍负责阻止 GUI 点击穿透。
	if is_transitioning:
		get_viewport().set_input_as_handled()


## prepare 在完全遮住旧画面、目标实例化成功后调用，必须同步返回 Error。
## hold_seconds 为死亡等既有演出保留时间；等待期间也锁输入，避免延迟跳转竞态。
func change_scene_to_file(path: String, prepare: Callable = Callable(), hold_seconds: float = 0.0, effect: StringName = &"fade", ready_gate: Callable = Callable()) -> Error:
	if is_transitioning:
		return ERR_BUSY
	if not ResourceLoader.exists(path, "PackedScene"):
		return ERR_FILE_NOT_FOUND
	var scene := load(path) as PackedScene
	return change_scene_to_packed(scene, prepare, hold_seconds, effect, ready_gate)


func change_scene_to_packed(scene: PackedScene, prepare: Callable = Callable(), hold_seconds: float = 0.0, effect: StringName = &"fade", ready_gate: Callable = Callable()) -> Error:
	if is_transitioning:
		return ERR_BUSY
	if scene == null or not scene.can_instantiate():
		return ERR_CANT_CREATE
	if not prepare.is_null() and not prepare.is_valid():
		return ERR_INVALID_PARAMETER
	if effect not in [&"fade", &"clay", &"boss", &"chapter"]:
		return ERR_INVALID_PARAMETER
	var source := get_tree().current_scene
	if source == null:
		return ERR_UNCONFIGURED
	_begin(&"scene")
	_effect = effect
	_ready_gate = ready_gate
	if _effect != &"fade":
		var material := _clay_material if _effect == &"clay" else _kiln_material
		_cover.material = material
		_cover.modulate.a = 1.0
		material.set_shader_parameter("progress", 0.0)
		material.set_shader_parameter("revealing", false)
		if _effect != &"clay":
			material.set_shader_parameter("chapter", _effect == &"chapter")
	_change_scene.call_deferred(scene, prepare, maxf(hold_seconds, 0.0), weakref(source))
	return OK


func _change_scene(scene: PackedScene, prepare: Callable, hold_seconds: float, source_ref: WeakRef) -> void:
	# 至少让当前战斗信号发布完，再等待打击/附魔反馈；等待期同样锁输入。
	await get_tree().process_frame
	while not _ready_gate.is_null():
		if not _ready_gate.is_valid() or source_ref.get_ref() != get_tree().current_scene:
			_finish(&"scene", ERR_DOES_NOT_EXIST)
			return
		if _ready_gate.call():
			break
		await get_tree().process_frame
	if hold_seconds > 0.0:
		await get_tree().create_timer(hold_seconds, true, false, true).timeout
	if _effect in SPECIAL_TIMINGS:
		_sound.stream = _boss_sound if _effect == &"boss" else _chapter_sound
		_sound.volume_db = float(AudioManager.config.cues["transition_boss" if _effect == &"boss" else "transition_chapter"].gain_db)
		_sound.play()
	await _fade_cover(1.0, _cover_duration(false))
	# 场景被外部替换时取消陈旧请求，不允许延迟任务把玩家带回旧流程。
	var source = source_ref.get_ref()
	if not is_instance_valid(source) or get_tree().current_scene != source:
		await _scene_failed(ERR_DOES_NOT_EXIST)
		return
	if not _resolver.is_null():
		if not _resolver.is_valid():
			await _scene_failed(ERR_INVALID_PARAMETER)
			return
		var path: String = _resolver.call()
		if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
			await _scene_failed(ERR_FILE_NOT_FOUND)
			return
		scene = load(path) as PackedScene
	var next_scene := scene.instantiate()
	if next_scene == null:
		await _scene_failed(ERR_CANT_CREATE)
		return
	if not prepare.is_null():
		if not prepare.is_valid():
			next_scene.free()
			await _scene_failed(ERR_INVALID_PARAMETER)
			return
		var prepared: int = prepare.call()
		if prepared != OK:
			next_scene.free()
			await _scene_failed(prepared)
			return
	var err := get_tree().change_scene_to_node(next_scene)
	if err != OK:
		next_scene.free()
		await _scene_failed(err)
		return
	# 仅成功切换才解除暂停；失败时保留原场景和暂停菜单。
	get_tree().paused = false
	await get_tree().scene_changed
	# 新版地图是战后结算的路由页：保持全遮盖，直到真正的奖励/局前场景就绪。
	for hop in 4:
		var routed := get_tree().current_scene
		if not routed.has_method("take_transition_destination"):
			break
		var redirect: PackedScene = routed.take_transition_destination()
		if redirect == null:
			break
		err = get_tree().change_scene_to_packed(redirect)
		if err != OK:
			await _scene_failed(err)
			return
		await get_tree().scene_changed
	# 当前各界面在 _ready 同步构建。再等一帧让 Container/延迟布局完成；
	# MapUI 的奖励/失败覆盖界面此时已建立，不会先闪出裸地图。
	await get_tree().process_frame
	scene_revealing.emit(get_tree().current_scene)
	# 奖励卡牌与揭幕并行；只等尚未结束的部分，不追加一整段串行动画。
	var entrance: Tween
	var destination := get_tree().current_scene
	if destination.has_method("play_transition_entrance"):
		entrance = destination.play_transition_entrance()
	await _fade_cover(0.0, _cover_duration(true))
	if entrance != null and entrance.is_valid() and entrance.is_running():
		await entrance.finished
	_finish(&"scene", OK)
	if not is_transitioning and is_instance_valid(destination) and destination.has_method("focus_transition_target"):
		destination.focus_transition_target()


func _scene_failed(error: int) -> void:
	_sound.stop()
	await _fade_cover(0.0, FADE_IN)
	_finish(&"scene", error)
	push_warning("[TransitionManager] 转场取消：%s" % error_string(error))


## 面板需先 setup，再传入本方法；父节点必须已在树中。
func open_panel(parent: Node, panel: Control, duration: float = PANEL_DURATION, distance: float = PANEL_DISTANCE) -> Error:
	if is_transitioning:
		return ERR_BUSY
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return ERR_INVALID_PARAMETER
	if not is_instance_valid(panel) or panel.get_parent() != null or panel.is_queued_for_deletion():
		return ERR_INVALID_PARAMETER
	var alpha := panel.modulate.a
	panel.modulate.a = 0.0
	_begin(&"panel_open")
	parent.add_child(panel)
	panel.show()
	_animate_panel.call_deferred(weakref(panel), alpha, false, Callable(), duration, distance)
	return OK


## 回调只在退场成功后执行一次；回调可以打开下一个面板。
func close_panel(panel: Control, on_closed: Callable = Callable(), duration: float = PANEL_DURATION, distance: float = PANEL_DISTANCE) -> Error:
	if is_transitioning:
		return ERR_BUSY
	if not is_instance_valid(panel) or not panel.is_inside_tree() or panel.is_queued_for_deletion():
		return ERR_INVALID_PARAMETER
	_begin(&"panel_close")
	_animate_panel.call_deferred(weakref(panel), 0.0, true, on_closed, duration, distance)
	return OK


func _animate_panel(panel_ref: WeakRef, alpha: float, closing: bool, on_closed: Callable, duration: float, distance: float) -> void:
	var kind := &"panel_close" if closing else &"panel_open"
	var panel = panel_ref.get_ref()
	if not is_instance_valid(panel) or not panel.is_inside_tree():
		_finish(kind, ERR_DOES_NOT_EXIST)
		return
	# 先完成 Container 布局，只移动内容，避免全屏底板位移后露出一条地图。
	await get_tree().process_frame
	if not is_instance_valid(panel) or not panel.is_inside_tree():
		_finish(kind, ERR_DOES_NOT_EXIST)
		return
	var body: Control = panel
	for child in panel.get_children():
		if child is CenterContainer and not child.is_queued_for_deletion():
			body = child
			break
	var home := body.position
	var from := home if closing else home + Vector2(0, distance)
	var to := home + Vector2(0, distance) if closing else home
	body.position = from
	# Tween 归单例持有；面板意外销毁也能结束并解锁。
	var tween := _new_tween()
	tween.tween_method(_set_panel_alpha.bind(panel_ref), panel.modulate.a, alpha, duration)
	tween.parallel().tween_method(_set_panel_position.bind(weakref(body)), from, to, duration)
	await tween.finished
	if not is_instance_valid(panel) or not panel.is_inside_tree() or panel.is_queued_for_deletion():
		_finish(kind, ERR_DOES_NOT_EXIST)
		return
	if closing:
		panel.hide()
		panel.queue_free()
	_finish(kind, OK)
	if not closing:
		focus_panel(panel)
	if closing and on_closed.is_valid():
		on_closed.call()


func _set_panel_position(position: Vector2, body_ref: WeakRef) -> void:
	var body = body_ref.get_ref()
	if is_instance_valid(body):
		body.position = position


func focus_panel(panel: Control) -> void:
	# 把键盘焦点交给新界面，不能留在被覆盖的地图按钮上。
	for button in panel.find_children("*", "BaseButton", true, false):
		if button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			return


func _set_panel_alpha(alpha: float, panel_ref: WeakRef) -> void:
	var panel = panel_ref.get_ref()
	if is_instance_valid(panel):
		panel.modulate.a = alpha


func _begin(kind: StringName) -> void:
	is_transitioning = true
	_effect = &"fade"
	_resolver = Callable()
	_ready_gate = Callable()
	_cover.material = null
	var focus := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_cover.modulate.a = 0.0
	_cover.show()
	_cover.grab_focus()
	set_process_input(true)
	transition_started.emit(kind)


func _finish(kind: StringName, error: int) -> void:
	_sound.stop()
	_cover.hide()
	_cover.material = null
	_cover.modulate.a = 0.0
	_cover.release_focus()
	set_process_input(false)
	is_transitioning = false
	var focus = _previous_focus.get_ref() if _previous_focus != null else null
	_previous_focus = null
	if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree() and not focus.is_queued_for_deletion():
		focus.grab_focus()
	transition_finished.emit(kind, error)


func _new_tween() -> Tween:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ignore_time_scale(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func _fade_cover(alpha: float, duration: float) -> void:
	var tween := _new_tween()
	if _effect != &"fade":
		var material := _cover.material as ShaderMaterial
		material.set_shader_parameter("revealing", alpha == 0.0)
		tween.tween_method(_set_shader_progress.bind(material), 1.0 - alpha, alpha, duration)
	else:
		tween.tween_property(_cover, "modulate:a", alpha, duration)
	await tween.finished


func _set_shader_progress(progress: float, material: ShaderMaterial) -> void:
	material.set_shader_parameter("progress", progress)


func _cover_duration(revealing: bool) -> float:
	if _effect in SPECIAL_TIMINGS:
		var timing: Vector2 = SPECIAL_TIMINGS[_effect]
		return timing.y if revealing else timing.x
	if _effect == &"clay":
		return CLAY_IN if revealing else CLAY_OUT
	return FADE_IN if revealing else FADE_OUT

## 在全遮盖后选择场景，并同步执行原入口的读档/开局逻辑。
func change_scene_resolved(resolve: Callable) -> Error:
	if not resolve.is_valid():
		return ERR_INVALID_PARAMETER
	var current := get_tree().current_scene
	if current == null:
		return ERR_UNCONFIGURED
	var error := change_scene_to_file(current.scene_file_path)
	if error == OK:
		_resolver = resolve
	return error


## 已存在的内容层入场（例如战利品总览关闭后的选牌区）。
func reveal_content(panel: Control) -> Error:
	if is_transitioning:
		return ERR_BUSY
	if not is_instance_valid(panel) or not panel.is_inside_tree():
		return ERR_INVALID_PARAMETER
	_begin(&"panel_open")
	_reveal_content.call_deferred(weakref(panel))
	return OK


func _reveal_content(panel_ref: WeakRef) -> void:
	var panel = panel_ref.get_ref()
	if not is_instance_valid(panel):
		_finish(&"panel_open", ERR_DOES_NOT_EXIST)
		return
	var tween: Tween = panel.play_transition_entrance()
	if tween != null and tween.is_valid() and tween.is_running():
		await tween.finished
	_finish(&"panel_open", OK)
	if is_instance_valid(panel) and panel.has_method("focus_transition_target"):
		panel.focus_transition_target()
