extends SceneTree
## Shape labels, siding fingerprints, and near-duplicate guards.
##   godot --headless --path . --script res://test/test_td36_metrics.gd

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _initialize() -> void:
	print("== test_td36_metrics ==")
	_ok(PuzzleMetrics.classify_shape([[0, 0]]) == "monomino", "monomino")
	_ok(PuzzleMetrics.classify_shape([[0, 0], [1, 0]]) == "domino", "domino")
	_ok(PuzzleMetrics.classify_shape([[0, 0], [0, 1], [1, 1]]) == "L-tromino", "L-tromino")
	_ok(PuzzleMetrics.classify_shape([[0, 0], [1, 0], [2, 0]]) == "I-tromino", "I-tromino")
	_ok(PuzzleMetrics.classify_shape([[1, 0], [0, 1], [1, 1], [2, 1]]) == "T-tetromino", "T-tetromino")
	_ok(PuzzleMetrics.classify_shape([[1, 0], [2, 0], [0, 1], [1, 1]]) == "S-tetromino", "S-tetromino")
	_ok(PuzzleMetrics.classify_shape([[0, 0], [1, 0], [1, 1], [2, 1]]) == "Z-tetromino", "Z-tetromino")
	_ok(PuzzleMetrics.classify_shape([[0, 0], [0, 1], [1, 1], [1, 2]]) == "S-tetromino", "S-tetromino vertical")
	_ok(PuzzleMetrics.classify_shape([[1, 0], [0, 1], [1, 1], [2, 1], [1, 2]]) == "custom-5", "plus pentomino")
	var siding := PuzzleMetrics.structural_fingerprint({
		"board": {"cols": 8, "rows": 2, "walls": []},
		"pieces": [
			{"cells": [[0, 0]], "color": "red"},
			{"cells": [[0, 0]], "color": "blue"},
			{"cells": [[0, 0]], "color": "green"},
			{"cells": [[0, 0]], "color": "yellow"},
		],
		"gates": [],
	})
	_ok(str(siding["family"]) == "siding_1d", "four monominoes on 2 rows are siding_1d")
	_ok(PuzzleMetrics.near_duplicate(siding, siding), "identical siding fingerprints are near-duplicates")
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)
