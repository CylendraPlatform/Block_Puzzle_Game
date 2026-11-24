extends Control
## Settings screen: toggle SFX, Music, Haptics (persisted via Settings autoload).

func _ready() -> void:
	_build()

func _build() -> void:
	var root := UIKit.column(UIKit.mount(self))

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	var back := UIKit.button("Back", _on_back)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Vector2(120, UIKit.TOUCH_H)
	bar.add_child(back)
	var title := UIKit.wrapping_label("Settings", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bar.add_child(title)
	root.add_child(bar)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 16)
	scroll.add_child(box)

	box.add_child(_toggle("Sound Effects", Settings.sfx, func(v): Settings.set_sfx(v)))
	box.add_child(_toggle("Music", Settings.music, func(v): Settings.set_music(v)))
	box.add_child(_toggle("Haptics", Settings.haptics, func(v): Settings.set_haptics(v)))
	box.add_child(_toggle("Share Analytics", not Settings.analytics_opt_out, func(v): Settings.set_analytics_opt_out(not v)))
	box.add_child(_shop_row())

func _shop_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 22)
	l.custom_minimum_size = Vector2(0, UIKit.TOUCH_H)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var owned: bool = IAP and IAP.has_entitlement("remove_ads")
	l.text = "Remove Ads"
	row.add_child(l)
	var price := "Owned" if owned else IAP.CATALOG["remove_ads"]["price"]
	var b := UIKit.button(price, func() -> void:
		if IAP:
			IAP.purchase("remove_ads"))
	b.disabled = owned
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.custom_minimum_size = Vector2(120, UIKit.TOUCH_H)
	b.pressed.connect(func() -> void:
		b.text = "Owned"
		b.disabled = true)
	row.add_child(b)
	return row

func _toggle(label: String, value: bool, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0, UIKit.TOUCH_H)
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	var cb_btn := CheckButton.new()
	cb_btn.custom_minimum_size = Vector2(UIKit.TOUCH_H, UIKit.TOUCH_H)
	cb_btn.button_pressed = value
	cb_btn.toggled.connect(func(on):
		if Audio: Audio.sfx("tap")
		cb.call(on))
	row.add_child(cb_btn)
	return row

func _on_back() -> void:
	if Audio: Audio.sfx("tap")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
