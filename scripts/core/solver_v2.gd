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
##
## time_budget_ms > 0 adds a wall-clock cap: exceeding it returns UNKNOWN_CAP_REACHED
## (a recorded limitation, never UNSOLVABLE). profile_* expose the last search's time split.

static var profile_legal_us := 0
static var profile_transition_us := 0
## Test seam for the time-budget clock. When valid it replaces Time.get_ticks_usec()
## for the budget deadline only, so the expiry branch can be driven deterministically.
## Production leaves it empty (real clock); profiling always uses the real clock.
static var _clock := Callable()

static func _now_us() -> int:
	return int(_clock.call()) if _clock.is_valid() else Time.get_ticks_usec()

static func solve(definition: Dictionary, initial_state: PuzzleState, max_states: int = 200000, time_budget_ms: int = 0) -> Dictionary:
	profile_legal_us = 0
	profile_transition_us = 0
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
	context.simple = PuzzleEngine.is_simple(definition)
	var searched := _search(definition, initial_state, max_states, context, time_budget_ms)
	if str(searched["status"]) != PuzzleEngine.SOLVED:
		return searched
	return _checked(definition, initial_state, int(searched["explored_states"]), searched["witness"])

static func _search(definition: Dictionary, initial_state: PuzzleState, max_states: int, context: PuzzleSearchContext, time_budget_ms: int = 0) -> Dictionary:
	# Each queue entry carries its own search key so a popped state never re-hashes it.
	var start_key := initial_state.search_key()
	var queue: Array = [[initial_state, start_key]]
	var head := 0
	var seen := {start_key: true}
	var parent := {}
	var explored := 0
	var deadline := _now_us() + time_budget_ms * 1000 if time_budget_ms > 0 else 0
	while head < queue.size():
		if explored >= max_states:
			return _result(PuzzleEngine.UNKNOWN_CAP_REACHED, explored, -1, [], [])
		if deadline > 0 and _now_us() > deadline:
			return _result(PuzzleEngine.UNKNOWN_CAP_REACHED, explored, -1, [], [])
		explored += 1
		var entry: Array = queue[head]
		head += 1
		var current: PuzzleState = entry[0]
		var current_key: String = entry[1]
		var legal_start := Time.get_ticks_usec()
		var legal := PuzzleEngine.legal_actions(definition, current, "", context)
		profile_legal_us += Time.get_ticks_usec() - legal_start
		for action in legal:
			var transition_start := Time.get_ticks_usec()
			var applied: Dictionary = PuzzleEngine.transition(current, action, definition, context)
			profile_transition_us += Time.get_ticks_usec() - transition_start
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
			queue.append([next, key])
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
