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
var _recorded := false
var _earned := 0
var _board: BoardViewV2
var _title: Label
var _moves: Label
var _win_layer: Control
var _win_name: Label
var _win_stars: Label
var _next: Button
var _pause_layer: Control

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
	_board.reconcile()
	_board.set_locked(false)
	_board.show_state(_definition, _session.state)
	_win_layer.visible = false
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
func _record_win() -> void:
	if _recorded:
		return
	_recorded = true
	_earned = _score.stars(int(_entry.get("par", 0)))
	if not _custom:
		var result := _store().record_completion(CampaignCatalog.CLASSIC, str(_entry["id"]), _index, _earned)
		if int(result.get("v2", OK)) != OK:
			push_warning("progress save failed: %s" % str(result))
	if Analytics:
		Analytics.log_event("level_complete", {"level": _level_number(), "moves": _score.moves, "stars": _earned, "undos": _undos})

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

func _on_undo() -> void:
	if _session == null or _pause_layer.visible:
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
	if _session == null:
		return
	if Analytics:
		Analytics.log_event("level_restart", {"level": _level_number()})
	if _custom:
		_start(_definition)
	else:
		_load_index(_index)

func _on_pause() -> void:
	if _session != null and not _win_layer.visible:
		_set_pause(true)

func _on_resume() -> void:
	_set_pause(false)

# --- Navigation ----------------------------------------------------------------------------

func _on_next() -> void:
	if _custom:
		Settings.custom_level = null
		GameRoute.go(get_tree(), GameRoute.EDITOR_SCENE)
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
	_leave(GameRoute.MENU_SCENE)

func _on_levels() -> void:
	_leave(GameRoute.LEVELS_SCENE)

func _leave(path: String) -> void:
	_board.reconcile()
	if Settings:
		Settings.custom_level = null
	GameRoute.go(get_tree(), path)
