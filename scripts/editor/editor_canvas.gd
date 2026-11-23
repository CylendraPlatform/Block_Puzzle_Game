class_name EditorCanvas
extends Control
## Renders an editable level `state` dict and reports taps on cells / edges.
## state = {cols, rows, walls:Array, blocks:Array, gates:Array}

signal cell_tapped(cell: Vector2i)
signal edge_tapped(side: String, perp: int)

const COLORS := {
	"red": Color("#ff5d73"), "blue": Color("#5b8cff"), "green": Color("#3dd6a8"),
	"yellow": Color("#ffc857"), "orange": Color("#ff9f45"), "purple": Color("#b980ff"),
}
const BG := Color("#242838")
const GRID_LINE := Color("#2f3449")
const WALL := Color("#11131c")

var state := {"cols": 6, "rows": 6, "walls": [], "blocks": [], "gates": []}
var _cell := 0.0
var _origin := Vector2.ZERO

func set_state(s: Dictionary) -> void:
	state = s
	queue_redraw()

func _layout() -> void:
	var cols: int = state["cols"]
	var rows: int = state["rows"]
	_cell = minf(size.x / (cols + 1.0), size.y / (rows + 1.0))
	_origin = Vector2((size.x - _cell * cols) * 0.5, (size.y - _cell * rows) * 0.5)

func _px(cell: Vector2i) -> Vector2:
	return _origin + Vector2(cell.x, cell.y) * _cell

func _draw() -> void:
	_layout()
	var cols: int = state["cols"]
	var rows: int = state["rows"]
	draw_rect(Rect2(_origin, Vector2(_cell * cols, _cell * rows)), BG, true)
	for x in range(cols + 1):
		var gx := _origin.x + x * _cell
		draw_line(Vector2(gx, _origin.y), Vector2(gx, _origin.y + _cell * rows), GRID_LINE, 1.0)
	for y in range(rows + 1):
		var gy := _origin.y + y * _cell
		draw_line(Vector2(_origin.x, gy), Vector2(_origin.x + _cell * cols, gy), GRID_LINE, 1.0)
	for w in state["walls"]:
		draw_rect(Rect2(_px(Vector2i(int(w[0]), int(w[1]))), Vector2(_cell, _cell)), WALL, true)
	for g in state["gates"]:
		_draw_gate(g)
	for b in state["blocks"]:
		var col: Color = COLORS.get(b["color"], Color.WHITE)
		var pos := Vector2i(int(b["pos"][0]), int(b["pos"][1]))
		for c in b["cells"]:
			var cell := Vector2i(int(c[0]), int(c[1])) + pos
			var r := Rect2(_px(cell) + Vector2(_cell, _cell) * 0.08, Vector2(_cell, _cell) * 0.84)
			draw_rect(r, col, true)
			draw_rect(r, col.darkened(0.25), false, 2.0)

func _draw_gate(g: Dictionary) -> void:
	var col: Color = COLORS.get(g["color"], Color.WHITE)
	var thick := _cell * 0.28
	var lo: int = int(g["lo"])
	var hi: int = int(g["hi"])
	var side: String = g["side"]
	var cols: int = state["cols"]
	var rows: int = state["rows"]
	var r: Rect2
	match side:
		"left": r = Rect2(_origin.x - thick, _origin.y + lo * _cell, thick, (hi - lo + 1) * _cell)
		"right": r = Rect2(_origin.x + cols * _cell, _origin.y + lo * _cell, thick, (hi - lo + 1) * _cell)
		"top": r = Rect2(_origin.x + lo * _cell, _origin.y - thick, (hi - lo + 1) * _cell, thick)
		"bottom": r = Rect2(_origin.x + lo * _cell, _origin.y + rows * _cell, (hi - lo + 1) * _cell, thick)
	draw_rect(r, col, true)

func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	if not pressed:
		return
	var cols: int = state["cols"]
	var rows: int = state["rows"]
	var local := (pos - _origin) / _cell
	var cx := floori(local.x)
	var cy := floori(local.y)
	if cx >= 0 and cx < cols and cy >= 0 and cy < rows:
		cell_tapped.emit(Vector2i(cx, cy))
	elif cx == -1 and cy >= 0 and cy < rows:
		edge_tapped.emit("left", cy)
	elif cx == cols and cy >= 0 and cy < rows:
		edge_tapped.emit("right", cy)
	elif cy == -1 and cx >= 0 and cx < cols:
		edge_tapped.emit("top", cx)
	elif cy == rows and cx >= 0 and cx < cols:
		edge_tapped.emit("bottom", cx)
