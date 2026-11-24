class_name SolverV2
extends RefCounted
## Shortest committed-move search. Expands only PuzzleEngine actions.
##
## max_states is the number of states that may be expanded (popped).
## The starting state costs one expansion unless it is already a win.
## A win discovered as a child does not need its own expansion.
## max_states 0 expands nothing: an already-won state is SOLVED, otherwise
## the result is UNKNOWN_CAP_REACHED. UNSOLVABLE is returned only after the
## queue empties inside the budget. Search keys ignore move_number.

static func solve(definition: Dictionary, initial_state: PuzzleState, max_states: int = 200000) -> Dictionary:
	PuzzleEngine.assume_valid = false
	var diags := LevelValidator.validate_v2(definition)
	if not diags.is_empty():
		return _result(PuzzleEngine.INVALID_LEVEL, 0, -1, [], diags)
	if PuzzleEngine._unsupported_reason(definition, initial_state) != "":
		return _result(PuzzleEngine.INVALID_LEVEL, 0, -1, [], [LevelValidator._diag("UNSUPPORTED_FEATURE", "definition", "Advanced mechanics are not solvable in TD-2.")])
	if not PuzzleEngine._state_matches(definition, initial_state):
		return _result(PuzzleEngine.INVALID_LEVEL, 0, -1, [], [LevelValidator._diag("STATE_MISMATCH", "state", "Puzzle state does not match the level definition.")])
	if PuzzleEngine.is_won(definition, initial_state):
		return _checked(definition, initial_state, 0, [])
	PuzzleEngine.assume_valid = true
	var searched := _search(definition, initial_state, max_states)
	PuzzleEngine.assume_valid = false
	if str(searched["status"]) != PuzzleEngine.SOLVED:
		return searched
	return _checked(definition, initial_state, int(searched["explored_states"]), searched["witness"])

static func _search(definition: Dictionary, initial_state: PuzzleState, max_states: int) -> Dictionary:
	var queue: Array = [[initial_state, []]]
	var seen := {initial_state.search_key(): true}
	var explored := 0
	while not queue.is_empty():
		if explored >= max_states:
			return _result(PuzzleEngine.UNKNOWN_CAP_REACHED, explored, -1, [], [])
		explored += 1
		var item: Array = queue.pop_front()
		var current: PuzzleState = item[0]
		var path: Array = item[1]
		for action in PuzzleEngine.legal_actions(definition, current):
			var applied: Dictionary = PuzzleEngine.transition(current, action, definition)
			if not bool(applied["ok"]):
				continue
			var next: PuzzleState = applied["next_state"]
			var witness: Array = path.duplicate()
			witness.append(action)
			if PuzzleEngine.is_won(definition, next):
				return _result(PuzzleEngine.SOLVED, explored, witness.size(), witness, [])
			var key := next.search_key()
			if seen.has(key):
				continue
			seen[key] = true
			queue.append([next, witness])
	return _result(PuzzleEngine.UNSOLVABLE, explored, -1, [], [])

static func _checked(definition: Dictionary, initial_state: PuzzleState, explored: int, witness: Array) -> Dictionary:
	var cursor := initial_state
	for action in witness:
		var applied: Dictionary = PuzzleEngine.transition(cursor, action, definition)
		if not bool(applied["ok"]):
			return _result(PuzzleEngine.INVALID_LEVEL, explored, -1, [], [LevelValidator._diag("INVALID_LEVEL", "witness", "Witness replay rejected an action.")])
		cursor = applied["next_state"]
	if not PuzzleEngine.is_won(definition, cursor) or cursor.move_number != initial_state.move_number + witness.size():
		return _result(PuzzleEngine.INVALID_LEVEL, explored, -1, [], [LevelValidator._diag("INVALID_LEVEL", "witness", "Witness replay did not win.")])
	return _result(PuzzleEngine.SOLVED, explored, witness.size(), witness, [])

static func _result(status: String, explored: int, length: int, witness: Array, diagnostics: Array) -> Dictionary:
	return {
		"status": status,
		"explored_states": explored,
		"solution_length": length,
		"witness": witness,
		"diagnostics": diagnostics,
	}
