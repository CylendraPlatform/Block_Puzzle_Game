extends SceneTree
## Integration test for the continuous finger-follow drag in BoardView.
## Simulates a touch drag that slides a block out its matching gate and checks
## the `won` signal fires. Run:
##   godot --headless --path . --script res://test/test_drag.gd

var _won := false
var _fails := 0

func _ok(c: bool, m: String) -> void:
	print(("  PASS  " if c else "  FAIL  "), m)
	if not c:
		_fails += 1

func _initialize() -> void:
	print("== test_drag ==")
	var board := BoardView.new()
	board.size = Vector2(720, 1000)
	root.add_child(board)
	board.won.connect(func(): _won = true)
	var lv := Level.from_dict({
		"id": 1, "name": "d", "cols": 5, "rows": 5, "walls": [],
		"blocks": [{ "id": "b1", "color": "red", "cells": [[0,0]], "pos": [2,2] }],
		"gates": [{ "color": "red", "side": "right", "lo": 0, "hi": 4 }],
	})
	board.load_level(lv)
	await process_frame
	await process_frame   # let _process compute layout (_cell/_origin)

	var centre := board._px_from_cell(Vector2i(2, 2)) + Vector2(board._cell, board._cell) * 0.5
	board._begin_drag(centre)
	_ok(board._sel_id == "b1", "grab selects the block")
	board._update_drag(centre + Vector2(board._cell * 4.0, 0))
	_ok(board.blocks[0]["pos"] == Vector2i(4, 2), "drag slides block to the gate edge")
	_ok(board._pending_exit == true, "pushing past edge flags exit")
	board._end_drag()
	await create_timer(0.4).timeout   # exit pop tween + removal
	_ok(_won, "block exits gate and level is won")

	var b2 := BoardView.new()
	b2.size = Vector2(720, 1000)
	root.add_child(b2)
	b2.load_level(Level.from_dict({
		"id": 2, "name": "u", "cols": 5, "rows": 5, "walls": [],
		"blocks": [{ "id": "x", "color": "blue", "cells": [[0,0]], "pos": [0,2] }],
		"gates": [{ "color": "blue", "side": "right", "lo": 0, "hi": 4 }],
	}))
	await process_frame
	await process_frame
	var snap := b2.snapshot()
	var c2 := b2._px_from_cell(Vector2i(0, 2)) + Vector2(b2._cell, b2._cell) * 0.5
	b2._begin_drag(c2)
	b2._update_drag(c2 + Vector2(b2._cell * 2.0, 0))
	b2._end_drag()
	_ok(b2.blocks[0]["pos"] == Vector2i(2, 2), "drag moves block right by 2")
	b2.restore(snap)
	_ok(b2.blocks[0]["pos"] == Vector2i(0, 2), "undo restores original position")

	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)
