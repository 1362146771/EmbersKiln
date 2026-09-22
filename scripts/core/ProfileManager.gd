extends Node
## Autoload: ProfileManager —— 独立永久档案读写。
## Run 结束只由 SaveManager 删除单局存档，不影响本管理器的 profile.json。

const PROFILE_PATH := "user://profile.json"
const PROFILE_VERSION := 9

var is_loaded := false
var autosave_enabled := true
## 测试场可隔离显式保存；正式游戏默认路径不变。
var runtime_profile_path := PROFILE_PATH


func _ready() -> void:
	load_or_create_profile()
	if not SignalBus.profile_changed.is_connected(_on_profile_changed):
		SignalBus.profile_changed.connect(_on_profile_changed)


func _on_profile_changed() -> void:
	if is_loaded and autosave_enabled:
		save_profile()


func load_or_create_profile() -> bool:
	if not FileAccess.file_exists(PROFILE_PATH):
		ProfileState.reset_to_defaults(false)
		if not save_profile():
			return false
		is_loaded = true
		SignalBus.profile_loaded.emit(true)
		return true

	var data := load_from_file(PROFILE_PATH)
	if not data.is_empty() and ProfileState.from_save_dict(data, false):
		if int(data.get("version", -1)) != PROFILE_VERSION and not save_profile():
			push_error("[ProfileManager] 永久档案迁移后保存失败")
			return false
		is_loaded = true
		SignalBus.profile_loaded.emit(false)
		SignalBus.profile_changed.emit()
		SignalBus.fireseed_changed.emit(ProfileState.fireseed_balance)
		return true

	push_error("[ProfileManager] 永久档案无效，已隔离原文件并创建新档案")
	if not quarantine_invalid_file(PROFILE_PATH):
		push_error("[ProfileManager] 无法隔离损坏档案，拒绝覆盖")
		return false
	ProfileState.reset_to_defaults(false)
	if not save_profile():
		return false
	is_loaded = true
	SignalBus.profile_loaded.emit(true)
	return true


func save_profile() -> bool:
	return save_to_file(runtime_profile_path, ProfileState.to_save_dict())


func has_profile() -> bool:
	return FileAccess.file_exists(PROFILE_PATH)


## 通过同目录临时文件与备份替换，避免写入中断直接破坏最后一份有效档案。
func save_to_file(path: String, data: Dictionary) -> bool:
	if int(data.get("version", -1)) != PROFILE_VERSION:
		push_error("[ProfileManager] 拒绝保存版本不匹配的档案")
		return false

	var temp_path := path + ".tmp"
	var backup_path := path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("[ProfileManager] 无法写入临时档案 %s：%d" % [temp_path, FileAccess.get_open_error()])
		return false
	file.store_line(JSON.stringify(data))
	file.flush()
	file.close()

	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		push_error("[ProfileManager] 无法打开档案目录：%s" % path.get_base_dir())
		return false
	var target_name := path.get_file()
	var temp_name := temp_path.get_file()
	var backup_name := backup_path.get_file()
	if dir.file_exists(backup_name):
		dir.remove(backup_name)
	if dir.file_exists(target_name):
		var backup_error := dir.rename(target_name, backup_name)
		if backup_error != OK:
			push_error("[ProfileManager] 无法创建档案备份：%d" % backup_error)
			return false

	var replace_error := dir.rename(temp_name, target_name)
	if replace_error != OK:
		push_error("[ProfileManager] 无法提交永久档案：%d" % replace_error)
		if dir.file_exists(backup_name):
			dir.rename(backup_name, target_name)
		return false
	if dir.file_exists(backup_name):
		dir.remove(backup_name)
	return true


func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[ProfileManager] 无法读取 %s：%d" % [path, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("[ProfileManager] 永久档案 JSON 损坏：%s" % path)
		return {}
	return parsed


func load_profile_from_file(path: String, emit_changed: bool = true) -> bool:
	var data := load_from_file(path)
	return not data.is_empty() and ProfileState.from_save_dict(data, emit_changed)


## 测试与生产共用：保留无效原文件，返回是否成功移动。
func quarantine_invalid_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	var source_name := path.get_file()
	var suffix := str(int(Time.get_unix_time_from_system()))
	var target_name := source_name + ".invalid." + suffix
	var serial := 1
	while dir.file_exists(target_name):
		target_name = source_name + ".invalid." + suffix + "." + str(serial)
		serial += 1
	return dir.rename(source_name, target_name) == OK
