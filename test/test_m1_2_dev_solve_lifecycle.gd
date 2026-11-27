extends SceneTree
## Dev-only background solve lifecycle (PilotGame): the solver's opt-in cancel token, the
## screen exiting mid-solve, reopening the QA screen, rapid level switching, a screen freed
## while its solve is still queued behind a busy worker pool, and (last) quitting with a
## solve in flight. The task belongs to its screen: _exit_tree() cancels and waits.
##   godot --headless --path . --script res://test/test_m1_2_dev_solve_lifecycle.gd

var _fails := 0
## Loaded at runtime: pilot_game.gd uses the Audio autoload (see CLAUDE.md gotchas).
var _pilot = null

func _ok(condition: bool, message: String) -> void:
	if condition:
		print("  PASS  ", message)
	else:
		print("  FAIL  ", message)
		_fails += 1

func _initialize() -> void:
	print("== test_m1_2_dev_solve_lifecycle ==")
	_pilot = load("res://scripts/game/pilot_game.gd")
	_solver_cancel_is_opt_in()
	DevAccess.force = 1
	await _exit_mid_solve_then_reopen()
	await _rapid_switching()
	await _freed_while_queued()
	await _release_mode_runs_no_solver()
	DevAccess.force = 1
	# Last: quit while a solve is still running. The shell wrapper times the exit and checks
	# the exit code (a running solver used to block shutdown and then segfault).
	_pilot._dev_verdicts.clear()
	var screen := await _open()
	_ok(screen._dev_task != -1 and not WorkerThreadPool.is_task_completed(screen._dev_task), "adv-001 solve in flight at quit")
	DevAccess.force = -1
	print("== done: %d failure(s) ==" % _fails)
	print("QUIT_WITH_SOLVE_IN_FLIGHT t=%d" % Time.get_ticks_msec())
	quit(_fails)

func _open() -> Control:
	var screen: Control = load("res://scenes/AdvancedQa.tscn").instantiate()
	root.add_child(screen)
	while not screen.is_node_ready():
		await process_frame
	return screen

func _pick(screen: Control, id: String) -> void:
	for node in screen.find_children("*", "Button", true, false):
		if (node as Button).text == id:
			(node as Button).pressed.emit()
			return

## Lets a live screen collect results (its _process polls its task).
func _settle(screen: Control, limit_ms: int) -> bool:
	var start := Time.get_ticks_msec()
	while screen._dev_task != -1:
		if Time.get_ticks_msec() - start > limit_ms:
			return false
		OS.delay_msec(10)
		screen._process(0.0)
	return true

func _defn(id: String) -> Dictionary:
	for path in AdvancedCatalog.list_paths():
		var raw := AdvancedCatalog.read_definition(path)
		if str(raw.get("id", "")) == id:
			return LevelLoader.load_definition(raw)["definition"]
	return {}

func _solver_cancel_is_opt_in() -> void:
	var defn := _defn("adv-003")
	var plain := SolverV2.solve(defn, PuzzleState.from_definition(defn), 8000)
	var unused := SolverV2.solve(defn, PuzzleState.from_definition(defn), 8000, 0, Semaphore.new())
	var stop := Semaphore.new()
	stop.post()
	var cancelled := SolverV2.solve(defn, PuzzleState.from_definition(defn), 8000, 0, stop)
	_ok(str(plain["status"]) == "SOLVED" and int(plain["solution_length"]) == 3, "no cancel token: unchanged result (SOLVED, 3)")
	_ok(str(unused["status"]) == "SOLVED" and int(unused["explored_states"]) == int(plain["explored_states"]), "an un-posted token changes nothing")
	_ok(str(cancelled["status"]) == "UNKNOWN_CAP_REACHED" and int(cancelled["explored_states"]) == 0, "a posted token stops before the first expansion (never UNSOLVABLE)")

func _exit_mid_solve_then_reopen() -> void:
	_pilot._dev_verdicts.clear()
	var screen := await _open()
	_ok(screen._dev_task != -1, "opening adv-001 starts its dev solve on a worker")
	OS.delay_msec(300)
	var start := Time.get_ticks_msec()
	screen.free()
	var exit_ms := Time.get_ticks_msec() - start
	_ok(exit_ms < 1000, "leaving the screen cancels the running solve promptly (%d ms)" % exit_ms)
	_ok(not _pilot._dev_verdicts.has("adv-001"), "a cancelled solve caches nothing")
	var again := await _open()
	_ok(again._dev_task != -1, "reopening the QA screen solves the level again")
	_ok(_settle(again, 60000) and again._status.text.contains("SOLVED (4)"), "verdict delivered after reopen: %s" % again._status.text)
	again.free()

func _rapid_switching() -> void:
	_pilot._dev_verdicts.clear()
	_pilot._dev_verdicts["adv-001"] = "SOLVED (4)"  # covered above; keeps this case fast
	var screen := await _open()
	var max_in_flight := 0
	for id in ["adv-002", "adv-003", "adv-001", "adv-002", "adv-003", "adv-002"]:
		_pick(screen, id)
		screen._process(0.0)
		max_in_flight = maxi(max_in_flight, 1 if screen._dev_task != -1 else 0)
	_ok(max_in_flight <= 1, "rapid switching never runs more than one solve")
	_ok(_settle(screen, 20000), "all queued work settles")
	# Contract: the level on screen gets its verdict; a level left before the worker was free
	# is not queued, and is solved when it is shown again.
	_ok(str(_pilot._dev_verdicts.get("adv-002", "")) == "SOLVED (3)", "the level on screen gets its real verdict: %s" % str(_pilot._dev_verdicts))
	_ok(screen._status.text.contains("Dev adv-002 SOLVED (3)"), "status matches the level on screen: %s" % screen._status.text)
	_pick(screen, "adv-003")
	_ok(_settle(screen, 20000) and screen._status.text.contains("Dev adv-003 SOLVED (3)"), "a level skipped during rapid switching is solved when shown again: %s" % screen._status.text)
	screen.free()

## force = 0 is what DevAccess.enabled() returns in a release export (no editor feature,
## OS.is_debug_build() false, no --dev argument).
func _release_mode_runs_no_solver() -> void:
	DevAccess.force = 0
	_pilot._dev_verdicts.clear()
	var menu: Control = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	while not menu.is_node_ready():
		await process_frame
	var labels: Array = []
	for node in menu.find_children("*", "Button", true, false):
		labels.append((node as Button).text)
	_ok(not labels.has("Advanced QA") and not labels.has("v2 Pilot") and not labels.has("TD-3.6 QA") and not labels.has("Editor"), "release menu hides every QA route: %s" % str(labels))
	_ok(labels.has("Play") and labels.has("Levels") and labels.has("Settings"), "release menu keeps the player entries: %s" % str(labels))
	menu.free()
	var screen := await _open()
	var picks := 0
	for node in screen.find_children("*", "Button", true, false):
		if (node as Button).text.begins_with("adv-"):
			picks += 1
	_ok(screen._dev_task == -1 and _pilot._dev_verdicts.is_empty(), "release mode starts no solver task")
	_ok(picks == 0 and screen._status.text == "Moves 0", "release mode shows no selector and no dev readout: '%s'" % screen._status.text)
	screen.free()

func _freed_while_queued() -> void:
	_pilot._dev_verdicts.clear()
	_pilot._dev_verdicts["adv-001"] = "SOLVED (4)"
	# Occupy the worker pool so the dev solve is still queued when its screen is freed.
	var busy: Array = []
	for i in OS.get_processor_count() * 2:
		busy.append(WorkerThreadPool.add_task(func() -> void: OS.delay_msec(1500)))
	var screen := await _open()
	_pick(screen, "adv-003")
	var queued: bool = screen._dev_task != -1 and not WorkerThreadPool.is_task_completed(screen._dev_task)
	_ok(queued, "adv-003 solve queued behind a busy pool")
	screen.free()
	_ok(not _pilot._dev_verdicts.has("adv-003"), "freeing the screen cancelled the queued solve; nothing cached")
	for id in busy:
		WorkerThreadPool.wait_for_task_completion(id)
	var again := await _open()
	_pick(again, "adv-003")
	_ok(_settle(again, 20000) and again._status.text.contains("Dev adv-003 SOLVED (3)"), "the next screen solves it normally: %s" % again._status.text)
	again.free()
