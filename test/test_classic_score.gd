extends SceneTree
## M1.3-C ClassicScore (plan §6.1, D2) and Classic stars on the v2 GameScreen.
## Commit +1, rejected action 0, Undo never refunds, Restart resets, stars from score and par,
## and earned stars never decrease (replay worse, Undo, Restart, quit mid-level, app restart).
## Progress lives in an isolated user:// folder; the real saves are checked untouched.
##   godot --headless --path . --script res://test/test_classic_score.gd

const DT := 0.05
const MAX_FRAMES := 400
const DIR := "user://m13c_classic_score/"

var _fails := 0
var _progress: Node
var _settings: Node

func _ok(condition: bool, message: String) -> void:
	if condition:
		print("  PASS  ", message)
	else:
		print("  FAIL  ", message)
		_fails += 1

func _initialize() -> void:
	print("== test_classic_score ==")
	var real := _real_digest()
	_progress = root.get_node("Progress")
	_settings = root.get_node("Settings")
	_unit()
	_clean()
	await _screen_scoring()
	_clean()
	DirAccess.remove_absolute(DIR.trim_suffix("/"))
	_ok(_real_digest() == real, "real user:// progress files untouched")
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

# --- helpers -------------------------------------------------------------------------------

func _real_digest() -> String:
	var parts := PackedStringArray()
	for name: String in ["progress.save", "progress_v2.save", "progress_v2.save.bak", "progress_v2.save.tmp"]:
		var path: String = "user://" + name
		parts.append(FileAccess.get_md5(path) if FileAccess.file_exists(path) else "-")
	return ",".join(parts)

func _clean() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + f)
	DirAccess.make_dir_recursive_absolute(DIR)

func _open_screen(selected: int) -> Control:
	_settings.custom_level = null
	_settings.selected_level = selected
	var screen: Control = load("res://scenes/GameScreen.tscn").instantiate()
	root.add_child(screen)
	while not screen.is_node_ready():
		await process_frame
	return screen

func _close(screen: Control) -> void:
	root.remove_child(screen)
	screen.free()

func _pump(screen: Control) -> void:
	var frames := 0
	while screen._session.input_locked and frames < MAX_FRAMES:
		screen._process(DT)
		screen._board._process(DT)
		frames += 1
	screen._process(DT)

func _witness(screen: Control) -> Array:
	var defn: Dictionary = screen._definition
	return SolverV2.solve(defn, PuzzleState.from_definition(defn), 200000).get("witness", [])

func _play(screen: Control, actions: Array) -> void:
	for action in actions:
		screen._on_commit(action)
		_pump(screen)

## One accepted non-exit move.
func _one_move(screen: Control) -> void:
	for action in PuzzleEngine.legal_actions(screen._definition, screen._session.state, ""):
		if action.kind == PuzzleAction.MOVE:
			screen._on_commit(action)
			_pump(screen)
			return
	_ok(false, "level has a non-exit move")

## One accepted non-exit move, then Undo: score +1, board back where it was.
func _waste_one_move(screen: Control) -> void:
	_one_move(screen)
	screen._on_undo()

# --- tests ---------------------------------------------------------------------------------

func _unit() -> void:
	var s := ClassicScore.new()
	_ok(s.moves == 0, "new score is 0")
	s.on_commit()
	s.on_commit()
	s.on_commit()
	_ok(s.moves == 3, "three accepted actions -> 3")
	s.on_undo()
	_ok(s.moves == 3, "Undo never refunds")
	_ok(s.stars(3) == Catalog.star_rating(3, 3) and s.stars(3) == 3, "stars use Catalog.star_rating (3 at par)")
	_ok(s.stars(1) == Catalog.star_rating(3, 1), "stars over par follow the legacy formula")
	s.on_restart()
	_ok(s.moves == 0, "Restart resets to 0")

func _screen_scoring() -> void:
	var store: ProgressStore = _progress.open_store(DIR)
	var screen: Control = await _open_screen(-1)
	_ok(screen._index == 0 and str(screen._entry["id"]) == "legacy-1", "fresh progress resumes at legacy-1")
	var par := int(screen._entry["par"])
	var witness := _witness(screen)
	_ok(witness.size() == par, "v2 witness for legacy-1 has par length %d" % par)
	screen._on_commit(PuzzleAction.move("no-such-piece", "left", Vector2i.ZERO))
	_ok(screen._score.moves == 0 and screen._session.move_count() == 0, "rejected action does not count")
	_waste_one_move(screen)
	_ok(screen._score.moves == 1 and screen._session.move_count() == 0, "Undo keeps score 1, engine move_number back to 0")
	screen._on_restart()
	_ok(screen._score.moves == 0, "Restart resets the score")
	# Quit mid-level (one accepted, non-winning move): nothing recorded.
	_one_move(screen)
	_ok(screen._score.moves == 1 and not screen._session.is_won(), "mid-level: one move made, not won")
	_close(screen)
	store = _progress.open_store(DIR)
	_ok(store.stars("classic", "legacy-1") == 0 and store.unlocked("classic") == 0, "quitting mid-level records nothing")
	# Perfect win: 3 stars, unlocked 1, legacy file in step.
	screen = await _open_screen(0)
	_play(screen, witness)
	_ok(screen._session.is_won() and screen._score.moves == par, "won in par moves")
	_ok(screen._earned == 3 and screen._win_layer.visible, "3 stars shown on the win card")
	_ok(_progress.store.stars("classic", "legacy-1") == 3 and _progress.store.unlocked("classic") == 1, "stars 3 and unlocked 1 recorded by stable id")
	var v1: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "progress.save"))
	_ok(int(v1["unlocked"]) == 1 and int(v1["stars"]["0"]) == 3, "progress.save dual-written in the legacy format")
	_close(screen)
	# Replay worse -> lower earned, stored stays 3.
	screen = await _open_screen(0)
	for i in 4:
		_waste_one_move(screen)
	_play(screen, witness)
	_ok(screen._score.moves == par + 4, "score counts the wasted, undone moves (%d)" % screen._score.moves)
	_ok(screen._earned == Catalog.star_rating(par + 4, par) and screen._earned < 3, "worse replay earns %d stars" % screen._earned)
	_ok(_progress.store.stars("classic", "legacy-1") == 3, "stored stars never decrease")
	screen._on_undo()
	screen._on_restart()
	_ok(_progress.store.stars("classic", "legacy-1") == 3, "Undo / Restart after a win keep 3 stars")
	_close(screen)
	# App restart: reopen the store from disk.
	store = _progress.open_store(DIR)
	_ok(store.stars("classic", "legacy-1") == 3 and store.unlocked("classic") == 1, "stars and unlock survive an app restart")
	_progress.store = null
