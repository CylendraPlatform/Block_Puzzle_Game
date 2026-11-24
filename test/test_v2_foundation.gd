extends SceneTree
## TD-1 foundation tests. Schema JSON files are not solver-proven levels.
##   godot --headless --path . --script res://test/test_v2_foundation.gd

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _initialize() -> void:
	print("== test_v2_foundation ==")
	_schema_cases()
	_legacy_roundtrip()
	_state_and_transition()
	_search_status()
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

func _schema_cases() -> void:
	var minimal := _load_fixture("schema_minimal.json")
	_ok(LevelValidator.validate_v2(minimal).is_empty(), "minimal schema fixture validates")
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(_load_fixture("schema_disconnected.json")), "DISCONNECTED_PIECE"), "disconnected piece is rejected")
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(_load_fixture("schema_overlap.json")), "OVERLAP"), "overlapping pieces are rejected")
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(_load_fixture("schema_gate_overlap.json")), "OVERLAPPING_GATES"), "overlapping gates are rejected")
	var colors := LevelValidator.validate_v2(_load_fixture("schema_bad_color.json"))
	_ok(LevelValidator.has_code(colors, "INVALID_COLOR"), "unknown color is rejected")
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(_load_fixture("schema_bad_trigger.json")), "MALFORMED_TRIGGER"), "trigger without when is rejected")
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(_load_fixture("schema_duplicate_id.json")), "DUPLICATE_ID"), "duplicate piece id is rejected")
	var hidden := _load_fixture("schema_hidden_locked.json")
	_ok(LevelValidator.validate_v2(hidden).is_empty(), "locked and hidden schema parses without executing it")
	var unsupported := {"schema_version": 9, "id": "nope"}
	var loaded: Dictionary = LevelLoader.load_definition(unsupported)
	_ok(loaded["ok"] == false and LevelValidator.has_code(loaded["diagnostics"], "UNSUPPORTED_VERSION"), "unsupported schema version is rejected")
	var missing_version := {"id": 3, "name": "Legacy shape", "cols": 3, "rows": 3, "blocks": [{"id": "b1", "color": "red", "cells": [[0, 0]], "pos": [0, 0]}], "gates": [{"color": "red", "side": "right", "lo": 0, "hi": 0}]}
	var v1_load: Dictionary = LevelLoader.load_definition(missing_version)
	_ok(v1_load["source"] == "v1" and v1_load["legacy"] is Level, "missing schema_version uses the legacy parser")
	var missing_id: Dictionary = minimal.duplicate(true)
	missing_id["pieces"][0]["id"] = ""
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(missing_id), "MISSING_FIELD"), "missing piece id is rejected")
	var outside: Dictionary = minimal.duplicate(true)
	outside["pieces"][0]["pos"] = [9, 9]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(outside), "OUT_OF_BOUNDS"), "out-of-bounds occupancy is rejected")
	var extra: Dictionary = minimal.duplicate(true)
	extra["teleport"] = true
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(extra), "UNSUPPORTED_MECHANIC"), "unknown mechanic field is rejected")
	var envelopes := PuzzleEvent.sort_stable([
		PuzzleEvent.make(PuzzleEvent.PIECE_EXITED, "b", 1),
		PuzzleEvent.make(PuzzleEvent.PIECE_MOVED, "a", 0),
	])
	_ok(envelopes[0].subject_id == "a" and envelopes[1].type == PuzzleEvent.PIECE_EXITED, "event envelopes sort by priority then subject")

func _legacy_roundtrip() -> void:
	var before_progress := Catalog.load_progress()
	var paths := Catalog.list_paths()
	_ok(paths.size() == 100, "legacy campaign still has 100 files (got %d)" % paths.size())
	var failures := 0
	for path in paths:
		var original := FileAccess.get_file_as_string(path)
		var raw: Variant = JSON.parse_string(original)
		if typeof(raw) != TYPE_DICTIONARY:
			failures += 1
			continue
		var data: Dictionary = raw
		var legacy := Level.from_dict(data)
		var adapted: Dictionary = V1Adapter.to_v2(data)
		if FileAccess.get_file_as_string(path) != original:
			failures += 1
			continue
		if not _same_geometry(legacy, adapted):
			failures += 1
			continue
		var diags := LevelValidator.validate_v2(adapted)
		if not diags.is_empty():
			print("  FAIL  adapter invalid ", path, " ", diags[0])
			failures += 1
			continue
		if legacy.blocks.is_empty():
			continue
		var blocks := legacy.clone_blocks()
		var outcome: Dictionary = Rules.slide_result(legacy, blocks, blocks[0], "right", 3)
		if not outcome.has("steps"):
			failures += 1
	_ok(failures == 0, "100 v1 levels adapt without rewriting files or changing occupancy")
	var first_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_001.json"))
	var first: Dictionary = first_raw
	var adapted_first: Dictionary = V1Adapter.to_v2(first)
	var piece: Dictionary = adapted_first["pieces"][0]
	var gate: Dictionary = adapted_first["gates"][0]
	_ok(piece["id"] == "b1" and piece["color"] == "green" and piece["pos"][0] == 0 and piece["pos"][1] == 4, "level 1 piece position is preserved")
	_ok(gate["side"] == "bottom" and gate["lo"] == 0 and gate["hi"] == 4 and gate["accept"][0] == "green" and gate["initial_state"] == "open", "level 1 gate span stays open")
	var after_progress := Catalog.load_progress()
	_ok(int(before_progress["unlocked"]) == int(after_progress["unlocked"]), "adapter does not change unlocked progress")
	_ok(str(before_progress["stars"]) == str(after_progress["stars"]), "adapter does not change best stars")

func _same_geometry(legacy: Level, adapted: Dictionary) -> bool:
	if int(adapted["board"]["cols"]) != legacy.cols or int(adapted["board"]["rows"]) != legacy.rows:
		return false
	if adapted["pieces"].size() != legacy.blocks.size() or adapted["gates"].size() != legacy.gates.size():
		return false
	for i in legacy.blocks.size():
		var old: Dictionary = legacy.blocks[i]
		var new: Dictionary = adapted["pieces"][i]
		if new["id"] != old["id"] or new["color"] != old["color"]:
			return false
		if int(new["pos"][0]) != old["pos"].x or int(new["pos"][1]) != old["pos"].y:
			return false
		if new["cells"].size() != old["cells"].size():
			return false
		for c in old["cells"].size():
			if int(new["cells"][c][0]) != old["cells"][c].x or int(new["cells"][c][1]) != old["cells"][c].y:
				return false
		var old_abs := Level.block_cells(old)
		for cell in old_abs:
			var found := false
			for offset in new["cells"]:
				if int(offset[0]) + int(new["pos"][0]) == cell.x and int(offset[1]) + int(new["pos"][1]) == cell.y:
					found = true
			if not found:
				return false
	for i in legacy.gates.size():
		var old_gate: Dictionary = legacy.gates[i]
		var new_gate: Dictionary = adapted["gates"][i]
		if new_gate["side"] != old_gate["side"] or int(new_gate["lo"]) != int(old_gate["lo"]) or int(new_gate["hi"]) != int(old_gate["hi"]):
			return false
		if new_gate["accept"][0] != old_gate["color"] or new_gate["initial_state"] != "open":
			return false
	return true

func _state_and_transition() -> void:
	var definition := _load_fixture("schema_minimal.json")
	var first := PuzzleState.from_definition(definition)
	var second := PuzzleState.new()
	second.schema_version = 2
	second.level_id = first.level_id
	second.gates["red_exit"] = {"mode": "OPEN", "counter_remaining": -1}
	second.pieces["r1"] = {"pos": Vector2i(1, 1), "active": true, "revealed": true}
	_ok(first.canonical_hash() == second.canonical_hash(), "state hash ignores dictionary insertion order")
	var copy := first.duplicate()
	copy.pieces["r1"]["pos"] = Vector2i(3, 3)
	copy.move_number = 2
	copy.trigger_fired["later"] = true
	_ok(first.pieces["r1"]["pos"] == Vector2i(1, 1) and first.move_number == 0, "deep copy does not share piece state")
	_ok(first.canonical_hash() != copy.canonical_hash(), "reveal, move number, and trigger flags change the hash")
	var before := first.canonical_text()
	var rejected: Dictionary = PuzzleEngine.transition(first, PuzzleAction.move("r1", "right", Vector2i(2, 1)), definition)
	_ok(rejected["ok"] == false and rejected["error"]["code"] == "RULES_NOT_IMPLEMENTED" and rejected["next_state"] == null, "unimplemented movement is an explicit rejection")
	_ok(first.canonical_text() == before, "rejected movement does not mutate state")
	var hidden := _load_fixture("schema_hidden_locked.json")
	var hidden_state := PuzzleState.from_definition(hidden)
	var hidden_before := hidden_state.canonical_text()
	var blocked: Dictionary = PuzzleEngine.transition(hidden_state, PuzzleAction.exit_through("g1", "green_exit"), hidden)
	_ok(blocked["error"]["code"] == "UNSUPPORTED_FEATURE" and blocked["ok"] == false, "hidden and locked mechanics do not pretend to run")
	_ok(hidden_state.canonical_text() == hidden_before, "unsupported feature rejection does not mutate state")
	_ok(bool(hidden_state.pieces["g1"]["revealed"]) == false and hidden_state.gates["green_exit"]["mode"] == "LOCKED", "state hash inputs keep reveal and lock flags")

func _search_status() -> void:
	_ok(PuzzleEngine.search_status(false, false, true) == PuzzleEngine.UNKNOWN_CAP_REACHED, "cap hit is UNKNOWN_CAP_REACHED")
	_ok(PuzzleEngine.search_status(false, false, true) != PuzzleEngine.UNSOLVABLE, "cap hit is not UNSOLVABLE")
	_ok(PuzzleEngine.search_status(false, true, false) == PuzzleEngine.UNSOLVABLE, "complete unsuccessful search is UNSOLVABLE")
	_ok(PuzzleEngine.search_status(true, true, false) == PuzzleEngine.SOLVED, "solved search stays SOLVED")

func _load_fixture(name: String) -> Dictionary:
	var text := FileAccess.get_file_as_string("res://test/fixtures/v2/" + name)
	var parsed: Variant = JSON.parse_string(text)
	return parsed as Dictionary
