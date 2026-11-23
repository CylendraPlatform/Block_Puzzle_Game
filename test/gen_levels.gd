extends SceneTree
## Procedural generator for 100 original, solver-verified levels with rising
## difficulty. Every emitted level is checked with Rules.solve_min_moves, so
## only solvable puzzles are written. Deterministic (seeded).
##   godot --headless --path . --script res://test/gen_levels.gd

const COLORS := ["red", "blue", "green", "yellow", "orange", "purple"]
const SIDES := ["left", "right", "top", "bottom"]
const SHAPES := [
	[[0, 0]],
	[[0, 0], [1, 0]],
	[[0, 0], [0, 1]],
	[[0, 0], [1, 0], [2, 0]],
	[[0, 0], [0, 1], [0, 2]],
	[[0, 0], [0, 1], [1, 1]],
	[[0, 0], [1, 0], [0, 1], [1, 1]],
]

var _rng := RandomNumberGenerator.new()

func _tier(n: int) -> Dictionary:
	if n <= 10:
		return {"cols": 5, "rows": 5, "blocks": _pick(1, 2), "colors": _pick(1, 2), "walls": 0, "minmoves": 2}
	elif n <= 30:
		return {"cols": _pick(5, 6), "rows": _pick(5, 6), "blocks": _pick(2, 3), "colors": _pick(2, 3), "walls": _pick(0, 1), "minmoves": 3}
	elif n <= 60:
		return {"cols": 6, "rows": 6, "blocks": _pick(3, 4), "colors": _pick(3, 4), "walls": _pick(1, 2), "minmoves": 4}
	elif n <= 85:
		return {"cols": 6, "rows": 6, "blocks": _pick(4, 5), "colors": _pick(3, 4), "walls": _pick(2, 3), "minmoves": 5}
	else:
		return {"cols": _pick(6, 7), "rows": _pick(6, 7), "blocks": 5, "colors": _pick(4, 5), "walls": _pick(3, 4), "minmoves": 5}

func _pick(a: int, b: int) -> int:
	return _rng.randi_range(a, b)

func _shape_extent(cells: Array) -> Vector2i:
	var mx := 0
	var my := 0
	for c in cells:
		mx = max(mx, int(c[0]))
		my = max(my, int(c[1]))
	return Vector2i(mx, my)

func _try_build(p: Dictionary) -> Dictionary:
	var cols: int = p["cols"]
	var rows: int = p["rows"]
	var occ := {}
	var walls: Array = []
	for _i in range(p["walls"]):
		var wx := _rng.randi_range(1, cols - 2)
		var wy := _rng.randi_range(1, rows - 2)
		var cell := Vector2i(wx, wy)
		if not occ.has(cell):
			occ[cell] = true
			walls.append([wx, wy])

	var palette: Array = COLORS.duplicate()
	_shuffle(palette)
	palette = palette.slice(0, p["colors"])

	var blocks: Array = []
	var used_colors := {}
	var tries := 0
	while blocks.size() < p["blocks"] and tries < 60:
		tries += 1
		var shape: Array = SHAPES[_rng.randi_range(0, SHAPES.size() - 1)]
		var ext := _shape_extent(shape)
		if ext.x >= cols or ext.y >= rows:
			continue
		var px := _rng.randi_range(0, cols - 1 - ext.x)
		var py := _rng.randi_range(0, rows - 1 - ext.y)
		var cells_abs := []
		var ok := true
		for c in shape:
			var cell := Vector2i(int(c[0]) + px, int(c[1]) + py)
			if occ.has(cell):
				ok = false
				break
			cells_abs.append(cell)
		if not ok:
			continue
		for cell in cells_abs:
			occ[cell] = true
		var color: String = palette[blocks.size() % palette.size()]
		used_colors[color] = true
		blocks.append({"id": "b%d" % (blocks.size() + 1), "color": color, "cells": shape, "pos": [px, py]})

	if blocks.is_empty():
		return {}

	var gates: Array = []
	var side_pool: Array = SIDES.duplicate()
	_shuffle(side_pool)
	var si := 0
	for color in used_colors.keys():
		var side: String = side_pool[si % side_pool.size()]
		si += 1
		var hi := (rows - 1) if (side == "left" or side == "right") else (cols - 1)
		gates.append({"color": color, "side": side, "lo": 0, "hi": hi})

	return {"cols": cols, "rows": rows, "walls": walls, "blocks": blocks, "gates": gates}

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _to_level(d: Dictionary, n: int) -> Level:
	return Level.from_dict({
		"id": n, "name": "Level %d" % n,
		"cols": d["cols"], "rows": d["rows"],
		"walls": d["walls"], "blocks": d["blocks"], "gates": d["gates"],
	})

func _initialize() -> void:
	_rng.seed = 987654321
	var summary: Array[String] = []
	for n in range(1, 101):
		var p := _tier(n)
		var best := {}
		var best_moves := -1
		var attempts := 0
		while attempts < 120:
			attempts += 1
			var cand := _try_build(p)
			if cand.is_empty():
				continue
			var lv := _to_level(cand, n)
			var moves := Rules.solve_min_moves(lv, 40000)   # bounded cost; -1 = unsolvable or too complex
			if moves < 0:
				continue
			if moves >= int(p["minmoves"]):
				best = cand
				best_moves = moves
				break
			if moves > best_moves:
				best = cand
				best_moves = moves
		if best.is_empty():
			push_error("could not generate level %d" % n)
			continue
		_write_level(best, n)
		summary.append("L%03d moves=%d blocks=%d colors=%d %dx%d" % [n, best_moves, best["blocks"].size(), best["gates"].size(), best["cols"], best["rows"]])
	for s in summary:
		print(s)
	print("== generated %d levels ==" % summary.size())
	quit(0)

func _write_level(d: Dictionary, n: int) -> void:
	var nm := "Level %d" % n
	if n == 1:
		nm = "First Slide"
	var obj := {
		"id": n, "name": nm,
		"cols": d["cols"], "rows": d["rows"],
		"walls": d["walls"], "blocks": d["blocks"], "gates": d["gates"],
	}
	var path := "res://levels/level_%03d.json" % n
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(obj, "  "))
