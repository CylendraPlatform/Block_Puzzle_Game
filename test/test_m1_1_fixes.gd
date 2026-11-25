extends SceneTree
## M1.1 PR #10 review fixes: initial gate resolution, cascade bound, time budget.
##   godot --headless --path . --script res://test/test_m1_1_fixes.gd

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _solve(defn: Dictionary, budget_ms: int = 0) -> Dictionary:
	if not LevelValidator.validate_v2(defn).is_empty():
		return {"status": "INVALID", "len": -1, "explored": 0}
	var initial := PuzzleState.from_definition(defn)
	var res := SolverV2.solve(defn, initial, 200000, budget_ms)
	return {"status": str(res["status"]), "len": int(res["solution_length"]), "explored": int(res["explored_states"])}

func _initialize() -> void:
	print("== test_m1_1_fixes ==")

	# --- Finding #1: a counter:0 gate is open at t=0 before any action. ---
	var zero_counter := {
		"schema_version": 2, "id": "fix-zero", "name": "Zero Counter",
		"board": {"cols": 3, "rows": 1, "walls": []},
		"pieces": [{"id": "red", "color": "red", "cells": [[0, 0]], "pos": [1, 0], "required": true, "reveal": "visible"}],
		"gates": [{"id": "cg", "side": "right", "lo": 0, "hi": 0, "accept": ["red"], "initial_state": "locked", "counter": {"remaining": 0}}],
		"goals": {"all_required_pieces_exited": true},
	}
	_ok(LevelValidator.validate_v2(zero_counter).is_empty(), "counter:0 gate level is schema-valid")
	var zc_state := PuzzleState.from_definition(zero_counter)
	_ok(str(zc_state.gates["cg"]["mode"]) == "OPEN", "counter:0 gate is OPEN at t=0")
	var zc := _solve(zero_counter)
	_ok(zc["status"] == "SOLVED" and zc["len"] == 1, "counter:0 gate is solvable with no wasted move (len 1) got %s len %d" % [zc["status"], zc["len"]])

	# Control: a counter:1 gate with no decrementer stays locked and is unsolvable.
	var stuck := zero_counter.duplicate(true)
	stuck["id"] = "fix-stuck"
	stuck["gates"][0]["counter"] = {"remaining": 1}
	var stuck_state := PuzzleState.from_definition(stuck)
	_ok(str(stuck_state.gates["cg"]["mode"]) == "LOCKED", "counter:1 gate stays LOCKED at t=0")
	_ok(_solve(stuck)["status"] == "UNSOLVABLE", "counter:1 gate with no decrementer is unsolvable")

	# --- Finding #5: one exit fans out to several triggers in a single resolution. ---
	var fanout := {
		"schema_version": 2, "id": "fix-fanout", "name": "Fan-out",
		"board": {"cols": 4, "rows": 4, "walls": []},
		"pieces": [
			{"id": "red", "color": "red", "cells": [[0, 0]], "pos": [0, 0], "required": true, "reveal": "visible"},
			{"id": "green", "color": "green", "cells": [[0, 0]], "pos": [2, 2], "required": true, "reveal": "hidden"},
			{"id": "blue", "color": "blue", "cells": [[0, 0]], "pos": [3, 3], "required": true, "reveal": "visible"},
		],
		"gates": [
			{"id": "red_left", "side": "left", "lo": 0, "hi": 0, "accept": ["red"], "initial_state": "open"},
			{"id": "green_bottom", "side": "bottom", "lo": 2, "hi": 2, "accept": ["green"], "initial_state": "open"},
			{"id": "blue_bottom", "side": "bottom", "lo": 3, "hi": 3, "accept": ["blue"], "initial_state": "locked", "counter": {"remaining": 1}},
		],
		"blockers": [{"id": "b1", "cell": [2, 3]}],
		"triggers": [
			{"id": "t_reveal", "when": {"event": "piece_exited", "piece_id": "red"}, "effect": {"type": "reveal_piece", "piece_id": "green"}},
			{"id": "t_unblock", "when": {"event": "piece_exited", "piece_id": "red"}, "effect": {"type": "remove_blocker", "blocker_id": "b1"}},
			{"id": "t_dec", "when": {"event": "piece_exited", "piece_id": "red"}, "effect": {"type": "decrement_counter", "gate_id": "blue_bottom"}},
		],
		"goals": {"all_required_pieces_exited": true},
	}
	var fo := _solve(fanout)
	_ok(fo["status"] == "SOLVED" and fo["len"] == 3, "fan-out cascade (3 triggers on one exit) SOLVED len 3 got %s len %d" % [fo["status"], fo["len"]])

	# --- Finding #4: the time budget expires as UNKNOWN_CAP_REACHED, driven by an
	# injected clock so the result is independent of machine speed. The fake clock reads
	# 0 for the deadline computation and the first in-loop check (one state expands), then
	# jumps far past the deadline (the search stops). A 2-move level guarantees no child of
	# the initial state is a win, so the stop happens on the budget, not a solution. ---
	var two := {
		"schema_version": 2, "id": "fix-budget", "name": "Budget",
		"board": {"cols": 2, "rows": 1, "walls": []},
		"pieces": [
			{"id": "red", "color": "red", "cells": [[0, 0]], "pos": [0, 0], "required": true, "reveal": "visible"},
			{"id": "blue", "color": "blue", "cells": [[0, 0]], "pos": [1, 0], "required": true, "reveal": "visible"},
		],
		"gates": [
			{"id": "red_left", "side": "left", "lo": 0, "hi": 0, "accept": ["red"], "initial_state": "open"},
			{"id": "blue_right", "side": "right", "lo": 0, "hi": 0, "accept": ["blue"], "initial_state": "open"},
		],
		"goals": {"all_required_pieces_exited": true},
	}
	var calls := [0]
	SolverV2._clock = func() -> int:
		calls[0] += 1
		return 0 if calls[0] <= 2 else 1000000000
	var budgeted := SolverV2.solve(two, PuzzleState.from_definition(two), 200000, 1)
	SolverV2._clock = Callable()
	_ok(str(budgeted["status"]) == PuzzleEngine.UNKNOWN_CAP_REACHED, "injected-clock budget expiry reports UNKNOWN_CAP_REACHED (not SOLVED/UNSOLVABLE) got %s" % str(budgeted["status"]))
	_ok(int(budgeted["explored_states"]) == 1, "budget stopped deterministically after exactly one expansion (explored %d)" % int(budgeted["explored_states"]))
	# Sanity: the same level solves normally when the budget is disabled.
	_ok(_solve(two)["status"] == "SOLVED", "the budget level is genuinely solvable without a budget")

	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)
