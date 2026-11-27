extends SceneTree
## Positioned-gate proof-of-concept levels (design proposal, not shipped content).
## Reads design/gate_proto/levels/*.json (a .gdignore folder: not imported, not exported, not
## in any campaign or save) and for each level checks:
##   - it loads as a schema-v2 definition with no diagnostics;
##   - SolverV2 solves it and its minimum equals authored_metrics.par;
##   - the authored solution replays through PuzzleEngine.transition and wins in par moves;
##   - every gate is binding: widening that gate to its full edge makes the minimum shorter,
##     and widening all gates does too (gate position, not decoration, sets the puzzle);
##   - PuzzleMetrics agrees on the minimum; every gate is reachable; the optimal-sequence count
##     is complete; in multi-piece levels the pieces are proven to depend on each other and to
##     interact; no block can exit on move 1;
##   - gate grammar (spec section 3): 1-3 cells, one colour per gate, one gate per colour, no
##     overlap on an edge, no two gates sharing a corner, and every required block fits through
##     a gate of its colour.
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
	_policy_self_test()
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
	print("     optimal sequences: %d (complete %s), dependency_proven %s, genuine_multi_piece %s, branching %s" % [m["shortest_path_count"], m["shortest_path_count_complete"], m["dependency_proven"], m["genuine_multi_piece"], m["branching"]])
	_ok(int(m["solution_length"]) == par, "%s PuzzleMetrics agrees on the minimum" % file)
	_ok((m["unreachable_gates"] as Array).is_empty(), "%s every gate reachable (unreachable: %s)" % [file, m["unreachable_gates"]])
	_ok(bool(m["shortest_path_count_complete"]), "%s optimal-sequence count is complete (%d)" % [file, m["shortest_path_count"]])
	if _required_count(defn) > 1:
		_ok(bool(m["dependency_proven"]), "%s pieces proven to depend on each other" % file)
		_ok(bool(m["genuine_multi_piece"]), "%s genuine multi-piece interaction" % file)
	var first_exit := false
	for a in PuzzleEngine.legal_actions(defn, start):
		first_exit = first_exit or (a as PuzzleAction).kind == PuzzleAction.EXIT
	_ok(not first_exit, "%s no block can exit on move 1" % file)
	_policy(defn, file)
	var all_wide := _widened(defn, -1)
	var wide_min := int(SolverV2.solve(all_wide, PuzzleState.from_definition(all_wide), 500000)["solution_length"])
	_ok(wide_min >= 0 and wide_min < par, "%s all gates full-edge: minimum %d < %d (positions matter)" % [file, wide_min, par])
	for i in (defn["gates"] as Array).size():
		var one := _widened(defn, i)
		var one_min := int(SolverV2.solve(one, PuzzleState.from_definition(one), 500000)["solution_length"])
		_ok(one_min >= 0 and one_min < par, "%s gate %s full-edge alone: minimum %d < %d (gate is binding)" % [file, defn["gates"][i]["id"], one_min, par])

## New-campaign gate grammar (GAME_DESIGN_SPEC.md section 3) and a usable gate per block.
func _policy(defn: Dictionary, file: String) -> void:
	var cols := int(defn["board"]["cols"])
	var rows := int(defn["board"]["rows"])
	var gates: Array = defn["gates"]
	var colors := {}
	for g in gates:
		var span := int(g["hi"]) - int(g["lo"]) + 1
		_ok(span >= 1 and span <= 3, "%s gate %s is 1-3 cells wide (%d)" % [file, g["id"], span])
		_ok((g["accept"] as Array).size() == 1, "%s gate %s accepts exactly one colour" % [file, g["id"]])
		colors[str(g["accept"][0])] = int(colors.get(str(g["accept"][0]), 0)) + 1
	for c in colors.keys():
		_ok(int(colors[c]) == 1, "%s one gate for %s (%d)" % [file, c, colors[c]])
	for i in gates.size():
		for j in range(i + 1, gates.size()):
			var a: Dictionary = gates[i]
			var b: Dictionary = gates[j]
			if a["side"] == b["side"]:
				_ok(int(a["hi"]) < int(b["lo"]) or int(b["hi"]) < int(a["lo"]), "%s gates %s and %s do not overlap" % [file, a["id"], b["id"]])
	var corner := {}
	for g in gates:
		for cell in _corner_cells(g, cols, rows):
			_ok(not corner.has(cell), "%s gate %s does not meet %s at corner %s" % [file, g["id"], corner.get(cell, ""), cell])
			corner[cell] = g["id"]
	for p in defn["pieces"]:
		if not bool(p.get("required", true)):
			continue
		var size := _extent(p["cells"])
		var usable := false
		for g in gates:
			if not (g["accept"] as Array).has(p["color"]):
				continue
			var need := size.y if str(g["side"]) in ["left", "right"] else size.x
			usable = usable or need <= int(g["hi"]) - int(g["lo"]) + 1
		_ok(usable, "%s piece %s (%dx%d) fits through a gate of its colour" % [file, p["id"], size.x, size.y])

## The grammar checks must reject a level that breaks them: a 4-cell gate, a second red gate
## overlapping the first, a 1-cell blue gate sharing the bottom-right corner with it, and a 2x2
## blue square too big for that gate. Expected: 5 violations, counted then discarded.
func _policy_self_test() -> void:
	var bad := {
		"board": {"cols": 5, "rows": 5},
		"pieces": [
			{"id": "tall", "color": "red", "cells": [[0, 0], [0, 1], [0, 2], [0, 3]], "required": true},
			{"id": "square", "color": "blue", "cells": [[0, 0], [1, 0], [0, 1], [1, 1]], "required": true},
		],
		"gates": [
			{"id": "wide", "side": "bottom", "lo": 1, "hi": 4, "accept": ["red"]},
			{"id": "twin", "side": "bottom", "lo": 0, "hi": 1, "accept": ["red"]},
			{"id": "corner", "side": "right", "lo": 4, "hi": 4, "accept": ["blue"]},
		],
	}
	var before := _fails
	print("-- grammar self-test (FAIL lines below are expected)")
	_policy(bad, "self-test")
	var caught := _fails - before
	_fails = before
	# wide > 3 cells; red has 2 gates; wide / twin overlap; wide / corner share (4,4); the
	# square (2 tall) cannot pass the 1-cell blue gate. The tall red bar fits (1 wide at the bottom).
	_ok(caught == 5, "grammar checks catch the 5 planted violations (%d)" % caught)

## Board corners a gate's span touches, as "x,y".
func _corner_cells(g: Dictionary, cols: int, rows: int) -> Array:
	var out: Array = []
	var side := str(g["side"])
	var lo := int(g["lo"])
	var hi := int(g["hi"])
	var last := (rows if side in ["left", "right"] else cols) - 1
	var x_fixed := {"left": 0, "right": cols - 1}
	var y_fixed := {"top": 0, "bottom": rows - 1}
	for t in [0, last]:
		if lo <= t and t <= hi:
			out.append("%d,%d" % ([x_fixed[side], t] if side in ["left", "right"] else [t, y_fixed[side]]))
	return out

func _extent(cells: Array) -> Vector2i:
	var mx := 0
	var my := 0
	for c in cells:
		mx = maxi(mx, int(c[0]))
		my = maxi(my, int(c[1]))
	return Vector2i(mx + 1, my + 1)

func _required_count(defn: Dictionary) -> int:
	var n := 0
	for p in defn["pieces"]:
		n += int(bool(p.get("required", true)))
	return n

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
