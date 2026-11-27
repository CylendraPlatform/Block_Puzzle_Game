extends SceneTree
## BoardViewV2 presentation geometry for every Classic level at phone-sized views:
## the frame stays inside the view with balanced margins, gate slots stay inside the frame
## band (the outer rim is never cut), and touch still maps to the right cells / pieces.
## Presentation only: no rule, save or routing code is exercised beyond legal_actions.
##   godot --headless --path . --script res://test/test_board_geometry.gd

## Board-view sizes: the GameScreen board area (safe content width x height below the HUD)
## for 360x800, 393x852, 411x891 and the Galaxy M31 canvas (720x1560), plus a short view
## that makes the height the limit.
const VIEWS := [
	{"name": "360x800", "size": Vector2(328, 560)},
	{"name": "393x852", "size": Vector2(361, 600)},
	{"name": "411x891", "size": Vector2(379, 640)},
	{"name": "m31", "size": Vector2(688, 1380)},
	{"name": "height-limited", "size": Vector2(688, 300)},
]
const EPS := 0.01

var _fails := 0
var _checks := 0

func _ok(c: bool, m: String) -> void:
	_checks += 1
	if not c:
		print("  FAIL  ", m)
		_fails += 1

func _initialize() -> void:
	print("== test_board_geometry ==")
	var levels := _classic_levels()
	_ok(levels.size() == 100, "found the 100 Classic levels (%d)" % levels.size())
	var view := BoardViewV2.new()
	view.center_vertically = true
	root.add_child(view)
	for spec in VIEWS:
		var before := _fails
		for item in levels:
			_check_level(view, item["name"], item["definition"], spec)
		print("  %s %s: %d level(s) checked, %d failure(s)" % ["PASS" if _fails == before else "FAIL", spec["name"], levels.size(), _fails - before])
	_check_swipe(view, levels[0]["definition"])
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

func _check_level(view: BoardViewV2, name: String, defn: Dictionary, spec: Dictionary) -> void:
	var tag := "%s/%s" % [spec["name"], name]
	view.size = spec["size"]
	view.show_state(defn, PuzzleState.from_definition(defn))
	view._layout()
	var area := Rect2(Vector2.ZERO, view.size)
	var frame := view.frame_rect()
	var left := frame.position.x
	var right := area.end.x - frame.end.x
	var top := frame.position.y
	var bottom := area.end.y - frame.end.y
	_ok(area.grow(EPS).encloses(frame), "%s frame %s inside view %s" % [tag, frame, area])
	_ok(absf(left - right) < EPS, "%s left/right margins equal (%.2f / %.2f)" % [tag, left, right])
	_ok(absf(top - bottom) < EPS, "%s top/bottom margins equal (%.2f / %.2f)" % [tag, top, bottom])
	_ok(left < EPS or top <= BoardViewV2.FRAME_GAP_Y + EPS, "%s frame fills the limiting dimension" % tag)
	var board := view.board_rect()
	var band := board.position.x - frame.position.x
	_ok(absf(band - view._cell * BoardViewV2.FRAME_RATIO) < EPS, "%s frame band is FRAME_RATIO cells" % tag)
	var cols := int(defn["board"]["cols"])
	var rows := int(defn["board"]["rows"])
	var lanes_by_side := {}
	for gate in defn.get("gates", []):
		var gid := str(gate.get("id", ""))
		var slot := view.gate_slot(gate, cols, rows)
		_ok(slot.size.x > 0.0 and slot.size.y > 0.0, "%s gate %s has a slot" % [tag, gid])
		_ok(frame.grow(-1.0).encloses(slot), "%s gate %s slot %s keeps an unbroken outer rim inside %s" % [tag, gid, slot, frame])
		# Cell doors: the rail covers exactly lo..hi (never narrower than the rule) and there is
		# one door per cell in that range, inside the rail, centred on its cell.
		var lo := int(gate["lo"])
		var hi := int(gate["hi"])
		var side := str(gate["side"])
		var vertical := side == "left" or side == "right"
		var along_start := slot.position.y if vertical else slot.position.x
		var along_len := slot.size.y if vertical else slot.size.x
		var edge_start := board.position.y if vertical else board.position.x
		_ok(absf(along_start - (edge_start + lo * view._cell)) < EPS and absf(along_len - (hi - lo + 1) * view._cell) < EPS, "%s gate %s rail spans exactly %d..%d" % [tag, gid, lo, hi])
		var doors := view.gate_doors(gate, cols, rows)
		_ok(doors.size() == hi - lo + 1, "%s gate %s has one door per cell (%d)" % [tag, gid, doors.size()])
		for i in doors.size():
			var door: Rect2 = doors[i]
			var c := door.get_center()
			var cell_mid := edge_start + (lo + i + 0.5) * view._cell
			_ok(slot.grow(EPS).encloses(door), "%s gate %s door %d inside its rail" % [tag, gid, i])
			_ok(absf((c.y if vertical else c.x) - cell_mid) < EPS, "%s gate %s door %d centred on cell %d" % [tag, gid, i, lo + i])
		var lane := view.gate_lane(gate)
		if not lanes_by_side.has(side):
			lanes_by_side[side] = []
		lanes_by_side[side].append(lane)
	# Gates on one edge (all Classic shared edges overlap fully) get distinct lanes 0..n-1.
	for side in lanes_by_side.keys():
		var lanes: Array = lanes_by_side[side]
		var seen := {}
		for lane in lanes:
			seen[(lane as Vector2i).x] = true
			_ok((lane as Vector2i).y == lanes.size(), "%s %s edge: lane count %d matches %d gate(s)" % [tag, side, (lane as Vector2i).y, lanes.size()])
		_ok(seen.size() == lanes.size(), "%s %s edge: every gate has its own lane" % [tag, side])
	# Touch mapping: centres and both inner corners of every cell map back to that cell;
	# points on the frame band map off the board.
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var p := view._px(c)
			_ok(view.cell_at(view.cell_center(c)) == c, "%s centre of %s maps back" % [tag, c])
			_ok(view.cell_at(p + Vector2(0.5, 0.5)) == c and view.cell_at(p + Vector2.ONE * (view._cell - 0.5)) == c, "%s corners of %s map back" % [tag, c])
	var mid := board.get_center()
	_ok(view.cell_at(Vector2(frame.position.x + 1.0, mid.y)).x < 0, "%s left frame band is off the board" % tag)
	_ok(view.cell_at(Vector2(frame.end.x - 1.0, mid.y)).x >= cols, "%s right frame band is off the board" % tag)
	_ok(view.cell_at(Vector2(mid.x, frame.position.y + 1.0)).y < 0, "%s top frame band is off the board" % tag)
	_ok(view.cell_at(Vector2(mid.x, frame.end.y - 1.0)).y >= rows, "%s bottom frame band is off the board" % tag)
	for id in view.state.pieces.keys():
		var piece: Dictionary = view.state.pieces[id]
		if not bool(piece.get("revealed", true)):
			continue
		_ok(view._piece_at(view.cell_at(view.cell_center(piece["pos"]))) == str(id), "%s touch on %s grabs it" % [tag, id])

## A real swipe through _gui_input commits the same action choose_action picks for it.
func _check_swipe(view: BoardViewV2, defn: Dictionary) -> void:
	view.size = VIEWS[3]["size"]
	view.show_state(defn, PuzzleState.from_definition(defn))
	view._layout()
	var committed: Array = []
	view.commit_requested.connect(func(a: PuzzleAction) -> void: committed.append(a))
	var picked: PuzzleAction = null
	var piece_id := ""
	for id in view.state.pieces.keys():
		for item in PuzzleEngine.legal_actions(defn, view.state, id):
			var action := item as PuzzleAction
			if action != null and action.kind != PuzzleAction.EXIT:
				picked = action
				piece_id = str(id)
				break
		if picked != null:
			break
	_ok(picked != null, "level 1 has a legal in-board move")
	if picked == null:
		return
	var origin: Vector2i = view.state.pieces[piece_id]["pos"]
	var dist := absi(picked.landing.x - origin.x) + absi(picked.landing.y - origin.y)
	var start := view.cell_center(origin)
	var finish := start + Vector2(view._dir(picked.direction)) * view._cell * float(dist)
	view._gui_input(_touch(start, true))
	view._gui_input(_drag(start.lerp(finish, 0.5)))
	view._gui_input(_drag(finish))
	view._gui_input(_touch(finish, false))
	_ok(committed.size() == 1, "swipe commits exactly one action (%d)" % committed.size())
	if committed.size() == 1:
		var got := committed[0] as PuzzleAction
		_ok(got.direction == picked.direction and got.landing == picked.landing, "swipe on %s %s lands on %s" % [piece_id, picked.direction, picked.landing])

func _touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	return e

func _drag(pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.position = pos
	return e
