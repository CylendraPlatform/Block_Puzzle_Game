class_name StarRow
extends Control
## Three drawn stars (earned ones filled), so star counts never depend on a font glyph.

const COUNT := 3
const FILLED := Color("#FFD143")
const EMPTY := Color(1, 1, 1, 0.28)

var earned := 0:
	set(value):
		earned = clampi(value, 0, COUNT)
		queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var r := minf(size.y * 0.5, size.x / (COUNT * 2.4))
	if r <= 0.5:
		return
	var step := r * 2.4
	var left := (size.x - step * (COUNT - 1)) * 0.5
	for i in COUNT:
		var center := Vector2(left + step * i, size.y * 0.5)
		draw_colored_polygon(_star(center, r), FILLED if i < earned else EMPTY)

static func _star(center: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 10:
		var radius := r if k % 2 == 0 else r * 0.45
		var angle := -PI / 2.0 + k * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
