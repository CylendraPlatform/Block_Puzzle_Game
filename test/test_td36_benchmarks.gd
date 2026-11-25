extends SceneTree
## Schema, shortest witness, replay, and card agreement for eight TD-3.6 levels.
##   godot --headless --path . --script res://test/test_td36_benchmarks.gd

const DIR := "res://levels_v2/td36"
const CARDS := "res://docs/v2/td36_level_cards.json"
const CAP := 80000
const SAVE := "user://progress.save"
const PILOT_SAVE := "user://pilot_v2.save"

var _fails := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _initialize() -> void:
	print("== test_td36_benchmarks ==")
	var before_progress := FileAccess.file_exists(SAVE)
	var before_pilot := FileAccess.file_exists(PILOT_SAVE)
	var names := _json_names(DIR)
	_ok(names.size() == 8, "exactly eight TD-3.6 files")
	_ok(PilotCatalog.list_paths().size() == 15, "pilot catalog still has 15 files")
	_ok(Catalog.list_paths().size() == 100, "legacy catalog still has 100 files")
	var cards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CARDS))
	_ok(typeof(cards) == TYPE_DICTIONARY and cards.size() == 8, "eight level cards")
	var bent := 0
	var easy := 0
	var medium := 0
	var hard := 0
	var expert := 0
	print(PuzzleMetrics.csv_header())
	for i in names.size():
		var expected_id := "td36-%03d" % (i + 1)
		var path: String = DIR + "/" + names[i]
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_ok(typeof(raw) == TYPE_DICTIONARY and str(raw.get("id", "")) == expected_id, "id %s" % expected_id)
		var loaded := LevelLoader.load_definition(raw)
		if not bool(loaded["ok"]):
			_fails += 1
			print("  FAIL  schema ", path, " ", loaded["diagnostics"])
			continue
		var definition: Dictionary = loaded["definition"]
		for piece in definition["pieces"]:
			if piece["cells"].size() >= 3 and not _straight(piece["cells"]):
				bent += 1
		var metrics := PuzzleMetrics.evaluate(definition, CAP)
		print(PuzzleMetrics.csv_row(metrics))
		_ok(str(metrics["status"]) == PuzzleEngine.SOLVED, "%s SOLVED" % expected_id)
		_ok(bool(metrics["shortest_proven"]), "%s shortest proven" % expected_id)
		_ok(bool(metrics["witness_replayed"]), "%s witness replayed" % expected_id)
		_ok(metrics["unreachable_cells"].is_empty(), "%s no unreachable cells" % expected_id)
		_ok(metrics["unreachable_gates"].is_empty(), "%s gates reachable" % expected_id)
		_ok(bool(metrics["dependency_proven"]), "%s dependency proven" % expected_id)
		if not cards.has(expected_id):
			_fails += 1
			print("  FAIL  missing card ", expected_id)
			continue
		var card: Dictionary = cards[expected_id]
		_ok(str(card.get("solver_status", "")) == PuzzleEngine.SOLVED, "%s card status" % expected_id)
		_ok(int(card.get("shortest_actions", -1)) == int(metrics["solution_length"]), "%s card length" % expected_id)
		_ok(int(card.get("states_explored", -1)) == int(metrics["explored_states"]), "%s card explored" % expected_id)
		_ok(int(card.get("search_cap", -1)) == CAP, "%s card cap" % expected_id)
		_ok(bool(card.get("witness_replayed", false)), "%s card replay" % expected_id)
		var tier := str(card.get("tier_target", ""))
		if tier == "Easy":
			easy += 1
		elif tier == "Medium":
			medium += 1
		elif tier == "Hard":
			hard += 1
		elif tier == "Expert":
			expert += 1
		print("  SOLVED  %s  len %d  explored %d  paths %d  dep %s" % [
			expected_id,
			int(metrics["solution_length"]),
			int(metrics["explored_states"]),
			int(metrics["shortest_path_count"]),
			str(metrics["dependency_proven"]),
		])
	_ok(bent > 0, "set includes a bent connected shape")
	_ok(easy >= 2 and medium >= 2 and hard >= 2 and expert >= 2, "two cards per target tier")
	_ok(FileAccess.file_exists(SAVE) == before_progress, "did not create user://progress.save")
	_ok(FileAccess.file_exists(PILOT_SAVE) == before_pilot, "did not write user://pilot_v2.save")
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

func _json_names(dir: String) -> Array[String]:
	var names: Array[String] = []
	var folder := DirAccess.open(dir)
	if folder == null:
		return names
	folder.list_dir_begin()
	var name := folder.get_next()
	while name != "":
		if name.ends_with(".json"):
			names.append(name)
		name = folder.get_next()
	folder.list_dir_end()
	names.sort()
	return names

func _straight(cells: Array) -> bool:
	var same_x := true
	var same_y := true
	var x0 := int(cells[0][0])
	var y0 := int(cells[0][1])
	for cell in cells:
		if int(cell[0]) != x0:
			same_x = false
		if int(cell[1]) != y0:
			same_y = false
	return same_x or same_y
