extends SceneTree
## Validate every shipped level: parseable, has blocks+gates, and is solvable.
##   godot --headless --path . --script res://test/validate_all.gd
## Exit code = number of failing levels.

func _initialize() -> void:
	var dir := DirAccess.open("res://levels")
	var files: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".json"):
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()

	var fails := 0
	for name in files:
		var file := FileAccess.open("res://levels/" + name, FileAccess.READ)
		var data: Variant = JSON.parse_string(file.get_as_text())
		if typeof(data) != TYPE_DICTIONARY:
			print("  FAIL ", name, " — not valid JSON")
			fails += 1
			continue
		var lv := Level.from_dict(data)
		var why := ""
		if lv.blocks.is_empty():
			why = "no blocks"
		elif lv.gates.is_empty():
			why = "no gates"
		elif not Rules.solve(lv)["solvable"]:
			why = "UNSOLVABLE"
		if why != "":
			print("  FAIL ", name, " — ", why)
			fails += 1
	print("== validated %d levels, %d failure(s) ==" % [files.size(), fails])
	quit(fails)
