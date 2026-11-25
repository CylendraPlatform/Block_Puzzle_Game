extends SceneTree
## M1.1 Phase C: color-switching gates + phase-aware SolverV2.
##   godot --headless --path . --script res://test/test_m1_1_phase_c.gd

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _solve(defn: Dictionary) -> Dictionary:
	if not LevelValidator.validate_v2(defn).is_empty():
		return {"status": "INVALID", "len": -1, "hash": ""}
	var initial := PuzzleState.from_definition(defn)
	var res := SolverV2.solve(defn, initial, 200000)
	var final_hash := ""
	if str(res["status"]) == PuzzleEngine.SOLVED:
		var cursor := initial
		for action in res["witness"]:
			var applied := PuzzleEngine.transition(cursor, action, defn)
			if not bool(applied["ok"]):
				return {"status": "REPLAY_FAIL", "len": -1, "hash": ""}
			cursor = applied["next_state"]
		if not PuzzleEngine.is_won(defn, cursor):
			return {"status": "REPLAY_NOT_WON", "len": -1, "hash": ""}
		final_hash = cursor.canonical_hash()
	return {"status": str(res["status"]), "len": int(res["solution_length"]), "hash": final_hash}

func _initialize() -> void:
	print("== test_m1_1_phase_c ==")

	# Shiftgate: gate accepts blue at phase 0, red at phase 1. Red must spend one move
	# to advance the phase before it can exit.
	var shiftgate := {
		"schema_version": 2, "id": "c-shift", "name": "Shiftgate",
		"board": {"cols": 3, "rows": 1, "walls": []},
		"pieces": [{"id": "red", "color": "red", "cells": [[0, 0]], "pos": [0, 0], "required": true, "reveal": "visible"}],
		"gates": [{"id": "g", "side": "right", "lo": 0, "hi": 0, "accept": ["blue", "red"], "initial_state": "open", "color_schedule": ["blue", "red"]}],
		"goals": {"all_required_pieces_exited": true},
	}
	var init := PuzzleState.from_definition(shiftgate)
	var exits_at_phase0 := 0
	for a in PuzzleEngine.legal_actions(shiftgate, init, "red"):
		if a.kind == PuzzleAction.EXIT:
			exits_at_phase0 += 1
	_ok(exits_at_phase0 == 0, "red cannot exit at phase 0 (gate accepts blue)")
	var r := _solve(shiftgate)
	_ok(r["status"] == "SOLVED" and r["len"] == 2, "Shiftgate SOLVED len 2 (wait one phase) got %s len %d" % [r["status"], r["len"]])
	var again := _solve(shiftgate)
	_ok(again["len"] == r["len"] and again["hash"] == r["hash"] and r["hash"] != "", "deterministic solve (same length + final hash)")

	# Phase is in the search key: same board, different phase => different key.
	var p0 := PuzzleState.from_definition(shiftgate)
	var p1 := PuzzleState.from_definition(shiftgate)
	p1.move_number = 1
	p1.gates["g"]["phase"] = 1
	_ok(p0.search_key() != p1.search_key(), "gate phase distinguishes search states")

	# Two pieces, one per phase: phase 0 takes red, phase 1 takes blue.
	var pair := {
		"schema_version": 2, "id": "c-pair", "name": "Shift Pair",
		"board": {"cols": 3, "rows": 1, "walls": []},
		"pieces": [
			{"id": "red", "color": "red", "cells": [[0, 0]], "pos": [1, 0], "required": true, "reveal": "visible"},
			{"id": "blue", "color": "blue", "cells": [[0, 0]], "pos": [0, 0], "required": true, "reveal": "visible"},
		],
		"gates": [{"id": "g", "side": "right", "lo": 0, "hi": 0, "accept": ["red", "blue"], "initial_state": "open", "color_schedule": ["red", "blue"]}],
		"goals": {"all_required_pieces_exited": true},
	}
	var rp := _solve(pair)
	_ok(rp["status"] == "SOLVED" and rp["len"] == 2, "Shift Pair SOLVED len 2 (red then blue) got %s len %d" % [rp["status"], rp["len"]])

	# Malformed schedules are validation failures.
	var bad_color := shiftgate.duplicate(true)
	bad_color["gates"][0]["color_schedule"] = ["blue", "teal"]
	_ok(not LevelValidator.validate_v2(bad_color).is_empty(), "unknown color in schedule is rejected")
	var mismatch := shiftgate.duplicate(true)
	mismatch["gates"][0]["color_schedule"] = ["blue"]
	_ok(not LevelValidator.validate_v2(mismatch).is_empty(), "schedule not matching accept is rejected")
	var locked_switch := shiftgate.duplicate(true)
	locked_switch["gates"][0]["initial_state"] = "locked"
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(locked_switch), "GATE_STATE_CONFLICT"), "a locked color-switching gate is rejected")

	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)
