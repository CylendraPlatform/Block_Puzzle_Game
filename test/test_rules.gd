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

func _load(path: String) -> Level:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "missing " + path)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	return Level.from_dict(data)

func _initialize() -> void:
	print("== test_rules ==")

	# Level 1 — trivial single-drag exit.
	var l1 := _load("res://levels/level_001.json")
	_ok(l1.is_valid(), "L1 valid")
	var b1: Dictionary = l1.blocks[0]
	var r := Rules.slide_result(l1, l1.blocks, b1, "right", 9999)
	_ok(r["exit"] == true, "L1 red exits right")
	_ok(int(r["steps"]) == 3, "L1 red slides 3 then exits (got %d)" % int(r["steps"]))
	_ok(Rules.solve(l1)["solvable"] == true, "L1 solvable")

	# Level 2 — ordering: red blocked until blue leaves.
	var l2 := _load("res://levels/level_002.json")
	var red: Dictionary = l2.blocks[0]
	var rr := Rules.slide_result(l2, l2.blocks, red, "right", 9999)
	_ok(rr["exit"] == false, "L2 red cannot exit while blue blocks")
	_ok(int(rr["steps"]) == 1, "L2 red slides only 1 (got %d)" % int(rr["steps"]))
	_ok(Rules.solve(l2)["solvable"] == true, "L2 solvable")

	# Level 3 — multi-color, with a wall.
	var l3 := _load("res://levels/level_003.json")
	_ok(Rules.solve(l3)["solvable"] == true, "L3 solvable")

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
