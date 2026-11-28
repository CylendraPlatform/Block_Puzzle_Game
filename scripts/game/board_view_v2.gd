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
## Project settings that tune the two thresholds above (M1.3 D4); the constants are the
## defaults and the fallback for a missing or non-positive value.
const EXIT_PAST_SETTING := "gameplay/exit_past"
const EXIT_PAST_EDGE_SETTING := "gameplay/exit_past_edge"
## Layout constants live in BoardGeometry (shared with theme skins); kept here as aliases for
## existing callers. Frame band width in cells; space above / below the frame; part of the
## frame band a gate slot occupies (the rest stays an unbroken outer rim).
const FRAME_RATIO := BoardGeometry.FRAME_RATIO
const FRAME_GAP_Y := BoardGeometry.FRAME_GAP_Y
const GATE_DEPTH := BoardGeometry.GATE_DEPTH

var definition: Dictionary = {}
var state: PuzzleState
var input_locked := false
## Centre the board vertically in this view (GameScreen). Off keeps the top-aligned layout the
## pilot / QA screens use. Presentation only: touch mapping follows the same _origin.
var center_vertically := false

## Current layout (BoardGeometry.fit); _cell and _origin mirror it for the drawing code.
var geometry := BoardGeometry.new()
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
## Presentation queue (M1.2 plan R1). `state` stays the authoritative PuzzleState and
## drives geometry; `_shown` holds the mechanic flags the player has seen so far (gate
## mode / counter / phase, blocker, reveal). Each queued step copies one event's
## end-visual from `state` into `_shown`, so the picture never runs ahead of the animation
## and nothing here ever writes PuzzleState. Draining every step lands exactly on `state`.
var _shown: PuzzleState = null
var _steps: Array[Dictionary] = []
var _step_t := 0.0
var _step_begun := false
var _flashes: Array[Dictionary] = []
const STEP_MOVE := 0.18
const STEP_EXIT := 0.34
const STEP_EVENT := 0.30
const FLASH_TIME := 0.30
const SHOWN_EVENTS := [PuzzleEvent.GATE_COUNTER_CHANGED, PuzzleEvent.GATE_UNLOCKED, PuzzleEvent.BLOCKER_REMOVED, PuzzleEvent.PIECE_REVEALED]

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

## Present one committed action as an ordered sequence. Call after show_state() has
## installed the new authoritative state. `previous` is the state before the commit; it is
## duplicated, never mutated (the session keeps it as its undo snapshot). Steps: the move
## itself, then each mechanic event in PuzzleEvent.sort_stable order (plan R1).
func begin_transition(previous: PuzzleState, events: Array, leaving: bool) -> void:
	fast_forward()
	_shown = previous.duplicate()
	_steps.append({"kind": "move", "subject": "", "time": STEP_EXIT if leaving else STEP_MOVE})
	for event in PuzzleEvent.sort_stable(events):
		var kind := str(event.type)
		if kind in SHOWN_EVENTS:
			_steps.append({"kind": kind, "subject": str(event.subject_id), "time": STEP_EVENT})
	_step_t = 0.0
	_step_begun = false
	queue_redraw()

## True while queued steps remain; the controller keeps input locked until this is false.
func transition_active() -> bool:
	return not _steps.is_empty()

## Pending step kinds in play order (tests and diagnostics).
func pending_steps() -> Array:
	var out: Array = []
	for step in _steps:
		out.append(str(step["kind"]))
	return out

## Mechanic flags currently on screen: the presentation copy mid-transition, otherwise the
## authoritative state.
func shown_state() -> PuzzleState:
	return _shown if _shown != null else state

## Apply every pending step's end-visual at once. Steps copy from `state`, so this lands
## exactly on the authoritative picture; it only skips tweens and never writes PuzzleState.
func fast_forward() -> void:
	if _shown != null:
		for step in _steps:
			_apply_step(step)
	_steps.clear()
	_step_t = 0.0
	_step_begun = false
	_shown = null
	_flashes.clear()
	queue_redraw()

## Settle any transition and drop exit slides so the next redraw is the authoritative state.
## Used by Undo / Restart / level load and any interruption (plan R2).
func reconcile() -> void:
	fast_forward()
	_exits.clear()

## Advance the queue by `delta` seconds. A move step applies its visual (gate phase) once the
## piece has landed; an event step applies its visual, with a ring, as it begins. A long
## frame drains several steps at once instead of stalling.
func advance_transition(delta: float) -> void:
	if _steps.is_empty():
		return
	if not _step_begun:
		_begin_step(_steps[0])
	_step_t += delta
	while not _steps.is_empty() and _step_t >= float(_steps[0]["time"]):
		_step_t -= float(_steps[0]["time"])
		var done: Dictionary = _steps.pop_front()
		_step_begun = false
		if str(done["kind"]) == "move":
			_apply_step(done)
		if not _steps.is_empty():
			_begin_step(_steps[0])
	if _steps.is_empty():
		_step_t = 0.0
		_shown = null
	queue_redraw()

func _begin_step(step: Dictionary) -> void:
	_step_begun = true
	var kind := str(step["kind"])
	if kind == "move":
		return
	_apply_step(step)
	var pos = _event_center(kind, str(step["subject"]))
	if pos != null:
		_flashes.append({"pos": pos, "t": 0.0})

## Copy one event's end-visual from the authoritative state into the presentation copy.
## shortcut: a counter is shown at its committed value, so two decrements of one gate in a
## single commit read as one change; step counters through if a level ever does that.
func _apply_step(step: Dictionary) -> void:
	if _shown == null or state == null:
		return
	var subject := str(step["subject"])
	match str(step["kind"]):
		"move":
			for gid in state.gates.keys():
				if state.gates[gid].has("phase") and _shown.gates.has(gid):
					_shown.gates[gid]["phase"] = int(state.gates[gid]["phase"])
		PuzzleEvent.GATE_COUNTER_CHANGED:
			if state.gates.has(subject) and _shown.gates.has(subject):
				_shown.gates[subject]["counter_remaining"] = int(state.gates[subject]["counter_remaining"])
		PuzzleEvent.GATE_UNLOCKED:
			if state.gates.has(subject) and _shown.gates.has(subject):
				_shown.gates[subject]["mode"] = str(state.gates[subject]["mode"])
		PuzzleEvent.BLOCKER_REMOVED:
			if state.blockers.has(subject) and _shown.blockers.has(subject):
				_shown.blockers[subject]["active"] = bool(state.blockers[subject]["active"])
		PuzzleEvent.PIECE_REVEALED:
			if state.pieces.has(subject) and _shown.pieces.has(subject):
				_shown.pieces[subject]["revealed"] = bool(state.pieces[subject]["revealed"])

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

## Cells of push past the last landing that turn a drag into an exit.
static func exit_past(near_edge: bool) -> float:
	var key := EXIT_PAST_EDGE_SETTING if near_edge else EXIT_PAST_SETTING
	var fallback := EXIT_PAST_AT_EDGE if near_edge else EXIT_PAST
	var value: Variant = ProjectSettings.get_setting(key, fallback)
	if not (value is float or value is int) or float(value) <= 0.0:
		return fallback
	return float(value)

static func steps_for_drag(travel_cells: float, max_dist: int, exit_ready: bool, near_edge: bool) -> int:
	if travel_cells < 0.5:
		return 0
	var past := exit_past(near_edge)
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
	advance_transition(delta)
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

## The frame is fitted together with the board: its outer edge spans the view's width (the
## same content edges as the HUD buttons) unless the height is the limit, and it never
## leaves the view. Gates are drawn inside the frame band.
func _layout() -> void:
	geometry.refit(definition.get("board", {}), size, center_vertically)
	_cell = geometry.cell
	_origin = geometry.origin

## Board and frame geometry in this view's local coordinates (tests and diagnostics).
func board_rect() -> Rect2:
	return geometry.board_rect()

func frame_rect() -> Rect2:
	return geometry.frame_rect()

## The cell under a local point; points on the frame or outside map off the board.
func cell_at(local: Vector2) -> Vector2i:
	return geometry.cell_at(local)

func cell_center(cell: Vector2i) -> Vector2:
	return geometry.cell_center(cell)

func _px(cell: Vector2i) -> Vector2:
	return geometry.cell_px(cell)

func _cell_at(px: Vector2) -> Vector2i:
	return geometry.cell_at(px)

func _draw() -> void:
	if state == null or definition.is_empty():
		return
	_layout()
	# Before the container lays the board out, cells are a pixel or less: nothing to draw,
	# and text glyphs would be asked for a zero font size.
	if _cell < 4.0:
		return
	var board: Dictionary = definition.get("board", {})
	var cols := int(board.get("cols", 1))
	var rows := int(board.get("rows", 1))
	_round(frame_rect(), TD35Theme.FRAME, int(clampf(_cell * 0.22, 12.0, 28.0)))
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
	# Mechanic flags come from what the player has seen so far; geometry stays authoritative.
	var flags := shown_state()
	for blocker in definition.get("blockers", []):
		if typeof(blocker) != TYPE_DICTIONARY:
			continue
		var bid := str(blocker.get("id", ""))
		if flags.blockers.has(bid) and bool(flags.blockers[bid]["active"]):
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
		if flags.pieces.has(id) and not bool(flags.pieces[id].get("revealed", true)):
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
	# Visual derived from the gate state the player has seen (shown_state): scheduled colour
	# for a color-switching gate, a locked style + lock glyph while LOCKED, a counter badge.
	var gid := str(gate.get("id", ""))
	var gstate: Dictionary = shown_state().gates.get(gid, {})
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
	var slot := gate_slot(gate, cols, rows)
	if slot.size == Vector2.ZERO:
		return
	# The slot is a recess in the frame band, the same colour as the board bed, so the gate
	# reads as an opening in an unbroken frame; the coloured lip sits inside it.
	var lip := slot.grow(-maxf(1.5, _cell * FRAME_RATIO * 0.1))
	_round(slot, TD35Theme.BASE, int(clampf(_cell * 0.08, 3.0, 8.0)))
	_round(lip, color, int(clampf(_cell * 0.06, 2.0, 6.0)))
	if locked:
		_glyph_lock(lip.get_center())
	var remaining := int(gstate.get("counter_remaining", -1))
	if remaining > 0:
		_badge(lip.get_center(), str(remaining))

## A gate's slot in local coordinates (BoardGeometry.gate_slot).
func gate_slot(gate: Dictionary, cols: int, rows: int) -> Rect2:
	return geometry.gate_slot(gate, cols, rows)

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
	var lifted := 1.0
	if id == _drag_id and alpha > 0.99:
		lifted = 1.025
	for corner in corners:
		var pixel := base + Vector2(corner) * _cell
		var from_center := pixel - (base + center * _cell)
		var placed := base + center * _cell + from_center * 0.94 * lifted
		# Within the 3 % inset the 0.94 scale leaves, so a resting piece's shadow stays on its
		# own cells and never spills onto the frame or a gate.
		shadow.append(placed + Vector2(0, _cell * 0.03))
		body.append(placed)
	var shadow_color := Color(TD35Theme.SHADOW, 0.28 * alpha)
	draw_colored_polygon(shadow, shadow_color)
	var edge := color.darkened(0.28)
	edge.a = alpha
	draw_colored_polygon(body, color)
	var shine := color.lightened(0.28)
	shine.a = 0.42 * alpha
	# Gloss: the body shrunk inwards, nudged up by less than the shrink, so it always stays
	# inside the piece outline (also for L-shapes).
	var inset := _cell * 0.07
	for gloss in Geometry2D.offset_polygon(body, -inset, Geometry2D.JOIN_MITER):
		var moved := PackedVector2Array()
		for point in gloss:
			moved.append(point + Vector2(0, -inset * 0.5))
		if moved.size() >= 3:
			draw_colored_polygon(moved, shine)
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
