class_name PilotGame
extends Control
## Developer route for the 15 v2 pilot levels. Does not write progress.save.
## Subclasses (e.g. AdvancedQA) override the level source + title + save hooks below to
## reuse this screen for a different, campaign-separate level set.

## Level source + save hooks — overridable so a QA screen can point at another set without
## touching campaign progress.
func _level_paths() -> Array[String]:
	return PilotCatalog.list_paths()

func _read_level(path: String) -> Dictionary:
	return PilotCatalog.read_definition(path)

func _saved_index() -> int:
	return PilotCatalog.load_index()

func _save_index(index: int) -> void:
	PilotCatalog.save_index(index)

func _screen_title(index: int) -> String:
	return "Level %d" % (index + 1)

var _paths: Array[String] = []
var _index := 0
var _definition: Dictionary = {}
var _session: PuzzleSessionV2
var _board: BoardViewV2
var _title: Label
var _prompt: Label
var _status: Label
var _win_layer: Control
var _prompt_row: Control
var _lock_left := 0.0

func _ready() -> void:
	_paths = _level_paths()
	_index = clampi(_saved_index(), 0, maxi(0, _paths.size() - 1))
	_build()
	if not _paths.is_empty():
		_load(_index)

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(TD35Theme.make_bg())
	var safe := SafeArea.new()
	add_child(safe)
	var column := UIKit.column(safe)
	column.add_theme_constant_override("separation", 8)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var back := UIKit.button("Menu", _on_menu)
	TD35Theme.style_compact(back)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var restart := UIKit.button("Restart", _on_restart)
	TD35Theme.style_compact(restart)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var undo := UIKit.button("Undo", _on_undo)
	TD35Theme.style_compact(undo)
	undo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", TD35Theme.NAVY)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(back)
	bar.add_child(restart)
	bar.add_child(undo)
	column.add_child(bar)
	column.add_child(_title)
	_prompt_row = HBoxContainer.new()
	_prompt = Label.new()
	_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.add_theme_font_size_override("font_size", 16)
	_prompt.add_theme_color_override("font_color", TD35Theme.NAVY)
	var hide := UIKit.button("Hide", func() -> void: _prompt_row.visible = false)
	TD35Theme.style_compact(hide)
	hide.size_flags_horizontal = Control.SIZE_SHRINK_END
	_prompt_row.add_child(_prompt)
	_prompt_row.add_child(hide)
	column.add_child(_prompt_row)
	_board = BoardViewV2.new()
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.commit_requested.connect(_on_commit)
	_board.bumped.connect(func() -> void:
		if Audio:
			Audio.sfx("bump"))
	column.add_child(_board)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", TD35Theme.NAVY)
	column.add_child(_status)
	var win := UIKit.modal(safe, "Level Complete!")
	_win_layer = win["layer"]
	var card: PanelContainer = win["card"]
	card.add_theme_stylebox_override("panel", TD35Theme.card_box())
	var box: VBoxContainer = win["box"]
	var heading := box.get_child(0) as Label
	if heading != null:
		heading.add_theme_color_override("font_color", TD35Theme.NAVY)
	var next := UIKit.button("Next", _on_next)
	TD35Theme.style_button(next, true)
	var menu := UIKit.button("Menu", _on_menu)
	TD35Theme.style_button(menu, false)
	box.add_child(next)
	box.add_child(menu)

func _load(index: int) -> void:
	if index < 0 or index >= _paths.size():
		return
	_index = index
	_save_index(index)
	var raw := _read_level(_paths[index])
	var loaded := LevelLoader.load_definition(raw)
	if not bool(loaded["ok"]):
		_title.text = "Invalid pilot level"
		_status.text = "Schema rejected this file. It was not started."
		return
	_definition = loaded["definition"]
	_session = PuzzleSessionV2.open(_definition)
	_board.show_state(_definition, _session.state)
	_win_layer.visible = false
	_prompt_row.visible = true
	var metrics: Dictionary = _definition.get("authored_metrics", {})
	_prompt.text = str(metrics.get("prompt", ""))
	_title.text = _screen_title(index)
	_refresh_status()

func _refresh_status() -> void:
	if _session == null:
		return
	_status.text = "Moves %d" % _session.move_count()
	if not DevAccess.enabled():
		return
	var solved := SolverV2.solve(_definition, PuzzleState.from_definition(_definition), 8000)
	var verdict := str(solved["status"])
	var length := int(solved["solution_length"])
	_status.text = "Moves %d    Dev %s %s (%s)" % [_session.move_count(), str(_definition.get("id", "")), verdict, str(length)]

func _on_commit(action: PuzzleAction) -> void:
	if _session == null or _session.input_locked:
		return
	var applied := _session.commit(action)
	if not bool(applied["ok"]):
		if Audio:
			Audio.sfx("bump")
		return
	_session.input_locked = true
	_board.set_locked(true)
	var leaving := action.kind == PuzzleAction.EXIT
	if leaving:
		_board.note_exit(action.piece_id, action.direction)
	_board.show_state(_definition, _session.state, leaving)
	# Animate the committed mechanic transitions (unlock / counter / reveal / blocker).
	_board.queue_events(applied.get("events", []))
	_lock_left = maxf(0.34 if leaving else 0.18, _board.FLASH_TIME)
	if _session.is_won():
		_win_layer.visible = true
	_refresh_status()

func _process(delta: float) -> void:
	if _lock_left <= 0.0 or _session == null:
		return
	# Stay locked until both the move settle and any transition flashes finish, so no
	# second action can be committed while the board is animating.
	_lock_left -= delta
	if _lock_left <= 0.0 and not _board.flashes_active():
		_session.input_locked = false
		_board.set_locked(false)

func _on_undo() -> void:
	if _session == null or not _session.undo():
		return
	# Cancel any pending animation and redraw the authoritative restored state.
	_board.reconcile()
	_lock_left = 0.0
	_session.input_locked = false
	_board.set_locked(false)
	_win_layer.visible = false
	_board.show_state(_definition, _session.state)
	_refresh_status()

func _on_restart() -> void:
	if _session == null:
		return
	_session.restart()
	_board.reconcile()
	_lock_left = 0.0
	_board.set_locked(false)
	_win_layer.visible = false
	_board.show_state(_definition, _session.state)
	_refresh_status()

func _on_next() -> void:
	if _index + 1 < _paths.size():
		_load(_index + 1)
	else:
		_on_menu()

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
