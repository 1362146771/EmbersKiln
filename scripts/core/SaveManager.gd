extends Node
## Autoload: SaveManager —— 单局存档读写（P4）。
## 落盘路径 user://save.json；通过 SignalBus 在关键节点自动存档。
## 运行时数据全部来自 RunState，本脚本不持有任何玩法数值。

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 6
const SUPPORTED_SAVE_VERSIONS := [2, 3, 4, 5, 6]

## 测试可临时改写到隔离路径；生产环境始终使用默认 SAVE_PATH。
var runtime_save_path := SAVE_PATH


func _ready() -> void:
	if SignalBus != null:
		# 进入新一层 / 战斗结束：增量自动存档
		SignalBus.floor_entered.connect(_on_floor_entered)
		SignalBus.combat_ended.connect(_on_combat_ended)
		# 幕间推进（非终幕 Boss 胜利 / 开局 act=0）：自动存档（P-C）
		SignalBus.act_changed.connect(_on_act_changed)
		# 单局结束（胜/败）：清档，避免读回已结束的局
		SignalBus.run_ended.connect(_on_run_ended)
	# 拦截窗口关闭，先存档再退出（见 _notification）
	get_tree().auto_accept_quit = false
	_purge_stale_save()
	print("[SaveManager] 已就绪，存档路径 %s" % runtime_save_path)


# ---------- 窗口关闭强存档 ----------
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if RunState != null and RunState.is_active:
			save_game()
		get_tree().quit()


# ---------- 自动存档钩子 ----------
func _on_floor_entered(_floor_index: int, _node_type: StringName) -> void:
	save_game()


func _on_combat_ended(_victory: bool) -> void:
	save_game()


func _on_run_ended(_victory: bool) -> void:
	delete_save()


## 幕间推进（advance_act）自动存档（P-C）。
## 开局 generate_acts 也会发 act_changed(0)，但彼时 RunState.is_active 尚未置 true，
## save_game() 的守卫会跳过，避免 run 未真正开始就落档。
func _on_act_changed(_act_index: int) -> void:
	save_game()


# ---------- 对外 API ----------
func save_game() -> bool:
	if RunState == null or not RunState.is_active:
		return false
	return save_to_file(runtime_save_path)


func load_game() -> bool:
	var d := load_from_file(runtime_save_path)
	if d.is_empty():
		return false
	if not d.has("version") or not SUPPORTED_SAVE_VERSIONS.has(int(d["version"])):
		push_error("[SaveManager] 存档版本不匹配，拒绝加载")
		return false
	if RunState == null:
		return false
	var ok := RunState.from_save_dict(d)
	if ok:
		if int(d.get("version", -1)) != SAVE_VERSION:
			save_game()
		SignalBus.run_loaded.emit()
		print("[SaveManager] 读档成功 — 第 %d 层，HP %d/%d" % [RunState.current_floor, RunState.hp, RunState.max_hp])
	return ok


## 永久城镇档案不算进行中的单局；主菜单只据此选择开始/继续。
func has_active_save() -> bool:
	var data := load_from_file(runtime_save_path)
	return (not data.is_empty()
		and SUPPORTED_SAVE_VERSIONS.has(int(data.get("version", -1)))
		and bool(data.get("is_active", false)))


func has_save() -> bool:
	return FileAccess.file_exists(runtime_save_path)


func delete_save() -> void:
	if has_save():
		var err := _remove_user_file()
		if err != OK:
			push_error("[SaveManager] 删档失败：%d" % err)


## 清理与当前 SAVE_VERSION 不匹配的旧版存档（P-A：v1 单幕存档拒绝并删除）。
func _purge_stale_save() -> void:
	if not has_save():
		return
	var d := load_from_file(runtime_save_path)
	if not d.is_empty() and not SUPPORTED_SAVE_VERSIONS.has(int(d.get("version", -1))):
		push_warning("[SaveManager] 检测到旧版存档(v%d)，按设计拒绝并删除" % int(d.get("version", -1)))
		delete_save()


func _remove_user_file() -> int:
	var da := DirAccess.open(runtime_save_path.get_base_dir())
	if da == null:
		return ERR_CANT_OPEN
	return da.remove(runtime_save_path.get_file())


# ---------- 测试用：任意路径读写 ----------
func save_to_file(path: String) -> bool:
	if RunState == null or not RunState.is_active:
		push_error("[SaveManager] RunState 未激活，无法存档")
		return false
	var data := RunState.to_save_dict()
	var json := JSON.stringify(data)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] 无法写入 %s：%d" % [path, FileAccess.get_open_error()])
		return false
	f.store_line(json)
	f.close()
	return true


## 返回解析后的 Dictionary；失败时返回空 Dictionary（is_empty()==true）。
func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[SaveManager] 无法读取 %s：%d" % [path, FileAccess.get_open_error()])
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SaveManager] 存档解析失败或格式损坏：%s" % path)
		return {}
	return parsed
