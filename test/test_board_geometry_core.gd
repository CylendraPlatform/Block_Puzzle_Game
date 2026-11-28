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
## 5. Partial gate: on prototype level A (a two-cell door on a five-cell edge), a drag of the
##    aligned block commits exactly one EXIT through that door; a misaligned block (rows 0-1,
##    against the frame, or half over the door) never commits an EXIT. user:// is snapshotted
##    before and after to prove nothing is written.

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
	before = _checks
	var user_before := _user_snapshot()
	_partial_gate(view)
	_ok(_user_snapshot() == user_before, "partial gate: user:// unchanged (no progress or save written)")
	print("  partial gate: %d check(s)" % (_checks - before))
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

## Real swipes through a short positioned gate (prototype level A: a two-cell red door on the
## right edge, rows 2-3, of a 5x5 board). The definition comes from the design folder in res://;
## no campaign, progress store or save is touched.
const PROTO_A := "res://design/gate_proto/levels/proto_a.json"

func _partial_gate(view: BoardViewV2) -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROTO_A))
	var loaded := LevelLoader.load_definition(raw if raw is Dictionary else {})
	_ok(bool(loaded["ok"]) and str(loaded["source"]) == "v2", "partial gate: proto_a loads as schema v2")
	if not bool(loaded["ok"]):
		return
	var defn: Dictionary = loaded["definition"]
	var gate: Dictionary = defn["gates"][0]
	var rows := int(defn["board"]["rows"])
	_ok(str(gate["side"]) == "right" and int(gate["hi"]) - int(gate["lo"]) + 1 < rows, "partial gate: the door is shorter than its edge")
	var committed: Array = []
	var record := func(a: PuzzleAction) -> void: committed.append(a)
	view.commit_requested.connect(record)
	for size in [VIEWS[3], VIEWS[0]]:
		var start := PuzzleState.from_definition(defn)
		# Aligned: drop the tall block to rows 2-3, then a drag right must leave through the door.
		var aligned := _apply(defn, start, "red", "down", Vector2i(1, 2))
		if aligned != null:
			_gate_swipe(view, defn, aligned, size, "right", 6.0, committed, true, "aligned @%s" % size)
		# Misaligned at the start (rows 0-1): a long drag right slides to the frame, never exits.
		_gate_swipe(view, defn, start, size, "right", 6.0, committed, false, "misaligned rows 0-1 @%s" % size)
		# Against the frame, still misaligned: the drag must commit nothing at all.
		var at_frame := _apply(defn, start, "red", "right", Vector2i(4, 0))
		if at_frame != null:
			_gate_swipe(view, defn, at_frame, size, "right", 2.0, committed, false, "at frame rows 0-1 @%s" % size)
		# Half over the door (rows 1-2): partial overlap is not an exit either.
		var half := _apply(defn, start, "red", "down", Vector2i(1, 1))
		if half != null:
			half = _apply(defn, half, "red", "right", Vector2i(4, 1))
		if half != null:
			_gate_swipe(view, defn, half, size, "right", 2.0, committed, false, "half over the door rows 1-2 @%s" % size)
	view.commit_requested.disconnect(record)

## Applies the legal MOVE of `id` in `direction` that lands on `landing`; null (and a failure) if none.
func _apply(defn: Dictionary, state: PuzzleState, id: String, direction: String, landing: Vector2i) -> PuzzleState:
	for item in PuzzleEngine.legal_actions(defn, state, id):
		var a := item as PuzzleAction
		if a != null and a.kind == PuzzleAction.MOVE and a.direction == direction and a.landing == landing:
			var result := PuzzleEngine.transition(state, a, defn)
			if bool(result["ok"]):
				return result["next_state"]
	_ok(false, "partial gate: setup move %s %s to %s is legal" % [id, direction, landing])
	return null

## Drags the red block `cells` cells in `direction` through _gui_input. With `expect_exit`, the
## engine must offer that exit and exactly one matching EXIT must be committed; otherwise the
## engine must offer none and no committed action may be an EXIT.
func _gate_swipe(view: BoardViewV2, defn: Dictionary, state: PuzzleState, size: Vector2, direction: String, cells: float, committed: Array, expect_exit: bool, tag: String) -> void:
	view.center_vertically = true
	view.size = size
	view.show_state(defn, state)
	view._layout()
	var engine_exit: PuzzleAction = null
	var max_dist := 0
	var origin: Vector2i = state.pieces["red"]["pos"]
	for item in PuzzleEngine.legal_actions(defn, state, "red"):
		var a := item as PuzzleAction
		if a == null or a.direction != direction:
			continue
		if a.kind == PuzzleAction.EXIT:
			engine_exit = a
		else:
			max_dist = maxi(max_dist, absi(a.landing.x - origin.x) + absi(a.landing.y - origin.y))
	_ok((engine_exit != null) == expect_exit, "partial gate %s: engine %s" % [tag, "offers the exit" if expect_exit else "offers no exit"])
	if expect_exit:
		cells = float(max_dist) + BoardViewV2.EXIT_PAST + 0.4
	committed.clear()
	var start := view.cell_center(origin)
	var finish := start + Vector2(view._dir(direction)) * view._cell * cells
	view._gui_input(_touch(start, true))
	view._gui_input(_drag(start.lerp(finish, 0.5)))
	view._gui_input(_drag(finish))
	view._gui_input(_touch(finish, false))
	var exits := committed.filter(func(a): return (a as PuzzleAction).kind == PuzzleAction.EXIT)
	if expect_exit:
		_ok(committed.size() == 1 and exits.size() == 1, "partial gate %s: exactly one EXIT committed (%d action(s))" % [tag, committed.size()])
		if exits.size() == 1:
			var got := exits[0] as PuzzleAction
			_ok(got.direction == direction and got.gate_id == str(defn["gates"][0]["id"]) and got.piece_id == "red", "partial gate %s: exit %s through %s" % [tag, got.direction, got.gate_id])
	else:
		_ok(exits.is_empty(), "partial gate %s: no EXIT committed (%d action(s))" % [tag, committed.size()])
		if max_dist == 0:
			_ok(committed.is_empty(), "partial gate %s: nothing committed against the frame" % tag)
		else:
			_ok(committed.size() == 1 and (committed[0] as PuzzleAction).landing == origin + view._dir(direction) * max_dist, "partial gate %s: one slide to the frame" % tag)

## Names, sizes and modification times of everything under user:// (to prove nothing is written).
func _user_snapshot() -> Array:
	var out: Array = []
	_walk("user://", out)
	out.sort()
	return out

func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		var path := dir.path_join(f)
		out.append("%s|%d|%d" % [path, FileAccess.get_size(path), FileAccess.get_modified_time(path)])
	for sub in d.get_directories():
		_walk(dir.path_join(sub), out)

func _touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	return e

func _drag(pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.position = pos
	return e
