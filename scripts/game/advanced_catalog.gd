class_name AdvancedCatalog
extends RefCounted
## Advanced-mechanic QA levels under levels_v2/benchmark_advanced (counter gates,
## hidden+blocker, color-switching). Separate from the production campaign; writes no save.

const DIR := "res://levels_v2/benchmark_advanced"

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
