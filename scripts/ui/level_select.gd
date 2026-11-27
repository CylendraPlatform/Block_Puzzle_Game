extends Control
## Level select: grid of levels, locked past the player's unlocked progress.
## Column count follows the safe-area width so cells stay on screen. Pearl theme (TD35Theme);
## earned stars are drawn by a StarRow in each completed cell.

const SEP := 12
const MIN_CELL := 72
## Room under the number for the star row.
const STAR_PAD := 26

var _scroll: ScrollContainer
var _grid: GridContainer
var _boxes := {}

func _ready() -> void:
	_build()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(TD35Theme.make_bg())
	var safe := SafeArea.new()
	add_child(safe)
	var root := UIKit.column(safe)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	var back := UIKit.button("Back", _on_back)
	TD35Theme.style_button(back, false)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size.x = 120
	bar.add_child(back)
	var title := UIKit.wrapping_label("Select Level", 26, TD35Theme.NAVY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bar.add_child(title)
	root.add_child(bar)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.resized.connect(_fit_grid)
	root.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", SEP)
	_grid.add_theme_constant_override("v_separation", SEP)
	_scroll.add_child(_grid)

	# Classic only: Chapter 1 stays hidden until it has content (M1.3-E).
	var v2 := GameRoute.uses_v2()
	var levels := CampaignCatalog.levels(CampaignCatalog.CLASSIC)
	var store: ProgressStore = Progress.get_store() if v2 else null
	var unlocked := store.unlocked(CampaignCatalog.CLASSIC) if v2 else Catalog.load_unlocked()
	var target := GameRoute.game_scene()
	for i in levels.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(MIN_CELL, MIN_CELL)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.text = str(i + 1)
		# v2 reads stars by stable id; the legacy route keeps its index-keyed progress.save.
		var stars := store.stars(CampaignCatalog.CLASSIC, str(levels[i]["id"])) if v2 else Catalog.get_stars(i)
		if i > unlocked:
			b.disabled = true
			_style_cell(b, TD35Theme.FRAME.lerp(TD35Theme.CANVAS, 0.55), 0)
			b.add_theme_color_override("font_disabled_color", TD35Theme.FRAME.lerp(TD35Theme.CANVAS, 0.15))
		elif i == unlocked:
			_style_cell(b, TD35Theme.CONFIRM, 0)
		else:
			_style_cell(b, TD35Theme.FRAME, STAR_PAD if stars > 0 else 0)
			if stars > 0:
				var row := StarRow.new()
				row.earned = stars
				row.anchor_left = 0.12
				row.anchor_right = 0.88
				row.anchor_top = 0.64
				row.anchor_bottom = 0.86
				b.add_child(row)
		if i <= unlocked:
			var idx := i
			b.pressed.connect(func() -> void:
				if Audio:
					Audio.sfx("tap")
				Settings.selected_level = idx
				Settings.custom_level = null
				GameRoute.go(get_tree(), target))
		_grid.add_child(b)
	_fit_grid()

## Fill, text and bottom padding for one cell state. Boxes are owned here (not the shared
## TD35Theme cache) because the star padding differs per cell.
func _style_cell(b: Button, fill: Color, bottom_pad: int) -> void:
	b.add_theme_color_override("font_color", TD35Theme.CANVAS_HIGH)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var shade := fill
		if state == "hover":
			shade = fill.lightened(0.06)
		elif state == "pressed":
			shade = fill.darkened(0.12)
		b.add_theme_stylebox_override(state, _cell_box(shade, bottom_pad))

func _cell_box(color: Color, bottom_pad: int) -> StyleBoxFlat:
	var key := "%s|%d" % [color.to_html(true), bottom_pad]
	if not _boxes.has(key):
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(18)
		box.content_margin_left = 6
		box.content_margin_right = 6
		box.content_margin_top = 6
		box.content_margin_bottom = 6 + bottom_pad
		_boxes[key] = box
	return _boxes[key]

func _fit_grid() -> void:
	if _scroll == null or _grid == null:
		return
	# Leave room for the vertical scrollbar so the last column is not drawn under it.
	var width := int(_scroll.size.x - _scroll.get_v_scroll_bar().get_combined_minimum_size().x - 4.0)
	if width < 1:
		return
	var min_cell := UIKit.touch_size(MIN_CELL)
	var cols := 1
	var cell := width
	for candidate_cols in range(6, 0, -1):
		var gaps := SEP * (candidate_cols - 1)
		var candidate := int((width - gaps) / float(candidate_cols))
		if candidate >= min_cell:
			cols = candidate_cols
			cell = candidate
			break
	_grid.columns = cols
	for child in _grid.get_children():
		var button := child as Button
		if button:
			button.custom_minimum_size = Vector2(cell, cell)

func _on_back() -> void:
	if Audio:
		Audio.sfx("tap")
	GameRoute.go(get_tree(), GameRoute.MENU_SCENE)
