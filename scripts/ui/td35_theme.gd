class_name TD35Theme
extends RefCounted
## Presentation tokens for the premium playful pilot and menu.
## Logical puzzle colors stay red, blue, green, yellow, orange, purple.

const CANVAS := Color("#FFF3E5")
const CANVAS_HIGH := Color("#FFF9F1")
const NAVY := Color("#19345B")
const FRAME := Color("#324B78")
const BASE := Color("#263B62")
const CELL := Color("#38517B")
const WALL := Color("#152848")
const CONFIRM := Color("#31C548")
const SHADOW := Color("#1C2540")
const PIECE := {
	"red": Color("#FF6178"),
	"blue": Color("#24BBF2"),
	"green": Color("#88D83A"),
	"yellow": Color("#FFD143"),
	"orange": Color("#FFA83A"),
	"purple": Color("#A95CF5"),
}

static var _boxes := {}

static func piece_color(name: String) -> Color:
	return PIECE.get(name, Color.WHITE)

static func make_bg() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, CANVAS_HIGH)
	gradient.set_color(1, CANVAS)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

static func style_button(button: Button, primary: bool) -> void:
	var fill := CONFIRM if primary else FRAME
	var down := fill.darkened(0.12)
	button.add_theme_color_override("font_color", Color.WHITE if primary else CANVAS_HIGH)
	button.add_theme_color_override("font_hover_color", Color.WHITE if primary else CANVAS_HIGH)
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_stylebox_override("normal", _box(fill, 16))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.06), 16))
	button.add_theme_stylebox_override("pressed", _box(down, 16))
	button.add_theme_stylebox_override("disabled", _box(fill.darkened(0.3), 16))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

static func style_compact(button: Button) -> void:
	button.add_theme_color_override("font_color", CANVAS_HIGH)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size = Vector2(48, 48)
	button.add_theme_stylebox_override("normal", _box(FRAME, 14))
	button.add_theme_stylebox_override("hover", _box(FRAME.lightened(0.08), 14))
	button.add_theme_stylebox_override("pressed", _box(NAVY, 14))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

static func card_box() -> StyleBoxFlat:
	return _box(CANVAS_HIGH, 22)

static func round_box(color: Color, radius: int) -> StyleBoxFlat:
	return _box(color, radius)

static func _box(color: Color, radius: int) -> StyleBoxFlat:
	var key := "%s|%d" % [color.to_html(true), radius]
	if _boxes.has(key):
		return _boxes[key]
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	_boxes[key] = box
	return box
