extends Control
## Level select: grid of levels, locked past the player's unlocked progress.
## Column count follows the safe-area width so cells stay on screen.

const SEP := 12
const MIN_CELL := 72

var _scroll: ScrollContainer
var _grid: GridContainer

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
	var title := UIKit.wrapping_label("Select Level", 26)
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
		UIKit.apply_compact(b)
		b.add_theme_font_size_override("font_size", 18)
		# v2 reads stars by stable id; the legacy route keeps its index-keyed progress.save.
		var stars := store.stars(CampaignCatalog.CLASSIC, str(levels[i]["id"])) if v2 else Catalog.get_stars(i)
		var num := str(i + 1)
		if i > unlocked:
			b.disabled = true
			b.text = num
		elif stars > 0:
			b.text = "%s\n%s" % [num, "*".repeat(stars) + "-".repeat(3 - stars)]
		else:
			b.text = num
			if i == unlocked:
				b.add_theme_color_override("font_color", Style.BLOCK["yellow"])
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

func _fit_grid() -> void:
	if _scroll == null or _grid == null:
		return
	var width := int(_scroll.size.x)
	if width < 1:
		return
	var cols := 1
	var cell := width
	for candidate_cols in range(6, 0, -1):
		var gaps := SEP * (candidate_cols - 1)
		var candidate := int((width - gaps) / float(candidate_cols))
		if candidate >= MIN_CELL:
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
