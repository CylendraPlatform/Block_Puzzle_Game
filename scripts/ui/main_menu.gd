extends Control
## Main menu: Play (resume at saved progress), Levels, Settings.

const BG := Color("#1b1e2b")

func _ready() -> void:
	if Audio:
		Audio._apply_music()
	_build()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Style.make_bg())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 20)
	center.add_child(v)

	var title := Label.new()
	title.text = "BLOCK PUZZLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	v.add_child(title)

	v.add_child(_btn("Play", _on_play))
	v.add_child(_btn("Levels", _on_levels))
	v.add_child(_btn("Editor", _on_editor))
	v.add_child(_btn("Settings", _on_settings))

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 64)
	b.pressed.connect(func():
		if Audio: Audio.sfx("tap")
		cb.call())
	return b

func _on_play() -> void:
	Settings.selected_level = -1   # resume at saved progress
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_levels() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/Editor.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/SettingsScreen.tscn")
