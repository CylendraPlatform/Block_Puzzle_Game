extends SceneTree
## One-time tool: give every level a distinct, themed name.
##   godot --headless --path . --script res://test/name_levels.gd

const ADJ := ["First", "Tight", "Narrow", "Busy", "Quiet", "Twin", "Triple", "Hidden",
	"Open", "Locked", "Swift", "Slow", "Bold", "Clever", "Tricky", "Final",
	"Color", "Corner", "Center", "Side"]
const NOUN := ["Slide", "Shuffle", "Gate", "Path", "Squeeze", "Jam", "Crossing",
	"Exit", "Maze", "Lane", "Shift", "Puzzle", "Escape", "Block", "Route"]

func _name_for(i: int) -> String:
	return "%s %s" % [ADJ[i % ADJ.size()], NOUN[(i / ADJ.size()) % NOUN.size()]]

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

	var i := 0
	var seen := {}
	for name in files:
		var path := "res://levels/" + name
		var fr := FileAccess.open(path, FileAccess.READ)
		var d: Dictionary = JSON.parse_string(fr.get_as_text())
		var nm := _name_for(i)
		d["name"] = nm
		seen[nm] = true
		var fw := FileAccess.open(path, FileAccess.WRITE)
		fw.store_string(JSON.stringify(d, "  "))
		i += 1
	print("named %d levels, %d unique" % [i, seen.size()])
	quit(0)
