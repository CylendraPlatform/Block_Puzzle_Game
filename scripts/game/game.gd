extends Control
## Top-level game controller: level list, HUD, undo/restart, win flow, progress.

const LEVELS_DIR := "res://levels"
const SAVE_PATH := "user://progress.save"

var _board: BoardView
var _level_label: Label
var _win_panel: Panel
var _levels: Array[String] = []        ## sorted resource paths
var _index := 0
var _undo: Array = []
var _unlocked := 0                      ## highest unlocked index

func _ready() -> void:
	_levels = _scan_levels()
	_unlocked = _load_progress()
	_build_ui()
	_load_index(clampi(_unlocked, 0, max(0, _levels.size() - 1)))

# ---------------------------------------------------------------------------
# Level discovery / persistence
# ---------------------------------------------------------------------------
func _scan_levels() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(LEVELS_DIR)
	if d:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.ends_with(".json"):
				out.append(LEVELS_DIR + "/" + f)
			f = d.get_next()
		d.list_dir_end()
	out.sort()
	if out.is_empty():
		# Fallback: probe numbered files (covers PCK edge cases).
		for i in range(1, 201):
			var p := "%s/level_%03d.json" % [LEVELS_DIR, i]
			if FileAccess.file_exists(p):
				out.append(p)
	return out

func _load_level_res(path: String) -> Level:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return Level.from_dict(data)

func _load_progress() -> int:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY and data.has("unlocked"):
		return int(data["unlocked"])
	return 0

func _save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"unlocked": _unlocked}))

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 72)
	root.add_child(bar)

	var restart := Button.new()
	restart.text = "Restart"
	restart.pressed.connect(_on_restart)
	bar.add_child(restart)

	var undo := Button.new()
	undo.text = "Undo"
	undo.pressed.connect(_on_undo)
	bar.add_child(undo)

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
	_board.won.connect(_on_won)
	root.add_child(_board)

	_win_panel = _build_win_panel()
	add_child(_win_panel)
	_win_panel.visible = false

func _build_win_panel() -> Panel:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 200)
	panel.position = Vector2(-180, -100)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(v)
	var lbl := Label.new()
	lbl.text = "Level Complete!"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 32)
	v.add_child(lbl)
	var next := Button.new()
	next.text = "Next"
	next.pressed.connect(_on_next)
	v.add_child(next)
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
	var lv := _load_level_res(_levels[i])
	if lv == null:
		push_error("failed to load level " + _levels[i])
		return
	_board.load_level(lv)
	_level_label.text = "Level %d  %s" % [lv.id, lv.name]

func _on_move_made(prev: Array) -> void:
	_undo.append(prev)

func _on_undo() -> void:
	if _undo.is_empty():
		return
	var snap: Array = _undo.pop_back()
	_board.restore(snap)

func _on_restart() -> void:
	_load_index(_index)

func _on_won() -> void:
	if _index + 1 > _unlocked:
		_unlocked = _index + 1
		_save_progress()
	_win_panel.visible = true

func _on_next() -> void:
	if _index + 1 < _levels.size():
		_load_index(_index + 1)
	else:
		_win_panel.visible = false
		_level_label.text = "All levels complete!"
