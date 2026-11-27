extends Control
## Main menu: Play (resume at saved progress), Levels, Settings.
## The level editor is a development tool and is not shown on player builds.

func _ready() -> void:
	if Audio:
		Audio._apply_music()
	_build()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(TD35Theme.make_bg())
	var safe := SafeArea.new()
	add_child(safe)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	# Dev builds stack four extra QA entries; a tighter gap keeps them inside the bottom
	# safe inset on 360x800. The player-facing menu keeps its 16px spacing.
	column.add_theme_constant_override("separation", 12 if DevAccess.enabled() else 16)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(column)
	center.resized.connect(func() -> void:
		column.custom_minimum_size.x = minf(420.0, maxf(0.0, center.size.x)))

	column.add_child(UIKit.wrapping_label("Block Puzzle", 40, TD35Theme.NAVY))
	column.add_child(UIKit.wrapping_label("Slide & Exit", 18, TD35Theme.FRAME))
	var lvl: int = clampi(_unlocked() + 1, 1, 100)
	column.add_child(UIKit.wrapping_label("Level %d" % lvl, 20, TD35Theme.NAVY))
	var play := UIKit.button("Play", _on_play)
	TD35Theme.style_button(play, true)
	column.add_child(play)
	var levels := UIKit.button("Levels", _on_levels)
	TD35Theme.style_button(levels, false)
	column.add_child(levels)
	if DevAccess.enabled():
		var editor := UIKit.button("Editor", _on_editor)
		TD35Theme.style_button(editor, false)
		column.add_child(editor)
		var pilot := UIKit.button("v2 Pilot", _on_pilot)
		TD35Theme.style_button(pilot, false)
		column.add_child(pilot)
		var td36 := UIKit.button("TD-3.6 QA", _on_td36)
		TD35Theme.style_button(td36, false)
		column.add_child(td36)
		var advanced := UIKit.button("Advanced QA", _on_advanced)
		TD35Theme.style_button(advanced, false)
		column.add_child(advanced)
	var settings := UIKit.button("Settings", _on_settings)
	TD35Theme.style_button(settings, false)
	column.add_child(settings)

## Classic progress from the route the engine flag selects (legacy: progress.save via Catalog,
## already resynchronised by the Progress autoload at startup; v2: ProgressStore).
static func _unlocked() -> int:
	if GameRoute.uses_v2():
		return Progress.get_store().unlocked(CampaignCatalog.CLASSIC)
	return Catalog.load_unlocked()

func _on_play() -> void:
	Settings.selected_level = -1   # resume at saved progress
	Settings.custom_level = null
	GameRoute.go(get_tree(), GameRoute.game_scene())

func _on_levels() -> void:
	GameRoute.go(get_tree(), GameRoute.LEVELS_SCENE)

func _on_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/Editor.tscn")

func _on_pilot() -> void:
	get_tree().change_scene_to_file("res://scenes/Pilot.tscn")

func _on_td36() -> void:
	get_tree().change_scene_to_file("res://scenes/Td36Qa.tscn")

func _on_advanced() -> void:
	get_tree().change_scene_to_file("res://scenes/AdvancedQa.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/SettingsScreen.tscn")
