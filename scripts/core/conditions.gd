class_name Conditions
extends RefCounted
## Pure, deterministic evaluation of trigger/unlock conditions against a PuzzleState.
## No side effects. Event history is read from the state: a piece_exited condition
## is satisfied once that piece is inactive; color_exits_at_least reads the cumulative
## per-color exit counters the engine maintains on the state.

## Evaluate a schema-valid condition node. `event` and `type` are synonyms.
static func satisfied(node: Dictionary, state: PuzzleState) -> bool:
	if node.has("all"):
		for sub in node["all"]:
			if typeof(sub) != TYPE_DICTIONARY or not satisfied(sub, state):
				return false
		return true
	if node.has("any"):
		for sub in node["any"]:
			if typeof(sub) == TYPE_DICTIONARY and satisfied(sub, state):
				return true
		return false
	var event := str(node.get("event", node.get("type", "")))
	if event == "piece_exited":
		var pid := str(node.get("piece_id", ""))
		return state.pieces.has(pid) and not bool(state.pieces[pid]["active"])
	if event == "color_exits_at_least":
		var color := str(node.get("color", ""))
		var count := int(node.get("count", 1))
		return int(state.event_counters.get(color, 0)) >= count
	return false
