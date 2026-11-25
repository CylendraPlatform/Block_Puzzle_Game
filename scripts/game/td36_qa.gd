extends Control
## Developer route for TD-3.6 fixtures and candidate puzzles.
## Writes only user://td36_qa.save. Does not touch Play or legacy saves.

var _paths: Array[String] = []
var _index := 0
var _definition: Dictionary = {}
var _session: PuzzleSessionV2
var _board: BoardViewV2
var _title: Label
var _prompt: Label
var _status: Label
var _timer_label: Label
var _picker: OptionButton
var _win_layer: Control
var _prompt_row: Control
var _lock_left := 0.0
var _elapsed := 0.0
var _timing := false

func _ready() -> void:
	_paths = Td36Catalog.list_paths()
	_index = clampi(Td36Catalog.load_index(), 0, maxi(0, _paths.size() - 1))
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
	bar.add_child(back)
	bar.add_child(restart)
	bar.add_child(undo)
	column.add_child(bar)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", TD35Theme.NAVY)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_title)
	var pick_row := HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 8)
	var prev := UIKit.button("Prev", _on_prev)
	TD35Theme.style_compact(prev)
	prev.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var next := UIKit.button("Next", _on_skip)
	TD35Theme.style_compact(next)
	next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_picker = OptionButton.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.item_selected.connect(_on_pick)
	for i in _paths.size():
		var raw := Td36Catalog.read_definition(_paths[i])
		var kind := "Fixture" if Td36Catalog.is_fixture(i) else "Candidate"
		_picker.add_item("%s %s — %s" % [kind, str(raw.get("id", "")), str(raw.get("name", ""))])
	pick_row.add_child(prev)
	pick_row.add_child(_picker)
	pick_row.add_child(next)
	column.add_child(pick_row)
	_prompt_row = HBoxContainer.new()
	_prompt = Label.new()
	_prompt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.add_theme_font_size_override("font_size", 15)
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
	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 15)
	_timer_label.add_theme_color_override("font_color", TD35Theme.NAVY)
	column.add_child(_timer_label)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 14)
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
	var next_win := UIKit.button("Next", _on_next)
	TD35Theme.style_button(next_win, true)
	var menu := UIKit.button("Menu", _on_menu)
	TD35Theme.style_button(menu, false)
	box.add_child(next_win)
	box.add_child(menu)

func _load(index: int) -> void:
	if index < 0 or index >= _paths.size():
		return
	_index = index
	Td36Catalog.save_index(index)
	_picker.set_block_signals(true)
	_picker.select(index)
	_picker.set_block_signals(false)
	var raw := Td36Catalog.read_definition(_paths[index])
	var loaded := LevelLoader.load_definition(raw)
	if not bool(loaded["ok"]):
		_title.text = "Invalid TD-3.6 level"
		_status.text = "Schema rejected this file. It was not started."
		return
	_definition = loaded["definition"]
	_session = PuzzleSessionV2.open(_definition)
	_board.show_state(_definition, _session.state)
	_win_layer.visible = false
	_prompt_row.visible = true
	_elapsed = 0.0
	_timing = false
	var metrics: Dictionary = _definition.get("authored_metrics", {})
	_prompt.text = str(metrics.get("prompt", ""))
	var kind := "Fixture" if Td36Catalog.is_fixture(index) else "Candidate"
	_title.text = "TD-3.6 QA  %s  %s" % [kind, str(_definition.get("id", ""))]
	_refresh_status()

func _refresh_status() -> void:
	_timer_label.text = "Time %s" % _format_time(_elapsed)
	if _session == null:
		return
	var kind := "Fixture" if Td36Catalog.is_fixture(_index) else "Candidate"
	_status.text = "Moves %d    %s %s" % [_session.move_count(), kind, str(_definition.get("id", ""))]

func _format_time(seconds: float) -> String:
	var whole := int(seconds)
	var mins := whole / 60
	var secs := whole % 60
	return "%d:%02d" % [mins, secs]

func _on_commit(action: PuzzleAction) -> void:
	if _session == null or _session.input_locked:
		return
	var applied := _session.commit(action)
	if not bool(applied["ok"]):
		if Audio:
			Audio.sfx("bump")
		return
	if not _timing:
		_timing = true
	_session.input_locked = true
	_board.set_locked(true)
	var leaving := action.kind == PuzzleAction.EXIT
	if leaving:
		_board.note_exit(action.piece_id, action.direction)
	_board.show_state(_definition, _session.state, leaving)
	_lock_left = 0.34 if leaving else 0.18
	if _session.is_won():
		_timing = false
		_win_layer.visible = true
	_refresh_status()

func _process(delta: float) -> void:
	if _timing:
		_elapsed += delta
		_timer_label.text = "Time %s" % _format_time(_elapsed)
	if _lock_left <= 0.0 or _session == null:
		return
	_lock_left -= delta
	if _lock_left <= 0.0:
		_session.input_locked = false
		_board.set_locked(false)

func _on_undo() -> void:
	if _session == null or not _session.undo():
		return
	_win_layer.visible = false
	_board.show_state(_definition, _session.state)
	_refresh_status()

func _on_restart() -> void:
	if _session == null:
		return
	_session.restart()
	_win_layer.visible = false
	_elapsed = 0.0
	_timing = false
	_board.show_state(_definition, _session.state)
	_refresh_status()

func _on_pick(index: int) -> void:
	_load(index)

func _on_prev() -> void:
	if _index > 0:
		_load(_index - 1)

func _on_skip() -> void:
	if _index + 1 < _paths.size():
		_load(_index + 1)

func _on_next() -> void:
	if _index + 1 < _paths.size():
		_load(_index + 1)
	else:
		_on_menu()

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
