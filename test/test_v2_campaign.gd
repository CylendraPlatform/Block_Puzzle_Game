extends SceneTree
## One-pass v2 solve of the shipped 100 levels. UNKNOWN_CAP_REACHED is a budget
## limit, not proof a level is unsolvable. This script does not edit level files.
##   godot --headless --path . --script res://test/test_v2_campaign.gd

func _initialize() -> void:
	var solved := 0
	var capped := 0
	var failed := 0
	for path in Catalog.list_paths():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var definition: Dictionary = V1Adapter.to_v2(raw)
		var state := PuzzleState.from_definition(definition)
		var result: Dictionary = SolverV2.solve(definition, state, 2500)
		var status := str(result["status"])
		if status == PuzzleEngine.SOLVED:
			var cursor := state
			var replay := true
			for action in result["witness"]:
				var applied: Dictionary = PuzzleEngine.transition(cursor, action, definition)
				if not bool(applied["ok"]):
					replay = false
					break
				cursor = applied["next_state"]
			if replay and PuzzleEngine.is_won(definition, cursor):
				solved += 1
				print("SOLVED ", path, " len ", result["solution_length"], " explored ", result["explored_states"])
			else:
				failed += 1
				print("REPLAY_FAIL ", path)
		elif status == PuzzleEngine.UNKNOWN_CAP_REACHED:
			capped += 1
			print("CAP ", path, " explored ", result["explored_states"])
		else:
			failed += 1
			print("FAIL ", path, " ", status)
	print("CAMPAIGN solved=%d cap=%d failed=%d" % [solved, capped, failed])
	quit(failed)
