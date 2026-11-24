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
	_strict_rejections(minimal)

func _strict_rejections(minimal: Dictionary) -> void:
	var defaults: Dictionary = minimal.duplicate(true)
	defaults["pieces"][0].erase("reveal")
	defaults["pieces"][0].erase("required")
	defaults["board"].erase("walls")
	defaults.erase("rules")
	defaults.erase("goals")
	defaults.erase("triggers")
	_ok(LevelValidator.validate_v2(defaults).is_empty(), "omitted optional fields keep documented defaults")
	var fractional: Dictionary = minimal.duplicate(true)
	fractional["pieces"][0]["pos"] = [1.5, 1]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(fractional), "INVALID_COORDINATE"), "fractional coordinates are rejected")
	_ok(not PuzzleState.from_definition(fractional).pieces.has("r1"), "fractional coordinates are not truncated into state")
	var negative_fraction: Dictionary = minimal.duplicate(true)
	negative_fraction["pieces"][0]["pos"] = [-0.2, 1]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(negative_fraction), "INVALID_COORDINATE"), "negative fractional coordinates are rejected")
	var text_coord: Dictionary = minimal.duplicate(true)
	text_coord["pieces"][0]["pos"] = ["1", 1]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(text_coord), "INVALID_COORDINATE"), "string coordinates are not coerced")
	var bool_coord: Dictionary = minimal.duplicate(true)
	bool_coord["pieces"][0]["cells"] = [[true, 0]]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(bool_coord), "INVALID_COORDINATE"), "boolean coordinates are not coerced")
	var wide_pos: Dictionary = minimal.duplicate(true)
	wide_pos["pieces"][0]["pos"] = [1, 1, 0]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(wide_pos), "INVALID_COORDINATE"), "position arrays must have length 2")
	var short_cell: Dictionary = minimal.duplicate(true)
	short_cell["pieces"][0]["cells"] = [[0]]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(short_cell), "INVALID_COORDINATE"), "cell arrays must have length 2")
	var fractional_board: Dictionary = minimal.duplicate(true)
	fractional_board["board"]["cols"] = 4.5
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(fractional_board), "INVALID_COORDINATE"), "fractional board size is rejected")
	var quoted_version: Dictionary = minimal.duplicate(true)
	quoted_version["schema_version"] = "2"
	var quoted_load: Dictionary = LevelLoader.load_definition(quoted_version)
	_ok(quoted_load["source"] == "rejected" and LevelValidator.has_code(quoted_load["diagnostics"], "UNSUPPORTED_VERSION"), "string schema_version is not coerced")
	var fractional_version: Dictionary = minimal.duplicate(true)
	fractional_version["schema_version"] = 2.5
	_ok(LevelLoader.load_definition(fractional_version)["source"] == "rejected", "fractional schema_version is not coerced")
	var visibility: Dictionary = minimal.duplicate(true)
	visibility["pieces"][0].erase("reveal")
	visibility["pieces"][0]["visibility"] = "hidden"
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(visibility), "UNSUPPORTED_MECHANIC"), "visibility is not accepted in place of reveal")
	var gate_typo: Dictionary = minimal.duplicate(true)
	gate_typo["gates"][0]["colour"] = "red"
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(gate_typo), "UNSUPPORTED_MECHANIC"), "unknown gate fields are rejected")
	var numeric_id: Dictionary = minimal.duplicate(true)
	numeric_id["pieces"][0]["id"] = 1
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(numeric_id), "INVALID_TYPE"), "numeric piece ids are rejected")
	var rotation_text: Dictionary = minimal.duplicate(true)
	rotation_text["rules"]["rotation"] = "false"
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(rotation_text), "INVALID_TYPE"), "string rotation is not coerced to a boolean")
	var required_text: Dictionary = minimal.duplicate(true)
	required_text["pieces"][0]["required"] = "yes"
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(required_text), "INVALID_TYPE"), "string required flag is rejected")
	var missing_piece: Dictionary = minimal.duplicate(true)
	missing_piece["triggers"] = [{"id": "t1", "when": {"event": "piece_exited", "piece_id": "missing"}, "effect": {"type": "reveal_piece", "piece_id": "r1"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(missing_piece), "UNKNOWN_REFERENCE"), "condition piece ids must exist")
	var gate_as_piece: Dictionary = minimal.duplicate(true)
	gate_as_piece["triggers"] = [{"id": "t1", "when": {"event": "piece_exited", "piece_id": "red_exit"}, "effect": {"type": "reveal_piece", "piece_id": "r1"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(gate_as_piece), "UNKNOWN_REFERENCE"), "a gate id cannot satisfy a piece reference")
	var missing_gate: Dictionary = minimal.duplicate(true)
	missing_gate["triggers"] = [{"id": "t1", "when": {"event": "piece_exited", "piece_id": "r1"}, "effect": {"type": "unlock_gate", "gate_id": "missing"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(missing_gate), "UNKNOWN_REFERENCE"), "effect gate ids must exist")
	var missing_blocker: Dictionary = minimal.duplicate(true)
	missing_blocker["triggers"] = [{"id": "t1", "when": {"event": "piece_exited", "piece_id": "r1"}, "effect": {"type": "remove_blocker", "blocker_id": "missing"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(missing_blocker), "UNKNOWN_REFERENCE"), "effect blocker ids must exist")
	var trigger_field: Dictionary = minimal.duplicate(true)
	trigger_field["triggers"] = [{"id": "t1", "trigger_id": "t1", "when": {"event": "piece_exited", "piece_id": "r1"}, "effect": {"type": "reveal_piece", "piece_id": "r1"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(trigger_field), "UNSUPPORTED_MECHANIC"), "trigger_id is not a reference field")
	var both_compound: Dictionary = minimal.duplicate(true)
	both_compound["triggers"] = [{"id": "t1", "when": {"all": [{"event": "piece_exited", "piece_id": "r1"}], "any": [{"event": "piece_exited", "piece_id": "r1"}]}, "effect": {"type": "reveal_piece", "piece_id": "r1"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(both_compound), "MALFORMED_TRIGGER"), "a condition cannot be both all and any")
	var empty_compound: Dictionary = minimal.duplicate(true)
	empty_compound["triggers"] = [{"id": "t1", "when": {"all": []}, "effect": {"type": "reveal_piece", "piece_id": "r1"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(empty_compound), "MALFORMED_TRIGGER"), "compound conditions cannot be empty")
	var bad_child: Dictionary = minimal.duplicate(true)
	bad_child["triggers"] = [{"id": "t1", "when": {"any": [1]}, "effect": {"type": "reveal_piece", "piece_id": "r1"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(bad_child), "MALFORMED_TRIGGER"), "compound condition entries must be objects")
	var both_names: Dictionary = minimal.duplicate(true)
	both_names["triggers"] = [{"id": "t1", "when": {"event": "piece_exited", "type": "piece_exited", "piece_id": "r1"}, "effect": {"type": "reveal_piece", "piece_id": "r1"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(both_names), "MALFORMED_TRIGGER"), "event and type cannot both name a condition")
	var bad_count: Dictionary = minimal.duplicate(true)
	bad_count["triggers"] = [{"id": "t1", "when": {"event": "color_exits_at_least", "color": "red", "count": 1.5}, "effect": {"type": "reveal_piece", "piece_id": "r1"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(bad_count), "MALFORMED_TRIGGER"), "fractional condition counts are rejected")
	var zero_count: Dictionary = minimal.duplicate(true)
	zero_count["triggers"] = [{"id": "t1", "when": {"event": "color_exits_at_least", "color": "red", "count": 0}, "effect": {"type": "reveal_piece", "piece_id": "r1"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(zero_count), "MALFORMED_TRIGGER"), "a zero condition count is rejected")
	var text_count: Dictionary = minimal.duplicate(true)
	text_count["triggers"] = [{"id": "t1", "when": {"event": "color_exits_at_least", "color": "red", "count": "2"}, "effect": {"type": "reveal_piece", "piece_id": "r1"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(text_count), "MALFORMED_TRIGGER"), "string condition counts are not coerced")
	var bad_counter: Dictionary = minimal.duplicate(true)
	bad_counter["gates"][0]["counter"] = {"remaining": -1}
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(bad_counter), "MALFORMED_TRIGGER"), "negative counters are rejected")
	var fraction_counter: Dictionary = minimal.duplicate(true)
	fraction_counter["gates"][0]["counter"] = {"remaining": 1.5}
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(fraction_counter), "MALFORMED_TRIGGER"), "fractional counters are rejected")
	var text_counter: Dictionary = minimal.duplicate(true)
	text_counter["gates"][0]["counter"] = {"remaining": "1"}
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(text_counter), "MALFORMED_TRIGGER"), "string counters are not coerced")
	var extra_counter: Dictionary = minimal.duplicate(true)
	extra_counter["gates"][0]["counter"] = {"remaining": 1, "opens": true}
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(extra_counter), "UNSUPPORTED_MECHANIC"), "unknown counter fields are rejected")
	var no_counter: Dictionary = minimal.duplicate(true)
	no_counter["triggers"] = [{"id": "t1", "when": {"event": "piece_exited", "piece_id": "r1"}, "effect": {"type": "decrement_counter", "gate_id": "red_exit"}}]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(no_counter), "MALFORMED_TRIGGER"), "decrement_counter requires a gate counter")
	var wall_width: Dictionary = minimal.duplicate(true)
	wall_width["board"]["walls"] = [[0, 0, 1]]
	_ok(LevelValidator.has_code(LevelValidator.validate_v2(wall_width), "INVALID_COORDINATE"), "wall arrays must have length 2")

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
	var rejected: Dictionary = PuzzleEngine.transition(first, PuzzleAction.move("r1", "right", Vector2i(2, 2)), definition)
	_ok(rejected["ok"] == false and rejected["error"]["code"] == "ILLEGAL_ACTION" and rejected["next_state"] == null, "forged landing is rejected")
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
