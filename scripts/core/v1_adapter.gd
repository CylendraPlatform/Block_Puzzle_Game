class_name V1Adapter
extends RefCounted
## Non-destructive map from a legacy level dictionary to schema_version 2.
## Does not write files, progress.save, or the caller's dictionary.

static func to_v2(data: Dictionary) -> Dictionary:
	var legacy_id := int(data.get("id", 0))
	var pieces: Array = []
	for block in data.get("blocks", []):
		if typeof(block) != TYPE_DICTIONARY:
			continue
		pieces.append({
			"id": str(block.get("id", "")),
			"cells": _copy_cells(block.get("cells", [[0, 0]])),
			"pos": _copy_pair(block.get("pos", [0, 0])),
			"color": str(block.get("color", "red")),
			"required": true,
			"reveal": "visible",
		})
	var gates: Array = []
	var index := 0
	for gate in data.get("gates", []):
		if typeof(gate) != TYPE_DICTIONARY:
			continue
		var side := str(gate.get("side", "right"))
		var color := str(gate.get("color", "red"))
		var lo := int(gate.get("lo", 0))
		var hi := int(gate.get("hi", 0))
		var gate_id := str(gate.get("id", ""))
		if gate_id.is_empty():
			gate_id = "g%d_%s_%s_%d_%d" % [index, side, color, lo, hi]
		gates.append({
			"id": gate_id,
			"side": side,
			"lo": lo,
			"hi": hi,
			"accept": [color],
			"initial_state": "open",
		})
		index += 1
	return {
		"schema_version": 2,
		"id": "legacy-%d" % legacy_id,
		"legacy_index": legacy_id,
		"name": str(data.get("name", "")),
		"board": {
			"cols": int(data.get("cols", 5)),
			"rows": int(data.get("rows", 5)),
			"walls": _copy_cells(data.get("walls", [])),
		},
		"rules": {"rotation": false, "timer_seconds": null},
		"pieces": pieces,
		"gates": gates,
		"triggers": [],
		"goals": {"all_required_pieces_exited": true},
		"authored_metrics": {"par": int(data.get("par", 0)), "source": "v1"},
	}

static func _copy_pair(value) -> Array:
	if typeof(value) != TYPE_ARRAY or value.size() < 2:
		return [0, 0]
	return [int(value[0]), int(value[1])]

static func _copy_cells(value) -> Array:
	var out: Array = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for cell in value:
		out.append(_copy_pair(cell))
	return out
