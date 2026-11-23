extends Control
## Level editor: place walls/blocks/gates, validate solvability, save, test-play.

const BG := Color("#1b1e2b")
const SAVE_PATH := "user://custom_level.json"
const COLORS := ["red", "blue", "green", "yellow", "orange", "purple"]
const SHAPES := [
	[[0, 0]], [[0, 0], [1, 0]], [[0, 0], [0, 1]],
	[[0, 0], [1, 0], [2, 0]], [[0, 0], [0, 1], [0, 2]],
	[[0, 0], [0, 1], [1, 1]], [[0, 0], [1, 0], [0, 1], [1, 1]],
]
const SHAPE_NAMES := ["1x1", "1x2", "2x1", "1x3", "3x1", "L", "2x2"]

var _st := {"cols": 6, "rows": 6, "walls": [], "blocks": [], "gates": []}
var _tool := "block"
var _color := "red"
var _shape := 0
var _next_id := 1

var _canvas: EditorCanvas
var _status: Label

func _ready() -> void:
	_build()
	_refresh()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var r1 := HBoxContainer.new()
	r1.add_child(_btn("Back", func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")))
	r1.add_child(_btn("Validate", _on_validate))
	r1.add_child(_btn("Save", _on_save))
	r1.add_child(_btn("Load", _on_load))
	r1.add_child(_btn("Test", _on_test))
	r1.add_child(_btn("Clear", _on_clear))
	root.add_child(r1)

	var r2 := HBoxContainer.new()
	for t in ["block", "wall", "gate", "erase"]:
		var tt: String = t
		r2.add_child(_btn(t.capitalize(), func(): _tool = tt; _refresh()))
	r2.add_child(_btn("Shape", func(): _shape = (_shape + 1) % SHAPES.size(); _refresh()))
	r2.add_child(_btn("Cols-", func(): _resize(-1, 0)))
	r2.add_child(_btn("Cols+", func(): _resize(1, 0)))
	r2.add_child(_btn("Rows-", func(): _resize(0, -1)))
	r2.add_child(_btn("Rows+", func(): _resize(0, 1)))
	root.add_child(r2)

	var r3 := HBoxContainer.new()
	for c in COLORS:
		var cc: String = c
		var b := Button.new()
		b.text = c.substr(0, 1).to_upper()
		b.add_theme_color_override("font_color", EditorCanvas.COLORS[c])
		b.pressed.connect(func(): _color = cc; _refresh())
		r3.add_child(b)
	root.add_child(r3)

	_status = Label.new()
	root.add_child(_status)

	_canvas = EditorCanvas.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.cell_tapped.connect(_on_cell)
	_canvas.edge_tapped.connect(_on_edge)
	root.add_child(_canvas)

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		if Audio: Audio.sfx("tap")
		cb.call())
	return b

func _refresh() -> void:
	_canvas.set_state(_st)
	_status.text = "Tool: %s   Color: %s   Shape: %s   (%dx%d)" % [_tool, _color, SHAPE_NAMES[_shape], _st["cols"], _st["rows"]]

func _block_index_at(cell: Vector2i) -> int:
	for i in _st["blocks"].size():
		var b = _st["blocks"][i]
		var pos := Vector2i(int(b["pos"][0]), int(b["pos"][1]))
		for c in b["cells"]:
			if Vector2i(int(c[0]), int(c[1])) + pos == cell:
				return i
	return -1

func _wall_index_at(cell: Vector2i) -> int:
	for i in _st["walls"].size():
		var w = _st["walls"][i]
		if Vector2i(int(w[0]), int(w[1])) == cell:
			return i
	return -1

func _occupied(cell: Vector2i) -> bool:
	return _block_index_at(cell) >= 0 or _wall_index_at(cell) >= 0

func _on_cell(cell: Vector2i) -> void:
	match _tool:
		"wall":
			var wi := _wall_index_at(cell)
			if wi >= 0:
				_st["walls"].remove_at(wi)
			elif _block_index_at(cell) < 0:
				_st["walls"].append([cell.x, cell.y])
		"block":
			var bi := _block_index_at(cell)
			if bi >= 0:
				_st["blocks"].remove_at(bi)
			else:
				_place_block(cell)
		"erase":
			var ei := _block_index_at(cell)
			if ei >= 0:
				_st["blocks"].remove_at(ei)
			else:
				var wi2 := _wall_index_at(cell)
				if wi2 >= 0:
					_st["walls"].remove_at(wi2)
	_refresh()

func _place_block(cell: Vector2i) -> void:
	var shape: Array = SHAPES[_shape]
	for c in shape:
		var t := Vector2i(int(c[0]), int(c[1])) + cell
		if t.x < 0 or t.y < 0 or t.x >= int(_st["cols"]) or t.y >= int(_st["rows"]) or _occupied(t):
			_status.text = "Block doesn't fit here"
			return
	_st["blocks"].append({"id": "e%d" % _next_id, "color": _color, "cells": shape.duplicate(true), "pos": [cell.x, cell.y]})
	_next_id += 1

func _on_edge(side: String, perp: int) -> void:
	if _tool == "gate":
		for i in _st["gates"].size():
			var g = _st["gates"][i]
			if g["side"] == side and int(g["lo"]) == perp and int(g["hi"]) == perp:
				_st["gates"].remove_at(i)
				_refresh()
				return
		_st["gates"].append({"color": _color, "side": side, "lo": perp, "hi": perp})
	elif _tool == "erase":
		for i in _st["gates"].size():
			var g2 = _st["gates"][i]
			if g2["side"] == side and perp >= int(g2["lo"]) and perp <= int(g2["hi"]):
				_st["gates"].remove_at(i)
				break
	_refresh()

func _resize(dc: int, dr: int) -> void:
	_st["cols"] = clampi(int(_st["cols"]) + dc, 3, 9)
	_st["rows"] = clampi(int(_st["rows"]) + dr, 3, 9)
	_prune()
	_refresh()

func _prune() -> void:
	var cols: int = _st["cols"]
	var rows: int = _st["rows"]
	var nb := []
	for b in _st["blocks"]:
		var pos := Vector2i(int(b["pos"][0]), int(b["pos"][1]))
		var fits := true
		for c in b["cells"]:
			var t := Vector2i(int(c[0]), int(c[1])) + pos
			if t.x >= cols or t.y >= rows:
				fits = false
		if fits:
			nb.append(b)
	_st["blocks"] = nb
	var nw := []
	for w in _st["walls"]:
		if int(w[0]) < cols and int(w[1]) < rows:
			nw.append(w)
	_st["walls"] = nw

func _on_validate() -> void:
	if _st["blocks"].is_empty():
		_status.text = "Add at least one block"
		return
	var lv := Level.from_dict(_st)
	var moves := Rules.solve_min_moves(lv)
	if moves >= 0:
		_status.text = "SOLVABLE  (min moves: %d)" % moves
	else:
		_status.text = "NOT SOLVABLE — adjust blocks/gates"

func _on_save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		var obj := _st.duplicate(true)
		obj["id"] = 0
		obj["name"] = "Custom"
		f.store_string(JSON.stringify(obj, "  "))
		_status.text = "Saved to custom_level.json"

func _on_load() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		_status.text = "No saved level"
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		_st = {
			"cols": int(data.get("cols", 6)), "rows": int(data.get("rows", 6)),
			"walls": data.get("walls", []), "blocks": data.get("blocks", []), "gates": data.get("gates", []),
		}
		_status.text = "Loaded"
		_refresh()

func _on_test() -> void:
	if _st["blocks"].is_empty():
		_status.text = "Add blocks before testing"
		return
	var obj := _st.duplicate(true)
	obj["id"] = 0
	obj["name"] = "Custom"
	Settings.custom_level = obj
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_clear() -> void:
	_st = {"cols": _st["cols"], "rows": _st["rows"], "walls": [], "blocks": [], "gates": []}
	_refresh()
