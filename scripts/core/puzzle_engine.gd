class_name PuzzleEngine
extends RefCounted
## Authoritative simple-gate movement. Advanced mechanics stay fail-closed.
## A call never mutates the given state.
##
## An EXIT is one committed move: the piece slides in a straight line to the
## unique open gate and leaves. Intermediate stops are separate MOVE actions.

const SOLVED := "SOLVED"
const UNSOLVABLE := "UNSOLVABLE"
const UNKNOWN_CAP_REACHED := "UNKNOWN_CAP_REACHED"
const INVALID_LEVEL := "INVALID_LEVEL"
const MAX_CASCADE := 32
const DIRECTIONS := ["left", "right", "up", "down"]
static var assume_valid := false

static func transition(state: PuzzleState, action: PuzzleAction, definition: Dictionary) -> Dictionary:
	if action == null or (action.kind != PuzzleAction.MOVE and action.kind != PuzzleAction.EXIT):
		return _reject("INVALID_ACTION", "Action kind is missing or unknown.")
	if not state.pieces.has(action.piece_id):
		return _reject("UNKNOWN_PIECE", "Piece '%s' is not in the puzzle state." % action.piece_id)
	var unsupported := _unsupported_reason(definition, state)
	if unsupported != "":
		return _reject("UNSUPPORTED_FEATURE", unsupported)
	if not assume_valid:
		var diags := LevelValidator.validate_v2(definition)
		if not diags.is_empty():
			return _reject("INVALID_LEVEL", "Definition failed schema validation.")
	if not _state_matches(definition, state):
		return _reject("STATE_MISMATCH", "Puzzle state does not match the level definition.")
	var piece: Dictionary = state.pieces[action.piece_id]
	if not bool(piece["active"]):
		return _reject("ILLEGAL_ACTION", "Piece '%s' is inactive." % action.piece_id)
	var legal := legal_actions(definition, state, action.piece_id)
	var matched: PuzzleAction = null
	for candidate in legal:
		if candidate.canonical_text() == action.canonical_text():
			matched = candidate
			break
	if matched == null:
		return _reject("ILLEGAL_ACTION", "That landing or exit is not legal.")
	var next := state.duplicate()
	var events: Array = []
	if matched.kind == PuzzleAction.MOVE:
		next.pieces[matched.piece_id]["pos"] = matched.landing
		events.append(PuzzleEvent.make(PuzzleEvent.PIECE_MOVED, matched.piece_id, 0))
	else:
		var slide: Dictionary = _exit_slide(definition, state, matched.piece_id, matched.gate_id)
		var origin: Vector2i = piece["pos"]
		var alignment: Vector2i = slide["pos"]
		next.pieces[matched.piece_id]["pos"] = alignment
		next.pieces[matched.piece_id]["active"] = false
		if alignment != origin:
			events.append(PuzzleEvent.make(PuzzleEvent.PIECE_MOVED, matched.piece_id, 0))
		events.append(PuzzleEvent.make(PuzzleEvent.PIECE_EXITED, matched.piece_id, 1))
	next.move_number += 1
	return {"ok": true, "next_state": next, "events": events, "error": {}}

static func legal_actions(definition: Dictionary, state: PuzzleState, piece_id: String = "") -> Array:
	if _unsupported_reason(definition, state) != "":
		return []
	if not assume_valid and not LevelValidator.validate_v2(definition).is_empty():
		return []
	if not _state_matches(definition, state):
		return []
	var geometry := _geometry(definition)
	var actions: Array = []
	var ids: Array = geometry.keys()
	ids.sort()
	for id in ids:
		if piece_id != "" and id != piece_id:
			continue
		if not bool(state.pieces[id]["active"]):
			continue
		_actions_for_piece(definition, state, geometry, id, actions)
	actions.sort_custom(func(left, right):
		return _action_sort_key(left, state, definition) < _action_sort_key(right, state, definition)
	)
	return actions

static func is_won(definition: Dictionary, state: PuzzleState) -> bool:
	var required := 0
	for piece in definition.get("pieces", []):
		if typeof(piece) != TYPE_DICTIONARY:
			return false
		var needed := true
		if piece.has("required"):
			needed = bool(piece["required"])
		if not needed:
			continue
		required += 1
		var id := str(piece.get("id", ""))
		if not state.pieces.has(id) or bool(state.pieces[id]["active"]):
			return false
	return true

static func search_status(solved: bool, search_complete: bool, cap_hit: bool) -> String:
	if solved:
		return SOLVED
	if cap_hit or not search_complete:
		return UNKNOWN_CAP_REACHED
	return UNSOLVABLE

static func _actions_for_piece(definition: Dictionary, state: PuzzleState, geometry: Dictionary, id: String, actions: Array) -> void:
	var origin: Vector2i = state.pieces[id]["pos"]
	var offsets: Array = geometry[id]["offsets"]
	var occupied := _occupied(definition, state, id)
	var bounds: Vector2i = _bounds(definition)
	for dir in DIRECTIONS:
		var slide := _walk(origin, offsets, dir, occupied, bounds)
		for landing in slide["landings"]:
			actions.append(PuzzleAction.move(id, dir, landing))
		if not bool(slide["boundary"]):
			continue
		var gates: Array = _matching_gates(definition, state, geometry[id]["color"], dir, slide["pos"], offsets)
		if gates.size() != 1:
			continue
		var exit_action := PuzzleAction.exit_through(id, gates[0])
		exit_action.direction = dir
		exit_action.landing = slide["pos"]
		actions.append(exit_action)

static func _exit_slide(definition: Dictionary, state: PuzzleState, piece_id: String, gate_id: String) -> Dictionary:
	var geometry := _geometry(definition)
	var origin: Vector2i = state.pieces[piece_id]["pos"]
	var offsets: Array = geometry[piece_id]["offsets"]
	var gate := _gate_by_id(definition, gate_id)
	var dir := _dir_for_side(str(gate.get("side", "")))
	var slide := _walk(origin, offsets, dir, _occupied(definition, state, piece_id), _bounds(definition))
	return {"pos": slide["pos"], "dir": dir}

static func _walk(origin: Vector2i, offsets: Array, dir: String, occupied: Dictionary, bounds: Vector2i) -> Dictionary:
	var step := _dir_vec(dir)
	var pos := origin
	var landings: Array = []
	while true:
		var nxt: Vector2i = pos + step
		var kind := _step_kind(nxt, offsets, occupied, bounds)
		if kind == "free":
			pos = nxt
			landings.append(pos)
			continue
		return {"landings": landings, "boundary": kind == "boundary", "pos": pos}
	return {"landings": landings, "boundary": false, "pos": pos}

static func _step_kind(pos: Vector2i, offsets: Array, occupied: Dictionary, bounds: Vector2i) -> String:
	var hit := false
	var outside := false
	for offset in offsets:
		var cell: Vector2i = pos + offset
		if cell.x < 0 or cell.y < 0 or cell.x >= bounds.x or cell.y >= bounds.y:
			outside = true
		elif occupied.has(cell):
			hit = true
	if hit:
		return "collision"
	if outside:
		return "boundary"
	return "free"

static func _matching_gates(definition: Dictionary, state: PuzzleState, color: String, dir: String, pos: Vector2i, offsets: Array) -> Array:
	var side := _side_for_dir(dir)
	var bounds := _bounds(definition)
	var perp_min := 999999
	var perp_max := -999999
	var on_edge := false
	var horizontal := side == "left" or side == "right"
	var edge := 0
	if side == "right":
		edge = bounds.x - 1
	elif side == "bottom":
		edge = bounds.y - 1
	for offset in offsets:
		var cell: Vector2i = pos + offset
		var along := cell.x if horizontal else cell.y
		var perp := cell.y if horizontal else cell.x
		if along == edge:
			on_edge = true
		perp_min = mini(perp_min, perp)
		perp_max = maxi(perp_max, perp)
	if not on_edge:
		return []
	var found: Array = []
	for gate in definition.get("gates", []):
		if typeof(gate) != TYPE_DICTIONARY or str(gate.get("side", "")) != side:
			continue
		var gate_id := str(gate.get("id", ""))
		if not state.gates.has(gate_id) or str(state.gates[gate_id]["mode"]) != "OPEN":
			continue
		var accepts: Array = gate.get("accept", [])
		if not accepts.has(color):
			continue
		var lo := int(gate.get("lo", 0))
		var hi := int(gate.get("hi", -1))
		if perp_min < lo or perp_max > hi:
			continue
		found.append(gate_id)
	found.sort()
	return found

static func _occupied(definition: Dictionary, state: PuzzleState, exclude_id: String) -> Dictionary:
	var occupied := {}
	var board: Dictionary = definition.get("board", {})
	for wall in board.get("walls", []):
		var cell = _pair(wall)
		if cell != null:
			occupied[cell] = true
	var geometry := _geometry(definition)
	for id in geometry.keys():
		if id == exclude_id or not bool(state.pieces[id]["active"]):
			continue
		var origin: Vector2i = state.pieces[id]["pos"]
		for offset in geometry[id]["offsets"]:
			occupied[origin + offset] = true
	return occupied

static func _geometry(definition: Dictionary) -> Dictionary:
	var geometry := {}
	for piece in definition.get("pieces", []):
		if typeof(piece) != TYPE_DICTIONARY:
			continue
		var offsets: Array = []
		for cell in piece.get("cells", []):
			var parsed = _pair(cell)
			if parsed != null:
				offsets.append(parsed)
		var needed := true
		if piece.has("required"):
			needed = bool(piece["required"])
		geometry[str(piece.get("id", ""))] = {
			"offsets": offsets,
			"color": str(piece.get("color", "")),
			"required": needed,
		}
	return geometry

static func _state_matches(definition: Dictionary, state: PuzzleState) -> bool:
	var geometry := _geometry(definition)
	if geometry.size() != state.pieces.size():
		return false
	for id in geometry.keys():
		if not state.pieces.has(id):
			return false
		if typeof(state.pieces[id].get("pos", null)) != TYPE_VECTOR2I:
			return false
	for gate in definition.get("gates", []):
		if typeof(gate) != TYPE_DICTIONARY or not state.gates.has(str(gate.get("id", ""))):
			return false
	return true

static func _state_has_advanced(state: PuzzleState) -> bool:
	for id in state.pieces.keys():
		if not bool(state.pieces[id]["revealed"]):
			return true
	for id in state.gates.keys():
		var gate: Dictionary = state.gates[id]
		if str(gate.get("mode", "OPEN")) != "OPEN":
			return true
		if int(gate.get("counter_remaining", -1)) >= 0:
			return true
	if not state.blockers.is_empty() or not state.event_counters.is_empty():
		return true
	return false

static func _unsupported_reason(definition: Dictionary, state: PuzzleState) -> String:
	if _uses_unimplemented_mechanics(definition) or _state_has_advanced(state):
		return "Triggers, locked gates, counters, blockers, or hidden pieces are parsed only. Runtime execution is not available."
	return ""

static func _uses_unimplemented_mechanics(definition: Dictionary) -> bool:
	var triggers = definition.get("triggers", [])
	if typeof(triggers) == TYPE_ARRAY and not triggers.is_empty():
		return true
	var blockers = definition.get("blockers", [])
	if typeof(blockers) == TYPE_ARRAY and not blockers.is_empty():
		return true
	for piece in definition.get("pieces", []):
		if typeof(piece) == TYPE_DICTIONARY and str(piece.get("reveal", "visible")) == "hidden":
			return true
	for gate in definition.get("gates", []):
		if typeof(gate) != TYPE_DICTIONARY:
			continue
		if str(gate.get("initial_state", "open")) == "locked":
			return true
		if gate.has("unlock_when") or gate.has("counter"):
			return true
	var rules = definition.get("rules", {})
	if rules is Dictionary and (bool(rules.get("rotation", false)) or rules.get("timer_seconds", null) != null):
		return true
	return false

static func _action_sort_key(action: PuzzleAction, state: PuzzleState, definition: Dictionary) -> String:
	var origin: Vector2i = state.pieces[action.piece_id]["pos"]
	var direction := action.direction
	var distance := absi(action.landing.x - origin.x) + absi(action.landing.y - origin.y)
	if action.kind == PuzzleAction.EXIT and direction == "":
		var gate := _gate_by_id(definition, action.gate_id)
		direction = _dir_for_side(str(gate.get("side", "")))
	var rank := "0" if action.kind == PuzzleAction.MOVE else "1"
	return "%s|%s|%04d|%s|%s" % [action.piece_id, direction, distance, rank, action.gate_id]

static func _gate_by_id(definition: Dictionary, gate_id: String) -> Dictionary:
	for gate in definition.get("gates", []):
		if typeof(gate) == TYPE_DICTIONARY and str(gate.get("id", "")) == gate_id:
			return gate
	return {}

static func _bounds(definition: Dictionary) -> Vector2i:
	var board: Dictionary = definition.get("board", {})
	return Vector2i(int(board.get("cols", 0)), int(board.get("rows", 0)))

static func _pair(value) -> Variant:
	if typeof(value) != TYPE_ARRAY or value.size() != 2:
		return null
	var x: Variant = LevelValidator.as_whole_int(value[0])
	var y: Variant = LevelValidator.as_whole_int(value[1])
	if x == null or y == null:
		return null
	return Vector2i(int(x), int(y))

static func _dir_vec(dir: String) -> Vector2i:
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

static func _dir_for_side(side: String) -> String:
	match side:
		"left":
			return "left"
		"right":
			return "right"
		"top":
			return "up"
		"bottom":
			return "down"
	return ""

static func _side_for_dir(dir: String) -> String:
	match dir:
		"left":
			return "left"
		"right":
			return "right"
		"up":
			return "top"
		"down":
			return "bottom"
	return ""

static func _reject(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"next_state": null,
		"events": [],
		"error": {"code": code, "message": message},
	}
