class_name BoardViewV2
extends Control
## Presentation and touch intent for v2. Gameplay commits only through PuzzleEngine.
## Pixel positions are never read back as rules.

signal commit_requested(action: PuzzleAction)
signal grabbed
signal bumped

const EASE_SPEED := 16.0
## A clear exit commits once the finger travels this far past the last in-board
## landing, measured in cells. Releasing on that landing stays a normal move.
const EXIT_PAST := 0.34
## System gesture bands eat the last part of a swipe. Inside the screen-edge
## zone the same exit needs only this shorter push past the last landing.
const EXIT_PAST_AT_EDGE := 0.12
const EDGE_ZONE := 48.0

var definition: Dictionary = {}
var state: PuzzleState
var input_locked := false

var _cell := 48.0
var _origin := Vector2.ZERO
var _visual := {}
var _drag_id := ""
var _drag_origin := Vector2i.ZERO
var _grab := Vector2.ZERO
var _axis := ""
var _drag_px := 0.0
var _pointer := Vector2.ZERO
var _dragging := false
var _exits: Array[Dictionary] = []

func note_exit(piece_id: String, direction: String) -> void:
	if state == null or not state.pieces.has(piece_id):
		return
	var origin: Vector2i = state.pieces[piece_id]["pos"]
	var from: Vector2 = _visual.get(piece_id, _px(origin))
	_exits.append({"id": piece_id, "dir": direction, "from": from, "t": 0.0})

func show_state(next_definition: Dictionary, next_state: PuzzleState, keep_exits: bool = false) -> void:
	definition = next_definition
	state = next_state
	_dragging = false
	_drag_id = ""
	_axis = ""
	_visual.clear()
	if not keep_exits:
		_exits.clear()
	queue_redraw()

func set_locked(locked: bool) -> void:
	input_locked = locked
	if locked:
		_dragging = false
		_drag_id = ""

static func choose_action(actions: Array, origin: Vector2i, direction: String, steps: int) -> PuzzleAction:
	if steps <= 0 or direction == "":
		return null
	var exit_action: PuzzleAction = null
	var max_dist := 0
	var by_dist := {}
	for item in actions:
		var action := item as PuzzleAction
		if action == null or action.direction != direction:
			continue
		if action.kind == PuzzleAction.EXIT:
			exit_action = action
			continue
		var dist := absi(action.landing.x - origin.x) + absi(action.landing.y - origin.y)
		by_dist[dist] = action
		if dist > max_dist:
			max_dist = dist
	if exit_action != null and steps > max_dist:
		return exit_action
	var want := mini(steps, max_dist)
	if by_dist.has(want):
		return by_dist[want]
	return null

static func steps_for_drag(travel_cells: float, max_dist: int, exit_ready: bool, near_edge: bool) -> int:
	if travel_cells < 0.5:
		return 0
	var past := EXIT_PAST_AT_EDGE if near_edge else EXIT_PAST
	if exit_ready and travel_cells >= float(max_dist) + past:
		return max_dist + 1
	var landed := int(round(travel_cells))
	if landed < 1:
		return 0
	return mini(landed, max_dist)

func _process(delta: float) -> void:
	var still: Array[Dictionary] = []
	for item in _exits:
		item["t"] = float(item["t"]) + delta
		if float(item["t"]) < 0.34:
			still.append(item)
	_exits = still
	if state == null:
		return
	_layout()
	for id in state.pieces.keys():
		var piece: Dictionary = state.pieces[id]
		if not bool(piece["active"]):
			continue
		if _dragging and id == _drag_id:
			continue
		var target := _px(piece["pos"])
		if not _visual.has(id):
			_visual[id] = target
		else:
			var current: Vector2 = _visual[id]
			if current.distance_to(target) > 0.5:
				_visual[id] = current.lerp(target, minf(1.0, delta * EASE_SPEED))
			else:
				_visual[id] = target
	queue_redraw()

func _layout() -> void:
	var board: Dictionary = definition.get("board", {})
	var cols := int(board.get("cols", 1))
	var rows := int(board.get("rows", 1))
	var margin := 36.0
	var avail := Vector2(maxf(1.0, size.x - margin * 2.0), maxf(1.0, size.y - margin * 2.0))
	_cell = minf(avail.x / float(cols), avail.y / float(rows))
	var board_size := Vector2(_cell * cols, _cell * rows)
	_origin = (size - board_size) * 0.5

func _px(cell: Vector2i) -> Vector2:
	return _origin + Vector2(cell) * _cell

func _cell_at(px: Vector2) -> Vector2i:
	var local := (px - _origin) / _cell
	return Vector2i(floori(local.x), floori(local.y))

func _draw() -> void:
	if state == null or definition.is_empty():
		return
	_layout()
	var board: Dictionary = definition.get("board", {})
	var cols := int(board.get("cols", 1))
	var rows := int(board.get("rows", 1))
	var tray := Rect2(_origin - Vector2(_cell, _cell) * 0.16, Vector2(cols, rows) * _cell + Vector2(_cell, _cell) * 0.32)
	_round(tray, Style.BOARD, _cell * 0.18)
	for y in rows:
		for x in cols:
			var rect := Rect2(_px(Vector2i(x, y)) + Vector2.ONE * _cell * 0.06, Vector2.ONE * _cell * 0.88)
			_round(rect, Style.CELL, _cell * 0.12)
	for wall in board.get("walls", []):
		if typeof(wall) != TYPE_ARRAY or wall.size() != 2:
			continue
		var rect := Rect2(_px(Vector2i(int(wall[0]), int(wall[1]))) + Vector2.ONE * _cell * 0.04, Vector2.ONE * _cell * 0.92)
		_round(rect, Style.WALL, _cell * 0.14)
	for gate in definition.get("gates", []):
		if typeof(gate) == TYPE_DICTIONARY:
			_draw_gate(gate, cols, rows)
	var geometry := PuzzleEngine._geometry(definition)
	var ids: Array = geometry.keys()
	ids.sort()
	for id in ids:
		if not state.pieces.has(id) or not bool(state.pieces[id]["active"]):
			continue
		var origin: Vector2i = state.pieces[id]["pos"]
		var base := _px(origin)
		if _visual.has(id):
			base = _visual[id]
		_draw_piece(str(id), geometry[id], base, 1.0)
	for item in _exits:
		var exit_id := str(item["id"])
		if not geometry.has(exit_id):
			continue
		var travel := clampf(float(item["t"]) / 0.34, 0.0, 1.0)
		var from: Vector2 = item["from"]
		var slide := from + Vector2(_dir(str(item["dir"]))) * _cell * (0.35 + travel * 1.2)
		_draw_piece(exit_id, geometry[exit_id], slide, 1.0 - travel)

func _draw_gate(gate: Dictionary, cols: int, rows: int) -> void:
	var accepts: Array = gate.get("accept", [])
	var color_name := "red"
	if not accepts.is_empty():
		color_name = str(accepts[0])
	var color := Style.block_color(color_name)
	var lo := int(gate.get("lo", 0))
	var hi := int(gate.get("hi", lo))
	var span := float(hi - lo + 1) * _cell
	var thick := _cell * 0.28
	var inset := _cell * 0.08
	var rect := Rect2()
	var side := str(gate.get("side", ""))
	match side:
		"left":
			rect = Rect2(_origin.x - thick, _origin.y + lo * _cell + inset, thick, span - inset * 2.0)
		"right":
			rect = Rect2(_origin.x + cols * _cell, _origin.y + lo * _cell + inset, thick, span - inset * 2.0)
		"top":
			rect = Rect2(_origin.x + lo * _cell + inset, _origin.y - thick, span - inset * 2.0, thick)
		"bottom":
			rect = Rect2(_origin.x + lo * _cell + inset, _origin.y + rows * _cell, span - inset * 2.0, thick)
		_:
			return
	_round(rect, color, thick * 0.45)

func _draw_piece(id: String, geometry: Dictionary, base: Vector2, alpha: float) -> void:
	if _dragging and id == _drag_id and alpha > 0.99:
		base = _px(state.pieces[id]["pos"]) + _drag_offset()
	var corners := _silhouette(geometry["offsets"])
	if corners.is_empty():
		return
	var shadow := PackedVector2Array()
	var fill := PackedVector2Array()
	var center := Vector2.ZERO
	for corner in corners:
		center += corner
	center /= float(corners.size())
	for corner in corners:
		var pixel := base + Vector2(corner) * _cell
		shadow.append(pixel + Vector2(0, _cell * 0.08))
		var from_center := pixel - (base + center * _cell)
		fill.append(base + center * _cell + from_center * 0.92)
	var color := Style.block_color(str(geometry["color"]))
	if id == _drag_id and alpha > 0.99:
		color = color.lightened(0.08)
	color.a = alpha
	var shadow_color := Color(0, 0, 0, 0.28 * alpha)
	draw_colored_polygon(shadow, shadow_color)
	draw_colored_polygon(fill, color)
	var outline := fill.duplicate()
	if outline.size() > 0:
		outline.append(outline[0])
	var edge := color.darkened(0.35)
	edge.a = alpha
	draw_polyline(outline, edge, maxf(2.0, _cell * 0.06), true)

func _silhouette(offsets: Array) -> PackedVector2Array:
	var occupied := {}
	for offset in offsets:
		occupied[offset] = true
	var edges := {}
	for offset in offsets:
		var cell: Vector2i = offset
		if not occupied.has(cell + Vector2i(0, -1)):
			edges[cell] = cell + Vector2i(1, 0)
		if not occupied.has(cell + Vector2i(1, 0)):
			edges[cell + Vector2i(1, 0)] = cell + Vector2i(1, 1)
		if not occupied.has(cell + Vector2i(0, 1)):
			edges[cell + Vector2i(1, 1)] = cell + Vector2i(0, 1)
		if not occupied.has(cell + Vector2i(-1, 0)):
			edges[cell + Vector2i(0, 1)] = cell
	if edges.is_empty():
		return PackedVector2Array()
	var start: Vector2i = edges.keys()[0]
	var cursor := start
	var poly := PackedVector2Array()
	for _i in edges.size() + 1:
		poly.append(Vector2(cursor))
		if not edges.has(cursor):
			break
		cursor = edges[cursor]
		if cursor == start:
			break
	return poly

func _drag_offset() -> Vector2:
	var step := _dir(_axis)
	var limit := float(_travel_cells()) * _cell
	return Vector2(step) * clampf(_drag_px, 0.0, limit)

func _travel_cells() -> int:
	var limits := _limits(_axis)
	return int(limits["max"]) + (1 if limits["exit"] else 0)

func _limits(direction: String) -> Dictionary:
	var max_dist := 0
	var has_exit := false
	if _drag_id == "" or state == null:
		return {"max": 0, "exit": false}
	for item in PuzzleEngine.legal_actions(definition, state, _drag_id):
		var action := item as PuzzleAction
		if action == null or action.direction != direction:
			continue
		if action.kind == PuzzleAction.EXIT:
			has_exit = true
		else:
			var dist := absi(action.landing.x - _drag_origin.x) + absi(action.landing.y - _drag_origin.y)
			max_dist = maxi(max_dist, dist)
	return {"max": max_dist, "exit": has_exit}

func _gui_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(event.position)
		else:
			_end()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin(event.position)
		else:
			_end()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_move(event.position)
	elif event is InputEventScreenDrag:
		_move(event.position)

func _begin(px: Vector2) -> void:
	if input_locked:
		return
	var cell := _cell_at(px)
	var id := _piece_at(cell)
	if id == "":
		return
	_drag_id = id
	_drag_origin = state.pieces[id]["pos"]
	_grab = px
	_pointer = px
	_axis = ""
	_drag_px = 0.0
	_dragging = true
	grabbed.emit()

func _move(px: Vector2) -> void:
	if not _dragging or _cell <= 0.0:
		return
	_pointer = px
	var delta := px - _grab
	if _axis == "" and delta.length() < _cell * 0.18:
		return
	if _axis == "":
		if absf(delta.x) >= absf(delta.y):
			_axis = "right" if delta.x > 0.0 else "left"
		else:
			_axis = "down" if delta.y > 0.0 else "up"
	if _axis == "right":
		_drag_px = delta.x
	elif _axis == "left":
		_drag_px = -delta.x
	elif _axis == "down":
		_drag_px = delta.y
	else:
		_drag_px = -delta.y
	_drag_px = maxf(0.0, _drag_px)

func _end() -> void:
	if not _dragging:
		return
	var limits := _limits(_axis)
	var travel := _drag_px / _cell if _cell > 0.0 else 0.0
	var steps := steps_for_drag(travel, int(limits["max"]), bool(limits["exit"]), _near_screen_edge(_axis, _pointer))
	var actions := PuzzleEngine.legal_actions(definition, state, _drag_id)
	var action := choose_action(actions, _drag_origin, _axis, steps)
	var overshot := travel > float(limits["max"]) + 0.5 and not bool(limits["exit"])
	_dragging = false
	_drag_id = ""
	_axis = ""
	if action == null:
		if steps > 0:
			bumped.emit()
		return
	if overshot:
		bumped.emit()
	commit_requested.emit(action)

func _near_screen_edge(direction: String, px: Vector2) -> bool:
	var zone := maxf(EDGE_ZONE, _cell * 0.45)
	match direction:
		"left":
			return px.x <= zone
		"right":
			return px.x >= size.x - zone
		"up":
			return px.y <= zone
		"down":
			return px.y >= size.y - zone
	return false

func _piece_at(cell: Vector2i) -> String:
	var geometry := PuzzleEngine._geometry(definition)
	for id in geometry.keys():
		if not bool(state.pieces[id]["active"]):
			continue
		var origin: Vector2i = state.pieces[id]["pos"]
		for offset in geometry[id]["offsets"]:
			if origin + offset == cell:
				return str(id)
	return ""

func _dir(direction: String) -> Vector2i:
	match direction:
		"left":
			return Vector2i(-1, 0)
		"right":
			return Vector2i(1, 0)
		"up":
			return Vector2i(0, -1)
		"down":
			return Vector2i(0, 1)
	return Vector2i.ZERO

func _round(rect: Rect2, color: Color, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	draw_style_box(box, rect)
