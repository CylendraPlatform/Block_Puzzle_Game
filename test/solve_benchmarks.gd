extends SceneTree
## Validates, solver-verifies, and witness-replays the original benchmark levels.
##   godot --headless --path . --script res://test/solve_benchmarks.gd
## Reports: status, shortest length, explored states, search cap, time, shape variety.
## UNKNOWN_CAP_REACHED is reported as a recorded limitation, never as unsolvable.

const CAP := 200000

func _initialize() -> void:
	print("== solve_benchmarks (cap=%d) ==" % CAP)
	var dir := "res://levels_v2/benchmark"
	var folder := DirAccess.open(dir)
	var paths: Array = []
	if folder:
		folder.list_dir_begin()
		var n := folder.get_next()
		while n != "":
			if n.ends_with(".json"):
				paths.append(dir + "/" + n)
			n = folder.get_next()
		folder.list_dir_end()
	paths.sort()
	var fails := 0
	for p in paths:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if typeof(raw) != TYPE_DICTIONARY:
			print("PARSE-FAIL ", p)
			fails += 1
			continue
		var loaded: Dictionary = LevelLoader.load_definition(raw)
		if not bool(loaded["ok"]):
			print("SCHEMA-FAIL ", p, "  ", loaded.get("diagnostics", loaded))
			fails += 1
			continue
		var defn: Dictionary = loaded["definition"]
		var initial := PuzzleState.from_definition(defn)
		var t0 := Time.get_ticks_usec()
		var res: Dictionary = SolverV2.solve(defn, initial, CAP)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		var id := str(raw.get("id", ""))
		var status := str(res["status"])
		var variety := _variety(defn)
		if status == PuzzleEngine.UNKNOWN_CAP_REACHED:
			print("%s  LIMIT  UNKNOWN_CAP_REACHED at cap %d (NOT unsolvable)  explored=%s  time=%.1fms  %s" % [id, CAP, str(res["explored_states"]), ms, variety])
			fails += 1
			continue
		if status != PuzzleEngine.SOLVED:
			print("%s  %s  explored=%s  time=%.1fms  %s" % [id, status, str(res["explored_states"]), ms, variety])
			fails += 1
			continue
		# Explicit witness replay (independent of SolverV2's internal check).
		var cursor := initial
		var replay_ok := true
		for action in res["witness"]:
			var applied: Dictionary = PuzzleEngine.transition(cursor, action, defn)
			if not bool(applied["ok"]):
				replay_ok = false
				break
			cursor = applied["next_state"]
		var won: bool = replay_ok and PuzzleEngine.is_won(defn, cursor) and cursor.move_number == initial.move_number + res["witness"].size()
		if not won:
			print("%s  REPLAY-FAIL  len=%s" % [id, str(res["solution_length"])])
			fails += 1
			continue
		var explored := maxi(1, int(res["explored_states"]))
		var us_per_state := float(Time.get_ticks_usec() - t0) / float(explored)
		var legal_ms := float(SolverV2.profile_legal_us) / 1000.0
		var transition_ms := float(SolverV2.profile_transition_us) / 1000.0
		print("%s  SOLVED  len=%s  explored=%s  cap=%d  time=%.1fms  (%.0f us/state; legal=%.0fms transition=%.0fms)  replay=OK  %s" % [id, str(res["solution_length"]), str(res["explored_states"]), CAP, ms, us_per_state, legal_ms, transition_ms, variety])
	print("== done: %d failure(s) ==" % fails)
	quit(fails)

func _variety(defn: Dictionary) -> String:
	var colors := {}
	var shapes := {}
	for piece in defn.get("pieces", []):
		colors[str(piece.get("color", ""))] = true
		var cells: Array = piece.get("cells", [])
		shapes[_shape_name(cells)] = int(shapes.get(_shape_name(cells), 0)) + 1
	var parts: Array = []
	var names: Array = shapes.keys()
	names.sort()
	for s in names:
		parts.append("%s×%d" % [s, int(shapes[s])])
	return "pieces=%d colors=%d shapes=[%s]" % [defn.get("pieces", []).size(), colors.size(), ", ".join(parts)]

func _shape_name(cells: Array) -> String:
	var k := cells.size()
	if k == 1:
		return "single"
	var same_x := true
	var same_y := true
	var x0 := int(cells[0][0])
	var y0 := int(cells[0][1])
	for c in cells:
		if int(c[0]) != x0:
			same_x = false
		if int(c[1]) != y0:
			same_y = false
	var straight := same_x or same_y
	if k == 2:
		return "domino"
	if k == 3:
		return "I-tromino" if straight else "L-tromino"
	return ("I-%d" % k) if straight else ("poly-%d" % k)
