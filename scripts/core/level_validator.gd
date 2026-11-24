class_name LevelValidator
extends RefCounted
## Strict checks for schema_version 2. Diagnostics are data, not UI copy.
## This does not execute triggers, counters, or movement.

const COLORS := ["red", "blue", "green", "yellow", "orange", "purple"]
const SIDES := ["left", "right", "top", "bottom"]
const GATE_STATES := ["open", "locked"]
const REVEALS := ["visible", "hidden"]
const CONDITION_EVENTS := ["piece_exited", "color_exits_at_least"]
const EFFECT_TYPES := ["reveal_piece", "unlock_gate", "decrement_counter", "remove_blocker"]
const TOP_LEVEL := ["schema_version", "id", "name", "chapter", "board", "rules", "pieces", "gates", "triggers", "blockers", "goals", "authored_metrics", "legacy_index"]

static func validate_v2(data: Dictionary) -> Array:
	var diags: Array = []
	if int(data.get("schema_version", -1)) != 2:
		diags.append(_diag("UNSUPPORTED_VERSION", "schema_version", "schema_version must be 2 for the v2 validator."))
		return diags
	for key in data.keys():
		if not TOP_LEVEL.has(str(key)):
			diags.append(_diag("UNSUPPORTED_MECHANIC", str(key), "Field '%s' is not part of schema_version 2." % str(key)))
	if not data.has("id") or str(data["id"]).is_empty():
		diags.append(_diag("MISSING_FIELD", "id", "Level id is required."))
	if not data.has("name"):
		diags.append(_diag("MISSING_FIELD", "name", "Level name is required."))
	var board = data.get("board", null)
	if typeof(board) != TYPE_DICTIONARY:
		diags.append(_diag("MISSING_FIELD", "board", "board.cols and board.rows are required."))
		return diags
	var cols := int(board.get("cols", 0))
	var rows := int(board.get("rows", 0))
	if cols <= 0 or rows <= 0:
		diags.append(_diag("OUT_OF_BOUNDS", "board", "Board cols and rows must be positive."))
	var walls := _as_array(board.get("walls", []))
	var wall_set := {}
	for i in walls.size():
		var cell: Variant = _cell(walls[i])
		if cell == null:
			diags.append(_diag("MALFORMED_TRIGGER", "board.walls[%d]" % i, "Wall must be [x, y]."))
			continue
		if not _inside(cell, cols, rows):
			diags.append(_diag("OUT_OF_BOUNDS", "board.walls[%d]" % i, "Wall %s is outside the board." % str(cell)))
		elif wall_set.has(cell):
			diags.append(_diag("OVERLAP", "board.walls[%d]" % i, "Duplicate wall at %s." % str(cell)))
		else:
			wall_set[cell] = true
	_check_rules(data.get("rules", {}), diags)
	var pieces = data.get("pieces", null)
	if typeof(pieces) != TYPE_ARRAY or pieces.is_empty():
		diags.append(_diag("MISSING_FIELD", "pieces", "At least one piece is required."))
		pieces = []
	var ids := {}
	var occupied := wall_set.duplicate()
	for i in pieces.size():
		_check_piece(pieces[i], i, cols, rows, ids, occupied, diags)
	var gates = data.get("gates", [])
	if typeof(gates) != TYPE_ARRAY:
		diags.append(_diag("MISSING_FIELD", "gates", "gates must be an array."))
		gates = []
	var spans := {"left": [], "right": [], "top": [], "bottom": []}
	for i in gates.size():
		_check_gate(gates[i], i, cols, rows, ids, spans, diags)
	var triggers = data.get("triggers", [])
	if typeof(triggers) != TYPE_ARRAY:
		diags.append(_diag("MALFORMED_TRIGGER", "triggers", "triggers must be an array."))
	else:
		for i in triggers.size():
			_check_trigger(triggers[i], i, ids, diags)
	if data.has("blockers"):
		_check_blockers(data["blockers"], cols, rows, ids, occupied, diags)
	_check_goals(data.get("goals", {}), diags)
	return diags

static func _check_rules(rules, diags: Array) -> void:
	if rules == null:
		return
	if typeof(rules) != TYPE_DICTIONARY:
		diags.append(_diag("UNSUPPORTED_MECHANIC", "rules", "rules must be an object."))
		return
	if bool(rules.get("rotation", false)):
		diags.append(_diag("UNSUPPORTED_MECHANIC", "rules.rotation", "Piece rotation is not a supported mechanic."))
	if rules.get("timer_seconds", null) != null:
		diags.append(_diag("UNSUPPORTED_MECHANIC", "rules.timer_seconds", "Timers are session state and are not accepted on a puzzle definition in TD-1."))

static func _check_piece(piece, index: int, cols: int, rows: int, ids: Dictionary, occupied: Dictionary, diags: Array) -> void:
	var path := "pieces[%d]" % index
	if typeof(piece) != TYPE_DICTIONARY:
		diags.append(_diag("MISSING_FIELD", path, "Piece must be an object."))
		return
	var id := str(piece.get("id", ""))
	if id.is_empty():
		diags.append(_diag("MISSING_FIELD", path + ".id", "Piece id is required."))
	elif ids.has(id):
		diags.append(_diag("DUPLICATE_ID", path + ".id", "Duplicate id '%s'." % id))
	else:
		ids[id] = "piece"
	var color := str(piece.get("color", ""))
	if not COLORS.has(color):
		diags.append(_diag("INVALID_COLOR", path + ".color", "Color '%s' is not a logical color." % color))
	var reveal := str(piece.get("reveal", "visible"))
	if not REVEALS.has(reveal):
		diags.append(_diag("MALFORMED_TRIGGER", path + ".reveal", "reveal must be visible or hidden."))
	if typeof(piece.get("pos", null)) != TYPE_ARRAY or piece["pos"].size() < 2:
		diags.append(_diag("MISSING_FIELD", path + ".pos", "Piece pos must be [x, y]."))
		return
	var origin := Vector2i(int(piece["pos"][0]), int(piece["pos"][1]))
	var cells = piece.get("cells", null)
	if typeof(cells) != TYPE_ARRAY or cells.is_empty():
		diags.append(_diag("MISSING_FIELD", path + ".cells", "Piece cells are required."))
		return
	var offsets: Array[Vector2i] = []
	var local := {}
	for c in cells.size():
		var offset: Variant = _cell(cells[c])
		if offset == null:
			diags.append(_diag("DISCONNECTED_PIECE", path + ".cells[%d]" % c, "Cell must be [x, y]."))
			return
		if local.has(offset):
			diags.append(_diag("OVERLAP", path + ".cells[%d]" % c, "Duplicate cell in piece '%s'." % id))
		local[offset] = true
		offsets.append(offset)
		var abs_cell: Vector2i = origin + offset
		if not _inside(abs_cell, cols, rows):
			diags.append(_diag("OUT_OF_BOUNDS", path, "Piece '%s' occupies %s outside the board." % [id, str(abs_cell)]))
		elif occupied.has(abs_cell):
			diags.append(_diag("OVERLAP", path, "Piece '%s' overlaps %s." % [id, str(abs_cell)]))
		else:
			occupied[abs_cell] = id
	if not _connected(offsets):
		diags.append(_diag("DISCONNECTED_PIECE", path + ".cells", "Piece '%s' is not orthogonally connected." % id))

static func _check_gate(gate, index: int, cols: int, rows: int, ids: Dictionary, spans: Dictionary, diags: Array) -> void:
	var path := "gates[%d]" % index
	if typeof(gate) != TYPE_DICTIONARY:
		diags.append(_diag("INVALID_GATE", path, "Gate must be an object."))
		return
	var id := str(gate.get("id", ""))
	if id.is_empty():
		diags.append(_diag("MISSING_FIELD", path + ".id", "Gate id is required."))
	elif ids.has(id):
		diags.append(_diag("DUPLICATE_ID", path + ".id", "Duplicate id '%s'." % id))
	else:
		ids[id] = "gate"
	var side := str(gate.get("side", ""))
	if not SIDES.has(side):
		diags.append(_diag("INVALID_GATE", path + ".side", "Gate side '%s' is invalid." % side))
		return
	var lo := int(gate.get("lo", 0))
	var hi := int(gate.get("hi", -1))
	var accept = gate.get("accept", null)
	var limit := rows if side == "left" or side == "right" else cols
	if lo > hi or lo < 0 or hi >= limit:
		diags.append(_diag("INVALID_GATE", path, "Gate '%s' span %d..%d is outside the %s edge." % [id, lo, hi, side]))
	else:
		var accept_colors: Array = []
		if typeof(accept) == TYPE_ARRAY:
			for color in accept:
				accept_colors.append(str(color))
		for prev in spans[side]:
			var ranges_overlap: bool = lo <= int(prev["hi"]) and int(prev["lo"]) <= hi
			if ranges_overlap and _colors_intersect(accept_colors, prev["accept"]):
				diags.append(_diag("OVERLAPPING_GATES", path, "Gate '%s' overlaps '%s' on %s for the same color." % [id, prev["id"], side]))
		spans[side].append({"id": id, "lo": lo, "hi": hi, "accept": accept_colors})
	if typeof(accept) != TYPE_ARRAY or accept.is_empty():
		diags.append(_diag("INVALID_GATE", path + ".accept", "Gate '%s' needs a non-empty accept list." % id))
	else:
		for color in accept:
			if not COLORS.has(str(color)):
				diags.append(_diag("INVALID_COLOR", path + ".accept", "Gate '%s' accepts unknown color '%s'." % [id, str(color)]))
	var mode := str(gate.get("initial_state", "open"))
	if not GATE_STATES.has(mode):
		diags.append(_diag("INVALID_GATE", path + ".initial_state", "initial_state must be open or locked."))
	if gate.has("unlock_when"):
		_check_condition(gate["unlock_when"], path + ".unlock_when", diags)
	if gate.has("counter"):
		if typeof(gate["counter"]) != TYPE_DICTIONARY or not gate["counter"].has("remaining"):
			diags.append(_diag("MALFORMED_TRIGGER", path + ".counter", "A gate counter needs remaining."))
		elif int(gate["counter"]["remaining"]) < 0:
			diags.append(_diag("MALFORMED_TRIGGER", path + ".counter", "Counter remaining cannot be negative."))

static func _check_trigger(trigger, index: int, ids: Dictionary, diags: Array) -> void:
	var path := "triggers[%d]" % index
	if typeof(trigger) != TYPE_DICTIONARY:
		diags.append(_diag("MALFORMED_TRIGGER", path, "Trigger must be an object."))
		return
	var id := str(trigger.get("id", ""))
	if id.is_empty():
		diags.append(_diag("MISSING_FIELD", path + ".id", "Trigger id is required."))
	elif ids.has(id):
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
	var kind := str(effect.get("type", ""))
	if not EFFECT_TYPES.has(kind):
		diags.append(_diag("UNSUPPORTED_MECHANIC", path + ".effect.type", "Effect '%s' is not a known typed effect." % kind))
		return
	if kind == "reveal_piece" and str(effect.get("piece_id", "")).is_empty():
		diags.append(_diag("MALFORMED_TRIGGER", path + ".effect", "reveal_piece requires piece_id."))
	elif kind == "unlock_gate" and str(effect.get("gate_id", "")).is_empty():
		diags.append(_diag("MALFORMED_TRIGGER", path + ".effect", "unlock_gate requires gate_id."))
	elif kind == "decrement_counter" and str(effect.get("gate_id", "")).is_empty():
		diags.append(_diag("MALFORMED_TRIGGER", path + ".effect", "decrement_counter requires gate_id."))
	elif kind == "remove_blocker" and str(effect.get("blocker_id", "")).is_empty():
		diags.append(_diag("MALFORMED_TRIGGER", path + ".effect", "remove_blocker requires blocker_id."))

static func _check_condition(node, path: String, diags: Array) -> void:
	if typeof(node) != TYPE_DICTIONARY:
		diags.append(_diag("MALFORMED_TRIGGER", path, "Condition must be an object."))
		return
	if node.has("all") or node.has("any"):
		var key := "all" if node.has("all") else "any"
		if typeof(node[key]) != TYPE_ARRAY or node[key].is_empty():
			diags.append(_diag("MALFORMED_TRIGGER", path + "." + key, "Compound condition needs a non-empty list."))
			return
		for i in node[key].size():
			_check_condition(node[key][i], "%s.%s[%d]" % [path, key, i], diags)
		return
	var event := str(node.get("event", node.get("type", "")))
	if event.is_empty():
		diags.append(_diag("MALFORMED_TRIGGER", path, "Condition needs event or type."))
	elif not CONDITION_EVENTS.has(event):
		diags.append(_diag("UNSUPPORTED_MECHANIC", path, "Condition '%s' is not a supported typed condition." % event))
	elif event == "piece_exited" and str(node.get("piece_id", "")).is_empty():
		diags.append(_diag("MALFORMED_TRIGGER", path, "piece_exited requires piece_id."))
	elif event == "color_exits_at_least":
		if not COLORS.has(str(node.get("color", ""))):
			diags.append(_diag("INVALID_COLOR", path, "color_exits_at_least needs a logical color."))
		if not node.has("count"):
			diags.append(_diag("MALFORMED_TRIGGER", path, "color_exits_at_least requires count."))

static func _check_blockers(blockers, cols: int, rows: int, ids: Dictionary, occupied: Dictionary, diags: Array) -> void:
	if typeof(blockers) != TYPE_ARRAY:
		diags.append(_diag("UNSUPPORTED_MECHANIC", "blockers", "blockers must be an array."))
		return
	for i in blockers.size():
		var blocker = blockers[i]
		var path := "blockers[%d]" % i
		if typeof(blocker) != TYPE_DICTIONARY or str(blocker.get("id", "")).is_empty():
			diags.append(_diag("MISSING_FIELD", path + ".id", "Blocker id is required."))
			continue
		var id := str(blocker["id"])
		if ids.has(id):
			diags.append(_diag("DUPLICATE_ID", path + ".id", "Duplicate id '%s'." % id))
		else:
			ids[id] = "blocker"
		var cell: Variant = _cell(blocker.get("cell", null))
		if cell == null or not _inside(cell, cols, rows):
			diags.append(_diag("OUT_OF_BOUNDS", path, "Blocker '%s' needs an in-bounds cell." % id))
		elif occupied.has(cell):
			diags.append(_diag("OVERLAP", path, "Blocker '%s' overlaps %s." % [id, str(cell)]))
		else:
			occupied[cell] = id

static func _check_goals(goals, diags: Array) -> void:
	if goals == null:
		return
	if typeof(goals) != TYPE_DICTIONARY:
		diags.append(_diag("UNSUPPORTED_MECHANIC", "goals", "goals must be an object."))
		return
	for key in goals.keys():
		if str(key) != "all_required_pieces_exited":
			diags.append(_diag("UNSUPPORTED_MECHANIC", "goals." + str(key), "Goal '%s' is not supported." % str(key)))

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
	if typeof(value) != TYPE_ARRAY or value.size() < 2:
		return null
	return Vector2i(int(value[0]), int(value[1]))

static func _inside(cell: Vector2i, cols: int, rows: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows

static func _as_array(value) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []

static func _diag(code: String, path: String, message: String) -> Dictionary:
	return {"code": code, "path": path, "message": message}

static func has_code(diags: Array, code: String) -> bool:
	for diag in diags:
		if str(diag.get("code", "")) == code:
			return true
	return false
