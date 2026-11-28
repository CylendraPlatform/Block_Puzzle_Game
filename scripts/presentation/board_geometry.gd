class_name BoardGeometry
extends RefCounted
## Pure board layout shared by BoardViewV2 (drawing and touch input) and, from GP-1 on, by
## the theme skins. No node, rule or save access: given a board size and a view size it
## gives the cell size, the board origin, the frame band and the gate slots, and maps between
## cells and pixels. Every theme uses this one geometry, so layouts never drift between themes.
## (GP-1 step 1, design/gate_proto/GP1_IMPLEMENTATION_PLAN.md.)

## The frame band is this many cells wide on every side of the board.
const FRAME_RATIO := 0.26
## Vertical breathing room kept above and below the frame inside the view.
const FRAME_GAP_Y := 12.0
## A gate slot reaches this fraction of the frame band outwards from the board edge.
const GATE_DEPTH := 0.8

var cols := 1
var rows := 1
var cell := 48.0
var origin := Vector2.ZERO

## Fits the board and its frame into `view_size`: the frame's outer edge spans the view's
## width unless the height is the limit, and it never leaves the view. `board` is the level's
## "board" dictionary (cols, rows); a missing value counts as 1.
static func fit(board: Dictionary, view_size: Vector2, center_vertically: bool) -> BoardGeometry:
	var g := BoardGeometry.new()
	g.refit(board, view_size, center_vertically)
	return g

## Same as fit(), in place: the view calls this on every redraw, so no object is allocated.
func refit(board: Dictionary, view_size: Vector2, center_vertically: bool) -> void:
	cols = int(board.get("cols", 1))
	rows = int(board.get("rows", 1))
	var span := Vector2(cols, rows) + Vector2.ONE * FRAME_RATIO * 2.0
	var avail := Vector2(maxf(1.0, view_size.x), maxf(1.0, view_size.y - FRAME_GAP_Y * 2.0))
	cell = minf(avail.x / span.x, avail.y / span.y)
	var frame := cell * FRAME_RATIO
	var board_size := Vector2(cell * cols, cell * rows)
	var outer_h := board_size.y + frame * 2.0
	var spare_y := maxf(0.0, view_size.y - outer_h)
	var top := spare_y * 0.5 if center_vertically else minf(28.0, spare_y * 0.16)
	origin = Vector2((view_size.x - board_size.x) * 0.5, top + frame)

func frame_band() -> float:
	return cell * FRAME_RATIO

func board_rect() -> Rect2:
	return Rect2(origin, Vector2(cols, rows) * cell)

func frame_rect() -> Rect2:
	return board_rect().grow(frame_band())

## Top-left pixel of a cell.
func cell_px(c: Vector2i) -> Vector2:
	return origin + Vector2(c) * cell

func cell_center(c: Vector2i) -> Vector2:
	return cell_px(c) + Vector2(cell, cell) * 0.5

## The cell under a pixel; points on the frame or outside map off the board.
func cell_at(px: Vector2) -> Vector2i:
	var local := (px - origin) / cell
	return Vector2i(floori(local.x), floori(local.y))

## A gate's slot: along its edge from `lo` to `hi` (inset by a small pad), and from the board
## edge outwards over GATE_DEPTH of the frame band, overlapping the board edge by one pixel so
## no seam shows. Empty for an unknown side. `board_cols` / `board_rows` default to this
## geometry's board.
func gate_slot(gate: Dictionary, board_cols := -1, board_rows := -1) -> Rect2:
	var c := cols if board_cols < 0 else board_cols
	var r := rows if board_rows < 0 else board_rows
	var lo := int(gate.get("lo", 0))
	var hi := int(gate.get("hi", lo))
	var along := float(hi - lo + 1) * cell
	var pad := clampf(cell * 0.08, 2.0, 6.0)
	var depth := frame_band() * GATE_DEPTH
	match str(gate.get("side", "")):
		"left":
			return Rect2(origin.x - depth, origin.y + lo * cell + pad, depth + 1.0, along - pad * 2.0)
		"right":
			return Rect2(origin.x + c * cell - 1.0, origin.y + lo * cell + pad, depth + 1.0, along - pad * 2.0)
		"top":
			return Rect2(origin.x + lo * cell + pad, origin.y - depth, along - pad * 2.0, depth + 1.0)
		"bottom":
			return Rect2(origin.x + lo * cell + pad, origin.y + r * cell - 1.0, along - pad * 2.0, depth + 1.0)
	return Rect2()
