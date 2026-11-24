class_name PuzzleEvent
extends RefCounted
## Ordered event envelope. TD-1 records the shape and sort order.
## The engine does not emit these until movement and triggers exist.

const PIECE_MOVED := "PieceMoved"
const PIECE_EXITED := "PieceExited"
const GATE_COUNTER_CHANGED := "GateCounterChanged"
const GATE_UNLOCKED := "GateUnlocked"
const PIECE_REVEALED := "PieceRevealed"
const BLOCKER_REMOVED := "BlockerRemoved"

var type := ""
var subject_id := ""
var priority := 0

static func make(event_type: String, subject: String, event_priority: int = 0) -> PuzzleEvent:
	var event := PuzzleEvent.new()
	event.type = event_type
	event.subject_id = subject
	event.priority = event_priority
	return event

func canonical_text() -> String:
	return "%d %s %s" % [priority, type, subject_id]

## Lower priority first, then type, then subject id. Does not run effects.
static func sort_stable(events: Array) -> Array:
	var ordered := events.duplicate()
	ordered.sort_custom(func(left, right):
		if left.priority != right.priority:
			return left.priority < right.priority
		if left.type != right.type:
			return left.type < right.type
		return left.subject_id < right.subject_id
	)
	return ordered
