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
	_gesture_threshold()
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

func _gesture_threshold() -> void:
	_ok(BoardViewV2.steps_for_drag(0.4, 3, true, false) == 0, "a tiny swipe does not commit")
	_ok(BoardViewV2.steps_for_drag(1.1, 3, true, false) == 1, "a one-cell swipe stays on that landing")
	_ok(BoardViewV2.steps_for_drag(3.0, 3, true, false) == 3, "releasing on the last cell does not exit")
	_ok(BoardViewV2.steps_for_drag(3.33, 3, true, false) == 3, "a push short of the exit threshold stays on the board")
	_ok(BoardViewV2.steps_for_drag(3.34, 3, true, false) == 4, "a 0.34-cell push past the last cell requests the exit")
	_ok(BoardViewV2.steps_for_drag(3.11, 3, true, true) == 3, "the screen-edge zone still allows a stop on the last cell")
	_ok(BoardViewV2.steps_for_drag(3.12, 3, true, true) == 4, "the screen-edge zone exits after a 0.12-cell push")
	_ok(BoardViewV2.steps_for_drag(6.0, 2, false, false) == 2, "a blocked drag stops on the furthest landing")
	for spec in [
		["right", "right", Vector2i(0, 2), [1, 0]],
		["left", "left", Vector2i(4, 2), [1, 0]],
		["down", "bottom", Vector2i(2, 0), [0, 1]],
		["up", "top", Vector2i(2, 4), [0, 1]],
	]:
		_assert_clear_exit(spec[0], spec[1], spec[2], [[0, 0]])
	_assert_clear_exit("right", "right", Vector2i(0, 2), [[0, 0], [1, 0], [2, 0]])
	_assert_clear_exit("down", "bottom", Vector2i(2, 0), [[0, 0], [0, 1]])
	var blocked := _open_board({
		"board": {"cols": 4, "rows": 1, "walls": [[2, 0]]},
		"pieces": [{"id": "red", "color": "red", "cells": [[0, 0]], "pos": [0, 0], "required": true, "reveal": "visible"}],
		"gates": [{"id": "red_right", "side": "right", "lo": 0, "hi": 0, "accept": ["red"], "initial_state": "open"}],
	})
	var blocked_actions := PuzzleEngine.legal_actions(blocked, PuzzleState.from_definition(blocked), "red")
	var blocked_steps := BoardViewV2.steps_for_drag(5.0, 1, false, false)
	var blocked_choice := BoardViewV2.choose_action(blocked_actions, Vector2i(0, 0), "right", blocked_steps)
	_ok(blocked_choice != null and blocked_choice.kind == PuzzleAction.MOVE and blocked_choice.landing == Vector2i(1, 0), "a wall in front of a gate does not become an exit")

func _assert_clear_exit(direction: String, side: String, pos: Vector2i, cells: Array) -> void:
	var definition := _open_board({
		"board": {"cols": 5, "rows": 5, "walls": []},
		"pieces": [{"id": "red", "color": "red", "cells": cells, "pos": [pos.x, pos.y], "required": true, "reveal": "visible"}],
		"gates": [{"id": "gate", "side": side, "lo": 0, "hi": 4, "accept": ["red"], "initial_state": "open"}],
	})
	var state := PuzzleState.from_definition(definition)
	var actions := PuzzleEngine.legal_actions(definition, state, "red")
	var max_dist := 0
	for action in actions:
		if action.kind == PuzzleAction.MOVE and action.direction == direction:
			var dist := absi(action.landing.x - pos.x) + absi(action.landing.y - pos.y)
			max_dist = maxi(max_dist, dist)
	var held := BoardViewV2.choose_action(actions, pos, direction, BoardViewV2.steps_for_drag(float(max_dist), max_dist, true, false))
	var flick := BoardViewV2.choose_action(actions, pos, direction, BoardViewV2.steps_for_drag(float(max_dist) + BoardViewV2.EXIT_PAST, max_dist, true, false))
	_ok(held != null and held.kind == PuzzleAction.MOVE, "%s hold on the last cell stays a move" % direction)
	_ok(flick != null and flick.kind == PuzzleAction.EXIT, "%s flick past the last cell exits" % direction)
	var session := PuzzleSessionV2.open(definition)
	var applied := session.commit(flick)
	_ok(bool(applied["ok"]) and session.move_count() == 1, "%s exit is one committed move" % direction)
	_ok(session.undo() and session.move_count() == 0 and bool(session.state.pieces["red"]["active"]), "%s undo restores the piece after the exit" % direction)

func _open_board(body: Dictionary) -> Dictionary:
	body["schema_version"] = 2
	body["id"] = "gesture"
	body["name"] = "Gesture"
	body["goals"] = {"all_required_pieces_exited": true}
	body["authored_metrics"] = {}
	var loaded := LevelLoader.load_definition(body)
	_ok(bool(loaded["ok"]), "gesture fixture validates")
	return loaded["definition"]

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
