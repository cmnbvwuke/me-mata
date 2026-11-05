extends Node
## Saves JSON versionados em user://saves/.

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves/"


func save(slot: int) -> Error:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var data := GameState.to_dict()
	data["save_version"] = SAVE_VERSION
	f.store_string(JSON.stringify(data, "\t"))
	return OK


func load_slot(slot: int) -> bool:
	if not FileAccess.file_exists(_path(slot)):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	GameState.from_dict(parsed)
	return true


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(_path(slot))


func _path(slot: int) -> String:
	return "%sslot_%d.json" % [SAVE_DIR, slot]
