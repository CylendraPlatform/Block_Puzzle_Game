class_name BoardView
extends Control
## Renders a Level and handles touch/drag to slide blocks. Owns the mutable
## working copy of blocks so the controller can snapshot/restore for undo.

signal move_made(prev: Array)   ## carries the pre-move snapshot for undo
signal block_exited(id: String)
signal won

const COLORS := {
	"red": Color("#ff5d73"),
	"blue": Color("#5b8cff"),
	"green": Color("#3dd6a8"),
	"yellow": Color("#ffc857"),
	"orange": Color("#ff9f45"),
	"purple": Color("#b980ff"),
}
const BG := Color("#242838")
const GRID_LINE := Color("#2f3449")
const WALL := Color("#11131c")

var level: Level
var blocks: Array[Dictionary] = []

var _cell := 0.0
var _origin := Vector2.ZERO

# Drag state
var _sel_id := ""
var _grab_cell := Vector2i.ZERO
var _sel_start := Vector2i.ZERO
var _axis := -1            ## -1 unset, 0 = x, 1 = y
var _pending_exit := false
var _pre: Array[Dictionary] = []   ## snapshot captured at grab, for undo
var _exiting := {}         ## id -> scale (pop animation)

func load_level(lv: Level) -> void:
	level = lv
	blocks = lv.clone_blocks()
	_clear_selection()
	_exiting.clear()
	queue_redraw()

func snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in blocks:
		var cells: Array[Vector2i] = []
		for c in b["cells"]:
			cells.append(c)
		out.append({"id": b["id"], "color": b["color"], "cells": cells, "pos": b["pos"]})
	return out

func restore(snap: Array) -> void:
	var out: Array[Dictionary] = []
	for b in snap:
		var cells: Array[Vector2i] = []
		for c in b["cells"]:
			cells.append(c)
		out.append({"id": b["id"], "color": b["color"], "cells": cells, "pos": b["pos"]})
	blocks = out
	_clear_selection()
	queue_redraw()

func _clear_selection() -> void:
	_sel_id = ""
	_axis = -1
	_pending_exit = false

# ---------------------------------------------------------------------------
# Layout helpers
# ---------------------------------------------------------------------------
func _recompute_layout() -> void:
	if level == null:
		return
	var avail := size
	# reserve ~half a cell on each side for gate bars
	_cell = minf(avail.x / (level.cols + 1.0), avail.y / (level.rows + 1.0))
	var bw := _cell * level.cols
	var bh := _cell * level.rows
	_origin = Vector2((size.x - bw) * 0.5, (size.y - bh) * 0.5)

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
# Drawing
# ---------------------------------------------------------------------------
func _draw() -> void:
	if level == null:
		return
	_recompute_layout()
	var bw := _cell * level.cols
	var bh := _cell * level.rows
	draw_rect(Rect2(_origin, Vector2(bw, bh)), BG, true)
	for x in range(level.cols + 1):
		var gx := _origin.x + x * _cell
		draw_line(Vector2(gx, _origin.y), Vector2(gx, _origin.y + bh), GRID_LINE, 1.0)
	for y in range(level.rows + 1):
		var gy := _origin.y + y * _cell
		draw_line(Vector2(_origin.x, gy), Vector2(_origin.x + bw, gy), GRID_LINE, 1.0)
	for w in level.walls:
		draw_rect(Rect2(_px_from_cell(w), Vector2(_cell, _cell)), WALL, true)
	for g in level.gates:
		_draw_gate(g)
	for b in blocks:
		_draw_block(b)

func _draw_gate(g: Dictionary) -> void:
	var col: Color = COLORS.get(g["color"], Color.WHITE)
	var thick := _cell * 0.28
	var lo: int = g["lo"]
	var hi: int = g["hi"]
	var side: String = g["side"]
	var r: Rect2
	match side:
		"left":
			r = Rect2(_origin.x - thick, _origin.y + lo * _cell, thick, (hi - lo + 1) * _cell)
		"right":
			r = Rect2(_origin.x + level.cols * _cell, _origin.y + lo * _cell, thick, (hi - lo + 1) * _cell)
		"top":
			r = Rect2(_origin.x + lo * _cell, _origin.y - thick, (hi - lo + 1) * _cell, thick)
		"bottom":
			r = Rect2(_origin.x + lo * _cell, _origin.y + level.rows * _cell, (hi - lo + 1) * _cell, thick)
	draw_rect(r, col, true)

func _draw_block(b: Dictionary) -> void:
	var col: Color = COLORS.get(b["color"], Color.WHITE)
	var scale := 1.0
	if _exiting.has(b["id"]):
		scale = _exiting[b["id"]]
	var pad := _cell * 0.08
	for c in b["cells"]:
		var cell: Vector2i = c + b["pos"]
		var s := Vector2(_cell - pad * 2.0, _cell - pad * 2.0) * scale
		var centre := _px_from_cell(cell) + Vector2(_cell, _cell) * 0.5
		var rect := Rect2(centre - s * 0.5, s)
		draw_rect(rect, col, true)
		draw_rect(rect, col.darkened(0.25), false, 2.0)

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
	_pre = snapshot()

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
	emit_signal("block_exited", id)
	queue_redraw()
	if Rules.is_won(blocks):
		emit_signal("won")
