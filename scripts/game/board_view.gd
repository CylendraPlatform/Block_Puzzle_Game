class_name BoardView
extends Control
## Renders a Level and handles touch/drag to slide blocks. Owns the mutable
## working copy of blocks so the controller can snapshot/restore for undo.
## Blocks ease smoothly toward their grid position for a polished settle feel.

signal move_made(prev: Array)   ## carries the pre-move snapshot for undo
signal block_exited(id: String)
signal won
signal grabbed
signal bumped

const COLORS := Style.BLOCK
const BG := Style.BOARD
const GRID_LINE := Color("#3a4166")
const WALL := Style.WALL
const EASE_SPEED := Style.EASE_SPEED
var _t := 0.0   ## time accumulator for idle gate pulse

var level: Level
var blocks: Array[Dictionary] = []

var _cell := 0.0
var _origin := Vector2.ZERO
var _visual := {}          ## id -> Vector2 (eased pixel top-left of origin cell)

# Drag state
var _sel_id := ""
var _grab_cell := Vector2i.ZERO
var _sel_start := Vector2i.ZERO
var _axis := -1            ## -1 unset, 0 = x, 1 = y
var _pending_exit := false
var _bumped := false
var _pre: Array[Dictionary] = []
var _exiting := {}         ## id -> scale (pop animation)

func load_level(lv: Level) -> void:
	level = lv
	blocks = lv.clone_blocks()
	_clear_selection()
	_exiting.clear()
	_visual.clear()
	queue_redraw()

func snapshot() -> Array[Dictionary]:
	return _copy(blocks)

func restore(snap: Array) -> void:
	blocks = _copy(snap)
	_visual.clear()
	_clear_selection()
	queue_redraw()

func _copy(src: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in src:
		var cells: Array[Vector2i] = []
		for c in b["cells"]:
			cells.append(c)
		out.append({"id": b["id"], "color": b["color"], "cells": cells, "pos": b["pos"]})
	return out

func _clear_selection() -> void:
	_sel_id = ""
	_axis = -1
	_pending_exit = false
	_bumped = false

# ---------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------
func _recompute_layout() -> void:
	if level == null:
		return
	# Fill the available area tightly (small margin for gate bars), fewer dead pixels.
	_cell = minf(size.x / (level.cols + 0.7), size.y / (level.rows + 0.7))
	var bw := _cell * level.cols
	var bh := _cell * level.rows
	_origin = Vector2((size.x - bw) * 0.5, (size.y - bh) * 0.5)

## Draw a rounded rect (optionally bordered / shadowed) via a StyleBoxFlat.
func _rounded(rect: Rect2, color: Color, radius: float, border_col := Color(0, 0, 0, 0), border_w := 0.0, shadow := 0.0, shadow_a := 0.5) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	if border_w > 0.0:
		sb.set_border_width_all(int(border_w))
		sb.border_color = border_col
	if shadow > 0.0:
		var sc := Style.SHADOW
		sc.a = shadow_a
		sb.shadow_color = sc
		sb.shadow_size = int(shadow)
		sb.shadow_offset = Vector2(0, shadow * 0.5)
	draw_style_box(sb, rect)

func _cell_from_px(px: Vector2) -> Vector2i:
	var local := (px - _origin) / _cell
	return Vector2i(floori(local.x), floori(local.y))

func _px_from_cell(cell: Vector2i) -> Vector2:
	return _origin + Vector2(cell.x, cell.y) * _cell

func _block_at(cell: Vector2i) -> String:
	for b in blocks:
		for c in b["cells"]:
			if c + b["pos"] == cell:
				return b["id"]
	return ""

func _get_block(id: String) -> Dictionary:
	for b in blocks:
		if b["id"] == id:
			return b
	return {}

# ---------------------------------------------------------------------------
# Easing
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if level == null:
		return
	_t += delta
	_recompute_layout()
	var moving := false
	for b in blocks:
		var id: String = b["id"]
		var target := _px_from_cell(b["pos"])
		if not _visual.has(id):
			_visual[id] = target
		else:
			var cur: Vector2 = _visual[id]
			if cur.distance_to(target) > 0.5:
				_visual[id] = cur.lerp(target, minf(1.0, delta * EASE_SPEED))
				moving = true
			else:
				_visual[id] = target
	# Always redraw so gates pulse gently; cheap for a small board.
	queue_redraw()

# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------
func _draw() -> void:
	if level == null:
		return
	_recompute_layout()
	var bw := _cell * level.cols
	var bh := _cell * level.rows
	# Board tray: rounded panel with soft drop shadow + subtle inset cells.
	var tray := Rect2(_origin - Vector2(_cell * 0.12, _cell * 0.12), Vector2(bw + _cell * 0.24, bh + _cell * 0.24))
	_rounded(tray, BG, _cell * 0.22, Color(0, 0, 0, 0), 0.0, _cell * 0.18, 0.55)
	for y in range(level.rows):
		for x in range(level.cols):
			var cr := Rect2(_px_from_cell(Vector2i(x, y)) + Vector2(_cell, _cell) * 0.06, Vector2(_cell, _cell) * 0.88)
			_rounded(cr, Style.CELL, _cell * 0.14)
	for w in level.walls:
		var wr := Rect2(_px_from_cell(w) + Vector2(_cell, _cell) * 0.04, Vector2(_cell, _cell) * 0.92)
		_rounded(wr, WALL, _cell * 0.16, Color(0, 0, 0, 0.35), 2.0)
	for g in level.gates:
		_draw_gate(g)
	for b in blocks:
		_draw_block(b)

func _draw_gate(g: Dictionary) -> void:
	var col: Color = COLORS.get(g["color"], Color.WHITE)
	var thick := _cell * 0.30
	var gap := _cell * 0.10
	var lo: int = g["lo"]
	var hi: int = g["hi"]
	var side: String = g["side"]
	var span := (hi - lo + 1) * _cell
	var r: Rect2
	match side:
		"left":
			r = Rect2(_origin.x - thick - gap, _origin.y + lo * _cell + gap, thick, span - gap * 2.0)
		"right":
			r = Rect2(_origin.x + level.cols * _cell + gap, _origin.y + lo * _cell + gap, thick, span - gap * 2.0)
		"top":
			r = Rect2(_origin.x + lo * _cell + gap, _origin.y - thick - gap, span - gap * 2.0, thick)
		"bottom":
			r = Rect2(_origin.x + lo * _cell + gap, _origin.y + level.rows * _cell + gap, span - gap * 2.0, thick)
	# Idle glow pulse.
	var pulse := 0.55 + 0.45 * (sin(_t * TAU / Style.GATE_PULSE) * 0.5 + 0.5)
	var glow := col
	glow.a = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(thick * 0.5))
	sb.border_color = col.lightened(0.35)
	sb.set_border_width_all(2)
	var gc := col
	gc.a = 0.6 * pulse
	sb.shadow_color = gc
	sb.shadow_size = int(_cell * 0.22 * pulse)
	draw_style_box(sb, r)

func _draw_block(b: Dictionary) -> void:
	var id: String = b["id"]
	var col: Color = COLORS.get(b["color"], Color.WHITE)
	if id == _sel_id:
		col = col.lightened(0.12)
	var scale := 1.0
	if _exiting.has(id):
		scale = _exiting[id]
	var base: Vector2 = _visual.get(id, _px_from_cell(b["pos"]))
	var pad := _cell * Style.CELL_PAD
	var radius := _cell * 0.20
	var selected := id == _sel_id
	for c in b["cells"]:
		var cell_tl := base + Vector2(c.x, c.y) * _cell
		var centre := cell_tl + Vector2(_cell, _cell) * 0.5
		var s := Vector2(_cell - pad * 2.0, _cell - pad * 2.0) * scale
		var rect := Rect2(centre - s * 0.5, s)
		# contact shadow + rounded body + dark bevel border
		var shadow := _cell * (0.14 if selected else 0.10)
		_rounded(rect, col, radius, col.darkened(0.32), 2.0, shadow, 0.5)
		# top highlight (directional light) — a lighter rounded band in the upper area
		var hl := col.lightened(0.30 if selected else 0.22)
		var hrect := Rect2(rect.position + Vector2(s.x * 0.12, s.y * 0.10), Vector2(s.x * 0.76, s.y * 0.40))
		_rounded(hrect, hl, radius * 0.7)

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _gui_input(event: InputEvent) -> void:
	if level == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_update_drag(event.position)
	elif event is InputEventScreenDrag:
		_update_drag(event.position)

func _begin_drag(px: Vector2) -> void:
	var cell := _cell_from_px(px)
	var id := _block_at(cell)
	if id == "":
		return
	_sel_id = id
	_grab_cell = cell
	_sel_start = _get_block(id)["pos"]
	_axis = -1
	_pending_exit = false
	_bumped = false
	_pre = snapshot()
	grabbed.emit()
	queue_redraw()

func _update_drag(px: Vector2) -> void:
	if _sel_id == "":
		return
	var cell := _cell_from_px(px)
	var d := cell - _grab_cell
	if _axis == -1:
		if abs(d.x) == 0 and abs(d.y) == 0:
			return
		_axis = 0 if abs(d.x) >= abs(d.y) else 1
	var amount: int = d.x if _axis == 0 else d.y
	var dir := ""
	if _axis == 0:
		dir = "right" if amount > 0 else "left"
	else:
		dir = "down" if amount > 0 else "up"
	var block := _get_block(_sel_id)
	var probe := {"id": block["id"], "color": block["color"], "cells": block["cells"], "pos": _sel_start}
	var r := Rules.slide_result(level, blocks, probe, dir, abs(amount))
	block["pos"] = r["pos"]
	_pending_exit = r["exit"]
	if amount != 0 and int(r["steps"]) == 0 and not r["exit"] and not _bumped:
		_bumped = true
		bumped.emit()
	queue_redraw()

func _end_drag() -> void:
	if _sel_id == "":
		return
	var id := _sel_id
	var start := _sel_start
	var block := _get_block(id)
	var moved: bool = block["pos"] != start
	if _pending_exit:
		emit_signal("move_made", _pre)
		_animate_exit(id)
	elif moved:
		emit_signal("move_made", _pre)
	_clear_selection()
	queue_redraw()

func _animate_exit(id: String) -> void:
	_exiting[id] = 1.0
	var tw := create_tween()
	tw.tween_method(func(v: float): _exiting[id] = v; queue_redraw(), 1.0, 0.0, 0.18)
	tw.tween_callback(func(): _remove_block(id))

func _remove_block(id: String) -> void:
	for i in blocks.size():
		if blocks[i]["id"] == id:
			blocks.remove_at(i)
			break
	_exiting.erase(id)
	_visual.erase(id)
	emit_signal("block_exited", id)
	queue_redraw()
	if Rules.is_won(blocks):
		emit_signal("won")
