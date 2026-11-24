class_name PuzzleState
extends RefCounted
## Canonical mutable puzzle facts. Geometry stays on the level definition.
## Timer, wallet, and animation progress are not part of this state.

var schema_version := 2
var level_id := ""
var pieces := {}
var gates := {}
var blockers := {}
var event_counters := {}
var trigger_fired := {}
var move_number := 0

static func from_definition(definition: Dictionary) -> PuzzleState:
	var state := PuzzleState.new()
	state.schema_version = int(definition.get("schema_version", 2))
	state.level_id = str(definition.get("id", ""))
	for piece in definition.get("pieces", []):
		if typeof(piece) != TYPE_DICTIONARY:
			continue
		var id := str(piece.get("id", ""))
		var pos = piece.get("pos", null)
		if typeof(pos) != TYPE_ARRAY or pos.size() != 2:
			continue
		var px: Variant = LevelValidator.as_whole_int(pos[0])
		var py: Variant = LevelValidator.as_whole_int(pos[1])
		if px == null or py == null:
			continue
		state.pieces[id] = {
			"pos": Vector2i(int(px), int(py)),
			"active": true,
			"revealed": str(piece.get("reveal", "visible")) != "hidden",
		}
	for gate in definition.get("gates", []):
		if typeof(gate) != TYPE_DICTIONARY:
			continue
		var remaining := -1
		if gate.get("counter", null) is Dictionary:
			var rem: Variant = LevelValidator.as_whole_int(gate["counter"].get("remaining", null))
			if rem != null and int(rem) >= 0:
				remaining = int(rem)
		state.gates[str(gate.get("id", ""))] = {
			"mode": "LOCKED" if str(gate.get("initial_state", "open")) == "locked" else "OPEN",
			"counter_remaining": remaining,
		}
	for blocker in definition.get("blockers", []):
		if typeof(blocker) != TYPE_DICTIONARY:
			continue
		var blocker_remaining := -1
		if blocker.has("counter_remaining"):
			var rem: Variant = LevelValidator.as_whole_int(blocker["counter_remaining"])
			if rem != null and int(rem) >= 0:
				blocker_remaining = int(rem)
		state.blockers[str(blocker.get("id", ""))] = {
			"active": true,
			"counter_remaining": blocker_remaining,
		}
	for trigger in definition.get("triggers", []):
		if typeof(trigger) == TYPE_DICTIONARY:
			state.trigger_fired[str(trigger.get("id", ""))] = false
	return state

func duplicate() -> PuzzleState:
	var copy := PuzzleState.new()
	copy.schema_version = schema_version
	copy.level_id = level_id
	copy.move_number = move_number
	for id in pieces.keys():
		var piece: Dictionary = pieces[id]
		copy.pieces[id] = {
			"pos": piece["pos"],
			"active": bool(piece["active"]),
			"revealed": bool(piece["revealed"]),
		}
	for id in gates.keys():
		var gate: Dictionary = gates[id]
		copy.gates[id] = {
			"mode": str(gate["mode"]),
			"counter_remaining": int(gate["counter_remaining"]),
		}
	for id in blockers.keys():
		var blocker: Dictionary = blockers[id]
		copy.blockers[id] = {
			"active": bool(blocker["active"]),
			"counter_remaining": int(blocker["counter_remaining"]),
		}
	for id in event_counters.keys():
		copy.event_counters[id] = int(event_counters[id])
	for id in trigger_fired.keys():
		copy.trigger_fired[id] = bool(trigger_fired[id])
	return copy

func canonical_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("schema=%d" % schema_version)
	lines.append("level=%s" % level_id)
	lines.append("move=%d" % move_number)
	for id in _sorted(pieces):
		var piece: Dictionary = pieces[id]
		var pos: Vector2i = piece["pos"]
		lines.append("piece %s active=%d pos=%d,%d revealed=%d" % [id, int(bool(piece["active"])), pos.x, pos.y, int(bool(piece["revealed"]))])
	for id in _sorted(gates):
		var gate: Dictionary = gates[id]
		var counter := int(gate["counter_remaining"])
		var counter_text := "none" if counter < 0 else str(counter)
		lines.append("gate %s mode=%s counter=%s" % [id, str(gate["mode"]), counter_text])
	for id in _sorted(blockers):
		var blocker: Dictionary = blockers[id]
		lines.append("blocker %s active=%d counter=%d" % [id, int(bool(blocker["active"])), int(blocker["counter_remaining"])])
	for id in _sorted(event_counters):
		lines.append("counter %s %d" % [id, int(event_counters[id])])
	for id in _sorted(trigger_fired):
		lines.append("trigger %s %d" % [id, int(bool(trigger_fired[id]))])
	return "\n".join(lines)

func canonical_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(canonical_text().to_utf8_buffer())
	return ctx.finish().hex_encode()

static func _sorted(source: Dictionary) -> Array:
	var keys: Array = source.keys()
	keys.sort()
	return keys
