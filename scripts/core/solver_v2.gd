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
	var diags := LevelValidator.validate_v2(definition)
	if not diags.is_empty():
		return _result(PuzzleEngine.INVALID_LEVEL, 0, -1, [], diags)
	if PuzzleEngine._unsupported_reason(definition) != "":
		return _result(PuzzleEngine.INVALID_LEVEL, 0, -1, [], [LevelValidator._diag("UNSUPPORTED_FEATURE", "definition", "Advanced mechanics are not solvable in TD-2.")])
	var problem := PuzzleEngine._state_problem(definition, initial_state, null)
	if problem != "":
		return _result(PuzzleEngine.INVALID_LEVEL, 0, -1, [], [LevelValidator._diag("STATE_MISMATCH", "state", "Puzzle state does not match the level definition (%s)." % problem)])
	if PuzzleEngine.is_won(definition, initial_state):
		return _checked(definition, initial_state, 0, [])
	var context := PuzzleSearchContext.new()
	context.schema_checked = true
	context.geometry = PuzzleEngine._geometry(definition)
	context.walls = PuzzleEngine._wall_cells(definition)
	context.bounds = PuzzleEngine._bounds(definition)
	var searched := _search(definition, initial_state, max_states, context)
	if str(searched["status"]) != PuzzleEngine.SOLVED:
		return searched
	return _checked(definition, initial_state, int(searched["explored_states"]), searched["witness"])

static func _search(definition: Dictionary, initial_state: PuzzleState, max_states: int, context: PuzzleSearchContext) -> Dictionary:
	var queue: Array = [initial_state]
	var head := 0
	var seen := {initial_state.search_key(): true}
	var parent := {}
	var explored := 0
	while head < queue.size():
		if explored >= max_states:
			return _result(PuzzleEngine.UNKNOWN_CAP_REACHED, explored, -1, [], [])
		explored += 1
		var current: PuzzleState = queue[head]
		head += 1
		var current_key := current.search_key()
		for action in PuzzleEngine.legal_actions(definition, current, "", context):
			var applied: Dictionary = PuzzleEngine.transition(current, action, definition, context)
			if not bool(applied["ok"]):
				continue
			var next: PuzzleState = applied["next_state"]
			if PuzzleEngine.is_won(definition, next, context):
				return _result(PuzzleEngine.SOLVED, explored, _depth(parent, current_key) + 1, _witness(parent, current_key, action), [])
			var key := next.search_key()
			if seen.has(key):
				continue
			seen[key] = true
			parent[key] = [current_key, action]
			queue.append(next)
	return _result(PuzzleEngine.UNSOLVABLE, explored, -1, [], [])

static func _witness(parent: Dictionary, current_key: String, last_action: PuzzleAction) -> Array:
	var chain: Array = []
	var key := current_key
	while parent.has(key):
		var link: Array = parent[key]
		chain.append(link[1])
		key = str(link[0])
	chain.reverse()
	chain.append(last_action)
	return chain

static func _depth(parent: Dictionary, current_key: String) -> int:
	var depth := 0
	var key := current_key
	while parent.has(key):
		depth += 1
		key = str(parent[key][0])
	return depth

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
