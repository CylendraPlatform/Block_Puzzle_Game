extends Control
## Game controller: level flow, HUD, pause, undo/restart, win, audio, progress.

var _board: BoardView
var _level_label: Label
var _win_panel: Panel
var _pause_panel: Panel
var _levels: Array[String] = []
var _index := 0
var _undo: Array = []
var _unlocked := 0
var _custom := false

func _ready() -> void:
	_levels = Catalog.list_paths()
	_unlocked = Catalog.load_unlocked()
	_build_ui()
	if Settings and Settings.custom_level != null:
		_custom = true
		var lv := Level.from_dict(Settings.custom_level)
		_board.load_level(lv)
		_level_label.text = "Custom Level  "
		return
	var start := _unlocked
	if Settings and Settings.selected_level >= 0:
		start = Settings.selected_level
	_load_index(clampi(start, 0, max(0, _levels.size() - 1)))

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#1b1e2b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 72)
	root.add_child(bar)
	bar.add_child(_bar_btn("Menu", _on_menu))
	bar.add_child(_bar_btn("Pause", _on_pause))
	bar.add_child(_bar_btn("Undo", _on_undo))
	bar.add_child(_bar_btn("Restart", _on_restart))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_level_label = Label.new()
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_level_label)

	_board = BoardView.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	_board.move_made.connect(_on_move_made)
	_board.block_exited.connect(_on_exited)
	_board.won.connect(_on_won)
	_board.grabbed.connect(func(): if Audio: Audio.sfx("tap"))
	_board.bumped.connect(func():
		if Audio:
			Audio.sfx("bump")
			Audio.haptic(12))
	root.add_child(_board)

	_win_panel = _popup("Level Complete!", "Next", _on_next)
	add_child(_win_panel)
	_win_panel.visible = false

	_pause_panel = _pause_overlay()
	add_child(_pause_panel)
	_pause_panel.visible = false

func _bar_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		if Audio: Audio.sfx("tap")
		cb.call())
	return b

func _popup(title: String, action_text: String, cb: Callable) -> Panel:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 200)
	panel.position = Vector2(-180, -100)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	panel.add_child(v)
	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 32)
	v.add_child(lbl)
	var btn := Button.new()
	btn.text = action_text
	btn.pressed.connect(func():
		if Audio: Audio.sfx("tap")
		cb.call())
	v.add_child(btn)
	return panel

func _pause_overlay() -> Panel:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 300)
	panel.position = Vector2(-180, -150)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var lbl := Label.new()
	lbl.text = "Paused"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 32)
	v.add_child(lbl)
	v.add_child(_bar_btn("Resume", _on_resume))
	v.add_child(_bar_btn("Restart", func(): _pause_panel.visible = false; _on_restart()))
	v.add_child(_bar_btn("Levels", _on_levels))
	v.add_child(_bar_btn("Main Menu", _on_menu))
	return panel

# ---------------------------------------------------------------------------
# Flow
# ---------------------------------------------------------------------------
func _load_index(i: int) -> void:
	if i < 0 or i >= _levels.size():
		return
	_index = i
	_undo.clear()
	_win_panel.visible = false
	_pause_panel.visible = false
	var lv := Catalog.load_level(_levels[i])
	if lv == null:
		push_error("failed to load level " + _levels[i])
		return
	_board.load_level(lv)
	_level_label.text = "Level %d  %s  " % [lv.id, lv.name]

func _on_move_made(prev: Array) -> void:
	_undo.append(prev)
	if Audio:
		Audio.sfx("slide")
		Audio.haptic(8)

func _on_exited(_id: String) -> void:
	if Audio:
		Audio.sfx("exit")
		Audio.haptic(18)

func _on_undo() -> void:
	if _undo.is_empty():
		return
	_board.restore(_undo.pop_back())

func _on_restart() -> void:
	_load_index(_index)

func _on_pause() -> void:
	_pause_panel.visible = true

func _on_resume() -> void:
	_pause_panel.visible = false

func _on_won() -> void:
	if not _custom and _index + 1 > _unlocked:
		_unlocked = _index + 1
		Catalog.save_unlocked(_unlocked)
	if Audio:
		Audio.sfx("win")
	_win_panel.visible = true

func _on_next() -> void:
	if _custom:
		Settings.custom_level = null
		get_tree().change_scene_to_file("res://scenes/Editor.tscn")
		return
	if _index + 1 < _levels.size():
		_load_index(_index + 1)
	else:
		_win_panel.visible = false
		_level_label.text = "All levels complete!"

func _on_menu() -> void:
	if Settings:
		Settings.custom_level = null
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_levels() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
