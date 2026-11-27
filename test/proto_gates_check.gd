extends SceneTree
## Positioned-gate proof-of-concept levels (design proposal, not shipped content).
## Reads design/gate_proto/levels/*.json (a .gdignore folder: not imported, not exported, not
## in any campaign or save) and for each level checks:
##   - it loads as a schema-v2 definition with no diagnostics;
##   - SolverV2 solves it and its minimum equals authored_metrics.par;
##   - the authored solution replays through PuzzleEngine.transition and wins in par moves;
##   - every gate is binding: widening that gate to its full edge makes the minimum shorter,
##     and widening all gates does too (gate position, not decoration, sets the puzzle);
##   - PuzzleMetrics agrees on the minimum, finds no unreachable gate, and reports the number of
##     optimal move sequences and whether the pieces genuinely depend on each other.
## Exit code = number of failures.
##   godot --headless --path . --script res://test/proto_gates_check.gd

const DIR := "res://design/gate_proto/levels/"

var _fails := 0

func _ok(c: bool, m: String) -> void:
	print("  %s  %s" % ["PASS" if c else "FAIL", m])
	if not c:
		_fails += 1

func _initialize() -> void:
	print("== proto_gates_check ==")
	var files := DirAccess.get_files_at(DIR)
	files.sort()
	var count := 0
	for f in files:
		if f.ends_with(".json"):
			count += 1
			_check(f)
	_ok(count == 3, "three prototype levels found (%d)" % count)
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

func _check(file: String) -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + file))
	var loaded := LevelLoader.load_definition(raw if raw is Dictionary else {})
	print("-- %s" % file)
	_ok(bool(loaded["ok"]) and str(loaded["source"]) == "v2", "%s loads as schema v2 (%s)" % [file, loaded.get("diagnostics", [])])
	if not bool(loaded["ok"]):
		return
	var defn: Dictionary = loaded["definition"]
	var metrics: Dictionary = defn.get("authored_metrics", {})
	var par := int(metrics.get("par", -1))
	var start := PuzzleState.from_definition(defn)
	var solved := SolverV2.solve(defn, start, 500000)
	_ok(str(solved["status"]) == PuzzleEngine.SOLVED, "%s solved (%s, %d states)" % [file, solved["status"], solved["explored_states"]])
	var minimum := int(solved["solution_length"])
	_ok(minimum == par, "%s SolverV2 minimum %d == authored par %d" % [file, minimum, par])
	print("     solver witness: %s" % ", ".join(_texts(solved["witness"])))
	_ok(_replay(defn, metrics.get("solution", [])) == par, "%s authored solution replays and wins in %d moves" % [file, par])
	var m := PuzzleMetrics.evaluate(defn, 500000)
	print("     optimal sequences: %d (complete %s), dependency_proven %s, genuine_multi_piece %s, unreachable gates %s" % [m["shortest_path_count"], m["shortest_path_count_complete"], m["dependency_proven"], m["genuine_multi_piece"], m["unreachable_gates"]])
	_ok(int(m["solution_length"]) == par and (m["unreachable_gates"] as Array).is_empty(), "%s PuzzleMetrics agrees on the minimum; every gate reachable" % file)
	var all_wide := _widened(defn, -1)
	var wide_min := int(SolverV2.solve(all_wide, PuzzleState.from_definition(all_wide), 500000)["solution_length"])
	_ok(wide_min >= 0 and wide_min < par, "%s all gates full-edge: minimum %d < %d (positions matter)" % [file, wide_min, par])
	for i in (defn["gates"] as Array).size():
		var one := _widened(defn, i)
		var one_min := int(SolverV2.solve(one, PuzzleState.from_definition(one), 500000)["solution_length"])
		_ok(one_min >= 0 and one_min < par, "%s gate %s full-edge alone: minimum %d < %d (gate is binding)" % [file, defn["gates"][i]["id"], one_min, par])

## A copy with gate `index` (or every gate, index -1) widened to its whole edge.
func _widened(defn: Dictionary, index: int) -> Dictionary:
	var copy: Dictionary = defn.duplicate(true)
	var cols := int(copy["board"]["cols"])
	var rows := int(copy["board"]["rows"])
	for i in (copy["gates"] as Array).size():
		if index >= 0 and i != index:
			continue
		var gate: Dictionary = copy["gates"][i]
		var side := str(gate["side"])
		gate["lo"] = 0
		gate["hi"] = (rows if side == "left" or side == "right" else cols) - 1
	return copy

## Replays [[piece, "exit"] | [piece, dir, [x, y]]] and returns the winning length, or -1.
func _replay(defn: Dictionary, solution: Array) -> int:
	var state := PuzzleState.from_definition(defn)
	for step in solution:
		var match_action: PuzzleAction = null
		for action in PuzzleEngine.legal_actions(defn, state, str(step[0])):
			var a := action as PuzzleAction
			if str(step[1]) == "exit" and a.kind == PuzzleAction.EXIT:
				match_action = a
			elif str(step[1]) != "exit" and a.kind == PuzzleAction.MOVE and a.direction == str(step[1]) and a.landing == Vector2i(int(step[2][0]), int(step[2][1])):
				match_action = a
		if match_action == null:
			print("     replay: no legal action for %s" % [step])
			return -1
		state = PuzzleEngine.transition(state, match_action, defn)["next_state"]
	return solution.size() if PuzzleEngine.is_won(defn, state) else -1

func _texts(witness: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for a in witness:
		var action := a as PuzzleAction
		out.append("%s exit %s" % [action.piece_id, action.gate_id] if action.kind == PuzzleAction.EXIT else "%s %s->%s" % [action.piece_id, action.direction, action.landing])
	return out
