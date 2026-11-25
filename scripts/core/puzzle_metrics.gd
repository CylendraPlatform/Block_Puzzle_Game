class_name PuzzleMetrics
extends RefCounted
## Deterministic difficulty measurements on top of SolverV2.
## Movement stays in PuzzleEngine. This module only reads searches.
##
## Ceilings, all counted in expanded states (SolverV2 pops):
## - main search: the cap passed to evaluate(), intended around 80000
## - shortest-path count: PATH_COUNT_CAP; a stopped count is a lower bound
## - one-piece counterfactuals: COUNTERFACTUAL_CAP
## There is no wall-clock kill. UNKNOWN_CAP_REACHED is not unsolvable,
## and shortest_proven is true only after a completed SOLVED search.

const PATH_COUNT_CAP := 80000
const COUNTERFACTUAL_CAP := 5000

static func evaluate(definition: Dictionary, max_states: int = 80000) -> Dictionary:
	var started := Time.get_ticks_msec()
	var initial := PuzzleState.from_definition(definition)
	var solved := SolverV2.solve(definition, initial, max_states)
	var elapsed := Time.get_ticks_msec() - started
	var status := str(solved["status"])
	var proven := status == PuzzleEngine.SOLVED
	var length := int(solved["solution_length"]) if proven else -1
	var witness: Array = solved["witness"] if proven else []
	var replay := _replay(definition, initial, witness) if proven else {"ok": false, "texts": [], "counts": []}
	var paths := _count_shortest(definition, initial, length) if proven else {"count": 0, "complete": false, "explored": 0}
	var dependencies := _dependencies(definition, witness) if proven else {"pieces": [], "proven": false}
	var reach := _reachability(definition)
	var info := Engine.get_version_info()
	return {
		"level_id": str(definition.get("id", "")),
		"godot": "%s.%s.%s" % [info.get("major", 0), info.get("minor", 0), info.get("patch", 0)],
		"search_cap": max_states,
		"status": status,
		"shortest_proven": proven,
		"solution_length": length,
		"explored_states": int(solved["explored_states"]),
		"elapsed_ms": elapsed,
		"initial_state_hash": initial.canonical_hash(),
		"level_signature": _signature(definition),
		"witness": replay["texts"],
		"witness_replayed": bool(replay["ok"]),
		"branching": _branching(replay["counts"]),
		"shortest_path_count": int(paths["count"]),
		"shortest_path_count_complete": bool(paths["complete"]),
		"path_count_explored": int(paths["explored"]),
		"path_count_cap": PATH_COUNT_CAP,
		"dependencies": dependencies["pieces"],
		"dependency_proven": bool(dependencies["proven"]),
		"unreachable_cells": reach["cells"],
		"unreachable_gates": reach["gates"],
		"diagnostics": _diagnostic_text(solved["diagnostics"]),
		"ceilings": {
			"expansion_cap": max_states,
			"path_count_cap": PATH_COUNT_CAP,
			"counterfactual_cap": COUNTERFACTUAL_CAP,
			"wall_clock_kill": false,
		},
	}

static func csv_header() -> String:
	return "level_id,status,shortest_proven,solution_length,explored_states,elapsed_ms,shortest_path_count,shortest_path_count_complete,branch_min,branch_max,branch_mean,dependency_proven,unreachable_cells"

static func csv_row(metrics: Dictionary) -> String:
	var branching: Dictionary = metrics["branching"]
	return "%s,%s,%s,%d,%d,%d,%d,%s,%d,%d,%.3f,%s,%d" % [
		metrics["level_id"],
		metrics["status"],
		str(bool(metrics["shortest_proven"])).to_lower(),
		int(metrics["solution_length"]),
		int(metrics["explored_states"]),
		int(metrics["elapsed_ms"]),
		int(metrics["shortest_path_count"]),
		str(bool(metrics["shortest_path_count_complete"])).to_lower(),
		int(branching["min"]),
		int(branching["max"]),
		float(branching["mean"]),
		str(bool(metrics["dependency_proven"])).to_lower(),
		metrics["unreachable_cells"].size(),
	]

static func _replay(definition: Dictionary, initial: PuzzleState, witness: Array) -> Dictionary:
	var cursor := initial.duplicate()
	var texts: Array[String] = []
	var counts: Array[int] = []
	for action in witness:
		if not (action is PuzzleAction):
			return {"ok": false, "texts": texts, "counts": counts}
		var matched: PuzzleAction = action
		counts.append(PuzzleEngine.legal_actions(definition, cursor).size())
		var applied: Dictionary = PuzzleEngine.transition(cursor, matched, definition)
		if not bool(applied["ok"]):
			return {"ok": false, "texts": texts, "counts": counts}
		texts.append(matched.canonical_text())
		cursor = applied["next_state"]
	var won := PuzzleEngine.is_won(definition, cursor) and cursor.move_number == initial.move_number + witness.size()
	return {"ok": won, "texts": texts, "counts": counts}

static func _branching(counts: Array) -> Dictionary:
	if counts.is_empty():
		return {"min": 0, "max": 0, "mean": 0.0, "bottleneck_step": -1, "counts": []}
	var low := int(counts[0])
	var high := low
	var total := 0
	var bottleneck := 0
	for index in counts.size():
		var value := int(counts[index])
		total += value
		if value < low:
			low = value
			bottleneck = index
		high = maxi(high, value)
	return {
		"min": low,
		"max": high,
		"mean": float(total) / float(counts.size()),
		"bottleneck_step": bottleneck,
		"counts": counts,
	}

static func _count_shortest(definition: Dictionary, initial: PuzzleState, length: int) -> Dictionary:
	if length < 0:
		return {"count": 0, "complete": false, "explored": 0}
	if length == 0:
		return {"count": 1, "complete": true, "explored": 0}
	var context := PuzzleSearchContext.new()
	context.schema_checked = true
	context.geometry = PuzzleEngine._geometry(definition)
	context.walls = PuzzleEngine._wall_cells(definition)
	context.bounds = PuzzleEngine._bounds(definition)
	var start_key := initial.search_key()
	var ways := {start_key: 1}
	var depth := {start_key: 0}
	var queue: Array = [initial]
	var head := 0
	var explored := 0
	var total := 0
	while head < queue.size():
		var current: PuzzleState = queue[head]
		head += 1
		var current_depth := int(depth[current.search_key()])
		if current_depth >= length:
			break
		if explored >= PATH_COUNT_CAP:
			return {"count": total, "complete": false, "explored": explored}
		explored += 1
		var current_ways := int(ways[current.search_key()])
		for action in PuzzleEngine.legal_actions(definition, current, "", context):
			var applied: Dictionary = PuzzleEngine.transition(current, action, definition, context)
			if not bool(applied["ok"]):
				continue
			var next: PuzzleState = applied["next_state"]
			var next_depth := current_depth + 1
			var key := next.search_key()
			if PuzzleEngine.is_won(definition, next, context):
				if next_depth == length:
					total += current_ways
				continue
			if not depth.has(key):
				depth[key] = next_depth
				ways[key] = current_ways
				queue.append(next)
			elif int(depth[key]) == next_depth:
				ways[key] = int(ways[key]) + current_ways
	return {"count": total, "complete": true, "explored": explored}

static func _dependencies(definition: Dictionary, witness: Array) -> Dictionary:
	var pieces: Array = definition.get("pieces", [])
	var delays := _delays(witness)
	var rows: Array = []
	var proven := false
	for piece in pieces:
		if typeof(piece) != TYPE_DICTIONARY:
			continue
		var piece_id := str(piece.get("id", ""))
		var solo := _solve_variant(_only_piece(definition, piece_id), COUNTERFACTUAL_CAP)
		var blocked: Array[String] = []
		for other in pieces:
			if typeof(other) != TYPE_DICTIONARY or str(other.get("id", "")) == piece_id:
				continue
			if _obstacle_changes(definition, piece_id, other, solo):
				blocked.append(str(other.get("id", "")))
		if not blocked.is_empty():
			proven = true
		var delay: Dictionary = delays.get(piece_id, {"delay": -1, "actions": 0})
		rows.append({
			"id": piece_id,
			"solo_status": solo["status"],
			"solo_length": solo["length"],
			"blocked_by": blocked,
			"witness_actions": int(delay["actions"]),
			"delay_before_exit": int(delay["delay"]),
		})
	return {"pieces": rows, "proven": proven}

static func _obstacle_changes(definition: Dictionary, mover_id: String, obstacle: Dictionary, solo: Dictionary) -> bool:
	var walled := _only_piece(definition, mover_id)
	var board: Dictionary = walled["board"].duplicate(true)
	var walls: Array = board.get("walls", []).duplicate()
	for cell in _absolute_cells(obstacle):
		walls.append(cell)
	board["walls"] = walls
	walled["board"] = board
	var blocked := _solve_variant(walled, COUNTERFACTUAL_CAP)
	if str(solo["status"]) != PuzzleEngine.SOLVED:
		return false
	if str(blocked["status"]) == PuzzleEngine.UNKNOWN_CAP_REACHED:
		return false
	if str(blocked["status"]) != PuzzleEngine.SOLVED:
		return true
	return int(blocked["length"]) > int(solo["length"])

static func _only_piece(definition: Dictionary, piece_id: String) -> Dictionary:
	var copy: Dictionary = definition.duplicate(true)
	var kept: Array = []
	for piece in copy.get("pieces", []):
		if typeof(piece) == TYPE_DICTIONARY and str(piece.get("id", "")) == piece_id:
			kept.append(piece)
	copy["pieces"] = kept
	return copy

static func _solve_variant(definition: Dictionary, cap: int) -> Dictionary:
	var result := SolverV2.solve(definition, PuzzleState.from_definition(definition), cap)
	var status := str(result["status"])
	return {
		"status": status,
		"length": int(result["solution_length"]) if status == PuzzleEngine.SOLVED else -1,
	}

static func _delays(witness: Array) -> Dictionary:
	var out := {}
	for action in witness:
		if not (action is PuzzleAction):
			continue
		var matched: PuzzleAction = action
		var piece_id: String = matched.piece_id
		if not out.has(piece_id):
			out[piece_id] = {"delay": -1, "actions": 0, "exited": false}
		out[piece_id]["actions"] = int(out[piece_id]["actions"]) + 1
		if matched.kind == PuzzleAction.EXIT and not bool(out[piece_id]["exited"]):
			var earlier := 0
			for prior in witness:
				if prior == matched:
					break
				if prior is PuzzleAction and (prior as PuzzleAction).piece_id != piece_id:
					earlier += 1
			out[piece_id]["delay"] = earlier
			out[piece_id]["exited"] = true
	return out

static func _reachability(definition: Dictionary) -> Dictionary:
	var board: Dictionary = definition.get("board", {})
	var cols := _whole(board.get("cols", 0))
	var rows := _whole(board.get("rows", 0))
	var walls := {}
	for wall in board.get("walls", []):
		var cell := _pair(wall)
		if cell != Vector2i(-1, -1):
			walls[cell] = true
	var seen := {}
	var queue: Array[Vector2i] = []
	for piece in definition.get("pieces", []):
		if typeof(piece) != TYPE_DICTIONARY:
			continue
		for cell in _absolute_cells(piece):
			var pos := Vector2i(int(cell[0]), int(cell[1]))
			if seen.has(pos):
				continue
			seen[pos] = true
			queue.append(pos)
	var head := 0
	var steps := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for step in steps:
			var next: Vector2i = current + step
			if next.x < 0 or next.y < 0 or next.x >= cols or next.y >= rows:
				continue
			if walls.has(next) or seen.has(next):
				continue
			seen[next] = true
			queue.append(next)
	var missing: Array[String] = []
	for y in rows:
		for x in cols:
			var pos := Vector2i(x, y)
			if walls.has(pos) or seen.has(pos):
				continue
			missing.append("%d,%d" % [x, y])
	var closed: Array[String] = []
	for gate in definition.get("gates", []):
		if typeof(gate) != TYPE_DICTIONARY:
			continue
		var side := str(gate.get("side", ""))
		var lo := _whole(gate.get("lo", 0))
		var hi := _whole(gate.get("hi", -1))
		var open := false
		for index in range(lo, hi + 1):
			var pos := Vector2i.ZERO
			match side:
				"left":
					pos = Vector2i(0, index)
				"right":
					pos = Vector2i(cols - 1, index)
				"top":
					pos = Vector2i(index, 0)
				"bottom":
					pos = Vector2i(index, rows - 1)
				_:
					continue
			if not walls.has(pos) and seen.has(pos):
				open = true
		if not open:
			closed.append(str(gate.get("id", "")))
	return {"cells": missing, "gates": closed}

static func _absolute_cells(piece: Dictionary) -> Array:
	var out: Array = []
	var pos = piece.get("pos", [])
	if typeof(pos) != TYPE_ARRAY or pos.size() != 2:
		return out
	var origin_x := _whole(pos[0])
	var origin_y := _whole(pos[1])
	for cell in piece.get("cells", []):
		var parsed := _pair(cell)
		if parsed == Vector2i(-1, -1):
			continue
		out.append([origin_x + parsed.x, origin_y + parsed.y])
	return out

static func _signature(definition: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("id=%s" % str(definition.get("id", "")))
	var board: Dictionary = definition.get("board", {})
	lines.append("board=%d,%d" % [_whole(board.get("cols", 0)), _whole(board.get("rows", 0))])
	var walls: Array = []
	for wall in board.get("walls", []):
		var parsed := _pair(wall)
		if parsed != Vector2i(-1, -1):
			walls.append("%d,%d" % [parsed.x, parsed.y])
	walls.sort()
	lines.append("walls=%s" % ",".join(walls))
	var piece_ids: Array = []
	var piece_rows := {}
	for piece in definition.get("pieces", []):
		if typeof(piece) != TYPE_DICTIONARY:
			continue
		var piece_id := str(piece.get("id", ""))
		piece_ids.append(piece_id)
		var cells: Array = []
		for cell in piece.get("cells", []):
			var parsed := _pair(cell)
			if parsed != Vector2i(-1, -1):
				cells.append("%d,%d" % [parsed.x, parsed.y])
		cells.sort()
		var pos := _pair(piece.get("pos", []))
		piece_rows[piece_id] = "%s %s %d,%d %s" % [piece_id, str(piece.get("color", "")), pos.x, pos.y, "|".join(cells)]
	piece_ids.sort()
	for piece_id in piece_ids:
		lines.append("piece %s" % str(piece_rows[piece_id]))
	var gate_ids: Array = []
	var gate_rows := {}
	for gate in definition.get("gates", []):
		if typeof(gate) != TYPE_DICTIONARY:
			continue
		var gate_id := str(gate.get("id", ""))
		gate_ids.append(gate_id)
		var accept: Array = []
		for color in gate.get("accept", []):
			accept.append(str(color))
		accept.sort()
		gate_rows[gate_id] = "%s %s %d %d %s" % [gate_id, str(gate.get("side", "")), _whole(gate.get("lo", 0)), _whole(gate.get("hi", 0)), "|".join(accept)]
	gate_ids.sort()
	for gate_id in gate_ids:
		lines.append("gate %s" % str(gate_rows[gate_id]))
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update("\n".join(lines).to_utf8_buffer())
	return ctx.finish().hex_encode()

static func _diagnostic_text(diagnostics: Array) -> Array:
	var out: Array[String] = []
	for item in diagnostics:
		if typeof(item) == TYPE_DICTIONARY:
			out.append("%s %s %s" % [item.get("code", ""), item.get("path", ""), item.get("message", "")])
		else:
			out.append(str(item))
	return out

static func _pair(value) -> Vector2i:
	if typeof(value) != TYPE_ARRAY or value.size() != 2:
		return Vector2i(-1, -1)
	var x: Variant = LevelValidator.as_whole_int(value[0])
	var y: Variant = LevelValidator.as_whole_int(value[1])
	if x == null or y == null:
		return Vector2i(-1, -1)
	return Vector2i(int(x), int(y))

static func _whole(value) -> int:
	var parsed: Variant = LevelValidator.as_whole_int(value)
	if parsed == null:
		return 0
	return int(parsed)
