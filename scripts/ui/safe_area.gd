class_name SafeArea
extends MarginContainer
## Keeps interactive children inside the platform display safe area.
## Insets come from DisplayServer.get_display_safe_area(), converted from window
## pixels into this viewport's canvas coordinates. A zero inset on desktop is
## correct. Tests set use_simulation so a punch-hole or navigation bar can be
## checked without hardcoding one phone model into the shipping layout.

const CONTENT_PAD := 16

## When true, simulate_insets (left, top, right, bottom) replaces the platform.
static var use_simulation := false
static var simulate_insets := Vector4.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_apply)
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply):
		vp.size_changed.connect(_apply)
	_apply()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_apply()

static func insets_from_pixels(window_size: Vector2i, safe: Rect2i, view_size: Vector2) -> Vector4:
	if window_size.x <= 0 or window_size.y <= 0:
		return Vector4.ZERO
	var sx := view_size.x / float(window_size.x)
	var sy := view_size.y / float(window_size.y)
	var left := maxf(0.0, safe.position.x * sx)
	var top := maxf(0.0, safe.position.y * sy)
	var right := maxf(0.0, (float(window_size.x) - safe.end.x) * sx)
	var bottom := maxf(0.0, (float(window_size.y) - safe.end.y) * sy)
	return Vector4(left, top, right, bottom)

static func platform_insets(viewport: Viewport) -> Vector4:
	if viewport == null:
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	return insets_from_pixels(DisplayServer.window_get_size(), safe, viewport.get_visible_rect().size)

func current_insets() -> Vector4:
	if use_simulation:
		return simulate_insets
	return platform_insets(get_viewport())

func content_rect() -> Rect2:
	var r := get_global_rect()
	var left := float(get_theme_constant("margin_left", "MarginContainer"))
	var top := float(get_theme_constant("margin_top", "MarginContainer"))
	var right := float(get_theme_constant("margin_right", "MarginContainer"))
	var bottom := float(get_theme_constant("margin_bottom", "MarginContainer"))
	return Rect2(r.position + Vector2(left, top), r.size - Vector2(left + right, top + bottom))

func _apply() -> void:
	var insets := current_insets()
	add_theme_constant_override("margin_left", int(ceil(insets.x)) + CONTENT_PAD)
	add_theme_constant_override("margin_top", int(ceil(insets.y)) + CONTENT_PAD)
	add_theme_constant_override("margin_right", int(ceil(insets.z)) + CONTENT_PAD)
	add_theme_constant_override("margin_bottom", int(ceil(insets.w)) + CONTENT_PAD)
