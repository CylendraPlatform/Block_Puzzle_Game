extends SceneTree
## M1.2 plan R1/R2 and PR #12 review follow-ups: ordered presentation queue with
## intermediate states, convergence to the authoritative state, interruption (Undo /
## Restart / level switch), input locking with no duplicate commits, the dev-only direct
## level selector, and the dev solver kept off the interaction path. Frames are driven by
## hand (no awaits), so the timing is deterministic.
##   godot --headless --path . --script res://test/test_m1_2_sequencing.gd

const DT := 0.05
const MAX_FRAMES := 400
var _fails := 0
var _witnesses := {}
## PilotGame loaded at runtime, not named as a class: pilot_game.gd uses the Audio autoload,
## which a directly-run --script cannot resolve at compile time (see CLAUDE.md gotchas).
var _pilot = null

func _ok(condition: bool, message: String) -> void:
	if condition:
		print("  PASS  ", message)
	else:
		print("  FAIL  ", message)
		_fails += 1

func _initialize() -> void:
	print("== test_m1_2_sequencing ==")
	var saves := _save_digest()
	_pilot = load("res://scripts/game/pilot_game.gd")
	DevAccess.force = 0
	_queue_order_and_intermediate_states()
	_colour_switch_waits_for_landing()
	_queue_converges_on_every_commit()
	_interruption_reconciles()
	await _screen_lock_undo_restart_win()
	DevAccess.force = 1
	await _selector_and_dev_solver()
	DevAccess.force = -1
	_ok(_save_digest() == saves, "campaign and pilot saves untouched (not written, not cleared)")
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

# --- helpers -------------------------------------------------------------------------

func _defn(id: String) -> Dictionary:
	for path in AdvancedCatalog.list_paths():
		var raw := AdvancedCatalog.read_definition(path)
		if str(raw.get("id", "")) == id:
			return LevelLoader.load_definition(raw)["definition"]
	return {}

func _witness(defn: Dictionary) -> Array:
	var id := str(defn.get("id", ""))
	if not _witnesses.has(id):
		_witnesses[id] = SolverV2.solve(defn, PuzzleState.from_definition(defn), 200000).get("witness", [])
	return _witnesses[id]

## Only the mechanic flags the presentation queue owns (positions stay authoritative).
func _flags(s: PuzzleState) -> String:
	var lines := PackedStringArray()
	var gids: Array = s.gates.keys()
	gids.sort()
	for gid in gids:
		var g: Dictionary = s.gates[gid]
		lines.append("g %s %s %d %d" % [gid, str(g["mode"]), int(g["counter_remaining"]), int(g.get("phase", -1))])
	var bids: Array = s.blockers.keys()
	bids.sort()
	for bid in bids:
		lines.append("b %s %d" % [bid, int(bool(s.blockers[bid]["active"]))])
	var pids: Array = s.pieces.keys()
	pids.sort()
	for pid in pids:
		lines.append("p %s %d" % [pid, int(bool(s.pieces[pid]["revealed"]))])
	return "\n".join(lines)

func _event_subject(events: Array, kind: String) -> String:
	for event in events:
		if str(event.type) == kind:
			return str(event.subject_id)
	return ""

## Replays the witness until the first commit that emits `kind`.
func _commit_with(defn: Dictionary, kind: String) -> Dictionary:
	var cursor := PuzzleState.from_definition(defn)
	for action in _witness(defn):
		var applied := PuzzleEngine.transition(cursor, action, defn)
		if not bool(applied["ok"]):
			return {}
		for event in applied["events"]:
			if str(event.type) == kind:
				return {"prev": cursor, "next": applied["next_state"], "events": applied["events"], "action": action}
		cursor = applied["next_state"]
	return {}

func _view(defn: Dictionary, shown: PuzzleState) -> BoardViewV2:
	var view := BoardViewV2.new()
	view.size = Vector2(720, 720)
	root.add_child(view)
	view.show_state(defn, shown)
	return view

## Mirrors PilotGame._on_commit's presentation calls.
func _present(view: BoardViewV2, defn: Dictionary, c: Dictionary) -> void:
	var action: PuzzleAction = c["action"]
	var leaving := action.kind == PuzzleAction.EXIT
	if leaving:
		view.note_exit(action.piece_id, action.direction)
	view.show_state(defn, c["next"], leaving)
	view.begin_transition(c["prev"], c["events"], leaving)

func _drain(view: BoardViewV2) -> void:
	var frames := 0
	while view.transition_active() and frames < MAX_FRAMES:
		view.advance_transition(DT)
		frames += 1

func _open_screen() -> Control:
	var screen: Control = load("res://scenes/AdvancedQa.tscn").instantiate()
	root.add_child(screen)
	# The root joins the tree only after _initialize starts; one frame lets _ready() run.
	# After this the test drives every frame by hand again.
	while not screen.is_node_ready():
		await process_frame
	return screen

func _pump(screen: Control) -> void:
	var frames := 0
	while screen._session.input_locked and frames < MAX_FRAMES:
		screen._process(DT)
		screen._board._process(DT)
		frames += 1

func _wait_dev_solve(screen: Control) -> void:
	var polls := 0
	while _pilot._dev_task != -1 and polls < 3000:
		OS.delay_msec(5)
		screen._process(0.0)
		polls += 1

func _save_digest() -> String:
	var parts := PackedStringArray()
	for path in ["user://progress.save", "user://pilot_v2.save"]:
		parts.append("%s=%s" % [path, FileAccess.get_md5(path) if FileAccess.file_exists(path) else "absent"])
	return " ".join(parts)

# --- R1: ordered queue, intermediate states, convergence -----------------------------

func _queue_order_and_intermediate_states() -> void:
	var defn := _defn("adv-001")
	var c := _commit_with(defn, PuzzleEvent.GATE_UNLOCKED)
	_ok(not c.is_empty(), "adv-001 witness has a commit that unlocks the counter gate")
	if c.is_empty():
		return
	var prev: PuzzleState = c["prev"]
	var next: PuzzleState = c["next"]
	var prev_text := prev.canonical_text()
	var next_text := next.canonical_text()
	var view := _view(defn, prev)
	_present(view, defn, c)
	var expected: Array = ["move"]
	for event in PuzzleEvent.sort_stable(c["events"]):
		if str(event.type) in BoardViewV2.SHOWN_EVENTS:
			expected.append(str(event.type))
	_ok(view.pending_steps() == expected, "steps follow PuzzleEvent.sort_stable: %s" % str(view.pending_steps()))
	var tick := expected.find(PuzzleEvent.GATE_COUNTER_CHANGED)
	_ok(tick != -1 and tick < expected.find(PuzzleEvent.GATE_UNLOCKED), "the counter tick is queued before the unlock it causes")
	_ok(_flags(view.shown_state()) == _flags(prev), "before playback the board still shows the pre-move mechanics")
	var gid := _event_subject(c["events"], PuzzleEvent.GATE_UNLOCKED)
	_ok(str(next.gates[gid]["mode"]) == "OPEN" and str(view.shown_state().gates[gid]["mode"]) == "LOCKED", "authoritative gate is OPEN while the shown gate stays LOCKED")
	var counter_frame := -1
	var open_frame := -1
	var frame := 0
	while view.transition_active() and frame < MAX_FRAMES:
		view.advance_transition(DT)
		frame += 1
		var shown: Dictionary = view.shown_state().gates[gid]
		if counter_frame == -1 and int(shown["counter_remaining"]) == int(next.gates[gid]["counter_remaining"]):
			counter_frame = frame
		if open_frame == -1 and str(shown["mode"]) == "OPEN":
			open_frame = frame
	_ok(not view.transition_active(), "the queue drains")
	_ok(counter_frame != -1 and counter_frame < open_frame, "counter shows its new value before the gate opens (frame %d < %d)" % [counter_frame, open_frame])
	_ok(_flags(view.shown_state()) == _flags(next), "after draining the board shows the authoritative mechanics")
	_ok(prev.canonical_text() == prev_text and next.canonical_text() == next_text, "presentation never wrote PuzzleState (undo snapshot and committed state unchanged)")
	view.queue_free()

func _colour_switch_waits_for_landing() -> void:
	var defn := _defn("adv-003")
	var gate_def: Dictionary = {}
	for gate in defn.get("gates", []):
		if GateRules.is_color_switching(gate):
			gate_def = gate
	var gid := str(gate_def.get("id", ""))
	_ok(gid != "", "adv-003 has a colour-switching gate")
	if gid == "":
		return
	var cursor := PuzzleState.from_definition(defn)
	var view := _view(defn, cursor)
	var shown_colours: Array = []
	var committed_colours: Array = []
	var held_mid_move := true
	for action in _witness(defn):
		var applied := PuzzleEngine.transition(cursor, action, defn)
		var next: PuzzleState = applied["next_state"]
		_present(view, defn, {"prev": cursor, "next": next, "events": applied["events"], "action": action})
		view.advance_transition(DT)
		if int(view.shown_state().gates[gid]["phase"]) != int(cursor.gates[gid]["phase"]):
			held_mid_move = false
		_drain(view)
		shown_colours.append(GateRules.scheduled_color(gate_def, int(view.shown_state().gates[gid]["phase"])))
		committed_colours.append(GateRules.scheduled_color(gate_def, int(next.gates[gid]["phase"])))
		cursor = next
	_ok(held_mid_move, "mid-move the gate keeps the colour the piece is heading into")
	_ok(shown_colours == committed_colours and shown_colours.size() == 3, "after each committed move the gate shows the next scheduled colour: %s" % str(shown_colours))
	_ok(shown_colours[0] != shown_colours[1] and shown_colours[1] != shown_colours[2], "the colour changes on every committed move")
	view.queue_free()

func _queue_converges_on_every_commit() -> void:
	for id in ["adv-001", "adv-002", "adv-003"]:
		var defn := _defn(id)
		var cursor := PuzzleState.from_definition(defn)
		var view := _view(defn, cursor)
		var commits := 0
		var mismatches := PackedStringArray()
		for action in _witness(defn):
			var applied := PuzzleEngine.transition(cursor, action, defn)
			var next: PuzzleState = applied["next_state"]
			var snapshot := cursor.canonical_text()
			_present(view, defn, {"prev": cursor, "next": next, "events": applied["events"], "action": action})
			# Apply every queued end-visual (what fast_forward does) and compare before settling.
			for step in view._steps:
				view._apply_step(step)
			if _flags(view._shown) != _flags(next) or cursor.canonical_text() != snapshot:
				mismatches.append("move %d" % (commits + 1))
			view.fast_forward()
			cursor = next
			commits += 1
		_ok(commits > 0 and mismatches.is_empty() and not view.transition_active(), "%s: each of %d committed moves' queue lands exactly on the authoritative mechanics %s" % [id, commits, str(mismatches)])
		_ok(PuzzleEngine.is_won(defn, cursor), "%s: witness replay through the presentation path wins" % id)
		view.queue_free()

func _interruption_reconciles() -> void:
	var defn := _defn("adv-002")
	var c := _commit_with(defn, PuzzleEvent.PIECE_REVEALED)
	_ok(not c.is_empty(), "adv-002 witness has a commit that reveals the hidden piece")
	if c.is_empty():
		return
	var prev: PuzzleState = c["prev"]
	var prev_text := prev.canonical_text()
	var view := _view(defn, prev)
	_present(view, defn, c)
	view.advance_transition(DT)
	var pid := _event_subject(c["events"], PuzzleEvent.PIECE_REVEALED)
	_ok(view.transition_active() and not bool(view.shown_state().pieces[pid]["revealed"]), "mid-transition the hidden piece is still shown hidden")
	view.reconcile()
	_ok(not view.transition_active() and view.shown_state() == view.state and view._exits.is_empty(), "reconcile() settles at once on the authoritative state")
	_ok(bool(view.shown_state().pieces[pid]["revealed"]), "after reconcile the piece shows revealed")
	_ok(prev.canonical_text() == prev_text, "interrupting never wrote the undo snapshot")
	view.queue_free()

# --- R2: input lock, no duplicate commits, Undo / Restart / win ----------------------

func _screen_lock_undo_restart_win() -> void:
	var screen: Control = await _open_screen()
	var session: PuzzleSessionV2 = screen._session
	var board: BoardViewV2 = screen._board
	var defn: Dictionary = screen._definition
	_ok(str(defn.get("id", "")) == "adv-001", "Advanced QA opens on adv-001")
	var w := _witness(defn)
	screen._on_commit(w[0])
	_ok(session.move_count() == 1 and session.input_locked and board.input_locked and board.transition_active(), "a commit locks input while its transition plays")
	screen._on_commit(w[1])
	_ok(session.move_count() == 1, "a second commit during the transition is ignored (no duplicate action)")
	board._begin(board.size * 0.5)
	_ok(not board._dragging, "a drag cannot begin while locked")
	_pump(screen)
	_ok(not session.input_locked and not board.input_locked and not board.transition_active(), "input unlocks once the queue drains")
	screen._on_commit(w[1])
	_pump(screen)
	var two := session.state.canonical_text()
	screen._on_commit(w[2])
	_ok(board.transition_active(), "third move is animating")
	screen._on_undo()
	_ok(session.move_count() == 2 and session.state.canonical_text() == two and not session.input_locked and not board.transition_active(), "Undo mid-transition settles the board and restores the previous move")
	screen._on_commit(w[2])
	screen._on_restart()
	_ok(session.move_count() == 0 and session.state.canonical_text() == PuzzleState.from_definition(defn).canonical_text() and not session.input_locked and not board.transition_active(), "Restart mid-transition settles the board and rebuilds the start state")
	for i in w.size():
		screen._on_commit(w[i])
		if i < w.size() - 1:
			_pump(screen)
	_ok(session.is_won() and not screen._win_layer.visible, "the win card waits while the winning move animates")
	_pump(screen)
	_ok(screen._win_layer.visible, "the win card appears once the winning transitions finish")
	screen.queue_free()

# --- Review P2: direct QA selection and the dev solver off the hot path -------------

func _selector_and_dev_solver() -> void:
	# adv-001 takes seconds to solve; its verdict is covered by solve_advanced_benchmarks.
	_pilot._dev_verdicts["adv-001"] = "SOLVED (4)"
	var screen: Control = await _open_screen()
	var picks := {}
	for node in screen.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text.begins_with("adv-"):
			picks[button.text] = button
	_ok(picks.size() == 3 and picks.has("adv-001") and picks.has("adv-002") and picks.has("adv-003"), "dev selector lists adv-001, adv-002, adv-003")
	if picks.size() != 3:
		screen.queue_free()
		return
	(picks["adv-003"] as Button).pressed.emit()
	_ok(str(screen._definition.get("id", "")) == "adv-003" and screen._title.text == "Advanced QA 3", "selector opens adv-003 directly, without finishing earlier levels")
	_ok(_pilot._dev_task != -1 and screen._status.text.contains("solving..."), "adv-003's dev solve runs on a worker; loading did not wait for it")
	_wait_dev_solve(screen)
	_ok(screen._status.text.contains("SOLVED (3)"), "dev readout shows the worker's verdict: %s" % screen._status.text)
	var w3 := _witness(screen._definition)
	screen._on_commit(w3[0])
	var solve_started: bool = _pilot._dev_task != -1
	_pump(screen)
	screen._on_undo()
	solve_started = solve_started or _pilot._dev_task != -1
	screen._on_restart()
	solve_started = solve_started or _pilot._dev_task != -1
	_ok(not solve_started and screen._status.text.contains("SOLVED (3)"), "commit / undo / restart never start a solve (verdict read from cache)")
	screen._on_commit(w3[0])
	_ok(screen._board.transition_active(), "an adv-003 move is animating before the level switch")
	(picks["adv-002"] as Button).pressed.emit()
	_ok(str(screen._definition.get("id", "")) == "adv-002" and screen._session.move_count() == 0 and not screen._session.input_locked and not screen._board.transition_active(), "switching level mid-transition reconciles and starts the new level unlocked")
	_wait_dev_solve(screen)
	_ok(_pilot._dev_task == -1, "no dev solve left in flight")
	screen.queue_free()
