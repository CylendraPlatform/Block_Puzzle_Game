extends SceneTree
## Validates and replays the 15 authored pilot levels.
##   godot --headless --path . --script res://test/test_v2_pilot.gd

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _initialize() -> void:
	print("== test_v2_pilot ==")
	var paths := PilotCatalog.list_paths()
	_ok(paths.size() == 15, "the pilot has exactly 15 levels")
	var seen := {}
	var narrow := 0
	var wide := 0
	var shaped := 0
	var short_stop := 0
	for index in paths.size():
		var path: String = paths[index]
		var raw := PilotCatalog.read_definition(path)
		var expected_id := "v2-%03d" % (index + 1)
		_ok(str(raw.get("id", "")) == expected_id and not seen.has(expected_id), "level id %s" % expected_id)
		seen[expected_id] = true
		var loaded := LevelLoader.load_definition(raw)
		if not bool(loaded["ok"]):
			_fails += 1
			print("  FAIL  schema ", path)
			continue
		var definition: Dictionary = loaded["definition"]
		for gate in definition["gates"]:
			if int(gate["hi"]) == int(gate["lo"]):
				narrow += 1
			if int(gate["hi"]) > int(gate["lo"]):
				wide += 1
		for piece in definition["pieces"]:
			var cells: Array = piece["cells"]
			if cells.size() >= 3 and not _straight(cells):
				shaped += 1
		var initial := PuzzleState.from_definition(definition)
		var result := SolverV2.solve(definition, initial, 20000)
		if result["status"] != PuzzleEngine.SOLVED:
			_fails += 1
			print("  FAIL  solve ", expected_id, " ", result["status"], " explored ", result["explored_states"])
			continue
		var cursor := initial
		var replay := true
		for action in result["witness"]:
			if action.kind == PuzzleAction.MOVE:
				var farthest := 0
				for candidate in PuzzleEngine.legal_actions(definition, cursor, action.piece_id):
					if candidate.kind == PuzzleAction.MOVE and candidate.direction == action.direction:
						var dist := absi(candidate.landing.x - cursor.pieces[action.piece_id]["pos"].x) + absi(candidate.landing.y - cursor.pieces[action.piece_id]["pos"].y)
						farthest = maxi(farthest, dist)
				var used := absi(action.landing.x - cursor.pieces[action.piece_id]["pos"].x) + absi(action.landing.y - cursor.pieces[action.piece_id]["pos"].y)
				if used < farthest:
					short_stop += 1
			var applied: Dictionary = PuzzleEngine.transition(cursor, action, definition)
			if not bool(applied["ok"]):
				replay = false
				break
			cursor = applied["next_state"]
		var won: bool = replay and PuzzleEngine.is_won(definition, cursor) and cursor.move_number == initial.move_number + result["witness"].size()
		if not won:
			_fails += 1
			print("  FAIL  replay ", expected_id)
		else:
			print("  SOLVED  %s  len %d  explored %d" % [expected_id, result["solution_length"], result["explored_states"]])
	_ok(narrow > 0 and wide > 0, "pilot gates include both one-cell and multi-cell openings")
	_ok(shaped > 0, "pilot pieces include a bent connected shape")
	_ok(short_stop > 0, "at least one solution stops short of the furthest slide")
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

func _straight(cells: Array) -> bool:
	var same_x := true
	var same_y := true
	var x0 = int(cells[0][0])
	var y0 = int(cells[0][1])
	for cell in cells:
		if int(cell[0]) != x0:
			same_x = false
		if int(cell[1]) != y0:
			same_y = false
	return same_x or same_y
