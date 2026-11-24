class_name PuzzleEngine
extends RefCounted
## Pure transition skeleton. TD-2 owns legal landing enumeration.
## A call never mutates the given state and never reports success for an unimplemented rule.

const SOLVED := "SOLVED"
const UNSOLVABLE := "UNSOLVABLE"
const UNKNOWN_CAP_REACHED := "UNKNOWN_CAP_REACHED"
const INVALID_LEVEL := "INVALID_LEVEL"
const MAX_CASCADE := 32

static func transition(state: PuzzleState, action: PuzzleAction, definition: Dictionary) -> Dictionary:
	if action == null or (action.kind != PuzzleAction.MOVE and action.kind != PuzzleAction.EXIT):
		return _reject("INVALID_ACTION", "Action kind is missing or unknown.")
	if not state.pieces.has(action.piece_id):
		return _reject("UNKNOWN_PIECE", "Piece '%s' is not in the puzzle state." % action.piece_id)
	if _uses_unimplemented_mechanics(definition):
		return _reject("UNSUPPORTED_FEATURE", "Triggers, locked gates, counters, blockers, or hidden pieces are parsed only. Runtime execution is not available.")
	return _reject("RULES_NOT_IMPLEMENTED", "Legal landing enumeration and exits are TD-2. This transition does not move pieces.")

## Cap exhaustion is never reported as a completed impossibility proof.
static func search_status(solved: bool, search_complete: bool, cap_hit: bool) -> String:
	if solved:
		return SOLVED
	if cap_hit or not search_complete:
		return UNKNOWN_CAP_REACHED
	return UNSOLVABLE

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

static func _reject(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"next_state": null,
		"events": [],
		"error": {"code": code, "message": message},
	}
