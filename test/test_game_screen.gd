extends SceneTree
## M1.3-C unified GameScreen: engine flag (default legacy) and routing, Play resume point, Level
## Select gating and stars by stable id, Next / Undo / Restart / Pause routes, Editor Test
## isolation, save migration from progress.save and rollback to the legacy Catalog, and no
## duplicate commits while the board animates, save-failure handling with injected write faults
## (failed / partial / read-only, idempotent retry, one completion event), Undo / Restart / Next /
## exit during the winning animation, and the gameplay/exit_past(_edge) settings (D4).
## Progress lives in an isolated user:// folder;
## navigation is captured through GameRoute.navigate_hook (no scene change).
##   godot --headless --path . --script res://test/test_game_screen.gd

const DT := 0.05
const MAX_FRAMES := 400
const DIR := "user://m13c_game_screen/"

var _fails := 0
var _progress: Node
var _settings: Node
var _routes: Array = []
var _analytics: Node
var _events: Array = []

func _ok(condition: bool, message: String) -> void:
	if condition:
		print("  PASS  ", message)
	else:
		print("  FAIL  ", message)
		_fails += 1

func _initialize() -> void:
	print("== test_game_screen ==")
	var real := _real_digest()
	_progress = root.get_node("Progress")
	_settings = root.get_node("Settings")
	GameRoute.navigate_hook = func(path: String) -> void: _routes.append(path)
	_engine_flag()
	_clean()
	await _migration_resume_and_gating()
	await _next_pause_and_routes()
	await _no_duplicate_commits()
	_rollback_to_legacy()
	_exit_settings()
	_analytics = root.get_node("Analytics")
	var sink: Callable = _analytics.remote_sink
	var opt_out: bool = _settings.analytics_opt_out
	_settings.analytics_opt_out = false
	_analytics.remote_sink = func(ev: Dictionary) -> void: _events.append(ev)
	await _save_failures()
	await _undo_during_win()
	_analytics.remote_sink = sink
	_settings.analytics_opt_out = opt_out
	_clean()
	await _editor_test_isolation()
	await _menu_and_editor_routes()
	ProjectSettings.set_setting(GameRoute.ENGINE_SETTING, GameRoute.LEGACY)
	GameRoute.navigate_hook = Callable()
	_progress.store = null
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

func _dir_digest() -> String:
	var parts := PackedStringArray()
	if DirAccess.dir_exists_absolute(DIR):
		var files := DirAccess.get_files_at(DIR)
		files.sort()
		for f in files:
			parts.append("%s=%s" % [f, FileAccess.get_md5(DIR + f)])
	return ",".join(parts)

func _clean() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for f in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR + f)
	DirAccess.make_dir_recursive_absolute(DIR)

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _instance(scene: String) -> Control:
	var node: Control = load(scene).instantiate()
	root.add_child(node)
	while not node.is_node_ready():
		await process_frame
	return node

func _open_screen(selected: int, custom = null) -> Control:
	_settings.custom_level = custom
	_settings.selected_level = selected
	return await _instance(GameRoute.V2_SCENE)

func _close(node: Control) -> void:
	root.remove_child(node)
	node.free()

func _pump(screen: Control) -> void:
	var frames := 0
	while screen._session.input_locked and frames < MAX_FRAMES:
		screen._process(DT)
		screen._board._process(DT)
		frames += 1
	screen._process(DT)

func _win(screen: Control) -> void:
	var defn: Dictionary = screen._definition
	for action in SolverV2.solve(defn, PuzzleState.from_definition(defn), 200000).get("witness", []):
		screen._on_commit(action)
		_pump(screen)

## Commits the solver witness, leaving the winning move's animation still playing.
func _win_mid_animation(screen: Control) -> void:
	var defn: Dictionary = screen._definition
	var witness: Array = SolverV2.solve(defn, PuzzleState.from_definition(defn), 200000).get("witness", [])
	for i in witness.size() - 1:
		screen._on_commit(witness[i])
		_pump(screen)
	screen._on_commit(witness.back())

## One accepted non-exit move, then Undo: score +1, board back where it was.
func _waste_one_move(screen: Control) -> void:
	for action in PuzzleEngine.legal_actions(screen._definition, screen._session.state, ""):
		if action.kind == PuzzleAction.MOVE:
			screen._on_commit(action)
			_pump(screen)
			screen._on_undo()
			return
	_ok(false, "level has a non-exit move")

func _completions() -> int:
	var n := 0
	for ev in _events:
		if str(ev["event"]) == "level_complete":
			n += 1
	return n

## What a fresh launch would load from disk.
func _disk() -> ProgressStore:
	return ProgressStore.open(DIR, 100)

func _v1_stars(index: int) -> int:
	var path := DIR + "progress.save"
	if not FileAccess.file_exists(path):
		return 0
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return int(data["stars"].get(str(index), 0)) if data is Dictionary else 0

## Fresh progress, the given write faults, legacy-1 won through GameScreen.
func _save_case(faults: String) -> Control:
	_clean()
	var store: ProgressStore = _progress.open_store(DIR)
	store._crash_at = faults
	var screen: Control = await _open_screen(0)
	_win(screen)
	return screen

func _last_route() -> String:
	return str(_routes.back()) if not _routes.is_empty() else ""

## The real legacy Catalog source, compiled with only SAVE_PATH redirected to the test folder.
func _legacy_catalog() -> GDScript:
	var src := FileAccess.get_file_as_string("res://scripts/core/catalog.gd")
	src = src.replace("class_name Catalog\n", "").replace("const SAVE_PATH := \"user://progress.save\"", "const SAVE_PATH := \"%sprogress.save\"" % DIR)
	var script := GDScript.new()
	script.source_code = src
	script.reload()
	return script

# --- tests ---------------------------------------------------------------------------------

func _engine_flag() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://project.godot")
	_ok(str(cfg.get_value("gameplay", "engine", "")) == "legacy", "project.godot ships gameplay/engine = legacy")
	_ok(str(cfg.get_value("autoload", "Progress", "")).ends_with("progress_service.gd") and cfg.get_section_keys("autoload")[0] == "Progress", "Progress autoload is first, so the store opens before any route")
	ProjectSettings.set_setting(GameRoute.ENGINE_SETTING, GameRoute.LEGACY)
	_ok(GameRoute.game_scene() == "res://scenes/Game.tscn", "legacy -> original Game.tscn")
	ProjectSettings.set_setting(GameRoute.ENGINE_SETTING, "something-else")
	_ok(GameRoute.game_scene() == "res://scenes/Game.tscn", "unknown value falls back to legacy")
	ProjectSettings.set_setting(GameRoute.ENGINE_SETTING, GameRoute.V2)
	_ok(GameRoute.game_scene() == GameRoute.V2_SCENE, "v2 -> GameScreen.tscn")
	for path: String in ["res://scenes/Game.tscn", "res://scripts/game/game.gd", "res://scripts/core/rules.gd", "res://scripts/game/board_view.gd", "res://scripts/core/catalog.gd"]:
		_ok(FileAccess.file_exists(path), "legacy route kept: " + path)

func _migration_resume_and_gating() -> void:
	# Existing legacy progress: 5 levels done, stars on index 0 and 3.
	_write(DIR + "progress.save", JSON.stringify({"unlocked": 5, "stars": {"0": 3, "3": 2}}))
	var store: ProgressStore = _progress.open_store(DIR)
	_ok(store.unlocked("classic") == 5 and store.stars("classic", "legacy-1") == 3 and store.stars("classic", "legacy-4") == 2, "progress.save migrated to stable ids")
	_ok(FileAccess.file_exists(DIR + "progress.save"), "progress.save kept after migration")
	var screen: Control = await _open_screen(-1)
	_ok(screen._index == 5 and str(screen._entry["id"]) == "legacy-6", "Play resumes at the unlocked level (legacy-6)")
	_close(screen)
	screen = await _open_screen(2)
	_ok(screen._index == 2, "Level Select pick of an unlocked level opens it")
	_close(screen)
	screen = await _open_screen(50)
	_ok(screen._index == 5, "a locked level request is gated to the resume point")
	_close(screen)
	var levels: Control = await _instance(GameRoute.LEVELS_SCENE)
	var buttons: Array = levels._grid.get_children()
	_ok(buttons.size() == 100, "Level Select lists the 100 Classic levels only (no Chapter 1)")
	_ok(not buttons[5].disabled and buttons[6].disabled, "Level Select gating: 1-6 open, 7+ locked")
	_ok(str(buttons[0].text).contains("***") and str(buttons[3].text).contains("**-"), "Level Select stars read by stable id")
	_routes.clear()
	buttons[3].pressed.emit()
	_ok(_last_route() == GameRoute.V2_SCENE and int(_settings.selected_level) == 3, "tapping level 4 routes to GameScreen")
	_close(levels)

func _next_pause_and_routes() -> void:
	var screen: Control = await _open_screen(5)
	_win(screen)
	_ok(screen._win_layer.visible and _progress.store.unlocked("classic") == 6, "win on legacy-6 unlocks legacy-7")
	screen._on_next()
	_ok(screen._index == 6 and not screen._win_layer.visible and screen._score.moves == 0, "Next opens legacy-7 with a fresh score")
	var legal: Array = PuzzleEngine.legal_actions(screen._definition, screen._session.state, "")
	screen._on_pause()
	_ok(screen._pause_layer.visible, "Pause opens the pause card")
	screen._on_commit(legal[0])
	_ok(screen._score.moves == 0 and screen._session.move_count() == 0, "no moves while paused")
	screen._on_resume()
	_ok(not screen._pause_layer.visible, "Resume closes it")
	screen._on_commit(legal[0])
	_pump(screen)
	_ok(screen._score.moves == 1, "play continues after Resume")
	screen._on_undo()
	_ok(screen._session.move_count() == 0 and screen._score.moves == 1, "Undo restores the board, keeps the score")
	screen._on_restart()
	_ok(screen._score.moves == 0 and screen._session.history.is_empty(), "Restart resets board and score")
	_routes.clear()
	screen._on_levels()
	_ok(_last_route() == GameRoute.LEVELS_SCENE, "Pause > Levels routes to Level Select")
	screen._on_menu()
	_ok(_last_route() == GameRoute.MENU_SCENE, "Pause > Main Menu routes to the menu")
	_close(screen)

func _no_duplicate_commits() -> void:
	var screen: Control = await _open_screen(6)
	var legal: Array = PuzzleEngine.legal_actions(screen._definition, screen._session.state, "")
	screen._on_commit(legal[0])
	_ok(screen._session.input_locked and screen._board.transition_active(), "input locked while the move animates")
	for i in 3:
		screen._on_commit(legal[legal.size() - 1])
	_ok(screen._score.moves == 1 and screen._session.history.size() == 1, "repeated input during the animation is ignored")
	_pump(screen)
	_ok(not screen._session.input_locked, "input unlocks when the queue drains")
	_close(screen)

func _rollback_to_legacy() -> void:
	# The v2 wins above were dual-written: the real legacy Catalog code reads them.
	var legacy := _legacy_catalog()
	var p: Dictionary = legacy.load_progress()
	_ok(int(p["unlocked"]) == 6 and int(p["stars"].get("5", 0)) >= 1 and int(p["stars"].get("0", 0)) == 3, "legacy Catalog sees v2 progress (rollback to gameplay/engine = legacy)")
	# Progress made on the legacy route is merged back on the next open.
	_write(DIR + "progress.save", JSON.stringify({"unlocked": 9, "stars": {"0": 3, "3": 2, "5": 3, "8": 1}}))
	var store: ProgressStore = _progress.open_store(DIR)
	_ok(store.unlocked("classic") == 9 and store.stars("classic", "legacy-9") == 1 and store.stars("classic", "legacy-6") == 3, "legacy-route progress merged back into v2")
	# An older progress.save never lowers v2 progress.
	_write(DIR + "progress.save", JSON.stringify({"unlocked": 2, "stars": {}}))
	store = _progress.open_store(DIR)
	_ok(store.unlocked("classic") == 9 and store.stars("classic", "legacy-1") == 3, "older progress.save never lowers progress")
	_ok(int(legacy.load_progress()["unlocked"]) == 9, "open() resyncs progress.save for the legacy route")

func _exit_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://project.godot")
	_ok(is_equal_approx(float(cfg.get_value("gameplay", "exit_past", -1.0)), 0.34) and is_equal_approx(float(cfg.get_value("gameplay", "exit_past_edge", -1.0)), 0.12), "project.godot ships gameplay/exit_past 0.34 and exit_past_edge 0.12")
	_ok(is_equal_approx(BoardViewV2.exit_past(false), 0.34) and is_equal_approx(BoardViewV2.exit_past(true), 0.12), "BoardViewV2 reads the default thresholds")
	_ok(BoardViewV2.steps_for_drag(3.33, 3, true, false) == 3 and BoardViewV2.steps_for_drag(3.34, 3, true, false) == 4, "default: exit after a 0.34-cell push")
	_ok(BoardViewV2.steps_for_drag(3.11, 3, true, true) == 3 and BoardViewV2.steps_for_drag(3.12, 3, true, true) == 4, "default edge zone: exit after a 0.12-cell push")
	ProjectSettings.set_setting(BoardViewV2.EXIT_PAST_SETTING, 0.5)
	ProjectSettings.set_setting(BoardViewV2.EXIT_PAST_EDGE_SETTING, 0.25)
	_ok(BoardViewV2.steps_for_drag(3.4, 3, true, false) == 3 and BoardViewV2.steps_for_drag(3.5, 3, true, false) == 4, "override gameplay/exit_past = 0.5 is used")
	_ok(BoardViewV2.steps_for_drag(3.2, 3, true, true) == 3 and BoardViewV2.steps_for_drag(3.25, 3, true, true) == 4, "override gameplay/exit_past_edge = 0.25 is used")
	ProjectSettings.set_setting(BoardViewV2.EXIT_PAST_SETTING, 0.0)
	ProjectSettings.set_setting(BoardViewV2.EXIT_PAST_EDGE_SETTING, "x")
	_ok(is_equal_approx(BoardViewV2.exit_past(false), 0.34) and is_equal_approx(BoardViewV2.exit_past(true), 0.12), "invalid values fall back to the defaults")
	ProjectSettings.set_setting(BoardViewV2.EXIT_PAST_SETTING, 0.34)
	ProjectSettings.set_setting(BoardViewV2.EXIT_PAST_EDGE_SETTING, 0.12)

func _save_failures() -> void:
	var before := _completions()
	# Both copies fail: not durable, never shown as saved.
	var screen: Control = await _save_case("progress_v2.save:open,progress.save:open")
	_ok(screen._session.is_won() and screen._win_layer.visible and screen._earned == 3, "both writes failed: the win card still shows the 3 stars earned")
	_ok(screen._save_status == "failed" and screen._save_note.visible and screen._save_note.text.contains("could not be saved") and screen._retry.visible, "both writes failed: shown as not saved, Retry Save offered")
	var disk := _disk()
	_ok(disk.stars("classic", "legacy-1") == 0 and disk.unlocked("classic") == 0, "both writes failed: a fresh launch has no completion (correctly not durable)")
	screen._on_retry_save()
	_ok(screen._save_status == "failed" and screen._retry.visible, "retry while the fault persists stays failed")
	_progress.store._crash_at = ""
	screen._on_retry_save()
	_ok(screen._save_status == "saved" and not screen._save_note.visible and not screen._retry.visible, "retry after the fault clears: saved, note and Retry hidden")
	disk = _disk()
	_ok(disk.stars("classic", "legacy-1") == 3 and disk.unlocked("classic") == 1 and _v1_stars(0) == 3, "after retry both copies hold 3 stars and unlocked 1")
	screen._on_retry_save()
	_ok(_progress.store.stars("classic", "legacy-1") == 3 and _progress.store.campaigns["classic"]["stars"].size() == 1, "extra retries add nothing")
	_ok(_completions() - before == 1, "one level_complete event across failure and retries")
	_close(screen)
	# Legacy copy fails: v2 is durable (partial); leaving retries the legacy copy.
	before = _completions()
	screen = await _save_case("progress.save:open")
	_ok(screen._save_status == "partial" and screen._save_note.text.begins_with("Progress saved") and screen._retry.visible, "legacy copy failed: partial, saved note, Retry offered")
	_ok(_v1_stars(0) == 0, "legacy copy failed: progress.save not yet updated")
	_progress.store._crash_at = ""
	_routes.clear()
	screen._on_menu()
	_ok(_last_route() == GameRoute.MENU_SCENE and screen._save_status == "saved" and _v1_stars(0) == 3, "Menu retries the pending legacy copy, then routes")
	_ok(_completions() - before == 1, "partial save: one level_complete event")
	_close(screen)
	# v2 copy fails: progress.save holds it, and the next launch merges it back.
	screen = await _save_case("progress_v2.save:open")
	_ok(screen._save_status == "partial" and _v1_stars(0) == 3, "v2 copy failed: partial, progress.save written")
	_progress.store._crash_at = ""
	screen._on_next()
	_ok(screen._index == 1 and screen._save_status == "" and not screen._retry.visible, "Next retries the pending copy and opens legacy-2 clean")
	disk = _disk()
	_ok(disk.stars("classic", "legacy-1") == 3 and disk.unlocked("classic") == 1, "fresh launch has the completion")
	_close(screen)
	# Leaving while the fault persists: routes on, still reported failed, kept in memory and
	# written by the next successful save.
	screen = await _save_case("progress_v2.save:open,progress.save:open")
	_routes.clear()
	screen._on_levels()
	_ok(_last_route() == GameRoute.LEVELS_SCENE and screen._save_status == "failed", "leaving with the fault still on routes on and stays reported failed")
	_ok(_progress.store.stars("classic", "legacy-1") == 3 and _disk().stars("classic", "legacy-1") == 0, "completion kept in memory only")
	_progress.store._crash_at = ""
	var result: Dictionary = _progress.store.save()
	_ok(int(result["v2"]) == OK and _disk().stars("classic", "legacy-1") == 3, "the next save writes the kept completion")
	_close(screen)
	# Newer save on the device: read-only, never claimed as saved, no Retry.
	_clean()
	_progress.open_store(DIR).read_only = true
	screen = await _open_screen(0)
	_win(screen)
	_ok(screen._save_status == "read_only" and screen._save_note.visible and not screen._retry.visible, "read-only store: not-saved note, no Retry")
	_ok(_progress.store.stars("classic", "legacy-1") == 0, "read-only store: nothing recorded")
	_progress.store.read_only = false
	_close(screen)

func _undo_during_win() -> void:
	_clean()
	_progress.open_store(DIR)
	var before := _completions()
	var screen: Control = await _open_screen(0)
	var par := int(screen._entry["par"])
	_win_mid_animation(screen)
	_ok(screen._session.is_won() and screen._board.transition_active() and _progress.store.stars("classic", "legacy-1") == 3, "completion recorded at the winning move while it still animates")
	var moves: int = screen._score.moves
	screen._on_undo()
	_ok(screen._session.is_won() and screen._score.moves == moves and screen._undos == 0, "Undo during the winning animation is ignored")
	_pump(screen)
	_ok(screen._win_layer.visible and screen._win_stars.text == "3 / 3 Stars", "win card shows the recorded 3 stars")
	screen._on_undo()
	_ok(screen._session.is_won() and screen._win_layer.visible, "Undo on the win card is ignored")
	_ok(_completions() - before == 1, "one level_complete event for the attempt")
	# Restart: a new attempt; a worse second win shows its own stars, stored stars stay 3.
	screen._on_restart()
	_ok(not screen._session.is_won() and screen._score.moves == 0 and not screen._recorded and screen._save_status == "", "Restart starts a new attempt")
	_waste_one_move(screen)
	_waste_one_move(screen)
	_win(screen)
	var worse := Catalog.star_rating(par + 2, par)
	_ok(screen._earned == worse and screen._win_stars.text == "%d / 3 Stars" % worse, "second win shows its own %d stars" % worse)
	_ok(_progress.store.stars("classic", "legacy-1") == 3 and _completions() - before == 2, "stored stars stay 3; the second attempt logs exactly one more completion")
	# Restart from Pause while the winning move animates.
	screen._on_restart()
	_win_mid_animation(screen)
	screen._on_pause()
	screen._on_restart()
	_ok(not screen._session.is_won() and not screen._win_layer.visible and _completions() - before == 3, "Pause > Restart during the winning animation keeps one event for that win")
	# Next while the winning move animates.
	_win_mid_animation(screen)
	screen._on_next()
	_ok(screen._index == 1 and not screen._session.is_won() and _progress.store.unlocked("classic") == 1 and _completions() - before == 4, "Next during the winning animation opens legacy-2, one event")
	_close(screen)
	# Exit while the winning move animates.
	screen = await _open_screen(0)
	_win_mid_animation(screen)
	_routes.clear()
	screen._on_menu()
	_ok(_last_route() == GameRoute.MENU_SCENE and _completions() - before == 5, "Menu during the winning animation routes, one event")
	_close(screen)
	var disk := _disk()
	_ok(disk.stars("classic", "legacy-1") == 3 and disk.unlocked("classic") == 1 and _v1_stars(0) == 3, "disk agrees: legacy-1 3 stars, unlocked 1, both copies")

func _editor_test_isolation() -> void:
	_progress.open_store(DIR)
	var before := _dir_digest()
	var custom: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_006.json"))
	custom["id"] = 0
	custom["name"] = "Custom"
	var screen: Control = await _open_screen(-1, custom)
	_ok(screen._custom and screen._title.text == "Custom Level" and screen._next.text == "Back to Editor", "custom v1 level opens through V1Adapter")
	_win(screen)
	_ok(screen._session.is_won() and screen._win_layer.visible, "custom level can be won")
	_ok(_dir_digest() == before and _progress.store.unlocked("classic") == 0, "editor test writes no campaign progress")
	_routes.clear()
	screen._on_next()
	_ok(_last_route() == GameRoute.EDITOR_SCENE and _settings.custom_level == null, "Back to Editor returns to the editor and clears the test level")
	_close(screen)

func _menu_and_editor_routes() -> void:
	for engine: String in [GameRoute.LEGACY, GameRoute.V2]:
		ProjectSettings.set_setting(GameRoute.ENGINE_SETTING, engine)
		var expected: String = "res://scenes/Game.tscn" if engine == GameRoute.LEGACY else GameRoute.V2_SCENE
		var menu: Control = await _instance(GameRoute.MENU_SCENE)
		_routes.clear()
		menu._on_play()
		_ok(_last_route() == expected and int(_settings.selected_level) == -1, "%s: Play routes to %s (resume)" % [engine, expected.get_file()])
		menu._on_levels()
		_ok(_last_route() == GameRoute.LEVELS_SCENE, "%s: Levels routes to Level Select" % engine)
		_close(menu)
		var editor: Control = await _instance(GameRoute.EDITOR_SCENE)
		editor._st = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_006.json"))
		_routes.clear()
		editor._on_test()
		_ok(_last_route() == expected and _settings.custom_level != null, "%s: Editor Test routes to %s" % [engine, expected.get_file()])
		_settings.custom_level = null
		_close(editor)
