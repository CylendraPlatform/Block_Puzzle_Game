class_name LevelValidator
extends RefCounted
## Strict checks for schema_version 2. Diagnostics are data, not UI copy.
## This does not execute triggers, counters, or movement.
## Optional fields and their defaults are documented in docs/v2/SCHEMA_V2.md.

const COLORS := ["red", "blue", "green", "yellow", "orange", "purple"]
const SIDES := ["left", "right", "top", "bottom"]
const GATE_STATES := ["open", "locked"]
const REVEALS := ["visible", "hidden"]
const CONDITION_EVENTS := ["piece_exited", "color_exits_at_least"]
const EFFECT_TYPES := ["reveal_piece", "unlock_gate", "decrement_counter", "remove_blocker"]
const TOP_LEVEL := ["schema_version", "id", "name", "chapter", "board", "rules", "pieces", "gates", "triggers", "blockers", "goals", "authored_metrics", "legacy_index"]
const BOARD_FIELDS := ["cols", "rows", "walls"]
const RULE_FIELDS := ["rotation", "timer_seconds"]
const PIECE_FIELDS := ["id", "cells", "pos", "color", "required", "reveal"]
const GATE_FIELDS := ["id", "side", "lo", "hi", "accept", "initial_state", "unlock_when", "counter"]
const TRIGGER_FIELDS := ["id", "when", "effect"]
const BLOCKER_FIELDS := ["id", "cell", "counter_remaining"]
const COUNTER_FIELDS := ["remaining"]

static func as_whole_int(value) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value)
	return null

static func validate_v2(data: Dictionary) -> Array:
	var diags: Array = []
	var version: Variant = as_whole_int(data.get("schema_version", null))
	if version == null or int(version) != 2:
		diags.append(_diag("UNSUPPORTED_VERSION", "schema_version", "schema_version must be the integer 2."))
		return diags
	_reject_unknown(data, TOP_LEVEL, "", diags)
	_require_id(data, "id", "id", diags)
	if not data.has("name"):
		diags.append(_diag("MISSING_FIELD", "name", "Level name is required."))
	elif typeof(data["name"]) != TYPE_STRING:
		diags.append(_diag("INVALID_TYPE", "name", "Level name must be a string."))
	_optional_whole(data, "chapter", "chapter", 0, diags)
	_optional_whole(data, "legacy_index", "legacy_index", 0, diags)
	var board = data.get("board", null)
	if typeof(board) != TYPE_DICTIONARY:
		diags.append(_diag("MISSING_FIELD", "board", "board is required."))
		return diags
	_reject_unknown(board, BOARD_FIELDS, "board", diags)
	var cols: Variant = _required_whole(board, "cols", "board.cols", 1, diags)
	var rows: Variant = _required_whole(board, "rows", "board.rows", 1, diags)
	var cols_i := 0 if cols == null else int(cols)
	var rows_i := 0 if rows == null else int(rows)
	var wall_set := {}
	_check_walls(board, cols_i, rows_i, wall_set, diags)
	_check_rules(data, diags)
	var pieces = data.get("pieces", null)
	if not data.has("pieces"):
		diags.append(_diag("MISSING_FIELD", "pieces", "pieces is required."))
		pieces = []
	elif typeof(pieces) != TYPE_ARRAY:
		diags.append(_diag("INVALID_TYPE", "pieces", "pieces must be an array."))
		pieces = []
	elif pieces.is_empty():
		diags.append(_diag("MISSING_FIELD", "pieces", "At least one piece is required."))
	var ids := {}
	var occupied := wall_set.duplicate()
	for i in pieces.size():
		_check_piece(pieces[i], i, cols_i, rows_i, ids, occupied, diags)
	if not data.has("gates"):
		diags.append(_diag("MISSING_FIELD", "gates", "gates is required."))
	var gates = data.get("gates", [])
	if typeof(gates) != TYPE_ARRAY:
		if data.has("gates"):
			diags.append(_diag("INVALID_TYPE", "gates", "gates must be an array."))
		gates = []
	var spans := {"left": [], "right": [], "top": [], "bottom": []}
	var counters := {}
	for i in gates.size():
		_check_gate(gates[i], i, cols_i, rows_i, ids, spans, counters, diags)
	_check_trigger_list(data, ids, diags)
	_check_blockers(data, cols_i, rows_i, ids, occupied, diags)
	_check_goals(data, diags)
	_check_metrics(data, diags)
	_check_references(data, ids, counters, diags)
	_check_gate_unlock_sources(data, diags)
	return diags

## A locked gate opens via exactly one source: its own unlock_when, its own counter,
## or an external unlock_gate trigger. An open gate must have no unlock source. This
## pass needs the trigger list, so it runs after per-gate checks.
static func _check_gate_unlock_sources(data: Dictionary, diags: Array) -> void:
	var gates = data.get("gates", [])
	if typeof(gates) != TYPE_ARRAY:
		return
	var unlock_targets := {}
	var triggers = data.get("triggers", [])
	if typeof(triggers) == TYPE_ARRAY:
		for trigger in triggers:
			if typeof(trigger) != TYPE_DICTIONARY:
				continue
			var effect = trigger.get("effect", null)
			if typeof(effect) == TYPE_DICTIONARY and str(effect.get("type", "")) == "unlock_gate":
				var target := str(effect.get("gate_id", ""))
				unlock_targets[target] = int(unlock_targets.get(target, 0)) + 1
	for i in gates.size():
		var gate = gates[i]
		if typeof(gate) != TYPE_DICTIONARY:
			continue
		var gid := str(gate.get("id", ""))
		var path := "gates[%d]" % i
		var has_external: bool = int(unlock_targets.get(gid, 0)) > 0
		var self_sources := int(gate.has("unlock_when")) + int(gate.has("counter"))
		if str(gate.get("initial_state", "open")) == "open":
			if has_external:
				diags.append(_diag("GATE_STATE_CONFLICT", path, "An open gate must not be the target of an unlock_gate trigger."))
			continue
		var total := self_sources + int(has_external)
		if total == 0:
			diags.append(_diag("GATE_STATE_CONFLICT", path, "A locked gate needs an unlock source (unlock_when, counter, or an unlock_gate trigger)."))
		elif total > 1:
			diags.append(_diag("GATE_STATE_CONFLICT", path, "A locked gate must have exactly one unlock source."))

static func _check_walls(board: Dictionary, cols: int, rows: int, wall_set: Dictionary, diags: Array) -> void:
	if not board.has("walls"):
		return
	var walls = board["walls"]
	if typeof(walls) != TYPE_ARRAY:
		diags.append(_diag("INVALID_TYPE", "board.walls", "walls must be an array of [x, y] pairs."))
		return
	for i in walls.size():
		var cell: Variant = _cell(walls[i])
		if cell == null:
			diags.append(_diag("INVALID_COORDINATE", "board.walls[%d]" % i, "Wall must be exactly two integer coordinates."))
			continue
		if not _inside(cell, cols, rows):
			diags.append(_diag("OUT_OF_BOUNDS", "board.walls[%d]" % i, "Wall %s is outside the board." % str(cell)))
		elif wall_set.has(cell):
			diags.append(_diag("OVERLAP", "board.walls[%d]" % i, "Duplicate wall at %s." % str(cell)))
		else:
			wall_set[cell] = true

static func _check_rules(data: Dictionary, diags: Array) -> void:
	if not data.has("rules"):
		return
	var rules = data["rules"]
	if typeof(rules) != TYPE_DICTIONARY:
		diags.append(_diag("INVALID_TYPE", "rules", "rules must be an object."))
		return
	_reject_unknown(rules, RULE_FIELDS, "rules", diags)
	if rules.has("rotation"):
		if typeof(rules["rotation"]) != TYPE_BOOL:
			diags.append(_diag("INVALID_TYPE", "rules.rotation", "rotation must be a boolean."))
		elif bool(rules["rotation"]):
			diags.append(_diag("UNSUPPORTED_MECHANIC", "rules.rotation", "Piece rotation is not a supported mechanic."))
	if rules.has("timer_seconds") and rules["timer_seconds"] != null:
		diags.append(_diag("UNSUPPORTED_MECHANIC", "rules.timer_seconds", "Timers are session state and are not accepted on a puzzle definition in TD-1."))

static func _check_piece(piece, index: int, cols: int, rows: int, ids: Dictionary, occupied: Dictionary, diags: Array) -> void:
	var path := "pieces[%d]" % index
	if typeof(piece) != TYPE_DICTIONARY:
		diags.append(_diag("INVALID_TYPE", path, "Piece must be an object."))
		return
	_reject_unknown(piece, PIECE_FIELDS, path, diags)
	var id := _require_id(piece, "id", path + ".id", diags)
	if not id.is_empty():
		if ids.has(id):
			diags.append(_diag("DUPLICATE_ID", path + ".id", "Duplicate id '%s'." % id))
		else:
			ids[id] = "piece"
	if not piece.has("color"):
		diags.append(_diag("MISSING_FIELD", path + ".color", "Piece color is required."))
	elif typeof(piece["color"]) != TYPE_STRING:
		diags.append(_diag("INVALID_TYPE", path + ".color", "Piece color must be a string."))
	elif not COLORS.has(piece["color"]):
		diags.append(_diag("INVALID_COLOR", path + ".color", "Color '%s' is not a logical color." % piece["color"]))
	if piece.has("reveal"):
		if typeof(piece["reveal"]) != TYPE_STRING or not REVEALS.has(piece["reveal"]):
			diags.append(_diag("INVALID_TYPE", path + ".reveal", "reveal must be visible or hidden."))
	if piece.has("required") and typeof(piece["required"]) != TYPE_BOOL:
		diags.append(_diag("INVALID_TYPE", path + ".required", "required must be a boolean."))
	var origin_ok := false
	var origin := Vector2i.ZERO
	if not piece.has("pos") or typeof(piece["pos"]) != TYPE_ARRAY:
		diags.append(_diag("MISSING_FIELD", path + ".pos", "Piece pos must be [x, y]."))
	elif piece["pos"].size() != 2:
		diags.append(_diag("INVALID_COORDINATE", path + ".pos", "Piece pos must be exactly two coordinates."))
	else:
		var px: Variant = as_whole_int(piece["pos"][0])
		var py: Variant = as_whole_int(piece["pos"][1])
		if px == null or py == null:
			diags.append(_diag("INVALID_COORDINATE", path + ".pos", "Piece pos must be integer coordinates."))
		else:
			origin = Vector2i(int(px), int(py))
			origin_ok = true
	var cells = piece.get("cells", null)
	if typeof(cells) != TYPE_ARRAY or cells.is_empty():
		diags.append(_diag("MISSING_FIELD", path + ".cells", "Piece cells are required."))
		return
	var offsets: Array[Vector2i] = []
	var local := {}
	for c in cells.size():
		var offset: Variant = _cell(cells[c])
		if offset == null:
			diags.append(_diag("INVALID_COORDINATE", path + ".cells[%d]" % c, "Cell must be exactly two integer coordinates."))
			continue
		if local.has(offset):
			diags.append(_diag("OVERLAP", path + ".cells[%d]" % c, "Duplicate cell in piece '%s'." % id))
		local[offset] = true
		offsets.append(offset)
		if not origin_ok:
			continue
		var abs_cell: Vector2i = origin + offset
		if not _inside(abs_cell, cols, rows):
			diags.append(_diag("OUT_OF_BOUNDS", path, "Piece '%s' occupies %s outside the board." % [id, str(abs_cell)]))
		elif occupied.has(abs_cell):
			diags.append(_diag("OVERLAP", path, "Piece '%s' overlaps %s." % [id, str(abs_cell)]))
		else:
			occupied[abs_cell] = id
	if not _connected(offsets):
		diags.append(_diag("DISCONNECTED_PIECE", path + ".cells", "Piece '%s' is not orthogonally connected." % id))

static func _check_gate(gate, index: int, cols: int, rows: int, ids: Dictionary, spans: Dictionary, counters: Dictionary, diags: Array) -> void:
	var path := "gates[%d]" % index
	if typeof(gate) != TYPE_DICTIONARY:
		diags.append(_diag("INVALID_GATE", path, "Gate must be an object."))
		return
	_reject_unknown(gate, GATE_FIELDS, path, diags)
	var id := _require_id(gate, "id", path + ".id", diags)
	if not id.is_empty():
		if ids.has(id):
			diags.append(_diag("DUPLICATE_ID", path + ".id", "Duplicate id '%s'." % id))
		else:
			ids[id] = "gate"
	var side := ""
	if not gate.has("side") or typeof(gate["side"]) != TYPE_STRING or not SIDES.has(gate["side"]):
		diags.append(_diag("INVALID_GATE", path + ".side", "Gate side is invalid."))
	else:
		side = gate["side"]
	var lo: Variant = _required_whole(gate, "lo", path + ".lo", 0, diags)
	var hi: Variant = _required_whole(gate, "hi", path + ".hi", 0, diags)
	var accept = gate.get("accept", null)
	var accept_colors: Array = []
	if typeof(accept) != TYPE_ARRAY or accept.is_empty():
		diags.append(_diag("INVALID_GATE", path + ".accept", "Gate '%s' needs a non-empty accept list." % id))
	else:
		for color in accept:
			if typeof(color) != TYPE_STRING:
				diags.append(_diag("INVALID_TYPE", path + ".accept", "Gate accept colors must be strings."))
			elif not COLORS.has(color):
				diags.append(_diag("INVALID_COLOR", path + ".accept", "Gate '%s' accepts unknown color '%s'." % [id, color]))
			else:
				accept_colors.append(color)
	if side != "" and lo != null and hi != null:
		var lo_i := int(lo)
		var hi_i := int(hi)
		var limit := rows if side == "left" or side == "right" else cols
		if lo_i > hi_i or lo_i < 0 or hi_i >= limit:
			diags.append(_diag("INVALID_GATE", path, "Gate '%s' span %d..%d is outside the %s edge." % [id, lo_i, hi_i, side]))
		else:
			for prev in spans[side]:
				var ranges_overlap: bool = lo_i <= int(prev["hi"]) and int(prev["lo"]) <= hi_i
				if ranges_overlap and _colors_intersect(accept_colors, prev["accept"]):
					diags.append(_diag("OVERLAPPING_GATES", path, "Gate '%s' overlaps '%s' on %s for the same color." % [id, prev["id"], side]))
			spans[side].append({"id": id, "lo": lo_i, "hi": hi_i, "accept": accept_colors})
	if gate.has("initial_state"):
		if typeof(gate["initial_state"]) != TYPE_STRING or not GATE_STATES.has(gate["initial_state"]):
			diags.append(_diag("INVALID_GATE", path + ".initial_state", "initial_state must be open or locked."))
	if gate.has("unlock_when"):
		_check_condition(gate["unlock_when"], path + ".unlock_when", diags)
	if gate.has("counter"):
		if _check_counter(gate["counter"], path + ".counter", diags) and not id.is_empty():
			counters[id] = true
	GateRules.validate_config(gate, path, diags)

static func _check_trigger_list(data: Dictionary, ids: Dictionary, diags: Array) -> void:
	if not data.has("triggers"):
		return
	var triggers = data["triggers"]
	if typeof(triggers) != TYPE_ARRAY:
		diags.append(_diag("INVALID_TYPE", "triggers", "triggers must be an array."))
		return
	for i in triggers.size():
		_check_trigger(triggers[i], i, ids, diags)

static func _check_trigger(trigger, index: int, ids: Dictionary, diags: Array) -> void:
	var path := "triggers[%d]" % index
	if typeof(trigger) != TYPE_DICTIONARY:
		diags.append(_diag("MALFORMED_TRIGGER", path, "Trigger must be an object."))
		return
	_reject_unknown(trigger, TRIGGER_FIELDS, path, diags)
	var id := _require_id(trigger, "id", path + ".id", diags)
	if not id.is_empty():
		if ids.has(id):
			diags.append(_diag("DUPLICATE_ID", path + ".id", "Duplicate id '%s'." % id))
		else:
			ids[id] = "trigger"
	if not trigger.has("when"):
		diags.append(_diag("MALFORMED_TRIGGER", path + ".when", "Trigger when is required."))
	else:
		_check_condition(trigger["when"], path + ".when", diags)
	var effect = trigger.get("effect", null)
	if typeof(effect) != TYPE_DICTIONARY:
		diags.append(_diag("MALFORMED_TRIGGER", path + ".effect", "Trigger effect is required."))
		return
	var kind := ""
	if typeof(effect.get("type", null)) != TYPE_STRING or not EFFECT_TYPES.has(effect["type"]):
		diags.append(_diag("UNSUPPORTED_MECHANIC", path + ".effect.type", "Effect '%s' is not a known typed effect." % str(effect.get("type", ""))))
	else:
		kind = effect["type"]
	var allowed: Array = ["type"]
	if kind == "reveal_piece":
		allowed = ["type", "piece_id"]
	elif kind == "unlock_gate" or kind == "decrement_counter":
		allowed = ["type", "gate_id"]
	elif kind == "remove_blocker":
		allowed = ["type", "blocker_id"]
	_reject_unknown(effect, allowed, path + ".effect", diags)
	if kind == "reveal_piece":
		_require_id(effect, "piece_id", path + ".effect.piece_id", diags)
	elif kind == "unlock_gate" or kind == "decrement_counter":
		_require_id(effect, "gate_id", path + ".effect.gate_id", diags)
	elif kind == "remove_blocker":
		_require_id(effect, "blocker_id", path + ".effect.blocker_id", diags)

static func _check_condition(node, path: String, diags: Array) -> void:
	if typeof(node) != TYPE_DICTIONARY:
		diags.append(_diag("MALFORMED_TRIGGER", path, "Condition must be an object."))
		return
	var has_all: bool = node.has("all")
	var has_any: bool = node.has("any")
	if has_all and has_any:
		diags.append(_diag("MALFORMED_TRIGGER", path, "A condition cannot be both all and any."))
		return
	if has_all or has_any:
		var key := "all" if has_all else "any"
		_reject_unknown(node, [key], path, diags)
		if typeof(node[key]) != TYPE_ARRAY or node[key].is_empty():
			diags.append(_diag("MALFORMED_TRIGGER", path + "." + key, "Compound condition needs a non-empty list."))
			return
		for i in node[key].size():
			_check_condition(node[key][i], "%s.%s[%d]" % [path, key, i], diags)
		return
	var has_event: bool = node.has("event")
	var has_type: bool = node.has("type")
	if has_event and has_type:
		diags.append(_diag("MALFORMED_TRIGGER", path, "Use either event or type, not both."))
		return
	if not has_event and not has_type:
		diags.append(_diag("MALFORMED_TRIGGER", path, "Condition needs event or type."))
		return
	var event_key := "event" if has_event else "type"
	if typeof(node[event_key]) != TYPE_STRING or not CONDITION_EVENTS.has(node[event_key]):
		diags.append(_diag("UNSUPPORTED_MECHANIC", path, "Condition '%s' is not a supported typed condition." % str(node[event_key])))
		return
	var event := str(node[event_key])
	if event == "piece_exited":
		_reject_unknown(node, [event_key, "piece_id"], path, diags)
		_require_id(node, "piece_id", path + ".piece_id", diags)
	else:
		_reject_unknown(node, [event_key, "color", "count"], path, diags)
		if typeof(node.get("color", null)) != TYPE_STRING or not COLORS.has(str(node.get("color", ""))):
			diags.append(_diag("INVALID_COLOR", path + ".color", "color_exits_at_least needs a logical color."))
		if not node.has("count"):
			diags.append(_diag("MALFORMED_TRIGGER", path + ".count", "color_exits_at_least requires count."))
		else:
			var count: Variant = as_whole_int(node["count"])
			if count == null or int(count) < 1:
				diags.append(_diag("MALFORMED_TRIGGER", path + ".count", "count must be an integer of at least 1."))

static func _check_counter(counter, path: String, diags: Array) -> bool:
	if typeof(counter) != TYPE_DICTIONARY:
		diags.append(_diag("MALFORMED_TRIGGER", path, "A counter must be an object."))
		return false
	_reject_unknown(counter, COUNTER_FIELDS, path, diags)
	if not counter.has("remaining"):
		diags.append(_diag("MALFORMED_TRIGGER", path + ".remaining", "A counter needs remaining."))
		return false
	var remaining: Variant = as_whole_int(counter["remaining"])
	if remaining == null or int(remaining) < 0:
		diags.append(_diag("MALFORMED_TRIGGER", path + ".remaining", "Counter remaining must be a non-negative integer."))
		return false
	return true

static func _check_blockers(data: Dictionary, cols: int, rows: int, ids: Dictionary, occupied: Dictionary, diags: Array) -> void:
	if not data.has("blockers"):
		return
	var blockers = data["blockers"]
	if typeof(blockers) != TYPE_ARRAY:
		diags.append(_diag("INVALID_TYPE", "blockers", "blockers must be an array."))
		return
	for i in blockers.size():
		var blocker = blockers[i]
		var path := "blockers[%d]" % i
		if typeof(blocker) != TYPE_DICTIONARY:
			diags.append(_diag("INVALID_TYPE", path, "Blocker must be an object."))
			continue
		_reject_unknown(blocker, BLOCKER_FIELDS, path, diags)
		var id := _require_id(blocker, "id", path + ".id", diags)
		if id.is_empty():
			continue
		if ids.has(id):
			diags.append(_diag("DUPLICATE_ID", path + ".id", "Duplicate id '%s'." % id))
		else:
			ids[id] = "blocker"
		var cell: Variant = _cell(blocker.get("cell", null))
		if cell == null or not _inside(cell, cols, rows):
			diags.append(_diag("OUT_OF_BOUNDS", path + ".cell", "Blocker '%s' needs an in-bounds cell of two integer coordinates." % id))
		elif occupied.has(cell):
			diags.append(_diag("OVERLAP", path, "Blocker '%s' overlaps %s." % [id, str(cell)]))
		else:
			occupied[cell] = id
		if blocker.has("counter_remaining"):
			var remaining: Variant = as_whole_int(blocker["counter_remaining"])
			if remaining == null or int(remaining) < 0:
				diags.append(_diag("MALFORMED_TRIGGER", path + ".counter_remaining", "Blocker counter_remaining must be a non-negative integer."))

static func _check_goals(data: Dictionary, diags: Array) -> void:
	if not data.has("goals"):
		return
	var goals = data["goals"]
	if typeof(goals) != TYPE_DICTIONARY:
		diags.append(_diag("INVALID_TYPE", "goals", "goals must be an object."))
		return
	for key in goals.keys():
		if str(key) != "all_required_pieces_exited":
			diags.append(_diag("UNSUPPORTED_MECHANIC", "goals." + str(key), "Goal '%s' is not supported." % str(key)))
	if goals.has("all_required_pieces_exited"):
		if typeof(goals["all_required_pieces_exited"]) != TYPE_BOOL:
			diags.append(_diag("INVALID_TYPE", "goals.all_required_pieces_exited", "all_required_pieces_exited must be a boolean."))
		elif not bool(goals["all_required_pieces_exited"]):
			diags.append(_diag("UNSUPPORTED_MECHANIC", "goals.all_required_pieces_exited", "The only supported goal is all required pieces exited."))

static func _check_metrics(data: Dictionary, diags: Array) -> void:
	if data.has("authored_metrics") and typeof(data["authored_metrics"]) != TYPE_DICTIONARY:
		diags.append(_diag("INVALID_TYPE", "authored_metrics", "authored_metrics must be an object."))

static func _check_references(data: Dictionary, ids: Dictionary, counters: Dictionary, diags: Array) -> void:
	var gates = data.get("gates", [])
	if typeof(gates) == TYPE_ARRAY:
		for i in gates.size():
			if typeof(gates[i]) == TYPE_DICTIONARY and gates[i].has("unlock_when"):
				_reference_condition(gates[i]["unlock_when"], "gates[%d].unlock_when" % i, ids, diags)
	var triggers = data.get("triggers", [])
	if typeof(triggers) != TYPE_ARRAY:
		return
	for i in triggers.size():
		if typeof(triggers[i]) != TYPE_DICTIONARY:
			continue
		var path := "triggers[%d]" % i
		if triggers[i].has("when"):
			_reference_condition(triggers[i]["when"], path + ".when", ids, diags)
		var effect = triggers[i].get("effect", null)
		if typeof(effect) == TYPE_DICTIONARY:
			_reference_effect(effect, path + ".effect", ids, counters, diags)

static func _reference_condition(node, path: String, ids: Dictionary, diags: Array) -> void:
	if typeof(node) != TYPE_DICTIONARY:
		return
	if node.has("all") and typeof(node["all"]) == TYPE_ARRAY:
		for i in node["all"].size():
			_reference_condition(node["all"][i], "%s.all[%d]" % [path, i], ids, diags)
	if node.has("any") and typeof(node["any"]) == TYPE_ARRAY:
		for i in node["any"].size():
			_reference_condition(node["any"][i], "%s.any[%d]" % [path, i], ids, diags)
	var event := str(node.get("event", node.get("type", "")))
	if event == "piece_exited" and typeof(node.get("piece_id", null)) == TYPE_STRING and not str(node["piece_id"]).is_empty():
		_expect_kind(ids, node["piece_id"], "piece", path + ".piece_id", diags)

static func _reference_effect(effect: Dictionary, path: String, ids: Dictionary, counters: Dictionary, diags: Array) -> void:
	var kind := str(effect.get("type", ""))
	if kind == "reveal_piece" and typeof(effect.get("piece_id", null)) == TYPE_STRING:
		_expect_kind(ids, effect["piece_id"], "piece", path + ".piece_id", diags)
	elif kind == "unlock_gate" and typeof(effect.get("gate_id", null)) == TYPE_STRING:
		_expect_kind(ids, effect["gate_id"], "gate", path + ".gate_id", diags)
	elif kind == "decrement_counter" and typeof(effect.get("gate_id", null)) == TYPE_STRING:
		if _expect_kind(ids, effect["gate_id"], "gate", path + ".gate_id", diags) and not counters.has(effect["gate_id"]):
			diags.append(_diag("MALFORMED_TRIGGER", path + ".gate_id", "decrement_counter requires a gate counter."))
	elif kind == "remove_blocker" and typeof(effect.get("blocker_id", null)) == TYPE_STRING:
		_expect_kind(ids, effect["blocker_id"], "blocker", path + ".blocker_id", diags)

static func _expect_kind(ids: Dictionary, id: String, kind: String, path: String, diags: Array) -> bool:
	if str(ids.get(id, "")) != kind:
		diags.append(_diag("UNKNOWN_REFERENCE", path, "No %s with id '%s'." % [kind, id]))
		return false
	return true

static func _require_id(obj: Dictionary, key: String, path: String, diags: Array) -> String:
	if not obj.has(key) or (typeof(obj[key]) == TYPE_STRING and str(obj[key]).is_empty()):
		diags.append(_diag("MISSING_FIELD", path, "Id is required."))
		return ""
	if typeof(obj[key]) != TYPE_STRING:
		diags.append(_diag("INVALID_TYPE", path, "Id must be a non-empty string."))
		return ""
	return str(obj[key])

static func _required_whole(obj: Dictionary, key: String, path: String, minimum: int, diags: Array) -> Variant:
	if not obj.has(key):
		diags.append(_diag("MISSING_FIELD", path, "%s is required." % key))
		return null
	var number: Variant = as_whole_int(obj[key])
	if number == null:
		diags.append(_diag("INVALID_COORDINATE", path, "%s must be an integer." % key))
		return null
	if int(number) < minimum:
		diags.append(_diag("OUT_OF_BOUNDS", path, "%s must be at least %d." % [key, minimum]))
		return null
	return number

static func _optional_whole(obj: Dictionary, key: String, path: String, minimum: int, diags: Array) -> void:
	if not obj.has(key):
		return
	var number: Variant = as_whole_int(obj[key])
	if number == null or int(number) < minimum:
		diags.append(_diag("INVALID_COORDINATE", path, "%s must be an integer of at least %d." % [key, minimum]))

static func _reject_unknown(obj: Dictionary, allowed: Array, path: String, diags: Array) -> void:
	for key in obj.keys():
		if allowed.has(str(key)):
			continue
		var field_path := str(key) if path.is_empty() else path + "." + str(key)
		diags.append(_diag("UNSUPPORTED_MECHANIC", field_path, "Field '%s' is not part of schema_version 2." % str(key)))

static func _colors_intersect(left: Array, right: Array) -> bool:
	for color in left:
		if right.has(color):
			return true
	return false

static func _connected(cells: Array[Vector2i]) -> bool:
	if cells.is_empty():
		return false
	var have := {}
	for cell in cells:
		have[cell] = true
	var seen := {cells[0]: true}
	var stack: Array[Vector2i] = [cells[0]]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + step
			if have.has(nxt) and not seen.has(nxt):
				seen[nxt] = true
				stack.append(nxt)
	return seen.size() == cells.size()

static func _cell(value) -> Variant:
	if typeof(value) != TYPE_ARRAY or value.size() != 2:
		return null
	var x: Variant = as_whole_int(value[0])
	var y: Variant = as_whole_int(value[1])
	if x == null or y == null:
		return null
	return Vector2i(int(x), int(y))

static func _inside(cell: Vector2i, cols: int, rows: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows

static func _diag(code: String, path: String, message: String) -> Dictionary:
	return {"code": code, "path": path, "message": message}

static func has_code(diags: Array, code: String) -> bool:
	for diag in diags:
		if str(diag.get("code", "")) == code:
			return true
	return false
