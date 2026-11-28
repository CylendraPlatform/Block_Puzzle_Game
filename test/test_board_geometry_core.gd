extends SceneTree
## BoardGeometry (GP-1 step 1): the pure board layout that BoardViewV2, input and the theme
## skins share. Presentation only: no rules, saves or routing are changed or written.
##   godot --headless --path . --script res://test/test_board_geometry_core.gd
##
## 1. Hand-computed layouts.
## 2. Equivalence with the previous implementation: LegacyLayout below is a frozen copy of
##    BoardViewV2's layout / slot / mapping code from main before the extraction (59a07dc).
##    Every Classic level, every supported view size, centred and top-aligned: cell size,
##    origin, board and frame rects, every gate slot, every cell centre and corner, frame
##    band off the board.
## 3. Reuse: one BoardGeometry and one BoardViewV2 reused across a different level, other
##    board dimensions, a resize, an alignment switch and repeated unchanged calls; each
##    result must equal a fresh fit and the legacy reference.
## 4. Touch: a real swipe through _gui_input commits an in-board move and a drag-to-exit
##    commits the exit, on a reused view.

const VIEWS := [Vector2(328, 560), Vector2(361, 600), Vector2(379, 640), Vector2(688, 1380), Vector2(688, 300)]
const EPS := 0.0001

var _fails := 0
var _checks := 0

func _ok(c: bool, m: String) -> void:
	_checks += 1
	if not c:
		print("  FAIL  ", m)
		_fails += 1

func _near(a: float, b: float) -> bool:
	return absf(a - b) < EPS

## Frozen copy of the pre-extraction BoardViewV2 code (main @ 59a07dc, _layout, board_rect,
## frame_rect, _px, _cell_at, gate_slot). Do not "fix" this: it is the reference.
class LegacyLayout:
	const FRAME_RATIO := 0.26
	const FRAME_GAP_Y := 12.0
	const GATE_DEPTH := 0.8
	var _cell := 48.0
	var _origin := Vector2.ZERO
	var definition: Dictionary = {}

	func layout(defn: Dictionary, size: Vector2, center_vertically: bool) -> void:
		definition = defn
		var board: Dictionary = definition.get("board", {})
		var cols := int(board.get("cols", 1))
		var rows := int(board.get("rows", 1))
		var span := Vector2(cols, rows) + Vector2.ONE * FRAME_RATIO * 2.0
		var avail := Vector2(maxf(1.0, size.x), maxf(1.0, size.y - FRAME_GAP_Y * 2.0))
		_cell = minf(avail.x / span.x, avail.y / span.y)
		var frame := _cell * FRAME_RATIO
		var board_size := Vector2(_cell * cols, _cell * rows)
		var outer_h := board_size.y + frame * 2.0
		var spare_y := maxf(0.0, size.y - outer_h)
		var top := spare_y * 0.5 if center_vertically else minf(28.0, spare_y * 0.16)
		_origin = Vector2((size.x - board_size.x) * 0.5, top + frame)

	func board_rect() -> Rect2:
		var board: Dictionary = definition.get("board", {})
		return Rect2(_origin, Vector2(int(board.get("cols", 1)), int(board.get("rows", 1))) * _cell)

	func frame_rect() -> Rect2:
		return board_rect().grow(_cell * FRAME_RATIO)

	func px(cell: Vector2i) -> Vector2:
		return _origin + Vector2(cell) * _cell

	func cell_at(p: Vector2) -> Vector2i:
		var local := (p - _origin) / _cell
		return Vector2i(floori(local.x), floori(local.y))

	func gate_slot(gate: Dictionary, cols: int, rows: int) -> Rect2:
		var lo := int(gate.get("lo", 0))
		var hi := int(gate.get("hi", lo))
		var along := float(hi - lo + 1) * _cell
		var pad := clampf(_cell * 0.08, 2.0, 6.0)
		var depth := _cell * FRAME_RATIO * GATE_DEPTH
		match str(gate.get("side", "")):
			"left":
				return Rect2(_origin.x - depth, _origin.y + lo * _cell + pad, depth + 1.0, along - pad * 2.0)
			"right":
				return Rect2(_origin.x + cols * _cell - 1.0, _origin.y + lo * _cell + pad, depth + 1.0, along - pad * 2.0)
			"top":
				return Rect2(_origin.x + lo * _cell + pad, _origin.y - depth, along - pad * 2.0, depth + 1.0)
			"bottom":
				return Rect2(_origin.x + lo * _cell + pad, _origin.y + rows * _cell - 1.0, along - pad * 2.0, depth + 1.0)
		return Rect2()

func _initialize() -> void:
	print("== test_board_geometry_core ==")
	var levels := _classic_levels()
	_ok(levels.size() == 100, "found the 100 Classic levels (%d)" % levels.size())
	_hand_computed()
	var before := _checks
	var view := BoardViewV2.new()
	root.add_child(view)
	for item in levels:
		for size in VIEWS:
			for centred in [true, false]:
				_equivalent(view, item["name"], item["definition"], size, centred)
	print("  equivalence: %d level(s) x %d view(s) x 2 alignments, %d check(s)" % [levels.size(), VIEWS.size(), _checks - before])
	before = _checks
	_reuse(view, levels)
	print("  reuse: %d check(s)" % (_checks - before))
	before = _checks
	_swipes(view, levels)
	print("  swipes: %d check(s)" % (_checks - before))
	view.queue_free()
	print("== done: %d check(s), %d failure(s) ==" % [_checks, _fails])
	quit(_fails)

func _classic_levels() -> Array:
	var out: Array = []
	var files := DirAccess.get_files_at("res://levels")
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/" + f))
		var loaded := LevelLoader.load_definition(raw if raw is Dictionary else {})
		if bool(loaded["ok"]):
			out.append({"name": f.get_basename(), "definition": loaded["definition"]})
		else:
			_ok(false, "%s loads" % f)
	return out

func _hand_computed() -> void:
	# 6x6 board in a 328x560 view, centred: span = 6 + 2 * 0.26 = 6.52 cells each way.
	var g := BoardGeometry.fit({"cols": 6, "rows": 6}, Vector2(328, 560), true)
	var cell := 328.0 / 6.52
	_ok(_near(g.cell, cell), "6x6 width-limited cell %.4f == %.4f" % [g.cell, cell])
	var outer := 6.0 * cell + 2.0 * cell * 0.26
	_ok(_near(g.origin.x, (328.0 - 6.0 * cell) * 0.5), "6x6 origin x centred")
	_ok(_near(g.origin.y, (560.0 - outer) * 0.5 + cell * 0.26), "6x6 origin y centred")
	_ok(g.board_rect().is_equal_approx(Rect2(g.origin, Vector2(6, 6) * cell)), "board rect")
	_ok(g.frame_rect().is_equal_approx(g.board_rect().grow(cell * 0.26)), "frame rect = board grown by the band")
	_ok(_near(g.frame_band(), cell * 0.26), "frame band")
	var t := BoardGeometry.fit({"cols": 6, "rows": 6}, Vector2(328, 560), false)
	_ok(_near(t.origin.y, minf(28.0, (560.0 - outer) * 0.16) + cell * 0.26), "top-aligned origin y")
	var h := BoardGeometry.fit({"cols": 6, "rows": 6}, Vector2(688, 300), true)
	_ok(_near(h.cell, 276.0 / 6.52), "height-limited cell")
	_ok(g.cell_at(g.cell_center(Vector2i(4, 1))) == Vector2i(4, 1), "centre maps back")
	_ok(g.cell_at(g.cell_px(Vector2i(0, 0)) - Vector2(1, 1)) == Vector2i(-1, -1), "outside top-left is off the board")
	var pad := clampf(cell * 0.08, 2.0, 6.0)
	var depth := cell * 0.26 * 0.8
	_ok(g.gate_slot({"side": "left", "lo": 2, "hi": 3}).is_equal_approx(Rect2(g.origin.x - depth, g.origin.y + 2.0 * cell + pad, depth + 1.0, 2.0 * cell - pad * 2.0)), "left gate slot rows 2..3")
	_ok(g.gate_slot({"side": "nowhere", "lo": 0, "hi": 0}) == Rect2(), "unknown side gives an empty slot")
	var e := BoardGeometry.fit({}, Vector2(100, 100), true)
	_ok(e.cols == 1 and e.rows == 1 and e.cell > 0.0, "missing board falls back to 1x1")

## Geometry `g` (and, when given, the view laid out the same way) equals the legacy reference.
func _same_as_legacy(g: BoardGeometry, defn: Dictionary, size: Vector2, centred: bool, tag: String, view: BoardViewV2 = null) -> void:
	var ref := LegacyLayout.new()
	ref.layout(defn, size, centred)
	var board: Dictionary = defn.get("board", {})
	var cols := int(board.get("cols", 1))
	var rows := int(board.get("rows", 1))
	_ok(_near(g.cell, ref._cell) and g.origin.is_equal_approx(ref._origin), "%s cell / origin" % tag)
	_ok(g.board_rect().is_equal_approx(ref.board_rect()), "%s board rect" % tag)
	_ok(g.frame_rect().is_equal_approx(ref.frame_rect()), "%s frame rect" % tag)
	for gate in defn.get("gates", []):
		var want := ref.gate_slot(gate, cols, rows)
		_ok(g.gate_slot(gate).is_equal_approx(want) and g.gate_slot(gate, cols, rows).is_equal_approx(want), "%s gate %s slot" % [tag, gate.get("id", "")])
		if view != null:
			_ok(view.gate_slot(gate, cols, rows).is_equal_approx(want), "%s view gate %s slot" % [tag, gate.get("id", "")])
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var p := ref.px(c)
			_ok(g.cell_px(c).is_equal_approx(p) and g.cell_center(c).is_equal_approx(p + Vector2(ref._cell, ref._cell) * 0.5), "%s cell %s position" % [tag, c])
			_ok(g.cell_at(p + Vector2(0.5, 0.5)) == c and g.cell_at(p + Vector2.ONE * (ref._cell - 0.5)) == c and g.cell_at(g.cell_center(c)) == c, "%s cell %s touch" % [tag, c])
	var frame := ref.frame_rect()
	var mid := ref.board_rect().get_center()
	for probe in [Vector2(frame.position.x + 1.0, mid.y), Vector2(frame.end.x - 1.0, mid.y), Vector2(mid.x, frame.position.y + 1.0), Vector2(mid.x, frame.end.y - 1.0)]:
		_ok(g.cell_at(probe) == ref.cell_at(probe), "%s frame probe %s maps like before" % [tag, probe])
	if view != null:
		_ok(_near(view._cell, ref._cell) and view._origin.is_equal_approx(ref._origin), "%s view mirrors" % tag)
		_ok(view.board_rect().is_equal_approx(ref.board_rect()) and view.frame_rect().is_equal_approx(ref.frame_rect()), "%s view rects" % tag)
		var c := Vector2i(cols - 1, rows - 1)
		_ok(view._px(c).is_equal_approx(ref.px(c)) and view.cell_at(view.cell_center(c)) == c, "%s view touch" % tag)

func _layout_view(view: BoardViewV2, defn: Dictionary, size: Vector2, centred: bool) -> void:
	view.center_vertically = centred
	view.size = size
	view.show_state(defn, PuzzleState.from_definition(defn))
	view._layout()

func _equivalent(view: BoardViewV2, name: String, defn: Dictionary, size: Vector2, centred: bool) -> void:
	_layout_view(view, defn, size, centred)
	var tag := "%s @%s %s" % [name, size, "centred" if centred else "top"]
	_same_as_legacy(BoardGeometry.fit(defn["board"], size, centred), defn, size, centred, tag, view)

func _reuse(view: BoardViewV2, levels: Array) -> void:
	# Pick two levels with different board dimensions.
	var a: Dictionary = levels[0]["definition"]
	var b: Dictionary = {}
	for item in levels:
		var d: Dictionary = item["definition"]
		if d["board"]["cols"] != a["board"]["cols"] or d["board"]["rows"] != a["board"]["rows"]:
			b = d
			break
	_ok(not b.is_empty(), "found two Classic levels with different board sizes")
	if b.is_empty():
		return
	var steps := [
		["first level", a, VIEWS[0], true],
		["different level and board dimensions", b, VIEWS[0], true],
		["viewport resize", b, VIEWS[3], true],
		["switch to top-aligned", b, VIEWS[3], false],
		["back to the first level", a, VIEWS[4], false],
		["switch back to centred", a, VIEWS[4], true],
	]
	var g := BoardGeometry.new()
	for step in steps:
		var defn: Dictionary = step[1]
		g.refit(defn["board"], step[2], step[3])
		_layout_view(view, defn, step[2], step[3])
		var tag := "reuse: %s" % step[0]
		_same_as_legacy(g, defn, step[2], step[3], tag, view)
		var fresh := BoardGeometry.fit(defn["board"], step[2], step[3])
		_ok(g.cols == fresh.cols and g.rows == fresh.rows and _near(g.cell, fresh.cell) and g.origin.is_equal_approx(fresh.origin), "%s equals a fresh fit" % tag)
	# Repeated calls without changes leave everything identical (no drift).
	var last: Array = steps[-1]
	var cell := g.cell
	var origin := g.origin
	for i in 5:
		g.refit(last[1]["board"], last[2], last[3])
		view._layout()
	_ok(g.cell == cell and g.origin == origin, "reuse: repeated refit is stable (exact)")
	_ok(view._cell == cell and view._origin == origin and view.geometry.cell == cell, "reuse: repeated view layout is stable (exact)")

## Real swipes through _gui_input on the reused view: an in-board move and a drag-to-exit.
func _swipes(view: BoardViewV2, levels: Array) -> void:
	var committed: Array = []
	var record := func(a: PuzzleAction) -> void: committed.append(a)
	view.commit_requested.connect(record)
	var moved := false
	var exited := false
	for item in levels:
		if moved and exited:
			break
		var defn: Dictionary = item["definition"]
		for size in [VIEWS[3], VIEWS[0]]:
			_layout_view(view, defn, size, true)
			for id in view.state.pieces.keys():
				for entry in PuzzleEngine.legal_actions(defn, view.state, id):
					var action := entry as PuzzleAction
					if action == null:
						continue
					if action.kind == PuzzleAction.EXIT and not exited:
						exited = _swipe(view, defn, str(id), action, committed, "%s @%s exit %s" % [item["name"], size, id])
					elif action.kind != PuzzleAction.EXIT and not moved:
						moved = _swipe(view, defn, str(id), action, committed, "%s @%s move %s" % [item["name"], size, id])
	view.commit_requested.disconnect(record)
	_ok(moved, "an in-board swipe was exercised")
	_ok(exited, "a drag-to-exit was exercised")

func _swipe(view: BoardViewV2, defn: Dictionary, id: String, action: PuzzleAction, committed: Array, tag: String) -> bool:
	_layout_view(view, defn, view.size, true)
	committed.clear()
	var origin: Vector2i = view.state.pieces[id]["pos"]
	var start := view.cell_center(origin)
	var cells := 0.0
	if action.kind == PuzzleAction.EXIT:
		# Past the last in-board landing by more than EXIT_PAST.
		cells = float(view._limits(action.direction)["max"]) + BoardViewV2.EXIT_PAST + 0.4
	else:
		cells = float(absi(action.landing.x - origin.x) + absi(action.landing.y - origin.y))
	var finish := start + Vector2(view._dir(action.direction)) * view._cell * cells
	view._gui_input(_touch(start, true))
	view._gui_input(_drag(start.lerp(finish, 0.5)))
	view._gui_input(_drag(finish))
	view._gui_input(_touch(finish, false))
	_ok(committed.size() == 1, "%s commits exactly one action (%d)" % [tag, committed.size()])
	if committed.size() != 1:
		return false
	var got := committed[0] as PuzzleAction
	if action.kind == PuzzleAction.EXIT:
		_ok(got.kind == PuzzleAction.EXIT and got.direction == action.direction, "%s is an exit %s" % [tag, action.direction])
	else:
		_ok(got.direction == action.direction and got.landing == action.landing, "%s lands on %s" % [tag, action.landing])
	return true

func _touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	return e

func _drag(pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.position = pos
	return e
