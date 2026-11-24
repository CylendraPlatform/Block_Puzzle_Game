class_name UIKit
extends RefCounted
## Shared control builders. Screens stay on the safe-area root; this only
## standardizes touch size, wrapping, and modal placement.

const TOUCH_H := 64
const POPUP_MAX_W := 520.0

static func fill(node: Control) -> Control:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return node

static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(0, TOUCH_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			var audio := tree.root.get_node_or_null("Audio")
			if audio:
				audio.sfx("tap")
		cb.call())
	return b

static func wrapping_label(text: String, size: int, color: Color = Style.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

static func apply_compact(b: Button) -> void:
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", _compact_box(Color("#2f3659")))
	b.add_theme_stylebox_override("hover", _compact_box(Color("#3a4270")))
	b.add_theme_stylebox_override("pressed", _compact_box(Color("#262c4a")))
	b.add_theme_stylebox_override("disabled", _compact_box(Color("#1e2437")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

static func _compact_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.set_corner_radius_all(12)
	return box

static func mount(host: Control) -> SafeArea:
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := Style.make_bg()
	host.add_child(bg)
	var safe := SafeArea.new()
	host.add_child(safe)
	return safe

static func column(parent: Node) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	parent.add_child(box)
	return box

static func modal(safe: Node, title: String) -> Dictionary:
	var layer := Control.new()
	fill(layer)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.visible = false
	safe.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	fill(dim)
	layer.add_child(dim)
	var center := CenterContainer.new()
	fill(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(card)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	box.add_child(wrapping_label(title, 28))
	var fit := func() -> void:
		card.custom_minimum_size.x = minf(POPUP_MAX_W, maxf(160.0, layer.size.x - 32.0))
	layer.resized.connect(fit)
	fit.call()
	return {"layer": layer, "box": box, "card": card}
