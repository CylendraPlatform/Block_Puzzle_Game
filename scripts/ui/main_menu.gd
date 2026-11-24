extends Control
## Main menu: Play (resume at saved progress), Levels, Settings.
## The level editor is a development tool and is not shown on player builds.

func _ready() -> void:
	if Audio:
		Audio._apply_music()
	_build()

func _build() -> void:
	var safe := UIKit.mount(self)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(column)
	center.resized.connect(func() -> void:
		column.custom_minimum_size.x = minf(420.0, maxf(0.0, center.size.x)))

	column.add_child(UIKit.wrapping_label("BLOCK PUZZLE", 48))
	var lvl: int = clampi(Catalog.load_unlocked() + 1, 1, 100)
	column.add_child(UIKit.wrapping_label("Level %d" % lvl, 24, Style.TEXT_DIM))
	column.add_child(UIKit.button("Play", _on_play))
	column.add_child(UIKit.button("Levels", _on_levels))
	if DevAccess.enabled():
		column.add_child(UIKit.button("Editor", _on_editor))
		column.add_child(UIKit.button("v2 Pilot", _on_pilot))
	column.add_child(UIKit.button("Settings", _on_settings))

func _on_play() -> void:
	Settings.selected_level = -1   # resume at saved progress
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_levels() -> void:
	get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")

func _on_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/Editor.tscn")

func _on_pilot() -> void:
	get_tree().change_scene_to_file("res://scenes/Pilot.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/SettingsScreen.tscn")
