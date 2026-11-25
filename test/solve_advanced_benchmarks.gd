extends SceneTree
## Validates, solver-verifies and witness-replays the ADVANCED benchmark levels
## (counter gate, hidden+blocker, color-switching). These exercise the M1.1 runtime.
##   godot --headless --path . --script res://test/solve_advanced_benchmarks.gd

const CAP := 200000

func _initialize() -> void:
	print("== solve_advanced_benchmarks (cap=%d) ==" % CAP)
	var dir := "res://levels_v2/benchmark_advanced"
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
		if status != PuzzleEngine.SOLVED:
			print("%s  %s  explored=%s  time=%.1fms" % [id, status, str(res["explored_states"]), ms])
			fails += 1
			continue
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
		print("%s  SOLVED  len=%s  explored=%s  cap=%d  time=%.1fms  replay=OK" % [id, str(res["solution_length"]), str(res["explored_states"]), CAP, ms])
	print("== done: %d failure(s) ==" % fails)
	quit(fails)
