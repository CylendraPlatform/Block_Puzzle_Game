extends SceneTree
## M1.2 Phase A/C: BoardViewV2 reads live state; hidden pieces / blockers are not grabbable.
##   godot --headless --path . --script res://test/test_m1_2_view.gd

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _initialize() -> void:
	print("== test_m1_2_view ==")
	var defn := {
		"schema_version": 2, "id": "m2v", "name": "view",
		"board": {"cols": 4, "rows": 4, "walls": []},
		"pieces": [
			{"id": "red", "color": "red", "cells": [[0, 0]], "pos": [0, 0], "required": true, "reveal": "visible"},
			{"id": "green", "color": "green", "cells": [[0, 0]], "pos": [2, 2], "required": true, "reveal": "hidden"},
		],
		"gates": [
			{"id": "red_left", "side": "left", "lo": 0, "hi": 0, "accept": ["red"], "initial_state": "open"},
			{"id": "green_bottom", "side": "bottom", "lo": 2, "hi": 2, "accept": ["green"], "initial_state": "open"},
		],
		"blockers": [{"id": "b1", "cell": [3, 3]}],
		"triggers": [{"id": "t", "when": {"event": "piece_exited", "piece_id": "red"}, "effect": {"type": "reveal_piece", "piece_id": "green"}}],
		"goals": {"all_required_pieces_exited": true},
	}
	_ok(LevelValidator.validate_v2(defn).is_empty(), "fixture is schema-valid")
	var view := BoardViewV2.new()
	root.add_child(view)
	view.show_state(defn, PuzzleState.from_definition(defn))

	# A visible piece is grabbable at its cell; the hidden piece and the blocker cell are not.
	_ok(view._piece_at(Vector2i(0, 0)) == "red", "visible piece is grabbable")
	_ok(view._piece_at(Vector2i(2, 2)) == "", "hidden piece is not grabbable until revealed")
	_ok(view._piece_at(Vector2i(3, 3)) == "", "blocker cell is not a grabbable piece")

	# After the engine reveals green, it becomes grabbable (view reflects authoritative state).
	var revealed := PuzzleState.from_definition(defn)
	revealed.pieces["green"]["revealed"] = true
	view.show_state(defn, revealed)
	_ok(view._piece_at(Vector2i(2, 2)) == "green", "revealed piece becomes grabbable")

	view.queue_free()

	# Compile-smoke the QA screen scripts + catalog (headless can't render, but this catches
	# syntax/contract errors) and confirm the advanced QA catalog is campaign-separate.
	_ok(load("res://scripts/game/pilot_game.gd") != null, "PilotGame compiles")
	_ok(load("res://scripts/game/advanced_qa.gd") != null, "AdvancedQA compiles")
	_ok(AdvancedCatalog.list_paths().size() == 3, "advanced QA catalog lists the 3 advanced levels")

	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)
