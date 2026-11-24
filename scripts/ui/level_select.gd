extends Control
## Level select: grid of levels, locked past the player's unlocked progress.

const BG := Color("#1b1e2b")

func _ready() -> void:
	_build()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var bar := HBoxContainer.new()
	var back := Button.new()
	back.text = "< Back"
	back.pressed.connect(_on_back)
	bar.add_child(back)
	var title := Label.new()
	title.text = "  Select Level"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	bar.add_child(title)
	root.add_child(bar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	var paths := Catalog.list_paths()
	var unlocked := Catalog.load_unlocked()
	for i in paths.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(92, 92)
		var stars := Catalog.get_stars(i)
		var num := str(i + 1)
		if i > unlocked:
			b.disabled = true
			b.text = num
		elif stars > 0:
			b.text = "%s\n%s" % [num, "*".repeat(stars) + "-".repeat(3 - stars)]
		else:
			b.text = num
			if i == unlocked:
				b.add_theme_color_override("font_color", Style.BLOCK["yellow"])  # current level
		if i <= unlocked:
			var idx := i
			b.pressed.connect(func():
				if Audio: Audio.sfx("tap")
				Settings.selected_level = idx
				get_tree().change_scene_to_file("res://scenes/Game.tscn"))
		grid.add_child(b)

func _on_back() -> void:
	if Audio: Audio.sfx("tap")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
