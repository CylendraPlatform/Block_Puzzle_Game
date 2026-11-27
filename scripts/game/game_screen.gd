extends Control
## Unified v2 gameplay screen (M1.3-C; plan §6). Opened by GameRoute when
## gameplay/engine = v2. Plays Classic (stable ids from CampaignCatalog, progress in
## ProgressStore via the Progress autoload) or the editor's custom v1 level (via LevelLoader /
## V1Adapter, never recorded). PuzzleSessionV2 owns state; BoardViewV2 only presents it;
## ClassicScore counts accepted actions and is never refunded by Undo.

var _entries: Array = []
var _index := -1
var _entry: Dictionary = {}
var _custom := false
var _definition: Dictionary = {}
var _session: PuzzleSessionV2
var _score := ClassicScore.new()
var _undos := 0
## The completion of this attempt was taken (stars fixed, analytics sent). Saving is tracked
## separately in _save_status, so a failed write is never shown as saved.
var _recorded := false
var _earned := 0
## "" (nothing to save) | saved | partial (one of the two save files written; the other is
## retried) | failed (neither written: not durable) | read_only (newer save found).
var _save_status := ""
var _board: BoardViewV2
var _title: Label
var _moves: Label
var _win_layer: Control
var _win_name: Label
var _win_stars: Label
var _save_note: Label
var _retry: Button
var _next: Button
var _pause_layer: Control
## Asks before leaving a won attempt whose save failed (Menu, Levels, Restart).
var _confirm_layer: Control
var _confirm_note: Label
var _confirm_action := Callable()

const UNSAVED_LEAVE_NOTE := "This win could not be saved. If you leave now it will be lost when the game closes, unless a later save succeeds."
const UNSAVED_RETRY_FAILED := "Saving failed again. If you leave now this win will be lost when the game closes, unless a later save succeeds."

func _ready() -> void:
	_build()
	if Settings and Settings.custom_level != null:
		_custom = true
		_next.text = "Back to Editor"
		_open_custom()
		return
	_entries = CampaignCatalog.levels(CampaignCatalog.CLASSIC)
	if _entries.is_empty():
		_title.text = "No levels found"
		return
	var unlocked := _store().unlocked(CampaignCatalog.CLASSIC)
	var start := unlocked
	if Settings and Settings.selected_level >= 0:
		start = Settings.selected_level
	# Gating: never open a level past the player's progress, whatever the caller asked for.
	_load_index(clampi(mini(start, unlocked), 0, _entries.size() - 1))

func _store() -> ProgressStore:
	return Progress.get_store()

# --- UI ------------------------------------------------------------------------------------

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(TD35Theme.make_bg())
	var safe := SafeArea.new()
	add_child(safe)
	var column := UIKit.column(safe)
	column.add_theme_constant_override("separation", 8)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var pause := UIKit.button("Pause", _on_pause)
	TD35Theme.style_compact(pause)
	pause.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", TD35Theme.NAVY)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var undo := UIKit.button("Undo", _on_undo)
	TD35Theme.style_compact(undo)
	undo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.add_child(pause)
	bar.add_child(_title)
	bar.add_child(undo)
	column.add_child(bar)
	_board = BoardViewV2.new()
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.commit_requested.connect(_on_commit)
	_board.bumped.connect(func() -> void:
		if Audio:
			Audio.sfx("bump")
			Audio.haptic(12))
	column.add_child(_board)
	_moves = Label.new()
	_moves.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moves.add_theme_font_size_override("font_size", 15)
	_moves.add_theme_color_override("font_color", TD35Theme.NAVY)
	column.add_child(_moves)
	var win := _modal(safe, "Level Complete!")
	_win_layer = win["layer"]
	var wv: VBoxContainer = win["box"]
	_win_name = UIKit.wrapping_label("", 20, TD35Theme.NAVY)
	wv.add_child(_win_name)
	wv.move_child(_win_name, 1)
	_win_stars = UIKit.wrapping_label("", 32, TD35Theme.NAVY)
	wv.add_child(_win_stars)
	wv.move_child(_win_stars, 2)
	_save_note = UIKit.wrapping_label("", 15, TD35Theme.NAVY)
	_save_note.visible = false
	wv.add_child(_save_note)
	wv.move_child(_save_note, 3)
	_retry = _modal_button(wv, "Retry Save", _on_retry_save, false)
	_retry.visible = false
	_next = _modal_button(wv, "Next", _on_next, true)
	_modal_button(wv, "Menu", _on_menu, false)
	var paused := _modal(safe, "Paused")
	_pause_layer = paused["layer"]
	var pv: VBoxContainer = paused["box"]
	_modal_button(pv, "Resume", _on_resume, true)
	_modal_button(pv, "Restart", func() -> void:
		_set_pause(false)
		_on_restart(), false)
	_modal_button(pv, "Levels", _on_levels, false)
	_modal_button(pv, "Main Menu", _on_menu, false)
	var confirm := _modal(safe, "Progress Not Saved")
	_confirm_layer = confirm["layer"]
	var cv: VBoxContainer = confirm["box"]
	_confirm_note = UIKit.wrapping_label(UNSAVED_LEAVE_NOTE, 16, TD35Theme.NAVY)
	cv.add_child(_confirm_note)
	cv.move_child(_confirm_note, 1)
	_modal_button(cv, "Retry Save", _on_confirm_retry, true)
	_modal_button(cv, "Leave Anyway", _on_confirm_leave, false)
	_modal_button(cv, "Stay", _on_confirm_stay, false)

func _modal(safe: Node, heading: String) -> Dictionary:
	var modal := UIKit.modal(safe, heading)
	var card: PanelContainer = modal["card"]
	card.add_theme_stylebox_override("panel", TD35Theme.card_box())
	var title := (modal["box"] as VBoxContainer).get_child(0) as Label
	if title != null:
		title.add_theme_color_override("font_color", TD35Theme.NAVY)
	return modal

func _modal_button(box: VBoxContainer, text: String, callback: Callable, primary: bool) -> Button:
	var b := UIKit.button(text, callback)
	TD35Theme.style_button(b, primary)
	box.add_child(b)
	return b

func _set_pause(on: bool) -> void:
	_pause_layer.visible = on

func _refresh() -> void:
	_moves.text = "Moves %d" % _score.moves

# --- Level flow ----------------------------------------------------------------------------

func _load_index(index: int) -> void:
	if index < 0 or index >= _entries.size():
		return
	_index = index
	_entry = _entries[index]
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(_entry["path"])))
	var loaded := LevelLoader.load_definition(raw if raw is Dictionary else {})
	if not bool(loaded["ok"]):
		push_error("failed to load level " + str(_entry["path"]))
		_session = null
		_title.text = "Level could not be loaded"
		return
	_start(loaded["definition"])
	_title.text = "Level %d — %s" % [int(_entry["legacy_id"]), str((raw as Dictionary).get("name", ""))]
	if Analytics:
		Analytics.log_event("level_start", {"level": _level_number()})

func _open_custom() -> void:
	var raw: Variant = Settings.custom_level
	var loaded := LevelLoader.load_definition(raw if raw is Dictionary else {})
	if not bool(loaded["ok"]):
		_session = null
		_title.text = "Custom level is not valid"
		return
	_start(loaded["definition"])
	_title.text = "Custom Level"

func _start(definition: Dictionary) -> void:
	_definition = definition
	_session = PuzzleSessionV2.open(definition)
	_score.on_restart()
	_undos = 0
	_recorded = false
	_save_status = ""
	_show_save_status()
	_board.reconcile()
	_board.set_locked(false)
	_board.show_state(_definition, _session.state)
	_win_layer.visible = false
	_confirm_layer.visible = false
	_confirm_action = Callable()
	_set_pause(false)
	_refresh()

func _level_number() -> int:
	return 0 if _custom else int(_entry.get("legacy_id", 0))

# --- Input ---------------------------------------------------------------------------------

func _on_commit(action: PuzzleAction) -> void:
	if _session == null or _session.input_locked or _pause_layer.visible or _session.is_won():
		return
	var previous := _session.state
	var applied := _session.commit(action)
	if not bool(applied["ok"]):
		if Audio:
			Audio.sfx("bump")
		return
	_score.on_commit()
	# Lock at once; it lifts only when the board's presentation queue drains (M1.2 R2).
	_session.input_locked = true
	_board.set_locked(true)
	var leaving := action.kind == PuzzleAction.EXIT
	if leaving:
		_board.note_exit(action.piece_id, action.direction)
	_board.show_state(_definition, _session.state, leaving)
	_board.begin_transition(previous, applied.get("events", []), leaving)
	if Audio:
		Audio.sfx("exit" if leaving else "slide")
		Audio.haptic(18 if leaving else 8)
	_refresh()
	if _session.is_won():
		_record_win()

## Saves the result as soon as the winning move is accepted, so leaving during the final
## animation cannot lose it. Custom (editor) levels are never recorded (par 0 = 3 stars,
## as on the legacy route).
## The completion (stars, analytics) is taken once per attempt; saving may be retried.
func _record_win() -> void:
	if _recorded:
		return
	_recorded = true
	_earned = _score.stars(int(_entry.get("par", 0)))
	if not _custom:
		_persist_win()
	if Analytics:
		Analytics.log_event("level_complete", {"level": _level_number(), "moves": _score.moves, "stars": _earned, "undos": _undos})

## Writes this attempt's completion. Idempotent: the store keeps the best stars and the highest
## unlock, so retrying the same completion never adds stars. progress_v2.save and the legacy
## progress.save are independent copies (the next launch merges either into the other), so one
## written copy is durable; neither written is not.
func _persist_win() -> void:
	var store := _store()
	var result := store.record_completion(CampaignCatalog.CLASSIC, str(_entry["id"]), _index, _earned)
	var v2_ok := int(result.get("v2", FAILED)) == OK
	var v1 := int(result.get("v1", -1))
	var v1_ok := v1 == OK
	if store.read_only:
		_save_status = "read_only"
	elif v2_ok and (v1_ok or v1 == -1):
		_save_status = "saved"
	elif v2_ok or v1_ok:
		_save_status = "partial"
	else:
		_save_status = "failed"
	if _save_status != "saved":
		push_warning("progress save %s: %s" % [_save_status, str(result)])
	_show_save_status()

func _save_pending() -> bool:
	return _recorded and not _custom and (_save_status == "failed" or _save_status == "partial")

func _show_save_status() -> void:
	var notes := {
		"partial": "Progress saved. A backup copy could not be written and will be retried.",
		"failed": "Progress could not be saved. The next level stays locked until this win is saved. Tap Retry Save.",
		"read_only": "Progress is not being saved: this device has a save from a newer version of the game.",
	}
	_save_note.text = str(notes.get(_save_status, ""))
	_save_note.visible = notes.has(_save_status)
	_retry.visible = _save_pending()
	# Advancing on an unsaved win would stack more progress that exists only in memory.
	_next.disabled = _save_status == "failed"

func _on_retry_save() -> void:
	if _save_pending():
		_persist_win()

## Leaving a won attempt (Next, Restart, Menu, Levels) retries a pending save once. The
## completion stays in the store's memory either way and is written again by the next save.
func _retry_pending_save() -> void:
	if _save_pending():
		_persist_win()

## Menu, Levels and Restart on a win whose save still fails after one more try: ask first.
## Returns true when the confirmation took over (the caller must not continue).
func _confirm_if_unsaved(action: Callable) -> bool:
	_retry_pending_save()
	if _save_status != "failed":
		return false
	_confirm_action = action
	_confirm_note.text = UNSAVED_LEAVE_NOTE
	_confirm_layer.visible = true
	return true

func _on_confirm_retry() -> void:
	_persist_win()
	if _save_status == "failed":
		_confirm_note.text = UNSAVED_RETRY_FAILED
		return
	_run_confirmed()

func _on_confirm_leave() -> void:
	push_warning("leaving with an unsaved win (level %d)" % _level_number())
	_run_confirmed()

func _on_confirm_stay() -> void:
	_confirm_layer.visible = false
	_confirm_action = Callable()

func _run_confirmed() -> void:
	_confirm_layer.visible = false
	var action := _confirm_action
	_confirm_action = Callable()
	if action.is_valid():
		action.call()

func _process(_delta: float) -> void:
	if _session == null or not _session.input_locked or _board.transition_active():
		return
	_session.input_locked = false
	_board.set_locked(false)
	# The win card waits for the winning move's transitions so they stay visible.
	if _session.is_won() and not _win_layer.visible:
		_win_name.text = _title.text
		_win_stars.text = "%d / 3 Stars" % _earned
		_win_layer.visible = true
		if Audio:
			Audio.sfx("win")

## A win is final for the attempt, as on the legacy route (its win card blocks Undo): Undo is
## ignored from the winning move on, including during the final animation, so the recorded
## completion, the shown stars and the board never disagree. Restart or Next start a new attempt.
func _on_undo() -> void:
	if _session == null or _pause_layer.visible or _session.is_won():
		return
	# Undo interrupts a playing transition: settle it, then restore the previous snapshot.
	_board.reconcile()
	_session.input_locked = false
	_board.set_locked(false)
	if not _session.undo():
		return
	_score.on_undo()
	_undos += 1
	_win_layer.visible = false
	_board.show_state(_definition, _session.state)
	_refresh()
	if Analytics:
		Analytics.log_event("undo_used", {"level": _level_number()})

func _on_restart() -> void:
	if _session == null or _confirm_if_unsaved(_restart_now):
		return
	_restart_now()

func _restart_now() -> void:
	if Analytics:
		Analytics.log_event("level_restart", {"level": _level_number()})
	if _custom:
		_start(_definition)
	else:
		_load_index(_index)

func _on_pause() -> void:
	if _session != null and not _win_layer.visible and not _confirm_layer.visible:
		_set_pause(true)

func _on_resume() -> void:
	_set_pause(false)

# --- Navigation ----------------------------------------------------------------------------

func _on_next() -> void:
	if _custom:
		Settings.custom_level = null
		GameRoute.go(get_tree(), GameRoute.EDITOR_SCENE)
		return
	_retry_pending_save()
	if _save_status == "failed":
		_show_save_status()
		return
	if _index + 1 < _entries.size():
		# Interstitial opportunity between levels (no-op unless a provider is set).
		if Ads and (_index + 1) % 3 == 0:
			Ads.show_interstitial("level_complete")
		_load_index(_index + 1)
	else:
		_win_layer.visible = false
		_title.text = "All levels complete!"

func _on_menu() -> void:
	if not _confirm_if_unsaved(_leave.bind(GameRoute.MENU_SCENE)):
		_leave(GameRoute.MENU_SCENE)

func _on_levels() -> void:
	if not _confirm_if_unsaved(_leave.bind(GameRoute.LEVELS_SCENE)):
		_leave(GameRoute.LEVELS_SCENE)

func _leave(path: String) -> void:
	_board.reconcile()
	_retry_pending_save()
	if Settings:
		Settings.custom_level = null
	GameRoute.go(get_tree(), path)
