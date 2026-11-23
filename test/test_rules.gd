extends SceneTree
## Headless logic tests. Run:
##   godot --headless --path . --script res://test/test_rules.gd
## Exits with code = number of failures (0 = all pass).

var _fails := 0

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  ", msg)
	else:
		print("  FAIL  ", msg)
		_fails += 1

func _initialize() -> void:
	print("== test_rules ==")

	# Fixed fixture: a 1x2 red block that must slide right to a red right-gate.
	var l1 := Level.from_dict({
		"id": 1, "name": "fixture1", "cols": 5, "rows": 5, "walls": [],
		"blocks": [{ "id": "b1", "color": "red", "cells": [[0,0],[1,0]], "pos": [0,2] }],
		"gates": [{ "color": "red", "side": "right", "lo": 2, "hi": 2 }],
	})
	_ok(l1.is_valid(), "L1 valid")
	var b1: Dictionary = l1.blocks[0]
	var r := Rules.slide_result(l1, l1.blocks, b1, "right", 9999)
	_ok(r["exit"] == true, "L1 red exits right")
	_ok(int(r["steps"]) == 3, "L1 red slides 3 then exits (got %d)" % int(r["steps"]))
	_ok(Rules.solve(l1)["solvable"] == true, "L1 solvable")

	# Ordering fixture: red can't exit right until blue (at x=4) leaves upward.
	var l2 := Level.from_dict({
		"id": 2, "name": "fixture2", "cols": 5, "rows": 5, "walls": [],
		"blocks": [
			{ "id": "b1", "color": "red", "cells": [[0,0]], "pos": [2,2] },
			{ "id": "b2", "color": "blue", "cells": [[0,0]], "pos": [4,2] },
		],
		"gates": [
			{ "color": "red", "side": "right", "lo": 2, "hi": 2 },
			{ "color": "blue", "side": "top", "lo": 4, "hi": 4 },
		],
	})
	var red: Dictionary = l2.blocks[0]
	var rr := Rules.slide_result(l2, l2.blocks, red, "right", 9999)
	_ok(rr["exit"] == false, "L2 red cannot exit while blue blocks")
	_ok(int(rr["steps"]) == 1, "L2 red slides only 1 (got %d)" % int(rr["steps"]))
	_ok(Rules.solve(l2)["solvable"] == true, "L2 solvable")

	# min-moves grading
	_ok(Rules.solve_min_moves(l1) == 1, "L1 min-moves is 1")
	_ok(Rules.solve_min_moves(l2) == 2, "L2 min-moves is 2")

	# Negative — a block whose only gate is the wrong color is unsolvable.
	var bad := Level.from_dict({
		"id": 99, "name": "bad", "cols": 3, "rows": 3, "walls": [],
		"blocks": [{ "id": "x", "color": "red", "cells": [[0,0]], "pos": [1,1] }],
		"gates": [{ "color": "blue", "side": "right", "lo": 1, "hi": 1 }],
	})
	_ok(Rules.solve(bad)["solvable"] == false, "mismatched-color level is unsolvable")

	# Win detection.
	_ok(Rules.is_won([]) == true, "empty board is won")

	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)
