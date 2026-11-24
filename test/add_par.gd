extends SceneTree
## One-time tool: add a "par" (shortest solution length) to every level JSON.
##   godot --headless --path . --script res://test/add_par.gd

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

	var done := 0
	for name in files:
		var path := "res://levels/" + name
		var fr := FileAccess.open(path, FileAccess.READ)
		var data: Variant = JSON.parse_string(fr.get_as_text())
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var lv := Level.from_dict(data)
		var par := Rules.solve_min_moves(lv, 80000)
		data["par"] = par
		var fw := FileAccess.open(path, FileAccess.WRITE)
		fw.store_string(JSON.stringify(data, "  "))
		done += 1
	print("added par to %d levels" % done)
	quit(0)
