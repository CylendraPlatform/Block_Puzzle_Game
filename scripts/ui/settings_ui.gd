extends Control
## Settings screen: toggle SFX, Music, Haptics (persisted via Settings autoload).

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
	root.add_theme_constant_override("separation", 16)
	add_child(root)

	var bar := HBoxContainer.new()
	var back := Button.new()
	back.text = "< Back"
	back.pressed.connect(_on_back)
	bar.add_child(back)
	var title := Label.new()
	title.text = "  Settings"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	bar.add_child(title)
	root.add_child(bar)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	center.add_child(box)

	box.add_child(_toggle("Sound Effects", Settings.sfx, func(v): Settings.set_sfx(v)))
	box.add_child(_toggle("Music", Settings.music, func(v): Settings.set_music(v)))
	box.add_child(_toggle("Haptics", Settings.haptics, func(v): Settings.set_haptics(v)))

func _toggle(label: String, value: bool, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(240, 0)
	l.add_theme_font_size_override("font_size", 24)
	row.add_child(l)
	var cb_btn := CheckButton.new()
	cb_btn.button_pressed = value
	cb_btn.toggled.connect(func(on):
		if Audio: Audio.sfx("tap")
		cb.call(on))
	row.add_child(cb_btn)
	return row

func _on_back() -> void:
	if Audio: Audio.sfx("tap")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
