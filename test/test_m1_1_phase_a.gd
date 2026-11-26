extends SceneTree
## M1.1 Phase A: gate-transition table + invariant state validation.
##   godot --headless --path . --script res://test/test_m1_1_phase_a.gd

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _gate(id: String, side: String, lo: int, hi: int, accept: Array, extra: Dictionary = {}) -> Dictionary:
	var g := {"id": id, "side": side, "lo": lo, "hi": hi, "accept": accept}
	for k in extra.keys():
		g[k] = extra[k]
	return g

func _base(gates: Array) -> Dictionary:
	return {
		"schema_version": 2, "id": "pa", "name": "phase a",
		"board": {"cols": 4, "rows": 4, "walls": []},
		"pieces": [{"id": "r", "color": "red", "cells": [[0, 0]], "pos": [0, 1], "required": true, "reveal": "visible"}],
		"gates": gates,
		"goals": {"all_required_pieces_exited": true},
	}

func _conflict(gates: Array) -> bool:
	return LevelValidator.has_code(LevelValidator.validate_v2(_base(gates)), "GATE_STATE_CONFLICT")

func _initialize() -> void:
	print("== test_m1_1_phase_a ==")

	# --- Gate-transition table ---
	var rg := func(extra): return _gate("rg", "left", 1, 1, ["red"], extra)
	_ok(not _conflict([rg.call({"initial_state": "open"})]), "open + no mechanism is valid")
	_ok(_conflict([rg.call({"initial_state": "open", "unlock_when": {"event": "piece_exited", "piece_id": "r"}})]), "open + unlock_when is rejected")
	_ok(_conflict([rg.call({"initial_state": "open", "counter": {"remaining": 1}})]), "open + counter is rejected")
	_ok(_conflict([rg.call({"initial_state": "locked"})]), "locked + no mechanism is rejected")
	_ok(not _conflict([rg.call({"initial_state": "locked", "unlock_when": {"event": "color_exits_at_least", "color": "red", "count": 1}})]), "locked + unlock_when is valid")
	_ok(not _conflict([rg.call({"initial_state": "locked", "counter": {"remaining": 2}})]), "locked + counter is valid")
	_ok(_conflict([rg.call({"initial_state": "locked", "unlock_when": {"event": "color_exits_at_least", "color": "red", "count": 1}, "counter": {"remaining": 2}})]), "locked + both mechanisms is rejected")

	# --- Invariant _state_problem ---
	var defn := {
		"schema_version": 2, "id": "pa2", "name": "phase a states",
		"board": {"cols": 4, "rows": 4, "walls": []},
		"pieces": [
			{"id": "r", "color": "red", "cells": [[0, 0]], "pos": [0, 1], "required": true, "reveal": "visible"},
			{"id": "h", "color": "green", "cells": [[0, 0]], "pos": [2, 2], "required": false, "reveal": "hidden"},
		],
		"gates": [
			{"id": "rg", "side": "left", "lo": 1, "hi": 1, "accept": ["red"], "initial_state": "open"},
			{"id": "cg", "side": "bottom", "lo": 2, "hi": 2, "accept": ["green"], "initial_state": "locked", "counter": {"remaining": 2}},
		],
		"triggers": [
			{"id": "t1", "when": {"event": "color_exits_at_least", "color": "red", "count": 1}, "effect": {"type": "decrement_counter", "gate_id": "cg"}},
		],
		"blockers": [{"id": "b1", "cell": [3, 3]}],
		"goals": {"all_required_pieces_exited": true},
	}
	_ok(LevelValidator.validate_v2(defn).is_empty(), "the state fixture is schema-valid")

	_ok(PuzzleEngine._state_problem(defn, PuzzleState.from_definition(defn), null) == "", "initial state is accepted")

	# Legitimate mutations accepted.
	var s = PuzzleState.from_definition(defn); s.gates["cg"]["counter_remaining"] = 1
	_ok(PuzzleEngine._state_problem(defn, s, null) == "", "decremented counter (2->1) accepted")
	s = PuzzleState.from_definition(defn); s.gates["cg"]["counter_remaining"] = 0; s.gates["cg"]["mode"] = "OPEN"
	_ok(PuzzleEngine._state_problem(defn, s, null) == "", "counter 0 + gate OPEN accepted")
	s = PuzzleState.from_definition(defn); s.pieces["h"]["revealed"] = true
	_ok(PuzzleEngine._state_problem(defn, s, null) == "", "revealed hidden piece accepted")
	s = PuzzleState.from_definition(defn); s.blockers["b1"]["active"] = false
	_ok(PuzzleEngine._state_problem(defn, s, null) == "", "removed blocker accepted")
	s = PuzzleState.from_definition(defn); s.event_counters["red"] = 1
	_ok(PuzzleEngine._state_problem(defn, s, null) == "", "exit counter within bound accepted")

	# Forged / impossible states rejected.
	s = PuzzleState.from_definition(defn); s.gates["cg"]["counter_remaining"] = 3
	_ok(PuzzleEngine._state_problem(defn, s, null) != "", "counter above initial rejected")
	s = PuzzleState.from_definition(defn); s.gates["cg"]["counter_remaining"] = -1
	_ok(PuzzleEngine._state_problem(defn, s, null) != "", "counter below zero rejected")
	s = PuzzleState.from_definition(defn); s.gates["rg"]["mode"] = "LOCKED"
	_ok(PuzzleEngine._state_problem(defn, s, null) != "", "static-open gate forced LOCKED rejected")
	s = PuzzleState.from_definition(defn); s.pieces["r"]["revealed"] = false
	_ok(PuzzleEngine._state_problem(defn, s, null) != "", "visible piece unrevealed rejected")
	s = PuzzleState.from_definition(defn); s.event_counters["red"] = 2
	_ok(PuzzleEngine._state_problem(defn, s, null) != "", "exit counter above color cap rejected")
	s = PuzzleState.from_definition(defn); s.event_counters["blue"] = 1
	_ok(PuzzleEngine._state_problem(defn, s, null) != "", "exit counter for absent color rejected")
	s = PuzzleState.from_definition(defn); s.blockers["b1"]["counter_remaining"] = 5
	_ok(PuzzleEngine._state_problem(defn, s, null) != "", "blocker counter above sentinel rejected")

	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)
