extends SceneTree
## Headless session and drag-intent tests. Not a device test.
##   godot --headless --path . --script res://test/test_v2_session.gd

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _initialize() -> void:
	print("== test_v2_session ==")
	_commit_undo_restart()
	_drag_choice()
	_campaign_untouched()
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

func _level(path: String) -> Dictionary:
	return PilotCatalog.read_definition(path)

func _commit_undo_restart() -> void:
	var definition := _level("res://levels_v2/pilot/v2_001.json")
	var session := PuzzleSessionV2.open(definition)
	var before := session.state.canonical_text()
	var bad := session.commit(PuzzleAction.move("red", "up", Vector2i(0, -1)))
	_ok(not bool(bad["ok"]) and session.state.canonical_text() == before, "an illegal drag does not change the session")
	var actions := PuzzleEngine.legal_actions(definition, session.state, "red")
	var exit_action: PuzzleAction = null
	for action in actions:
		if action.kind == PuzzleAction.EXIT:
			exit_action = action
	_ok(exit_action != null, "the first pilot level offers a straight exit")
	var applied := session.commit(exit_action)
	_ok(bool(applied["ok"]) and session.is_won() and session.move_count() == 1, "one exit wins the first pilot level")
	_ok(session.undo() and not session.is_won() and session.move_count() == 0, "undo restores the board after an exit")
	session.commit(exit_action)
	session.restart()
	_ok(not session.is_won() and session.move_count() == 0 and session.state.pieces["red"]["active"], "restart restores the authored start")
	session.input_locked = true
	var locked_before := session.state.canonical_text()
	var locked := session.commit(exit_action)
	_ok(not bool(locked["ok"]) and locked["error"]["code"] == "BUSY" and session.state.canonical_text() == locked_before, "a locked board rejects input without mutation")
	var optional := _level("res://levels_v2/pilot/v2_014.json")
	var replay := SolverV2.solve(optional, PuzzleState.from_definition(optional), 4000)
	var cursor := PuzzleSessionV2.open(optional)
	var won := true
	for action in replay["witness"]:
		if not bool(cursor.commit(action)["ok"]):
			won = false
	_ok(replay["status"] == PuzzleEngine.SOLVED and won and cursor.is_won() and bool(cursor.state.pieces["yellow"]["active"]), "an optional piece can remain when the required piece has left")

func _drag_choice() -> void:
	var definition := _level("res://levels_v2/pilot/v2_010.json")
	var state := PuzzleState.from_definition(definition)
	var actions := PuzzleEngine.legal_actions(definition, state, "purple")
	var origin: Vector2i = state.pieces["purple"]["pos"]
	var one := BoardViewV2.choose_action(actions, origin, "right", 1)
	var far := BoardViewV2.choose_action(actions, origin, "right", 9)
	_ok(one != null and one.kind == PuzzleAction.MOVE and one.landing == Vector2i(1, 1), "a short drag selects the intermediate landing")
	_ok(far != null and far.kind == PuzzleAction.MOVE and far.landing.x > one.landing.x, "a long drag without an exit stops at the furthest landing")
	var direct := _level("res://levels_v2/pilot/v2_001.json")
	var direct_state := PuzzleState.from_definition(direct)
	var direct_actions := PuzzleEngine.legal_actions(direct, direct_state, "red")
	var outward := BoardViewV2.choose_action(direct_actions, direct_state.pieces["red"]["pos"], "right", 9)
	_ok(outward != null and outward.kind == PuzzleAction.EXIT, "dragging past the edge commits the exit")

func _campaign_untouched() -> void:
	var unlocked := Catalog.load_unlocked()
	PilotCatalog.save_index(3)
	_ok(Catalog.load_unlocked() == unlocked, "pilot progress does not change the campaign unlock")
	var commercial := Catalog.list_paths()
	var leaked := false
	for path in commercial:
		if path.contains("levels_v2"):
			leaked = true
	_ok(commercial.size() == 100 and not leaked, "the commercial catalog still lists only the original 100 levels")
