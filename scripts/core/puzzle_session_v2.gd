class_name PuzzleSessionV2
extends RefCounted
## Authoritative v2 play session. Rendering never writes this state.
## Undo restores a previous committed state. One transition is one move.

var definition: Dictionary = {}
var state: PuzzleState
var history: Array = []
var input_locked := false

static func open(definition: Dictionary) -> PuzzleSessionV2:
	var session := PuzzleSessionV2.new()
	session.definition = definition
	session.restart()
	return session

func restart() -> void:
	state = PuzzleState.from_definition(definition)
	history.clear()
	input_locked = false

func commit(action: PuzzleAction) -> Dictionary:
	if input_locked:
		return {"ok": false, "next_state": null, "events": [], "error": {"code": "BUSY", "message": "Input is locked while the board animates."}}
	var before := state
	var applied: Dictionary = PuzzleEngine.transition(state, action, definition)
	if not bool(applied["ok"]):
		return applied
	history.append(before)
	state = applied["next_state"]
	return applied

func undo() -> bool:
	if input_locked or history.is_empty():
		return false
	state = history.pop_back()
	return true

func is_won() -> bool:
	return PuzzleEngine.is_won(definition, state)

func move_count() -> int:
	return state.move_number
