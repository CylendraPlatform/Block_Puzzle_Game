extends SceneTree
## Gate visual design mockups for owner review (PR #26 follow-up). Test-only: draws through a
## subclass of BoardViewV2 that overrides _draw_gate, so no shipped code changes. Every style
## marks exactly the logical exit range lo..hi (never narrower) and shows every colour on an
## edge shared by two gates.
## Writes build/qa/gate_mockups/<style>__<board>.png (desktop render, M31 canvas width).
##   godot --path . --script res://test/mockup_gates.gd

const STYLES := ["current", "A_recessed_doorway", "B_cell_doors", "C_rail_and_badge"]
const VIEW := Vector2i(720, 760)

## Synthetic legacy-format boards (design only; Classic has no short or medium gates) plus
## real Classic levels. Synthetic boards load through LevelLoader like any v1 level.
func _boards() -> Array:
	var short := _legacy("Short gates (1 cell)", [
		{"color": "red", "side": "left", "lo": 2, "hi": 2}, {"color": "blue", "side": "top", "lo": 4, "hi": 4},
		{"color": "green", "side": "right", "lo": 1, "hi": 1}, {"color": "yellow", "side": "bottom", "lo": 0, "hi": 0}])
	var medium := _legacy("Medium gates (3 of 6 cells)", [
		{"color": "red", "side": "left", "lo": 1, "hi": 3}, {"color": "blue", "side": "top", "lo": 2, "hi": 4},
		{"color": "green", "side": "right", "lo": 3, "hi": 5}, {"color": "yellow", "side": "bottom", "lo": 0, "hi": 2}])
	return [
		{"key": "1_short", "title": "Short (synthetic)", "raw": short},
		{"key": "2_medium", "title": "Medium (synthetic)", "raw": medium},
		{"key": "3_full_L35", "title": "Full, 4 sides (Level 35)", "raw": _level(35)},
		{"key": "4_full_L54", "title": "Full, 3 sides (Level 54)", "raw": _level(54)},
		{"key": "5_shared_L06", "title": "Two colours, one edge (Level 6)", "raw": _level(6)},
	]

func _legacy(name: String, gates: Array) -> Dictionary:
	return {"id": 900, "name": name, "cols": 6, "rows": 6, "par": 1, "walls": [[3, 3]], "gates": gates,
		"blocks": [
			{"id": "r", "color": "red", "pos": [1, 2], "cells": [[0, 0]]},
			{"id": "b", "color": "blue", "pos": [4, 1], "cells": [[0, 0], [0, 1]]},
			{"id": "g", "color": "green", "pos": [2, 4], "cells": [[0, 0], [1, 0]]},
			{"id": "y", "color": "yellow", "pos": [0, 0], "cells": [[0, 0]]}]}

func _level(n: int) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%03d.json" % n))

class MockView extends BoardViewV2:
	var style := "current"

	func _draw_gate(gate: Dictionary, cols: int, rows: int) -> void:
		if style == "current":
			super._draw_gate(gate, cols, rows)
			return
		var side := str(gate.get("side", ""))
		var lo := int(gate.get("lo", 0))
		var hi := int(gate.get("hi", lo))
		var color := TD35Theme.piece_color(_accept(gate))
		# Gates on the same edge whose ranges overlap share the depth: one band each.
		var mates: Array = []
		for other in definition.get("gates", []):
			if str(other.get("side", "")) == side and int(other.get("lo", 0)) <= hi and lo <= int(other.get("hi", 0)):
				mates.append(other)
		var band := mates.find(gate)
		var bands := mates.size()
		var depth := _cell * FRAME_RATIO * GATE_DEPTH
		var range_rect := _range_rect(side, lo, hi, cols, rows, depth)
		match style:
			"A_recessed_doorway":
				_style_a(side, range_rect, color, band, bands, lo, hi)
			"B_cell_doors":
				_style_b(side, range_rect, color, band, bands, lo, hi)
			"C_rail_and_badge":
				_style_c(side, range_rect, color, band, bands, lo, hi)

	func _accept(gate: Dictionary) -> String:
		var accepts: Array = gate.get("accept", [])
		return "red" if accepts.is_empty() else str(accepts[0])

	## Exactly lo..hi along the edge (no end pad), from the board edge out `depth`.
	func _range_rect(side: String, lo: int, hi: int, cols: int, rows: int, depth: float) -> Rect2:
		var a := lo * _cell
		var len := (hi - lo + 1) * _cell
		match side:
			"left": return Rect2(_origin.x - depth, _origin.y + a, depth, len)
			"right": return Rect2(_origin.x + cols * _cell, _origin.y + a, depth, len)
			"top": return Rect2(_origin.x + a, _origin.y - depth, len, depth)
			"bottom": return Rect2(_origin.x + a, _origin.y + rows * _cell, len, depth)
		return Rect2()

	## The k-th of n depth bands of an edge rect (band 0 next to the board).
	func _band(side: String, r: Rect2, k: int, n: int) -> Rect2:
		if n <= 1:
			return r
		match side:
			"left":
				var w := r.size.x / n
				return Rect2(r.end.x - w * (k + 1), r.position.y, w, r.size.y)
			"right":
				var w2 := r.size.x / n
				return Rect2(r.position.x + w2 * k, r.position.y, w2, r.size.y)
			"top":
				var h := r.size.y / n
				return Rect2(r.position.x, r.end.y - h * (k + 1), r.size.x, h)
			_:
				var h2 := r.size.y / n
				return Rect2(r.position.x, r.position.y + h2 * k, r.size.x, h2)

	func _outward(side: String) -> Vector2:
		match side:
			"left": return Vector2.LEFT
			"right": return Vector2.RIGHT
			"top": return Vector2.UP
		return Vector2.DOWN

	func _along(side: String) -> Vector2:
		return Vector2.DOWN if side == "left" or side == "right" else Vector2.RIGHT

	func _cells_in(side: String, r: Rect2, lo: int, hi: int) -> Array:
		var out: Array = []
		var axis := _along(side)
		for i in range(lo, hi + 1):
			var start := r.position + axis * float(i - lo) * _cell
			var size := Vector2(_cell, r.size.y) if axis == Vector2.RIGHT else Vector2(r.size.x, _cell)
			out.append(Rect2(start, size))
		return out

	func _arrow(center: Vector2, out: Vector2, s: float, col: Color) -> void:
		var side_v := Vector2(-out.y, out.x)
		draw_colored_polygon(PackedVector2Array([center + out * s * 0.55, center - out * s * 0.35 + side_v * s * 0.5, center - out * s * 0.35 - side_v * s * 0.5]), col)

	## A: one recessed doorway over the whole range: dark cut-out, colour fill, raised posts
	## just outside both ends, outward arrow per cell.
	func _style_a(side: String, r: Rect2, color: Color, k: int, n: int, lo: int, hi: int) -> void:
		if k == 0:
			_round(r, TD35Theme.SHADOW, int(clampf(_cell * 0.06, 2.0, 6.0)))
			var post := maxf(4.0, _cell * 0.1)
			var axis := _along(side)
			var cross := Vector2(post, r.size.y) if axis == Vector2.RIGHT else Vector2(r.size.x, post)
			var p0 := r.position - axis * post
			var p1 := r.position + axis * ((hi - lo + 1) * _cell)
			_round(Rect2(p0, cross), TD35Theme.CANVAS, 2)
			_round(Rect2(p1, cross), TD35Theme.CANVAS, 2)
		var inner := _band(side, r, k, n).grow(-maxf(1.5, _cell * 0.025))
		_round(inner, color, int(clampf(_cell * 0.05, 2.0, 5.0)))
		if k == n - 1:
			for cell in _cells_in(side, r, lo, hi):
				_arrow((cell as Rect2).get_center(), _outward(side), minf(r.size.x, r.size.y) * 0.7, Color(1, 1, 1, 0.9))

	## B: one doorway per cell in the range, on a thin dark rail; each door carries an arrow.
	func _style_b(side: String, r: Rect2, color: Color, k: int, n: int, lo: int, hi: int) -> void:
		if k == 0:
			_round(r, TD35Theme.SHADOW, 3)
		var gap := _cell * 0.1
		for cell in _cells_in(side, r, lo, hi):
			var door: Rect2 = cell
			if _along(side) == Vector2.RIGHT:
				door = door.grow_individual(-gap, 0, -gap, 0)
			else:
				door = door.grow_individual(0, -gap, 0, -gap)
			_round(_band(side, door, k, n).grow(-1.0), color, int(clampf(_cell * 0.06, 2.0, 6.0)))
			if k == n - 1:
				_arrow(door.get_center(), _outward(side), minf(door.size.x, door.size.y) * 0.7, Color(1, 1, 1, 0.9))

	## C: thin colour rail over the exact range with end ticks, plus one compact badge
	## (colour disc with an outward arrow) at the range centre.
	func _style_c(side: String, r: Rect2, color: Color, k: int, n: int, lo: int, hi: int) -> void:
		var axis := _along(side)
		var outward := _outward(side)
		var depth_len := r.size.x if axis == Vector2.DOWN else r.size.y
		var rail_t := maxf(3.0, depth_len * 0.32)
		var offset := float(k) * (rail_t + 2.0)
		var rail: Rect2
		match side:
			"left": rail = Rect2(r.end.x - rail_t - offset, r.position.y, rail_t, r.size.y)
			"right": rail = Rect2(r.position.x + offset, r.position.y, rail_t, r.size.y)
			"top": rail = Rect2(r.position.x, r.end.y - rail_t - offset, r.size.x, rail_t)
			_: rail = Rect2(r.position.x, r.position.y + offset, r.size.x, rail_t)
		_round(rail, color, 2)
		var thick := maxf(2.0, _cell * 0.04)
		var tick := Vector2(thick, r.size.y) if axis == Vector2.RIGHT else Vector2(r.size.x, thick)
		draw_rect(Rect2(r.position, tick), Color.WHITE)
		draw_rect(Rect2(r.position + axis * ((hi - lo + 1) * _cell - thick), tick), Color.WHITE)
		# Badge stays inside the frame band: diameter about the band width, centred in it.
		var band_w := _cell * FRAME_RATIO
		var radius := band_w * 0.5
		var center := r.get_center() + outward * (band_w - depth_len) * 0.5 + axis * float(k) * radius * 2.4
		draw_circle(center, radius, color)
		draw_arc(center, radius, 0.0, TAU, 24, Color.WHITE, 2.0)
		_arrow(center, outward, radius * 1.1, Color.WHITE)

var _fails := 0

func _initialize() -> void:
	print("== mockup_gates ==")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = VIEW
	DisplayServer.window_set_size(VIEW)
	for _i in 10:
		await process_frame
	var out := ProjectSettings.globalize_path("res://build/qa/gate_mockups")
	DirAccess.make_dir_recursive_absolute(out)
	var bg := ColorRect.new()
	bg.color = TD35Theme.CANVAS
	bg.size = Vector2(VIEW)
	root.add_child(bg)
	var view := MockView.new()
	view.center_vertically = true
	view.position = Vector2(16, 0)
	view.size = Vector2(VIEW.x - 32, VIEW.y)
	root.add_child(view)
	for board in _boards():
		var loaded := LevelLoader.load_definition(board["raw"])
		if not bool(loaded["ok"]):
			print("  FAIL  %s does not load" % board["key"])
			_fails += 1
			continue
		var defn: Dictionary = loaded["definition"]
		for style in STYLES:
			view.style = style
			view.show_state(defn, PuzzleState.from_definition(defn))
			view.queue_redraw()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.save_png(out.path_join("%s__%s.png" % [style, board["key"]]))
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)
