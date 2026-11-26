class_name PilotCatalog
extends RefCounted
## Opt-in v2 pilot files. This list is not the commercial campaign.

const DIR := "res://levels_v2/pilot"
const SAVE_PATH := "user://pilot_v2.save"

static func list_paths() -> Array[String]:
	var out: Array[String] = []
	var folder := DirAccess.open(DIR)
	if folder:
		folder.list_dir_begin()
		var name := folder.get_next()
		while name != "":
			if name.ends_with(".json"):
				out.append(DIR + "/" + name)
			name = folder.get_next()
		folder.list_dir_end()
	out.sort()
	return out

static func read_definition(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func load_index() -> int:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return 0
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var index: Variant = LevelValidator.as_whole_int(parsed.get("index", 0))
	if index == null or int(index) < 0:
		return 0
	return int(index)

static func save_index(index: int) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"index": index}))
