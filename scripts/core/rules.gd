class_name Rules
extends RefCounted
## Pure, deterministic puzzle logic. No engine/scene dependencies.
## Operates on Level data + a mutable Array[Dictionary] of blocks (see Level).

const DIRS := {
	"left": Vector2i(-1, 0),
	"right": Vector2i(1, 0),
	"up": Vector2i(0, -1),
	"down": Vector2i(0, 1),
}
const MAX_SOLVE_STATES := 200000   ## safety cap for the BFS solver

static func dir_vec(dir: String) -> Vector2i:
	return DIRS.get(dir, Vector2i.ZERO)

## Occupancy of walls + every block except `exclude_id`.
static func _occupancy(level: Level, blocks: Array, exclude_id: String) -> Dictionary:
	var occ := {}
	for w in level.walls:
		occ[w] = true
	for b in blocks:
		if b["id"] == exclude_id:
			continue
		for c in b["cells"]:
			occ[c + b["pos"]] = true
	return occ

static func _in_bounds(level: Level, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < level.cols and cell.y < level.rows

static func _side_for_dir(dir: String) -> String:
	match dir:
		"left": return "left"
		"right": return "right"
		"up": return "top"
		"down": return "bottom"
	return ""

## Does any block cell touch the given boundary edge?
static func _leading_at_edge(level: Level, cells: Array[Vector2i], side: String) -> bool:
	for c in cells:
		match side:
			"left":
				if c.x == 0:
					return true
			"right":
				if c.x == level.cols - 1:
					return true
			"top":
				if c.y == 0:
					return true
			"bottom":
				if c.y == level.rows - 1:
					return true
	return false

## True if a matching-color gate on `dir`'s side fully spans the block's
## crossing cells and the block is flush against that edge (ready to exit).
static func _can_exit(level: Level, block: Dictionary, dir: String) -> bool:
	var cells: Array[Vector2i] = Level.block_cells(block)
	var side := _side_for_dir(dir)
	if side == "":
		return false
	if not _leading_at_edge(level, cells, side):
		return false
	var horizontal := (side == "left" or side == "right")
	for g in level.gates:
		if g["side"] != side or g["color"] != block["color"]:
			continue
		var ok := true
		for c in cells:
			var perp: int = c.y if horizontal else c.x
			if perp < int(g["lo"]) or perp > int(g["hi"]):
				ok = false
				break
		if ok:
			return true
	return false

## Slide `block` in `dir` up to `desired` steps. Returns {steps, pos, exit}.
## exit=true means the block passes fully through a matching gate and is removed.
static func slide_result(level: Level, blocks: Array, block: Dictionary, dir: String, desired: int) -> Dictionary:
	var dv := dir_vec(dir)
	var occ := _occupancy(level, blocks, block["id"])
	var pos: Vector2i = block["pos"]
	var steps := 0
	while steps < desired:
		var next_pos := pos + dv
		var free := true
		for c in block["cells"]:
			var cell: Vector2i = c + next_pos
			if not _in_bounds(level, cell) or occ.has(cell):
				free = false
				break
		if free:
			pos = next_pos
			steps += 1
		else:
			var probe := {"id": block["id"], "color": block["color"], "cells": block["cells"], "pos": pos}
			if _can_exit(level, probe, dir):
				return {"steps": steps, "pos": pos, "exit": true}
			break
	return {"steps": steps, "pos": pos, "exit": false}

## Max full steps a block can slide in `dir` without exiting.
static func max_slide(level: Level, blocks: Array, block: Dictionary, dir: String) -> int:
	return int(slide_result(level, blocks, block, dir, 9999)["steps"])

static func is_won(blocks: Array) -> bool:
	return blocks.is_empty()

# ---------------------------------------------------------------------------
# Solver / validator — BFS over block configurations. Used by tests and the
# level editor to guarantee every shipped level is solvable (no softlock-only).
# ---------------------------------------------------------------------------

static func _state_key(blocks: Array) -> String:
	var parts: Array[String] = []
	for b in blocks:
		parts.append("%s:%d,%d" % [b["id"], b["pos"].x, b["pos"].y])
	parts.sort()
	return "|".join(parts)

static func _apply(blocks: Array, idx: int, new_pos: Vector2i, do_exit: bool) -> Array:
	var out: Array = []
	for i in blocks.size():
		if i == idx:
			if do_exit:
				continue
			out.append({"id": blocks[i]["id"], "color": blocks[i]["color"], "cells": blocks[i]["cells"], "pos": new_pos})
		else:
			out.append({"id": blocks[i]["id"], "color": blocks[i]["color"], "cells": blocks[i]["cells"], "pos": blocks[i]["pos"]})
	return out

## Returns {solvable:bool, states:int}. BFS to any all-exited state.
static func solve(level: Level) -> Dictionary:
	var start: Array = level.clone_blocks()
	if start.is_empty():
		return {"solvable": true, "states": 0}
	var seen := {}
	var queue: Array = [start]
	seen[_state_key(start)] = true
	var visited := 0
	while not queue.is_empty():
		visited += 1
		if visited > MAX_SOLVE_STATES:
			return {"solvable": false, "states": visited, "capped": true}
		var cur: Array = queue.pop_front()
		if cur.is_empty():
			return {"solvable": true, "states": visited}
		for idx in cur.size():
			var b: Dictionary = cur[idx]
			for dir in DIRS.keys():
				var r := slide_result(level, cur, b, dir, 9999)
				if r["exit"]:
					var ns := _apply(cur, idx, r["pos"], true)
					if ns.is_empty():
						return {"solvable": true, "states": visited}
					var k := _state_key(ns)
					if not seen.has(k):
						seen[k] = true
						queue.append(ns)
				elif int(r["steps"]) > 0:
					var ns2 := _apply(cur, idx, r["pos"], false)
					var k2 := _state_key(ns2)
					if not seen.has(k2):
						seen[k2] = true
						queue.append(ns2)
	return {"solvable": false, "states": visited}
