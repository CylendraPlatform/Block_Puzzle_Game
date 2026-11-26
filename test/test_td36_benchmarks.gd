extends SceneTree
## Schema, shortest witness, replay, and card agreement for TD-3.6 files.
## Fixtures 001-008 stay technical benchmarks. Candidates 009-016 are review-only.
##   godot --headless --path . --script res://test/test_td36_benchmarks.gd

const DIR := "res://levels_v2/td36"
const CARDS := "res://docs/v2/td36_level_cards.json"
const CAP := 80000
const SAVE := "user://progress.save"
const PILOT_SAVE := "user://pilot_v2.save"
const QA_SAVE := "user://td36_qa.save"
const FIXTURE_LENGTHS := [5, 6, 15, 18, 29, 22, 27, 31]

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
	var before_qa := FileAccess.file_exists(QA_SAVE)
	var names := _json_names(DIR)
	_ok(names.size() == 16, "sixteen TD-3.6 files")
	_ok(PilotCatalog.list_paths().size() == 15, "pilot catalog still has 15 files")
	_ok(Catalog.list_paths().size() == 100, "legacy catalog still has 100 files")
	_ok(Td36Catalog.list_paths().size() == 16, "TD-3.6 catalog lists 16 files")
	var cards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CARDS))
	_ok(typeof(cards) == TYPE_DICTIONARY and cards.size() == 16, "sixteen level cards")
	var fingerprints: Array = []
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
		var metrics := PuzzleMetrics.evaluate(definition, CAP)
		print(PuzzleMetrics.csv_row(metrics))
		fingerprints.append(metrics["structural_fingerprint"])
		_ok(str(metrics["status"]) == PuzzleEngine.SOLVED, "%s SOLVED" % expected_id)
		_ok(bool(metrics["shortest_proven"]), "%s shortest proven" % expected_id)
		_ok(bool(metrics["witness_replayed"]), "%s witness replayed" % expected_id)
		_ok(metrics["unreachable_cells"].is_empty(), "%s no unreachable cells" % expected_id)
		_ok(metrics["unreachable_gates"].is_empty(), "%s gates reachable" % expected_id)
		_ok(bool(metrics["dependency_proven"]), "%s dependency proven" % expected_id)
		_ok(str(metrics["human_difficulty"]) == "unmeasured", "%s human difficulty unmeasured" % expected_id)
		if i < 8:
			_ok(int(metrics["solution_length"]) == FIXTURE_LENGTHS[i], "%s fixture length unchanged" % expected_id)
		else:
			_ok(str(metrics["mechanism_family"]) != "siding_1d", "%s candidate is not 1D siding" % expected_id)
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
		_ok(str(card.get("human_difficulty", "")) == "unmeasured", "%s card human difficulty" % expected_id)
		print("  SOLVED  %s  len %d  explored %d  paths %d  family %s  pattern %s" % [
			expected_id,
			int(metrics["solution_length"]),
			int(metrics["explored_states"]),
			int(metrics["shortest_path_count"]),
			str(metrics["mechanism_family"]),
			str(metrics["structural_fingerprint"].get("pattern", "")),
		])
	for a in range(8, fingerprints.size()):
		for b in range(a + 1, fingerprints.size()):
			var sim := PuzzleMetrics.similarity(fingerprints[a], fingerprints[b])
			_ok(not PuzzleMetrics.near_duplicate(fingerprints[a], fingerprints[b]), "candidates td36-%03d and td36-%03d not near-duplicates (sim=%.3f)" % [a + 1, b + 1, sim])
	Td36Catalog.save_index(0)
	_ok(FileAccess.file_exists(SAVE) == before_progress, "did not create user://progress.save")
	_ok(FileAccess.file_exists(PILOT_SAVE) == before_pilot, "did not write user://pilot_v2.save")
	if not before_qa and FileAccess.file_exists(QA_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_SAVE))
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
