extends SceneTree
## M1.1 Phase B: effect runtime, triggers, counters, blockers, hidden reveal.
##   godot --headless --path . --script res://test/test_m1_1_phase_b.gd

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

## Solve a definition and replay the witness. Returns {status, len, explored, hash}.
func _solve(defn: Dictionary) -> Dictionary:
	var diags := LevelValidator.validate_v2(defn)
	if not diags.is_empty():
		return {"status": "INVALID", "len": -1, "explored": 0, "hash": "", "diag": diags}
	var initial := PuzzleState.from_definition(defn)
	var res := SolverV2.solve(defn, initial, 200000)
	var final_hash := ""
	if str(res["status"]) == PuzzleEngine.SOLVED:
		var cursor := initial
		for action in res["witness"]:
			var applied := PuzzleEngine.transition(cursor, action, defn)
			if not bool(applied["ok"]):
				return {"status": "REPLAY_FAIL", "len": -1, "explored": int(res["explored_states"]), "hash": ""}
			cursor = applied["next_state"]
		if not PuzzleEngine.is_won(defn, cursor):
			return {"status": "REPLAY_NOT_WON", "len": -1, "explored": int(res["explored_states"]), "hash": ""}
		final_hash = cursor.canonical_hash()
	return {"status": str(res["status"]), "len": int(res["solution_length"]), "explored": int(res["explored_states"]), "hash": final_hash}

func _initialize() -> void:
	print("== test_m1_1_phase_b ==")

	# B1 Gatekeeper: red exit opens green's locked gate via unlock_when.
	var gatekeeper := {
		"schema_version": 2, "id": "b-gatekeeper", "name": "Gatekeeper",
		"board": {"cols": 4, "rows": 4, "walls": []},
		"pieces": [
			{"id": "red", "color": "red", "cells": [[0, 0]], "pos": [0, 0], "required": true, "reveal": "visible"},
			{"id": "green", "color": "green", "cells": [[0, 0]], "pos": [0, 2], "required": true, "reveal": "visible"},
		],
		"gates": [
			{"id": "red_left", "side": "left", "lo": 0, "hi": 0, "accept": ["red"], "initial_state": "open"},
			{"id": "green_left", "side": "left", "lo": 2, "hi": 2, "accept": ["green"], "initial_state": "locked", "unlock_when": {"event": "piece_exited", "piece_id": "red"}},
		],
		"goals": {"all_required_pieces_exited": true},
	}
	var r1 := _solve(gatekeeper)
	_ok(r1["status"] == "SOLVED" and r1["len"] == 2, "Gatekeeper SOLVED len 2 (unlock_when) got %s len %d" % [r1["status"], r1["len"]])

	# B2 Counter gate: two red exits decrement a counter to 0, opening blue's gate.
	var counter_gate := {
		"schema_version": 2, "id": "b-counter", "name": "Counter",
		"board": {"cols": 4, "rows": 4, "walls": []},
		"pieces": [
			{"id": "r1", "color": "red", "cells": [[0, 0]], "pos": [0, 0], "required": true, "reveal": "visible"},
			{"id": "r2", "color": "red", "cells": [[0, 0]], "pos": [0, 1], "required": true, "reveal": "visible"},
			{"id": "blue", "color": "blue", "cells": [[0, 0]], "pos": [3, 3], "required": true, "reveal": "visible"},
		],
		"gates": [
			{"id": "red_left", "side": "left", "lo": 0, "hi": 1, "accept": ["red"], "initial_state": "open"},
			{"id": "blue_bottom", "side": "bottom", "lo": 3, "hi": 3, "accept": ["blue"], "initial_state": "locked", "counter": {"remaining": 2}},
		],
		"triggers": [
			{"id": "t1", "when": {"event": "piece_exited", "piece_id": "r1"}, "effect": {"type": "decrement_counter", "gate_id": "blue_bottom"}},
			{"id": "t2", "when": {"event": "piece_exited", "piece_id": "r2"}, "effect": {"type": "decrement_counter", "gate_id": "blue_bottom"}},
		],
		"goals": {"all_required_pieces_exited": true},
	}
	var r2 := _solve(counter_gate)
	_ok(r2["status"] == "SOLVED" and r2["len"] == 3, "Counter gate SOLVED len 3 (counter->open) got %s len %d" % [r2["status"], r2["len"]])

	# B3 Blocker removal: a blocker blocks red's lane until green's exit removes it.
	var blocker_level := {
		"schema_version": 2, "id": "b-blocker", "name": "Blocker",
		"board": {"cols": 4, "rows": 4, "walls": []},
		"pieces": [
			{"id": "green", "color": "green", "cells": [[0, 0]], "pos": [0, 0], "required": true, "reveal": "visible"},
			{"id": "red", "color": "red", "cells": [[0, 0]], "pos": [0, 2], "required": true, "reveal": "visible"},
		],
		"gates": [
			{"id": "green_left", "side": "left", "lo": 0, "hi": 0, "accept": ["green"], "initial_state": "open"},
			{"id": "red_right", "side": "right", "lo": 2, "hi": 2, "accept": ["red"], "initial_state": "open"},
		],
		"blockers": [{"id": "b1", "cell": [2, 2]}],
		"triggers": [
			{"id": "t_rm", "when": {"event": "piece_exited", "piece_id": "green"}, "effect": {"type": "remove_blocker", "blocker_id": "b1"}},
		],
		"goals": {"all_required_pieces_exited": true},
	}
	# With the blocker present red cannot exit right; it must wait for removal.
	var blk_init := PuzzleState.from_definition(blocker_level)
	var red_exit_blocked := true
	for a in PuzzleEngine.legal_actions(blocker_level, blk_init, "red"):
		if a.kind == PuzzleAction.EXIT:
			red_exit_blocked = false
	_ok(red_exit_blocked, "active blocker prevents red's exit")
	var r3 := _solve(blocker_level)
	_ok(r3["status"] == "SOLVED" and r3["len"] == 2, "Blocker removal SOLVED len 2 got %s len %d" % [r3["status"], r3["len"]])

	# B4 Hidden Hand: a hidden required piece is revealed by a trigger, then must exit.
	var hidden_level := {
		"schema_version": 2, "id": "b-hidden", "name": "Hidden Hand",
		"board": {"cols": 4, "rows": 4, "walls": []},
		"pieces": [
			{"id": "red", "color": "red", "cells": [[0, 0]], "pos": [0, 0], "required": true, "reveal": "visible"},
			{"id": "green", "color": "green", "cells": [[0, 0]], "pos": [2, 2], "required": true, "reveal": "hidden"},
		],
		"gates": [
			{"id": "red_left", "side": "left", "lo": 0, "hi": 0, "accept": ["red"], "initial_state": "open"},
			{"id": "green_bottom", "side": "bottom", "lo": 2, "hi": 2, "accept": ["green"], "initial_state": "open"},
		],
		"triggers": [
			{"id": "t_reveal", "when": {"event": "piece_exited", "piece_id": "red"}, "effect": {"type": "reveal_piece", "piece_id": "green"}},
		],
		"goals": {"all_required_pieces_exited": true},
	}
	var hid_init := PuzzleState.from_definition(hidden_level)
	_ok(not PuzzleEngine.is_won(hidden_level, hid_init), "level not won while hidden required piece is present")
	var hid_actions := 0
	for a in PuzzleEngine.legal_actions(hidden_level, hid_init, "green"):
		hid_actions += 1
	_ok(hid_actions == 0, "hidden piece has no legal actions until revealed")
	var r4 := _solve(hidden_level)
	_ok(r4["status"] == "SOLVED" and r4["len"] == 2, "Hidden Hand SOLVED len 2 got %s len %d" % [r4["status"], r4["len"]])

	# Effects rollback: an effect on a missing target returns false.
	var st := PuzzleState.from_definition(gatekeeper)
	_ok(not Effects.apply({"type": "unlock_gate", "gate_id": "nope"}, st, []), "unlock_gate on missing target fails")
	_ok(not Effects.apply({"type": "reveal_piece", "piece_id": "nope"}, st, []), "reveal_piece on missing target fails")

	# Determinism: solving twice yields the same length and final-state hash.
	var again := _solve(gatekeeper)
	_ok(again["len"] == r1["len"] and again["hash"] == r1["hash"] and r1["hash"] != "", "deterministic solve (same length + final hash)")

	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)
