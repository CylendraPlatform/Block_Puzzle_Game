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

static func transition(state: PuzzleState, action: PuzzleAction, definition: Dictionary, context: PuzzleSearchContext = null) -> Dictionary:
	if action == null or (action.kind != PuzzleAction.MOVE and action.kind != PuzzleAction.EXIT):
		return _reject("INVALID_ACTION", "Action kind is missing or unknown.")
	if not state.pieces.has(action.piece_id):
		return _reject("UNKNOWN_PIECE", "Piece '%s' is not in the puzzle state." % action.piece_id)
	var unsupported := _unsupported_reason(definition)
	if unsupported != "":
		return _reject("UNSUPPORTED_FEATURE", unsupported)
	if context == null or not context.schema_checked:
		var diags := LevelValidator.validate_v2(definition)
		if not diags.is_empty():
			return _reject("INVALID_LEVEL", "Definition failed schema validation.")
	var state_key := state.search_key()
	if context == null or context.checked_key != state_key:
		var problem := _state_problem(definition, state, context)
		if problem != "":
			return _reject("STATE_MISMATCH", "Puzzle state does not match the level definition (%s)." % problem)
	var piece: Dictionary = state.pieces[action.piece_id]
	if typeof(piece.get("active", null)) != TYPE_BOOL or not piece["active"]:
		return _reject("ILLEGAL_ACTION", "Piece '%s' is inactive." % action.piece_id)
	if not bool(piece.get("revealed", true)):
		return _reject("ILLEGAL_ACTION", "Piece '%s' is hidden and cannot move." % action.piece_id)
	var matched: PuzzleAction = action if context != null and context.owns(action, state_key) else null
	if matched == null:
		var legal := legal_actions(definition, state, action.piece_id, context)
		for candidate in legal:
			if candidate.canonical_text() == action.canonical_text():
				matched = candidate
				break
	if matched == null:
		return _reject("ILLEGAL_ACTION", "That landing or exit is not legal.")
	return _commit(state, matched, definition, context)

static func legal_actions(definition: Dictionary, state: PuzzleState, piece_id: String = "", context: PuzzleSearchContext = null) -> Array:
	if _unsupported_reason(definition) != "":
		return []
	if (context == null or not context.schema_checked) and not LevelValidator.validate_v2(definition).is_empty():
		return []
	if _state_problem(definition, state, context) != "":
		return []
	var geometry: Dictionary = context.geometry if context != null and not context.geometry.is_empty() else _geometry(definition)
	var actions: Array = []
	var ids: Array = geometry.keys()
	ids.sort()
	for id in ids:
		if piece_id != "" and id != piece_id:
			continue
		if typeof(state.pieces[id].get("active", null)) != TYPE_BOOL or not state.pieces[id]["active"]:
			continue
		if not bool(state.pieces[id].get("revealed", true)):
			continue
		_actions_for_piece(definition, state, geometry, id, actions, context)
	actions.sort_custom(func(left, right):
		return _action_sort_key(left, state, definition) < _action_sort_key(right, state, definition)
	)
	if context != null:
		var key := state.search_key()
		context.checked_key = key
		for issued in actions:
			context.trust(issued, key)
	return actions

static func is_won(definition: Dictionary, state: PuzzleState, context: PuzzleSearchContext = null) -> bool:
	if _state_problem(definition, state, context) != "":
		return false
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

static func _commit(state: PuzzleState, matched: PuzzleAction, definition: Dictionary, context: PuzzleSearchContext) -> Dictionary:
	var next := state.duplicate()
	var events: Array = []
	var piece: Dictionary = state.pieces[matched.piece_id]
	if matched.kind == PuzzleAction.MOVE:
		next.pieces[matched.piece_id]["pos"] = matched.landing
		events.append(PuzzleEvent.make(PuzzleEvent.PIECE_MOVED, matched.piece_id, 0))
	else:
		var slide: Dictionary = _exit_slide(definition, state, matched.piece_id, matched.gate_id, context)
		var origin: Vector2i = piece["pos"]
		var alignment: Vector2i = slide["pos"]
		next.pieces[matched.piece_id]["pos"] = alignment
		next.pieces[matched.piece_id]["active"] = false
		if alignment != origin:
			events.append(PuzzleEvent.make(PuzzleEvent.PIECE_MOVED, matched.piece_id, 0))
		events.append(PuzzleEvent.make(PuzzleEvent.PIECE_EXITED, matched.piece_id, 1))
		var exit_color := _piece_color(definition, matched.piece_id)
		next.event_counters[exit_color] = int(next.event_counters.get(exit_color, 0)) + 1
	next.move_number += 1
	_update_gate_phases(next, definition)
	var resolved := _resolve(next, definition, events)
	if not bool(resolved["ok"]):
		return _reject("CASCADE_LIMIT", str(resolved["message"]))
	return {"ok": true, "next_state": next, "events": events, "error": {}}

## Deterministic post-action world reaction: open gates whose condition now holds
## and fire one-shot triggers, cascading until the state settles. Sorted-id order
## keeps it reproducible; MAX_CASCADE bounds it; a failed effect rolls the action back.
static func _resolve(next: PuzzleState, definition: Dictionary, events: Array) -> Dictionary:
	var gate_ids: Array = []
	for gate in definition.get("gates", []):
		if typeof(gate) == TYPE_DICTIONARY:
			gate_ids.append(str(gate.get("id", "")))
	gate_ids.sort()
	var triggers: Array = []
	for trigger in definition.get("triggers", []):
		if typeof(trigger) == TYPE_DICTIONARY:
			triggers.append(trigger)
	triggers.sort_custom(func(left, right): return str(left.get("id", "")) < str(right.get("id", "")))
	for _pass in MAX_CASCADE:
		var changed := false
		for gid in gate_ids:
			var gate_state: Dictionary = next.gates[gid]
			if str(gate_state["mode"]) != "LOCKED":
				continue
			var gate_def := _gate_by_id(definition, gid)
			var kind := GateRules.classify(gate_def)
			var opened := false
			if kind == GateRules.UNLOCK_WHEN and Conditions.satisfied(gate_def["unlock_when"], next):
				opened = true
			elif kind == GateRules.COUNTER and int(gate_state["counter_remaining"]) == 0:
				opened = true
			if opened:
				gate_state["mode"] = "OPEN"
				events.append(PuzzleEvent.make(PuzzleEvent.GATE_UNLOCKED, gid, 2))
				changed = true
		for trigger in triggers:
			var tid := str(trigger.get("id", ""))
			if bool(next.trigger_fired.get(tid, false)):
				continue
			if Conditions.satisfied(trigger.get("when", {}), next):
				if not Effects.apply(trigger.get("effect", {}), next, events):
					return {"ok": false, "message": "Effect of trigger '%s' failed." % tid}
				next.trigger_fired[tid] = true
				changed = true
		if not changed:
			return {"ok": true, "message": ""}
	return {"ok": false, "message": "Cascade exceeded %d steps." % MAX_CASCADE}

static func _piece_color(definition: Dictionary, piece_id: String) -> String:
	for piece in definition.get("pieces", []):
		if typeof(piece) == TYPE_DICTIONARY and str(piece.get("id", "")) == piece_id:
			return str(piece.get("color", ""))
	return ""

## Keep each color-switching gate's phase equal to move_number % period, so the gate's
## accepted color (and the search key) advance one step per committed action.
static func _update_gate_phases(state: PuzzleState, definition: Dictionary) -> void:
	for gate in definition.get("gates", []):
		if typeof(gate) != TYPE_DICTIONARY or not gate.has("color_schedule"):
			continue
		var gid := str(gate.get("id", ""))
		if state.gates.has(gid):
			state.gates[gid]["phase"] = state.move_number % gate["color_schedule"].size()

static func _actions_for_piece(definition: Dictionary, state: PuzzleState, geometry: Dictionary, id: String, actions: Array, context: PuzzleSearchContext) -> void:
	var origin: Vector2i = state.pieces[id]["pos"]
	var offsets: Array = geometry[id]["offsets"]
	var occupied := _occupied(definition, state, id, geometry, context)
	var bounds: Vector2i = context.bounds if context != null and context.bounds != Vector2i.ZERO else _bounds(definition)
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

static func _exit_slide(definition: Dictionary, state: PuzzleState, piece_id: String, gate_id: String, context: PuzzleSearchContext) -> Dictionary:
	var geometry: Dictionary = context.geometry if context != null and not context.geometry.is_empty() else _geometry(definition)
	var origin: Vector2i = state.pieces[piece_id]["pos"]
	var offsets: Array = geometry[piece_id]["offsets"]
	var gate := _gate_by_id(definition, gate_id)
	var dir := _dir_for_side(str(gate.get("side", "")))
	var bounds: Vector2i = context.bounds if context != null and context.bounds != Vector2i.ZERO else _bounds(definition)
	var slide := _walk(origin, offsets, dir, _occupied(definition, state, piece_id, geometry, context), bounds)
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
		if GateRules.is_color_switching(gate):
			if GateRules.scheduled_color(gate, int(state.gates[gate_id].get("phase", 0))) != color:
				continue
		else:
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

static func _occupied(definition: Dictionary, state: PuzzleState, exclude_id: String, geometry: Dictionary, context: PuzzleSearchContext) -> Dictionary:
	var occupied := {}
	var walls: Dictionary = context.walls if context != null and not context.walls.is_empty() else _wall_cells(definition)
	for cell in walls.keys():
		occupied[cell] = true
	for id in geometry.keys():
		if id == exclude_id or not bool(state.pieces[id]["active"]):
			continue
		var origin: Vector2i = state.pieces[id]["pos"]
		for offset in geometry[id]["offsets"]:
			occupied[origin + offset] = true
	# Active blockers occupy their single cell until removed.
	for blocker in definition.get("blockers", []):
		if typeof(blocker) != TYPE_DICTIONARY:
			continue
		var bid := str(blocker.get("id", ""))
		if not state.blockers.has(bid) or not bool(state.blockers[bid]["active"]):
			continue
		var cell = _pair(blocker.get("cell", null))
		if cell != null:
			occupied[cell] = true
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
			"reveal": str(piece.get("reveal", "visible")),
		}
	return geometry

static func _wall_cells(definition: Dictionary) -> Dictionary:
	var walls := {}
	var board: Dictionary = definition.get("board", {})
	for wall in board.get("walls", []):
		var cell = _pair(wall)
		if cell != null:
			walls[cell] = true
	return walls

static func _state_matches(definition: Dictionary, state: PuzzleState) -> bool:
	return _state_problem(definition, state, null) == ""

static func _state_problem(definition: Dictionary, state: PuzzleState, context: PuzzleSearchContext) -> String:
	if state.schema_version != 2:
		return "schema"
	if state.level_id != str(definition.get("id", "")):
		return "level"
	if state.move_number < 0:
		return "move"
	var geometry: Dictionary = context.geometry if context != null and not context.geometry.is_empty() else _geometry(definition)
	if state.pieces.size() != geometry.size():
		return "pieces"
	var bounds: Vector2i = context.bounds if context != null and context.bounds != Vector2i.ZERO else _bounds(definition)
	var walls: Dictionary = context.walls if context != null and not context.walls.is_empty() else _wall_cells(definition)
	var occupied := {}
	for id in geometry.keys():
		if not state.pieces.has(id) or typeof(state.pieces[id]) != TYPE_DICTIONARY:
			return "piece"
		var piece: Dictionary = state.pieces[id]
		if typeof(piece.get("pos", null)) != TYPE_VECTOR2I:
			return "position"
		if typeof(piece.get("active", null)) != TYPE_BOOL or typeof(piece.get("revealed", null)) != TYPE_BOOL:
			return "piece-flags"
		# A visible piece must stay revealed; a hidden piece may be revealed or not.
		if str(geometry[id]["reveal"]) != "hidden" and not bool(piece["revealed"]):
			return "reveal"
		var origin: Vector2i = piece["pos"]
		for offset in geometry[id]["offsets"]:
			var cell: Vector2i = origin + offset
			if cell.x < 0 or cell.y < 0 or cell.x >= bounds.x or cell.y >= bounds.y:
				return "bounds"
			if walls.has(cell):
				return "wall"
			if bool(piece["active"]):
				if occupied.has(cell):
					return "overlap"
				occupied[cell] = true
	# Gates: accept any reachable mutation; reject structurally impossible state.
	# A static-open gate must stay OPEN; a counter never leaves [0, initial]; a
	# gate with no counter keeps the -1 sentinel.
	var expected_gates := _expected_gates(definition)
	if state.gates.size() != expected_gates.size():
		return "gates"
	for gate_id in expected_gates.keys():
		if not state.gates.has(gate_id) or typeof(state.gates[gate_id]) != TYPE_DICTIONARY:
			return "gate"
		var gate_state: Dictionary = state.gates[gate_id]
		var mode := str(gate_state.get("mode", ""))
		if mode != "OPEN" and mode != "LOCKED":
			return "gate-mode"
		if GateRules.classify(_gate_by_id(definition, gate_id)) == GateRules.STATIC_OPEN and mode != "OPEN":
			return "gate-mode"
		if typeof(gate_state.get("counter_remaining", null)) != TYPE_INT:
			return "gate-counter"
		var gate_counter := int(gate_state["counter_remaining"])
		var init_gate_counter := int(expected_gates[gate_id]["counter_remaining"])
		if init_gate_counter < 0:
			if gate_counter != -1:
				return "gate-counter"
		elif gate_counter < 0 or gate_counter > init_gate_counter:
			return "gate-counter"
		var switching_def := _gate_by_id(definition, gate_id)
		if GateRules.is_color_switching(switching_def):
			if int(gate_state.get("phase", -1)) != state.move_number % switching_def["color_schedule"].size():
				return "gate-phase"
	# Blockers: active may be true or false; counter stays within [0, initial];
	# an active blocker may not share a cell with an active piece.
	var expected_blockers := _expected_blockers(definition)
	if state.blockers.size() != expected_blockers.size():
		return "blockers"
	var blocker_cells := _blocker_cells(definition)
	for blocker_id in expected_blockers.keys():
		if not state.blockers.has(blocker_id) or typeof(state.blockers[blocker_id]) != TYPE_DICTIONARY:
			return "blocker"
		var blocker_state: Dictionary = state.blockers[blocker_id]
		if typeof(blocker_state.get("active", null)) != TYPE_BOOL or typeof(blocker_state.get("counter_remaining", null)) != TYPE_INT:
			return "blocker"
		var blocker_counter := int(blocker_state["counter_remaining"])
		var init_blocker_counter := int(expected_blockers[blocker_id])
		if init_blocker_counter < 0:
			if blocker_counter != -1:
				return "blocker"
		elif blocker_counter < 0 or blocker_counter > init_blocker_counter:
			return "blocker"
		if bool(blocker_state["active"]) and blocker_cells.has(blocker_id) and occupied.has(blocker_cells[blocker_id]):
			return "blocker-overlap"
	# Triggers: the fired flags cover exactly the defined triggers, each a boolean.
	var expected_triggers := _expected_triggers(definition)
	if state.trigger_fired.size() != expected_triggers.size():
		return "triggers"
	for trigger_id in expected_triggers.keys():
		if not state.trigger_fired.has(trigger_id) or typeof(state.trigger_fired[trigger_id]) != TYPE_BOOL:
			return "trigger"
	# Cumulative exit counters: color keys only, each within [0, pieces of that
	# color] (required and optional pieces both can exit).
	var color_caps := _color_exit_caps(definition)
	for key in state.event_counters.keys():
		var counter_key := str(key)
		if typeof(state.event_counters[key]) != TYPE_INT:
			return "counters"
		var counter_value := int(state.event_counters[key])
		if not color_caps.has(counter_key):
			return "counters"
		if counter_value < 0 or counter_value > int(color_caps[counter_key]):
			return "counters"
	return ""

static func _expected_gates(definition: Dictionary) -> Dictionary:
	var expected := {}
	for gate in definition.get("gates", []):
		if typeof(gate) != TYPE_DICTIONARY:
			continue
		var remaining := -1
		if gate.get("counter", null) is Dictionary:
			var rem: Variant = LevelValidator.as_whole_int(gate["counter"].get("remaining", null))
			if rem != null and int(rem) >= 0:
				remaining = int(rem)
		expected[str(gate.get("id", ""))] = {
			"mode": "LOCKED" if str(gate.get("initial_state", "open")) == "locked" else "OPEN",
			"counter_remaining": remaining,
		}
	return expected

static func _expected_blockers(definition: Dictionary) -> Dictionary:
	var expected := {}
	for blocker in definition.get("blockers", []):
		if typeof(blocker) != TYPE_DICTIONARY:
			continue
		var remaining := -1
		if blocker.has("counter_remaining"):
			var rem: Variant = LevelValidator.as_whole_int(blocker["counter_remaining"])
			if rem != null and int(rem) >= 0:
				remaining = int(rem)
		expected[str(blocker.get("id", ""))] = remaining
	return expected

static func _expected_triggers(definition: Dictionary) -> Dictionary:
	var expected := {}
	for trigger in definition.get("triggers", []):
		if typeof(trigger) == TYPE_DICTIONARY:
			expected[str(trigger.get("id", ""))] = true
	return expected

## Blocker id -> its single occupied cell, for integrity overlap checks.
static func _blocker_cells(definition: Dictionary) -> Dictionary:
	var cells := {}
	for blocker in definition.get("blockers", []):
		if typeof(blocker) != TYPE_DICTIONARY:
			continue
		var cell = _pair(blocker.get("cell", null))
		if cell != null:
			cells[str(blocker.get("id", ""))] = cell
	return cells

## Color -> number of pieces of that color (required and optional). This is the
## upper bound for a cumulative exit counter of that color.
static func _color_exit_caps(definition: Dictionary) -> Dictionary:
	var caps := {}
	for piece in definition.get("pieces", []):
		if typeof(piece) != TYPE_DICTIONARY:
			continue
		var color := str(piece.get("color", ""))
		caps[color] = int(caps.get(color, 0)) + 1
	return caps

static func _unsupported_reason(definition: Dictionary) -> String:
	if _uses_unimplemented_mechanics(definition):
		return "Triggers, locked gates, counters, blockers, or hidden pieces are parsed only. Runtime execution is not available."
	return ""

## M1.1 implements locked/conditional gates, counters, triggers, blockers and hidden
## pieces. Only rotation and a real-time timer stay out of scope and fail-closed.
static func _uses_unimplemented_mechanics(definition: Dictionary) -> bool:
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
