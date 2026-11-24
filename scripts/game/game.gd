extends Control
## Game controller: level flow, HUD, pause, undo/restart, win, audio, progress.

var _board: BoardView
var _level_label: Label
var _win_layer: Control
var _pause_layer: Control
var _win_panel: PanelContainer
var _pause_panel: PanelContainer
var _levels: Array[String] = []
var _index := 0
var _undo: Array = []
var _unlocked := 0
var _custom := false
var _undos := 0
var _moves := 0
var _par := 0
var _win_stars: Label
var _win_name: Label
var _level_name := ""

func _ready() -> void:
	_levels = Catalog.list_paths()
	_unlocked = Catalog.load_unlocked()
	_build_ui()
	if Settings and Settings.custom_level != null:
		_custom = true
		var lv := Level.from_dict(Settings.custom_level)
		_board.load_level(lv)
		_level_name = "Custom Level"
		_level_label.text = "  " + _level_name
		return
	var start := _unlocked
	if Settings and Settings.selected_level >= 0:
		start = Settings.selected_level
	_load_index(clampi(start, 0, max(0, _levels.size() - 1)))

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	var safe := UIKit.mount(self)
	var root := UIKit.column(safe)
	root.add_theme_constant_override("separation", 8)

	# Compact HUD. Menu and Restart live in the pause modal so the board
	# keeps the width and nothing sits in the cutout band.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var pause_btn := UIKit.button("Pause", _on_pause)
	pause_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIKit.apply_compact(pause_btn)
	var undo_btn := UIKit.button("Undo", _on_undo)
	undo_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIKit.apply_compact(undo_btn)
	_level_label = Label.new()
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 16)
	_level_label.add_theme_color_override("font_color", Style.TEXT_DIM)
	_level_label.clip_text = true
	_level_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bar.add_child(pause_btn)
	bar.add_child(_level_label)
	bar.add_child(undo_btn)
	root.add_child(bar)

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

	var win := UIKit.modal(safe, "Level Complete!")
	_win_layer = win["layer"]
	_win_panel = win["card"]
	var wv: VBoxContainer = win["box"]
	_win_name = UIKit.wrapping_label("", 20, Style.TEXT_DIM)
	wv.add_child(_win_name)
	wv.move_child(_win_name, 1)
	_win_stars = UIKit.wrapping_label("", 32, Style.BLOCK["yellow"])
	wv.add_child(_win_stars)
	wv.move_child(_win_stars, 2)
	wv.add_child(UIKit.button("Next", _on_next))

	var pause := UIKit.modal(safe, "Paused")
	_pause_layer = pause["layer"]
	_pause_panel = pause["card"]
	var pv: VBoxContainer = pause["box"]
	pv.add_child(UIKit.button("Resume", _on_resume))
	pv.add_child(UIKit.button("Restart", func() -> void:
		_set_pause(false)
		_on_restart()))
	pv.add_child(UIKit.button("Levels", _on_levels))
	pv.add_child(UIKit.button("Main Menu", _on_menu))

func _set_win(on: bool) -> void:
	_win_layer.visible = on

func _set_pause(on: bool) -> void:
	_pause_layer.visible = on

# ---------------------------------------------------------------------------
# Flow
# ---------------------------------------------------------------------------
func _load_index(i: int) -> void:
	if i < 0 or i >= _levels.size():
		return
	_index = i
	_undo.clear()
	_set_win(false)
	_set_pause(false)
	var lv := Catalog.load_level(_levels[i])
	if lv == null:
		push_error("failed to load level " + _levels[i])
		return
	_board.load_level(lv)
	_level_name = "Level %d — %s" % [lv.id, lv.name]
	_level_label.text = "  " + _level_name
	_undos = 0
	_moves = 0
	_par = lv.par
	if Analytics:
		Analytics.log_event("level_start", {"level": lv.id})

func _on_move_made(prev: Array) -> void:
	_undo.append(prev)
	_moves += 1
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
	_undos += 1
	if Analytics:
		Analytics.log_event("undo_used", {"level": _current_level_id()})

func _on_restart() -> void:
	if Analytics:
		Analytics.log_event("level_restart", {"level": _current_level_id()})
	if _custom:
		var lv := Level.from_dict(Settings.custom_level)
		_board.load_level(lv)
		_undos = 0
		_moves = 0
	else:
		_load_index(_index)

func _current_level_id() -> int:
	return 0 if _custom else _index + 1

func _on_pause() -> void:
	_set_pause(true)

func _on_resume() -> void:
	_set_pause(false)

func _on_won() -> void:
	var stars := Catalog.star_rating(_moves, _par)
	if not _custom:
		if _index + 1 > _unlocked:
			_unlocked = _index + 1
			Catalog.save_unlocked(_unlocked)
		Catalog.set_stars(_index, stars)
	_win_name.text = _level_name
	_win_stars.text = "%d / 3 Stars" % stars
	if Audio:
		Audio.sfx("win")
	if Analytics:
		Analytics.log_event("level_complete", {"level": _current_level_id(), "moves": _moves, "stars": stars, "undos": _undos})
	_celebrate()
	_set_win(true)

## Short, controlled celebratory particle burst (auto-frees).
func _celebrate() -> void:
	var p := CPUParticles2D.new()
	p.position = size * 0.5
	p.amount = 28
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 420.0
	p.gravity = Vector2(0, 520)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var grad := Gradient.new()
	grad.set_color(0, Style.BLOCK["yellow"])
	grad.set_color(1, Style.BLOCK["green"])
	p.color_ramp = grad
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)

func _on_next() -> void:
	if _custom:
		Settings.custom_level = null
		get_tree().change_scene_to_file("res://scenes/Editor.tscn")
		return
	if _index + 1 < _levels.size():
		# Interstitial opportunity between levels (no-op unless a provider is set
		# and the player hasn't bought remove-ads).
		if Ads and (_index + 1) % 3 == 0:
			Ads.show_interstitial("level_complete")
		_load_index(_index + 1)
	else:
		_set_win(false)
		_level_label.text = "All levels complete!"

func _on_menu() -> void:
	if Settings:
		Settings.custom_level = null
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_levels() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
