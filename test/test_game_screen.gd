extends SceneTree
## M1.3-C unified GameScreen: engine flag (default legacy) and routing, Play resume point, Level
## Select gating and stars by stable id, Next / Undo / Restart / Pause routes, Editor Test
## isolation, save migration from progress.save and rollback to the legacy Catalog, and no
## duplicate commits while the board animates. Progress lives in an isolated user:// folder;
## navigation is captured through GameRoute.navigate_hook (no scene change).
##   godot --headless --path . --script res://test/test_game_screen.gd

const DT := 0.05
const MAX_FRAMES := 400
const DIR := "user://m13c_game_screen/"

var _fails := 0
var _progress: Node
var _settings: Node
var _routes: Array = []

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
