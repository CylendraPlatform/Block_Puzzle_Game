extends SceneTree
## TD-2 solver tests. Hand-authored boards are schema fixtures, not campaign levels.
## The reference search below does not call PuzzleEngine or SolverV2.
##   godot --headless --path . --script res://test/test_v2_solver.gd

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _initialize() -> void:
	print("== test_v2_solver ==")
	_movement()
	_rejections()
	_search()
	_integrity()
	_legacy_sample()
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

func _movement() -> void:
	var stop := _stop_short()
	var stop_state := PuzzleState.from_definition(stop)
	var actions := PuzzleEngine.legal_actions(stop, stop_state, "red")
	var texts: Array = []
	for action in actions:
		texts.append(action.canonical_text())
	_ok(texts.has("move red right 2,0"), "intermediate landing is enumerated")
	_ok(texts.has("move red right 4,0"), "maximum landing is also enumerated")
	var solved: Dictionary = SolverV2.solve(stop, stop_state, 1000)
	_ok(solved["status"] == PuzzleEngine.SOLVED and int(solved["solution_length"]) == _ref_length(stop), "stop-short length matches the independent reference")
	_ok(int(solved["solution_length"]) == 2, "stop-short solution is two committed moves")
	_ok(_max_only_length(stop) < 0, "maximum slides alone cannot solve the stop-short board")
	_ok(_replay_wins(stop, stop_state, solved["witness"]), "stop-short witness replays to a win")
	var tunnel := _level(4, 2, [[2, 0]], [
		_piece("l", "red", [[0, 0], [1, 0], [0, 1]], [0, 0], true),
	], [_gate("out", "right", 0, 1, "red")])
	_ok(not _has_dir(PuzzleEngine.legal_actions(tunnel, PuzzleState.from_definition(tunnel)), "right"), "an L does not tunnel through one blocked cell")
	var ess := _level(3, 4, [[1, 0]], [
		_piece("s", "blue", [[0, 0], [1, 0], [1, 1], [2, 1]], [0, 1], true),
	], [_gate("out", "top", 0, 2, "blue")])
	_ok(not _has_dir(PuzzleEngine.legal_actions(ess, PuzzleState.from_definition(ess)), "up"), "an S does not tunnel through one blocked cell")
	var tee := _level(3, 3, [[1, 2]], [
		_piece("t", "green", [[0, 0], [1, 0], [2, 0], [1, 1]], [0, 0], true),
	], [_gate("out", "bottom", 0, 2, "green")])
	_ok(not _has_dir(PuzzleEngine.legal_actions(tee, PuzzleState.from_definition(tee)), "down"), "a T does not tunnel through one blocked cell")
	var narrow := _level(3, 2, [], [
		_piece("v", "red", [[0, 0], [0, 1]], [2, 0], true),
	], [_gate("thin", "right", 0, 0, "red")])
	_ok(not _has_exit(PuzzleEngine.legal_actions(narrow, PuzzleState.from_definition(narrow))), "a partial gate projection does not accept the piece")
	var wide := _level(3, 2, [], [
		_piece("v", "red", [[0, 0], [0, 1]], [2, 0], true),
	], [_gate("wide", "right", 0, 1, "red")])
	_ok(_has_exit(PuzzleEngine.legal_actions(wide, PuzzleState.from_definition(wide))), "a gate that covers the whole projection accepts the piece")
	var one := _level(3, 1, [], [_piece("a", "red", [[0, 0]], [0, 0], true)], [_gate("cell", "right", 0, 0, "red")])
	var one_state := PuzzleState.from_definition(one)
	var exited: Dictionary = PuzzleEngine.transition(one_state, PuzzleAction.exit_through("a", "cell"), one)
	_ok(bool(exited["ok"]) and exited["events"].size() == 2, "an interior exit emits move then exit")
	_ok(exited["events"][0].type == PuzzleEvent.PIECE_MOVED and exited["events"][1].type == PuzzleEvent.PIECE_EXITED, "exit events stay in that order")
	_ok(exited["next_state"].move_number == 1 and not bool(exited["next_state"].pieces["a"]["active"]), "an exit charges one move and retires the piece")
	_ok(one_state.move_number == 0 and bool(one_state.pieces["a"]["active"]), "a successful exit does not mutate the input")
	var wrong := _level(2, 1, [], [_piece("a", "red", [[0, 0]], [1, 0], true)], [_gate("no", "right", 0, 0, "blue")])
	_ok(not _has_exit(PuzzleEngine.legal_actions(wrong, PuzzleState.from_definition(wrong))), "the wrong color cannot use a gate")
	var shared := _level(2, 1, [], [_piece("a", "red", [[0, 0]], [1, 0], true)], [
		_gate("red_gate", "right", 0, 0, "red"),
		_gate("blue_gate", "right", 0, 0, "blue"),
	])
	var shared_actions := PuzzleEngine.legal_actions(shared, PuzzleState.from_definition(shared))
	_ok(_exit_gate(shared_actions) == "red_gate", "overlapping different-color gates select the matching gate")
	var blocked := _level(3, 1, [[1, 0]], [_piece("a", "red", [[0, 0]], [0, 0], true)], [_gate("out", "right", 0, 0, "red")])
	_ok(not _has_exit(PuzzleEngine.legal_actions(blocked, PuzzleState.from_definition(blocked))), "a blocked straight path cannot exit")

func _rejections() -> void:
	var level := _level(3, 1, [], [_piece("a", "red", [[0, 0]], [0, 0], true)], [_gate("out", "right", 0, 0, "red")])
	var state := PuzzleState.from_definition(level)
	var before := state.canonical_text()
	var forged: Dictionary = PuzzleEngine.transition(state, PuzzleAction.move("a", "right", Vector2i(0, 1)), level)
	_ok(forged["error"]["code"] == "ILLEGAL_ACTION" and forged["events"].is_empty(), "a teleported landing is rejected")
	var diagonal: Dictionary = PuzzleEngine.transition(state, PuzzleAction.move("a", "up-right", Vector2i(1, 0)), level)
	_ok(diagonal["error"]["code"] == "ILLEGAL_ACTION", "a diagonal direction is rejected")
	var noop: Dictionary = PuzzleEngine.transition(state, PuzzleAction.move("a", "right", Vector2i(0, 0)), level)
	_ok(noop["error"]["code"] == "ILLEGAL_ACTION", "a no-op landing is rejected")
	var bad_gate: Dictionary = PuzzleEngine.transition(state, PuzzleAction.exit_through("a", "missing"), level)
	_ok(bad_gate["error"]["code"] == "ILLEGAL_ACTION", "an unknown gate id is rejected")
	_ok(state.canonical_text() == before, "rejected actions do not leak state changes")
	state.pieces["a"]["active"] = false
	var inactive: Dictionary = PuzzleEngine.transition(state, PuzzleAction.move("a", "right", Vector2i(1, 0)), level)
	_ok(inactive["error"]["code"] == "ILLEGAL_ACTION", "an inactive piece cannot move")
	var mismatch := PuzzleState.from_definition(level)
	mismatch.pieces.erase("a")
	var broken: Dictionary = PuzzleEngine.transition(mismatch, PuzzleAction.exit_through("a", "out"), level)
	_ok(broken["error"]["code"] == "UNKNOWN_PIECE" or broken["error"]["code"] == "STATE_MISMATCH", "a missing piece does not move")
	var locked := _level(2, 1, [], [_piece("a", "red", [[0, 0]], [1, 0], true)], [_gate("locked", "right", 0, 0, "red")])
	locked["gates"][0]["initial_state"] = "locked"
	var locked_result: Dictionary = PuzzleEngine.transition(PuzzleState.from_definition(locked), PuzzleAction.exit_through("a", "locked"), locked)
	_ok(locked_result["error"]["code"] == "UNSUPPORTED_FEATURE" and locked_result["next_state"] == null, "a locked gate stays fail-closed")
	var hidden := _level(2, 1, [], [_piece("a", "red", [[0, 0]], [0, 0], true)], [_gate("out", "right", 0, 0, "red")])
	hidden["pieces"][0]["reveal"] = "hidden"
	var hidden_solve: Dictionary = SolverV2.solve(hidden, PuzzleState.from_definition(hidden), 20)
	_ok(hidden_solve["status"] == PuzzleEngine.INVALID_LEVEL and LevelValidator.has_code(hidden_solve["diagnostics"], "UNSUPPORTED_FEATURE"), "hidden pieces are not reported as solved")

func _search() -> void:
	var twin := _level(1, 3, [], [
		_piece("a", "red", [[0, 0]], [0, 0], true),
		_piece("b", "blue", [[0, 0]], [0, 2], true),
	], [_gate("top", "top", 0, 0, "red"), _gate("bottom", "bottom", 0, 0, "blue")])
	var twin_solved: Dictionary = SolverV2.solve(twin, PuzzleState.from_definition(twin), 50)
	_ok(twin_solved["status"] == PuzzleEngine.SOLVED and int(twin_solved["solution_length"]) == 2, "two direct exits take two moves")
	_ok(twin_solved["witness"][0].piece_id == "a", "equal-length solutions follow piece id order")
	_ok(int(twin_solved["solution_length"]) == _ref_length(twin), "two-exit length matches the independent reference")
	var twin_again: Dictionary = SolverV2.solve(twin, PuzzleState.from_definition(twin), 50)
	var same_path := true
	if twin_again["witness"].size() != twin_solved["witness"].size():
		same_path = false
	else:
		for index in twin_solved["witness"].size():
			if twin_solved["witness"][index].canonical_text() != twin_again["witness"][index].canonical_text():
				same_path = false
	_ok(same_path, "the same board returns the same witness on a second run")
	var optional := _level(2, 1, [], [
		_piece("parked", "blue", [[0, 0]], [0, 0], false),
		_piece("a", "red", [[0, 0]], [1, 0], true),
	], [_gate("out", "right", 0, 0, "red")])
	var optional_solved: Dictionary = SolverV2.solve(optional, PuzzleState.from_definition(optional), 20)
	_ok(optional_solved["status"] == PuzzleEngine.SOLVED and int(optional_solved["solution_length"]) == 1, "an optional piece does not have to exit")
	var dead := _level(2, 1, [], [_piece("a", "red", [[0, 0]], [0, 0], true)], [_gate("no", "right", 0, 0, "blue")])
	var dead_solved: Dictionary = SolverV2.solve(dead, PuzzleState.from_definition(dead), 20)
	_ok(dead_solved["status"] == PuzzleEngine.UNSOLVABLE and _ref_length(dead) < 0, "exhaustive failure is UNSOLVABLE")
	var capped: Dictionary = SolverV2.solve(dead, PuzzleState.from_definition(dead), 0)
	_ok(capped["status"] == PuzzleEngine.UNKNOWN_CAP_REACHED and int(capped["explored_states"]) == 0, "a zero cap does not claim unsolvable")
	var row := _level(4, 1, [], [_piece("a", "red", [[0, 0]], [0, 0], true)], [])
	var row_solved: Dictionary = SolverV2.solve(row, PuzzleState.from_definition(row), 100)
	_ok(row_solved["status"] == PuzzleEngine.UNSOLVABLE and int(row_solved["explored_states"]) == 4, "search ignores move count on a reversible row")
	var again := PuzzleState.from_definition(row)
	again.move_number = 7
	_ok(again.search_key() == PuzzleState.from_definition(row).search_key() and again.canonical_hash() != PuzzleState.from_definition(row).canonical_hash(), "search key excludes move number while the snapshot hash keeps it")
	var stop := _stop_short()
	var full: Dictionary = SolverV2.solve(stop, PuzzleState.from_definition(stop), 1000)
	var tight: Dictionary = SolverV2.solve(stop, PuzzleState.from_definition(stop), int(full["explored_states"]) - 1)
	_ok(tight["status"] == PuzzleEngine.UNKNOWN_CAP_REACHED, "one expansion under the solution budget is a cap, not a proof")
	var won := PuzzleState.from_definition(dead)
	won.pieces["a"]["active"] = false
	var already: Dictionary = SolverV2.solve(dead, won, 0)
	_ok(already["status"] == PuzzleEngine.SOLVED and int(already["solution_length"]) == 0, "an already-won state needs no search")
	var invalid: Dictionary = SolverV2.solve({"schema_version": 2, "id": "x"}, PuzzleState.new(), 10)
	_ok(invalid["status"] == PuzzleEngine.INVALID_LEVEL and invalid["witness"].is_empty(), "an invalid definition is not solved")

func _integrity() -> void:
	var level := _level(3, 2, [[0, 0]], [
		_piece("a", "red", [[0, 0]], [1, 0], true),
		_piece("b", "blue", [[0, 0]], [2, 1], true),
	], [_gate("out", "right", 0, 1, "red")])
	var cleared := PuzzleState.from_definition(level)
	cleared.pieces["a"]["active"] = false
	cleared.pieces["b"]["active"] = false
	var good: Dictionary = SolverV2.solve(level, cleared, 0)
	_ok(good["status"] == PuzzleEngine.SOLVED and int(good["solution_length"]) == 0, "a consistent cleared board is solved without search")
	var wrong_level := cleared.duplicate()
	wrong_level.level_id = "forged"
	_expect_rejected(level, wrong_level, "a forged level id is not a solved puzzle")
	var on_wall := cleared.duplicate()
	on_wall.pieces["a"]["pos"] = Vector2i(0, 0)
	_expect_rejected(level, on_wall, "an inactive piece on a wall is not a solved puzzle")
	var outside := PuzzleState.from_definition(level)
	outside.pieces["a"]["pos"] = Vector2i(-1, 0)
	_expect_rejected(level, outside, "an out-of-bounds piece is not searchable")
	var overlap := PuzzleState.from_definition(level)
	overlap.pieces["b"]["pos"] = Vector2i(1, 0)
	var overlap_before := overlap.canonical_text()
	var overlap_move: Dictionary = PuzzleEngine.transition(overlap, PuzzleAction.move("a", "right", Vector2i(2, 0)), level)
	_ok(overlap_move["error"]["code"] == "STATE_MISMATCH" and overlap_move["events"].is_empty() and overlap_move["next_state"] == null, "overlapping pieces are rejected")
	_ok(overlap.canonical_text() == overlap_before, "an overlap rejection does not mutate the input")
	var extra := cleared.duplicate()
	extra.pieces["ghost"] = {"pos": Vector2i(1, 1), "active": false, "revealed": true}
	_expect_rejected(level, extra, "an unexpected piece entry is not a solved puzzle")
	var missing_gate := cleared.duplicate()
	missing_gate.gates.erase("out")
	_expect_rejected(level, missing_gate, "a missing gate entry is not a solved puzzle")
	var extra_gate := cleared.duplicate()
	extra_gate.gates["extra"] = {"mode": "OPEN", "counter_remaining": -1}
	_expect_rejected(level, extra_gate, "an unexpected gate entry is not a solved puzzle")
	var shut := cleared.duplicate()
	shut.gates["out"]["mode"] = "SHUT"
	_expect_rejected(level, shut, "a gate mode that disagrees with the definition is not a solved puzzle")
	var counted := cleared.duplicate()
	counted.gates["out"]["counter_remaining"] = 2
	_expect_rejected(level, counted, "an unexpected gate counter is not a solved puzzle")
	var blocker := cleared.duplicate()
	blocker.blockers["stone"] = {"active": true, "counter_remaining": -1}
	_expect_rejected(level, blocker, "an unexpected blocker entry is not a solved puzzle")
	var counter := cleared.duplicate()
	counter.event_counters["mystery"] = 1
	_expect_rejected(level, counter, "an unexpected event counter is not a solved puzzle")
	var negative := cleared.duplicate()
	negative.move_number = -1
	_expect_rejected(level, negative, "a negative move count is not a solved puzzle")
	var old_schema := cleared.duplicate()
	old_schema.schema_version = 1
	_expect_rejected(level, old_schema, "the wrong state schema is not a solved puzzle")
	var bad_pos := PuzzleState.from_definition(level)
	bad_pos.pieces["a"]["pos"] = "1,0"
	var bad_active: bool = bad_pos.pieces["a"]["active"]
	var bad_result: Dictionary = SolverV2.solve(level, bad_pos, 0)
	_ok(bad_result["status"] == PuzzleEngine.INVALID_LEVEL and LevelValidator.has_code(bad_result["diagnostics"], "STATE_MISMATCH"), "a non-vector position is not a solved puzzle")
	_ok(bad_pos.pieces["a"]["active"] == bad_active and bad_pos.move_number == 0, "a position rejection does not mutate the input")
	var stop := _stop_short()
	SolverV2.solve(stop, PuzzleState.from_definition(stop), 20)
	var dirty := stop.duplicate()
	dirty["notes"] = "forged"
	var leaked: Dictionary = PuzzleEngine.transition(PuzzleState.from_definition(stop), PuzzleAction.move("red", "right", Vector2i(1, 0)), dirty)
	_ok(leaked["ok"] == false and leaked["error"]["code"] == "INVALID_LEVEL", "a search does not leave schema validation disabled")

func _expect_rejected(definition: Dictionary, state: PuzzleState, label: String) -> void:
	var before := state.canonical_text()
	var result: Dictionary = SolverV2.solve(definition, state, 0)
	_ok(result["status"] == PuzzleEngine.INVALID_LEVEL and result["status"] != PuzzleEngine.SOLVED and LevelValidator.has_code(result["diagnostics"], "STATE_MISMATCH") and result["witness"].is_empty(), label)
	_ok(state.canonical_text() == before, label + " does not mutate the input")

func _legacy_sample() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_001.json"))
	var data: Dictionary = raw
	var legacy := Level.from_dict(data)
	var adapted: Dictionary = V1Adapter.to_v2(data)
	var state := PuzzleState.from_definition(adapted)
	var blocks := legacy.clone_blocks()
	var legacy_step: Dictionary = Rules.slide_result(legacy, blocks, blocks[0], "right", 1)
	var moved: Dictionary = PuzzleEngine.transition(state, PuzzleAction.move("b1", "right", Vector2i(1, 4)), adapted)
	_ok(bool(moved["ok"]) and moved["next_state"].pieces["b1"]["pos"] == Vector2i(int(legacy_step["pos"].x), int(legacy_step["pos"].y)), "level 1 one-step slide matches legacy rules")
	var legacy_exit: Dictionary = Rules.slide_result(legacy, blocks, blocks[0], "down", 99)
	var solved: Dictionary = SolverV2.solve(adapted, state, 100)
	_ok(bool(legacy_exit["exit"]) and solved["status"] == PuzzleEngine.SOLVED and int(solved["solution_length"]) == Rules.solve_min_moves(legacy), "level 1 exit length matches the legacy solver")
	_ok(_replay_wins(adapted, state, solved["witness"]), "level 1 witness replays through the v2 transition")
	var adapter_ok := 0
	for path in Catalog.list_paths():
		var raw_level: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var adapted_level: Dictionary = V1Adapter.to_v2(raw_level)
		if LevelValidator.validate_v2(adapted_level).is_empty():
			adapter_ok += 1
		else:
			print("  FAIL  adapter ", path)
	_ok(adapter_ok == 100, "all 100 adapted v1 levels pass v2 schema validation")
	var broken_shape := _level(3, 2, [], [_piece("gap", "red", [[0, 0], [2, 0]], [0, 0], true)], [_gate("out", "right", 0, 1, "red")])
	var broken_solve: Dictionary = SolverV2.solve(broken_shape, PuzzleState.from_definition(broken_shape), 20)
	_ok(broken_solve["status"] == PuzzleEngine.INVALID_LEVEL, "disconnected geometry is not solved")
	var sample_solved := 0
	var paths := Catalog.list_paths()
	for index in mini(8, paths.size()):
		var path: String = paths[index]
		var level_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var level_data: Dictionary = level_raw
		var definition: Dictionary = V1Adapter.to_v2(level_data)
		var result: Dictionary = SolverV2.solve(definition, PuzzleState.from_definition(definition), 4000)
		var replay: bool = result["status"] == PuzzleEngine.SOLVED and _replay_wins(definition, PuzzleState.from_definition(definition), result["witness"])
		if replay:
			sample_solved += 1
		else:
			print("  FAIL  sample ", path, " ", result["status"], " explored ", result["explored_states"])
	_ok(sample_solved == mini(8, paths.size()), "first 8 adapted levels have replayed v2 solutions")
	print("  INFO  v2 solver replayed %d of the first 8 legacy levels; levels 9-100 were not solver-replayed" % sample_solved)

func _replay_wins(definition: Dictionary, state: PuzzleState, witness: Array) -> bool:
	var cursor := state
	for action in witness:
		var applied: Dictionary = PuzzleEngine.transition(cursor, action, definition)
		if not bool(applied["ok"]):
			return false
		cursor = applied["next_state"]
	return PuzzleEngine.is_won(definition, cursor) and cursor.move_number == state.move_number + witness.size()

func _stop_short() -> Dictionary:
	return _level(5, 1, [], [
		_piece("red", "red", [[0, 0]], [0, 0], true),
	], [_gate("top_gate", "top", 2, 2, "red")])

func _level(cols: int, rows: int, walls: Array, pieces: Array, gates: Array) -> Dictionary:
	return {
		"schema_version": 2,
		"id": "hand",
		"name": "Hand authored schema fixture",
		"board": {"cols": cols, "rows": rows, "walls": walls},
		"pieces": pieces,
		"gates": gates,
		"goals": {"all_required_pieces_exited": true},
	}

func _piece(id: String, color: String, cells: Array, pos: Array, required: bool) -> Dictionary:
	return {"id": id, "color": color, "cells": cells, "pos": pos, "required": required, "reveal": "visible"}

func _gate(id: String, side: String, lo: int, hi: int, color: String) -> Dictionary:
	return {"id": id, "side": side, "lo": lo, "hi": hi, "accept": [color], "initial_state": "open"}

func _has_dir(actions: Array, dir: String) -> bool:
	for action in actions:
		if action.kind == PuzzleAction.MOVE and action.direction == dir:
			return true
	return false

func _has_exit(actions: Array) -> bool:
	return _exit_gate(actions) != ""

func _exit_gate(actions: Array) -> String:
	for action in actions:
		if action.kind == PuzzleAction.EXIT:
			return action.gate_id
	return ""

func _ref_length(definition: Dictionary) -> int:
	return _independent_search(definition, false, 1000)

func _max_only_length(definition: Dictionary) -> int:
	return _independent_search(definition, true, 1000)

func _independent_search(definition: Dictionary, max_only: bool, cap: int) -> int:
	var pieces := {}
	for piece in definition["pieces"]:
		var offsets: Array = []
		for cell in piece["cells"]:
			offsets.append(Vector2i(int(cell[0]), int(cell[1])))
		pieces[piece["id"]] = {
			"offsets": offsets,
			"color": piece["color"],
			"required": bool(piece["required"]),
			"pos": Vector2i(int(piece["pos"][0]), int(piece["pos"][1])),
			"active": true,
		}
	var walls := {}
	for wall in definition["board"]["walls"]:
		walls[Vector2i(int(wall[0]), int(wall[1]))] = true
	var cols := int(definition["board"]["cols"])
	var rows := int(definition["board"]["rows"])
	var start := _clone_pieces(pieces)
	if _ref_won(start):
		return 0
	var queue: Array = [[start, 0]]
	var seen := {_ref_key(start): true}
	var explored := 0
	while not queue.is_empty():
		if explored >= cap:
			return -2
		explored += 1
		var item: Array = queue.pop_front()
		var current: Dictionary = item[0]
		var depth: int = item[1]
		var ids: Array = current.keys()
		ids.sort()
		for id in ids:
			if not bool(current[id]["active"]):
				continue
			for dir in ["left", "right", "up", "down"]:
				var landed: Array = _ref_landings(current, id, dir, walls, cols, rows)
				var chosen: Array = landed
				if max_only and not landed.is_empty():
					chosen = [landed[landed.size() - 1]]
				for landing in chosen:
					var moved := _clone_pieces(current)
					moved[id]["pos"] = landing
					if _ref_enqueue(queue, seen, moved, depth + 1):
						return depth + 1
				if _ref_can_exit(definition, current, id, dir, walls, cols, rows):
					var exited := _clone_pieces(current)
					exited[id]["active"] = false
					exited[id]["pos"] = _ref_alignment(current, id, dir, walls, cols, rows)
					if _ref_won(exited):
						return depth + 1
					_ref_enqueue(queue, seen, exited, depth + 1)
	return -1

func _ref_enqueue(queue: Array, seen: Dictionary, pieces: Dictionary, depth: int) -> bool:
	if _ref_won(pieces):
		return true
	var key := _ref_key(pieces)
	if seen.has(key):
		return false
	seen[key] = true
	queue.append([pieces, depth])
	return false

func _ref_won(pieces: Dictionary) -> bool:
	for id in pieces.keys():
		if bool(pieces[id]["required"]) and bool(pieces[id]["active"]):
			return false
	return true

func _ref_key(pieces: Dictionary) -> String:
	var ids: Array = pieces.keys()
	ids.sort()
	var parts: PackedStringArray = PackedStringArray()
	for id in ids:
		var pos: Vector2i = pieces[id]["pos"]
		parts.append("%s:%d,%d:%d" % [id, pos.x, pos.y, int(bool(pieces[id]["active"]))])
	return "|".join(parts)

func _ref_landings(pieces: Dictionary, id: String, dir: String, walls: Dictionary, cols: int, rows: int) -> Array:
	var step := _step(dir)
	var pos: Vector2i = pieces[id]["pos"]
	var landings: Array = []
	while true:
		var nxt: Vector2i = pos + step
		if _ref_kind(pieces, id, nxt, walls, cols, rows) != "free":
			return landings
		pos = nxt
		landings.append(pos)
	return landings

func _ref_can_exit(definition: Dictionary, pieces: Dictionary, id: String, dir: String, walls: Dictionary, cols: int, rows: int) -> bool:
	var alignment := _ref_alignment(pieces, id, dir, walls, cols, rows)
	if _ref_kind(pieces, id, alignment + _step(dir), walls, cols, rows) != "boundary":
		return false
	var side_for := {"left": "left", "right": "right", "up": "top", "down": "bottom"}
	var side: String = side_for[dir]
	var horizontal: bool = side == "left" or side == "right"
	var edge := 0
	if side == "right":
		edge = cols - 1
	elif side == "bottom":
		edge = rows - 1
	var perp_min := 999999
	var perp_max := -1
	var on_edge := false
	for offset in pieces[id]["offsets"]:
		var cell: Vector2i = alignment + offset
		var along := cell.x if horizontal else cell.y
		var perp := cell.y if horizontal else cell.x
		if along == edge:
			on_edge = true
		perp_min = mini(perp_min, perp)
		perp_max = maxi(perp_max, perp)
	if not on_edge:
		return false
	var matches := 0
	for gate in definition["gates"]:
		if str(gate["side"]) != side or not gate["accept"].has(pieces[id]["color"]):
			continue
		if perp_min < int(gate["lo"]) or perp_max > int(gate["hi"]):
			continue
		matches += 1
	return matches == 1

func _ref_alignment(pieces: Dictionary, id: String, dir: String, walls: Dictionary, cols: int, rows: int) -> Vector2i:
	var pos: Vector2i = pieces[id]["pos"]
	var step := _step(dir)
	while _ref_kind(pieces, id, pos + step, walls, cols, rows) == "free":
		pos += step
	return pos

func _ref_kind(pieces: Dictionary, id: String, pos: Vector2i, walls: Dictionary, cols: int, rows: int) -> String:
	var hit := false
	var outside := false
	var occupied := {}
	for other in pieces.keys():
		if other == id or not bool(pieces[other]["active"]):
			continue
		for offset in pieces[other]["offsets"]:
			occupied[pieces[other]["pos"] + offset] = true
	for offset in pieces[id]["offsets"]:
		var cell: Vector2i = pos + offset
		if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
			outside = true
		elif walls.has(cell) or occupied.has(cell):
			hit = true
	if hit:
		return "collision"
	if outside:
		return "boundary"
	return "free"

func _clone_pieces(pieces: Dictionary) -> Dictionary:
	var copy := {}
	for id in pieces.keys():
		copy[id] = pieces[id].duplicate()
		copy[id]["pos"] = pieces[id]["pos"]
	return copy

func _step(dir: String) -> Vector2i:
	match dir:
		"left":
			return Vector2i(-1, 0)
		"right":
			return Vector2i(1, 0)
		"up":
			return Vector2i(0, -1)
		"down":
			return Vector2i(0, 1)
	return Vector2i.ZERO
