class_name PuzzleAction
extends RefCounted
## A normalized intent. Applying it is PuzzleEngine.transition, not this object.

const MOVE := "move"
const EXIT := "exit"

var kind: String = ""
var piece_id: String = ""
var direction: String = ""
var landing: Vector2i = Vector2i.ZERO
var gate_id: String = ""

static func move(piece_id: String, direction: String, landing: Vector2i) -> PuzzleAction:
	var action := PuzzleAction.new()
	action.kind = MOVE
	action.piece_id = piece_id
	action.direction = direction
	action.landing = landing
	return action

static func exit_through(piece_id: String, gate_id: String) -> PuzzleAction:
	var action := PuzzleAction.new()
	action.kind = EXIT
	action.piece_id = piece_id
	action.gate_id = gate_id
	return action

func canonical_text() -> String:
	if kind == MOVE:
		return "move %s %s %d,%d" % [piece_id, direction, landing.x, landing.y]
	if kind == EXIT:
		return "exit %s %s" % [piece_id, gate_id]
	return "invalid"
