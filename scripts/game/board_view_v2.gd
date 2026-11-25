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
## Presentation queue: committed engine events are played as brief, ordered flashes.
## The queue never changes PuzzleState; it only animates transitions the engine already
## committed. reconcile() drops it so Undo/Restart redraw the authoritative state.
var _flashes: Array[Dictionary] = []
const FLASH_TIME := 0.30

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

## Enqueue committed engine events (in their emitted, priority-sorted order) as ordered
## transition flashes: gate unlock / counter change, piece reveal, blocker removal.
func queue_events(events: Array) -> void:
	for event in PuzzleEvent.sort_stable(events):
		var kind := str(event.type)
		if kind != PuzzleEvent.GATE_UNLOCKED and kind != PuzzleEvent.GATE_COUNTER_CHANGED \
				and kind != PuzzleEvent.PIECE_REVEALED and kind != PuzzleEvent.BLOCKER_REMOVED:
			continue
		var pos = _event_center(kind, str(event.subject_id))
		if pos != null:
			_flashes.append({"pos": pos, "t": 0.0})
	queue_redraw()

## True while transition flashes are still playing (used to hold the input lock).
func flashes_active() -> bool:
	return not _flashes.is_empty()

## Drop all transient presentation (flashes, exit slides) so the next redraw is the
## fully-settled authoritative state. Used by Undo / Restart and any interruption.
func reconcile() -> void:
	_flashes.clear()
	_exits.clear()
	queue_redraw()

func _event_center(kind: String, subject: String):
	var board: Dictionary = definition.get("board", {})
	var cols := int(board.get("cols", 1))
	var rows := int(board.get("rows", 1))
	if kind == PuzzleEvent.GATE_UNLOCKED or kind == PuzzleEvent.GATE_COUNTER_CHANGED:
		for gate in definition.get("gates", []):
			if typeof(gate) == TYPE_DICTIONARY and str(gate.get("id", "")) == subject:
				var lo := int(gate.get("lo", 0))
				var hi := int(gate.get("hi", lo))
				var mid := (float(lo + hi) + 1.0) * 0.5 * _cell
				match str(gate.get("side", "")):
					"left": return _origin + Vector2(0.0, mid)
					"right": return _origin + Vector2(cols * _cell, mid)
					"top": return _origin + Vector2(mid, 0.0)
					"bottom": return _origin + Vector2(mid, rows * _cell)
				return null
		return null
	if kind == PuzzleEvent.PIECE_REVEALED and state != null and state.pieces.has(subject):
		return _px(state.pieces[subject]["pos"]) + Vector2(_cell, _cell) * 0.5
	if kind == PuzzleEvent.BLOCKER_REMOVED:
		for blocker in definition.get("blockers", []):
			if typeof(blocker) == TYPE_DICTIONARY and str(blocker.get("id", "")) == subject:
				var c = blocker.get("cell", null)
				if typeof(c) == TYPE_ARRAY and c.size() == 2:
					return _px(Vector2i(int(c[0]), int(c[1]))) + Vector2(_cell, _cell) * 0.5
		return null
	return null

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
	if not _flashes.is_empty():
		var live: Array[Dictionary] = []
		for flash in _flashes:
			flash["t"] = float(flash["t"]) + delta
			if float(flash["t"]) < FLASH_TIME:
				live.append(flash)
		_flashes = live
		queue_redraw()
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
	var spare_y := maxf(0.0, size.y - board_size.y)
	_origin = Vector2((size.x - board_size.x) * 0.5, minf(28.0, spare_y * 0.16))

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
	var frame := _cell * 0.26
	var outer := Rect2(_origin - Vector2(frame, frame), Vector2(cols, rows) * _cell + Vector2(frame, frame) * 2.0)
	_round(outer, TD35Theme.FRAME, int(clampf(_cell * 0.22, 12.0, 28.0)))
	var inner := Rect2(_origin, Vector2(cols, rows) * _cell)
	_round(inner, TD35Theme.BASE, int(clampf(_cell * 0.12, 8.0, 18.0)))
	var gap := clampf(_cell * 0.08, 2.0, 4.0)
	for y in rows:
		for x in cols:
			var rect := Rect2(_px(Vector2i(x, y)) + Vector2(gap, gap), Vector2(_cell - gap * 2.0, _cell - gap * 2.0))
			_round(rect, TD35Theme.CELL, int(clampf(_cell * 0.16, 6.0, 14.0)))
	for wall in board.get("walls", []):
		if typeof(wall) != TYPE_ARRAY or wall.size() != 2:
			continue
		var rect := Rect2(_px(Vector2i(int(wall[0]), int(wall[1]))) + Vector2(gap * 0.4, gap * 0.4), Vector2(_cell - gap * 0.8, _cell - gap * 0.8))
		_round(rect, TD35Theme.WALL, int(clampf(_cell * 0.14, 6.0, 12.0)))
	for gate in definition.get("gates", []):
		if typeof(gate) == TYPE_DICTIONARY:
			_draw_gate(gate, cols, rows)
	for blocker in definition.get("blockers", []):
		if typeof(blocker) != TYPE_DICTIONARY:
			continue
		var bid := str(blocker.get("id", ""))
		if state.blockers.has(bid) and bool(state.blockers[bid]["active"]):
			var bcell = blocker.get("cell", null)
			if typeof(bcell) == TYPE_ARRAY and bcell.size() == 2:
				_draw_blocker(Vector2i(int(bcell[0]), int(bcell[1])))
	var geometry := PuzzleEngine._geometry(definition)
	_draw_preview(geometry)
	var ids: Array = geometry.keys()
	ids.sort()
	for id in ids:
		if not state.pieces.has(id) or not bool(state.pieces[id]["active"]):
			continue
		var origin: Vector2i = state.pieces[id]["pos"]
		# A hidden piece occupies its cells but shows no colour until revealed.
		if not bool(state.pieces[id].get("revealed", true)):
			for offset in geometry[id]["offsets"]:
				_draw_hidden(origin + offset)
			continue
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
	# Transition flashes: an expanding, fading ring at each committed event's location.
	for flash in _flashes:
		var ft := clampf(float(flash["t"]) / FLASH_TIME, 0.0, 1.0)
		var radius := _cell * (0.2 + ft * 0.5)
		draw_arc(flash["pos"], radius, 0.0, TAU, 24, Color(1, 1, 1, (1.0 - ft) * 0.9), maxf(2.0, _cell * 0.07))

func _draw_preview(geometry: Dictionary) -> void:
	if not _dragging or _axis == "" or _drag_id == "" or not geometry.has(_drag_id):
		return
	var limits := _limits(_axis)
	var max_dist := int(limits["max"])
	var travel := _drag_px / maxf(_cell, 0.001)
	var steps := steps_for_drag(travel, max_dist, bool(limits["exit"]), _near_screen_edge(_axis, _pointer))
	if steps <= 0:
		return
	var landing := mini(steps, max_dist)
	var extra := 0.45 if steps > max_dist else 0.0
	var base := _px(_drag_origin + _dir(_axis) * landing) + Vector2(_dir(_axis)) * _cell * extra
	_draw_piece(_drag_id, geometry[_drag_id], base, 0.15)

func _draw_gate(gate: Dictionary, cols: int, rows: int) -> void:
	# Static visual derived from the authoritative gate state: scheduled colour for a
	# color-switching gate, a locked style + lock glyph while LOCKED, and a counter badge.
	var gid := str(gate.get("id", ""))
	var gstate: Dictionary = state.gates.get(gid, {})
	var locked := str(gstate.get("mode", "OPEN")) == "LOCKED"
	var color_name := "red"
	if GateRules.is_color_switching(gate):
		color_name = GateRules.scheduled_color(gate, int(gstate.get("phase", 0)))
	else:
		var accepts: Array = gate.get("accept", [])
		if not accepts.is_empty():
			color_name = str(accepts[0])
	var color := TD35Theme.piece_color(color_name)
	if locked:
		color = color.darkened(0.45)
		color.s *= 0.5
	var lo := int(gate.get("lo", 0))
	var hi := int(gate.get("hi", lo))
	var span := float(hi - lo + 1) * _cell
	var frame := _cell * 0.26
	var pad := clampf(_cell * 0.08, 2.0, 6.0)
	var mouth := clampf(_cell * 0.2, 8.0, 22.0)
	var hole := Rect2()
	var lip := Rect2()
	var side := str(gate.get("side", ""))
	match side:
		"left":
			hole = Rect2(_origin.x - frame, _origin.y + lo * _cell + pad, frame + 2.0, span - pad * 2.0)
			lip = Rect2(_origin.x - mouth, hole.position.y, mouth + 2.0, hole.size.y)
		"right":
			hole = Rect2(_origin.x + cols * _cell - 2.0, _origin.y + lo * _cell + pad, frame + 2.0, span - pad * 2.0)
			lip = Rect2(_origin.x + cols * _cell - 2.0, hole.position.y, mouth + 2.0, hole.size.y)
		"top":
			hole = Rect2(_origin.x + lo * _cell + pad, _origin.y - frame, span - pad * 2.0, frame + 2.0)
			lip = Rect2(hole.position.x, _origin.y - mouth, hole.size.x, mouth + 2.0)
		"bottom":
			hole = Rect2(_origin.x + lo * _cell + pad, _origin.y + rows * _cell - 2.0, span - pad * 2.0, frame + 2.0)
			lip = Rect2(hole.position.x, _origin.y + rows * _cell - 2.0, hole.size.x, mouth + 2.0)
		_:
			return
	_round(hole, TD35Theme.CANVAS, int(clampf(_cell * 0.12, 4.0, 12.0)))
	_round(lip, color, int(clampf(_cell * 0.1, 3.0, 8.0)))
	if locked:
		_glyph_lock(lip.get_center())
	var remaining := int(gstate.get("counter_remaining", -1))
	if remaining > 0:
		_badge(lip.get_center(), str(remaining))

## A small padlock glyph (shackle arc + body) so a locked gate reads without colour.
func _glyph_lock(center: Vector2) -> void:
	var s := clampf(_cell * 0.22, 8.0, 20.0)
	var body := Rect2(center - Vector2(s * 0.5, s * 0.1), Vector2(s, s * 0.7))
	draw_rect(body, Color.WHITE)
	draw_rect(body, Color(0, 0, 0, 0.85), false, maxf(1.5, s * 0.08))
	var r := s * 0.32
	draw_arc(center - Vector2(0, s * 0.1), r, PI, TAU, 10, Color.WHITE, maxf(2.0, s * 0.12))
	draw_circle(center + Vector2(0, s * 0.22), maxf(1.5, s * 0.08), Color(0, 0, 0, 0.85))

## A high-contrast numeric badge (counter remaining), legible on a dense small screen.
func _badge(center: Vector2, text: String) -> void:
	var r := clampf(_cell * 0.2, 9.0, 18.0)
	draw_circle(center, r, Color(0.1, 0.12, 0.2, 0.95))
	draw_arc(center, r, 0.0, TAU, 20, Color.WHITE, maxf(1.5, r * 0.14))
	var font := ThemeDB.fallback_font
	var fs := int(r * 1.2)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(font, center + Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

## An active blocker: a distinct hatched obstacle tile (shape + cross-hatch, not colour).
func _draw_blocker(cell: Vector2i) -> void:
	var gap := clampf(_cell * 0.08, 2.0, 4.0)
	var rect := Rect2(_px(cell) + Vector2(gap, gap), Vector2(_cell - gap * 2.0, _cell - gap * 2.0))
	_round(rect, TD35Theme.WALL, int(clampf(_cell * 0.14, 6.0, 12.0)))
	var inset := _cell * 0.22
	var a := _px(cell) + Vector2(inset, inset)
	var b := _px(cell) + Vector2(_cell - inset, _cell - inset)
	var line := Color(1, 1, 1, 0.8)
	draw_line(a, b, line, maxf(2.0, _cell * 0.05))
	draw_line(Vector2(b.x, a.y), Vector2(a.x, b.y), line, maxf(2.0, _cell * 0.05))

## An unrevealed hidden piece: an obscured neutral tile with a "?" (no colour cue).
func _draw_hidden(cell: Vector2i) -> void:
	var gap := clampf(_cell * 0.08, 2.0, 4.0)
	var rect := Rect2(_px(cell) + Vector2(gap, gap), Vector2(_cell - gap * 2.0, _cell - gap * 2.0))
	_round(rect, TD35Theme.FRAME, int(clampf(_cell * 0.16, 6.0, 14.0)))
	var font := ThemeDB.fallback_font
	var fs := int(_cell * 0.5)
	var w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(font, _px(cell) + Vector2(_cell * 0.5 - w * 0.5, _cell * 0.68), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))

func _draw_piece(id: String, geometry: Dictionary, base: Vector2, alpha: float) -> void:
	if _dragging and id == _drag_id and alpha > 0.99:
		base = _px(state.pieces[id]["pos"]) + _drag_offset()
	var corners := _silhouette(geometry["offsets"])
	if corners.is_empty():
		return
	var center := Vector2.ZERO
	for corner in corners:
		center += corner
	center /= float(corners.size())
	var color := TD35Theme.piece_color(str(geometry["color"]))
	if id == _drag_id and alpha > 0.99:
		color = color.lightened(0.05)
	color.a = alpha
	var shadow := PackedVector2Array()
	var body := PackedVector2Array()
	var gloss := PackedVector2Array()
	var lifted := 1.0
	if id == _drag_id and alpha > 0.99:
		lifted = 1.025
	for corner in corners:
		var pixel := base + Vector2(corner) * _cell
		var from_center := pixel - (base + center * _cell)
		var placed := base + center * _cell + from_center * 0.94 * lifted
		shadow.append(placed + Vector2(0, _cell * 0.08))
		body.append(placed)
		gloss.append(placed + Vector2(-_cell * 0.03, -_cell * 0.06))
	var shadow_color := Color(TD35Theme.SHADOW, 0.28 * alpha)
	draw_colored_polygon(shadow, shadow_color)
	var edge := color.darkened(0.28)
	edge.a = alpha
	draw_colored_polygon(body, color)
	var shine := color.lightened(0.28)
	shine.a = 0.42 * alpha
	draw_colored_polygon(gloss, shine)
	var outline := body.duplicate()
	if outline.size() > 0:
		outline.append(outline[0])
	draw_polyline(outline, edge, maxf(2.0, _cell * 0.045), true)

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
		# A hidden piece cannot be grabbed until it is revealed (engine also rejects it).
		if not bool(state.pieces[id].get("revealed", true)):
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
	draw_style_box(TD35Theme.round_box(color, int(radius)), rect)
