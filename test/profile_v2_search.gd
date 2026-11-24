extends SceneTree
## Times SolverV2 on a few adapted levels. Not a pass/fail suite.
## Invoked only as: godot --headless --path . --script res://test/profile_v2_search.gd

func _initialize() -> void:
	var paths := ["res://levels/level_006.json", "res://levels/level_032.json", "res://levels/level_035.json", "res://levels/level_043.json", "res://levels/level_036.json"]
	for path in paths:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var definition: Dictionary = V1Adapter.to_v2(raw)
		var state := PuzzleState.from_definition(definition)
		var started := Time.get_ticks_usec()
		var result: Dictionary = SolverV2.solve(definition, state, 2500)
		var elapsed := Time.get_ticks_usec() - started
		var explored := int(result["explored_states"])
		var rate := 0.0
		if elapsed > 0:
			rate = float(explored) * 1000000.0 / float(elapsed)
		print("PROFILE %s status=%s explored=%d usec=%d per_sec=%.1f" % [path, result["status"], explored, elapsed, rate])
	_parts("res://levels/level_032.json")
	quit(0)

func _parts(path: String) -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var definition: Dictionary = V1Adapter.to_v2(raw)
	var state := PuzzleState.from_definition(definition)
	var repeats := 200
	var started := Time.get_ticks_usec()
	for _i in repeats:
		PuzzleEngine.legal_actions(definition, state)
	var actions_usec := Time.get_ticks_usec() - started
	var sample: Array = PuzzleEngine.legal_actions(definition, state)
	started = Time.get_ticks_usec()
	for _i in repeats:
		if not sample.is_empty():
			PuzzleEngine.transition(state, sample[0], definition)
	var transition_usec := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for _i in repeats:
		state.search_key()
	var key_usec := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for _i in 40:
		LevelValidator.validate_v2(definition)
	var validate_usec := Time.get_ticks_usec() - started
	print("PARTS actions_usec=%d transition_usec=%d search_key_usec=%d validate40_usec=%d repeats=%d" % [actions_usec, transition_usec, key_usec, validate_usec, repeats])
