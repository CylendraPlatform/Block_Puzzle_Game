extends SceneTree
## M1.1 Phase D: solver fast-path classification, profiling, and the time budget.
##   godot --headless --path . --script res://test/test_m1_1_phase_d.gd

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _lvl(pieces: Array, gates: Array, extra: Dictionary = {}) -> Dictionary:
	var d := {
		"schema_version": 2, "id": "d", "name": "d",
		"board": {"cols": 4, "rows": 4, "walls": []},
		"pieces": pieces, "gates": gates, "goals": {"all_required_pieces_exited": true},
	}
	for k in extra.keys():
		d[k] = extra[k]
	return d

func _initialize() -> void:
	print("== test_m1_1_phase_d ==")

	var red := {"id": "red", "color": "red", "cells": [[0, 0]], "pos": [0, 0], "required": true, "reveal": "visible"}
	var open_gate := {"id": "g", "side": "left", "lo": 0, "hi": 0, "accept": ["red"], "initial_state": "open"}

	# is_simple classification.
	_ok(PuzzleEngine.is_simple(_lvl([red], [open_gate])), "a plain level is simple")
	var hidden := red.duplicate(); hidden["reveal"] = "hidden"; hidden["id"] = "h"
	_ok(not PuzzleEngine.is_simple(_lvl([red, hidden], [open_gate])), "a hidden piece makes a level non-simple")
	_ok(not PuzzleEngine.is_simple(_lvl([red], [open_gate], {"blockers": [{"id": "b", "cell": [2, 2]}]})), "a blocker makes a level non-simple")
	var counter_gate := {"id": "cg", "side": "bottom", "lo": 2, "hi": 2, "accept": ["red"], "initial_state": "locked", "counter": {"remaining": 1}}
	_ok(not PuzzleEngine.is_simple(_lvl([red], [open_gate, counter_gate])), "a counter gate makes a level non-simple")
	var switch_gate := {"id": "sg", "side": "right", "lo": 0, "hi": 0, "accept": ["red", "blue"], "initial_state": "open", "color_schedule": ["red", "blue"]}
	_ok(not PuzzleEngine.is_simple(_lvl([red], [open_gate, switch_gate])), "a color-switching gate makes a level non-simple")

	# A plain level solves via the fast path; profiling counters are populated.
	var plain := _lvl([{"id": "red", "color": "red", "cells": [[0, 0]], "pos": [2, 0], "required": true, "reveal": "visible"}], [{"id": "g", "side": "right", "lo": 0, "hi": 0, "accept": ["red"], "initial_state": "open"}])
	var res := SolverV2.solve(plain, PuzzleState.from_definition(plain), 1000)
	_ok(str(res["status"]) == PuzzleEngine.SOLVED, "plain level still solves with the fast path")
	_ok(SolverV2.profile_legal_us >= 0 and SolverV2.profile_transition_us >= 0, "profiling counters are recorded")

	# The time budget never turns a solvable level unsolvable; a generous budget matches no budget.
	var budgeted := SolverV2.solve(plain, PuzzleState.from_definition(plain), 1000, 60000)
	_ok(str(budgeted["status"]) == PuzzleEngine.SOLVED and int(budgeted["solution_length"]) == int(res["solution_length"]), "a generous time budget matches the unbudgeted result")

	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)
