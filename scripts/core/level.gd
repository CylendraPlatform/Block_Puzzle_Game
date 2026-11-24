class_name Level
extends RefCounted
## Pure data model for one puzzle level. Engine-agnostic: no scene/node refs.
## Coordinates: grid cells, origin top-left, +x = right (col), +y = down (row).

const SIDES := ["left", "right", "top", "bottom"]

var id: int = 0
var name: String = ""
var cols: int = 5
var rows: int = 5
var par: int = 0                          ## shortest solution length (for star rating); 0 = unknown
var walls: Array[Vector2i] = []          ## blocked interior cells
var blocks: Array[Dictionary] = []        ## {id:String, color:String, cells:Array[Vector2i], pos:Vector2i}
var gates: Array[Dictionary] = []         ## {color:String, side:String, lo:int, hi:int}

## Build a Level from a plain dictionary (parsed JSON).
static func from_dict(d: Dictionary) -> Level:
	var lv := Level.new()
	lv.id = int(d.get("id", 0))
	lv.name = String(d.get("name", ""))
	lv.cols = int(d.get("cols", 5))
	lv.rows = int(d.get("rows", 5))
	lv.par = int(d.get("par", 0))
	for w in d.get("walls", []):
		lv.walls.append(Vector2i(int(w[0]), int(w[1])))
	for b in d.get("blocks", []):
		var cells: Array[Vector2i] = []
		for c in b.get("cells", [[0, 0]]):
			cells.append(Vector2i(int(c[0]), int(c[1])))
		lv.blocks.append({
			"id": String(b.get("id", "")),
			"color": String(b.get("color", "red")),
			"cells": cells,
			"pos": Vector2i(int(b["pos"][0]), int(b["pos"][1])),
		})
	for g in d.get("gates", []):
		lv.gates.append({
			"color": String(g.get("color", "red")),
			"side": String(g.get("side", "right")),
			"lo": int(g.get("lo", 0)),
			"hi": int(g.get("hi", 0)),
		})
	return lv

## Deep copy of the mutable block list (for undo snapshots / simulation).
func clone_blocks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in blocks:
		var cells: Array[Vector2i] = []
		for c in b["cells"]:
			cells.append(c)
		out.append({"id": b["id"], "color": b["color"], "cells": cells, "pos": b["pos"]})
	return out

## Absolute cells a block occupies given its current pos.
static func block_cells(b: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c in b["cells"]:
		out.append(c + b["pos"])
	return out

func is_valid() -> bool:
	if cols <= 0 or rows <= 0:
		return false
	for s in gates:
		if not SIDES.has(s["side"]):
			return false
	return true
