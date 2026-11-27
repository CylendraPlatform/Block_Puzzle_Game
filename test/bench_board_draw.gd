extends SceneTree
## Board redraw CPU cost (desktop, windowed; not a device measurement and not FPS).
## For every Classic level at the Galaxy M31 canvas size, times BoardViewV2._draw() (script
## side: geometry plus draw-command submission) over FRAMES redraws, and separately times the
## gloss inset (Geometry2D.offset_polygon on each piece's body polygon) in isolation.
##   godot --path . --script res://test/bench_board_draw.gd

const VIEW_SIZE := Vector2(688, 1380)
const FRAMES := 60
const INSET_REPEATS := 200

class TimedView extends BoardViewV2:
	var draw_usec := 0
	var draws := 0
	func _draw() -> void:
		var t := Time.get_ticks_usec()
		super._draw()
		draw_usec += Time.get_ticks_usec() - t
		draws += 1

func _initialize() -> void:
	print("== bench_board_draw (%s) ==" % OS.get_processor_name())
	root.size = Vector2i(720, 1560)
	var view := TimedView.new()
	view.center_vertically = true
	view.size = VIEW_SIZE
	root.add_child(view)
	var rows: Array = []
	var files := DirAccess.get_files_at("res://levels")
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/" + f))
		var defn: Dictionary = LevelLoader.load_definition(raw if raw is Dictionary else {})["definition"]
		view.show_state(defn, PuzzleState.from_definition(defn))
		await RenderingServer.frame_post_draw
		view.draw_usec = 0
		view.draws = 0
		for _i in FRAMES:
			view.queue_redraw()
			await RenderingServer.frame_post_draw
		var geometry := PuzzleEngine._geometry(defn)
		var cells := 0
		for id in geometry.keys():
			cells += (geometry[id]["offsets"] as Array).size()
		rows.append({"level": f.get_basename(), "pieces": geometry.size(), "cells": cells,
			"draw_us": float(view.draw_usec) / maxf(1.0, float(view.draws)), "draws": view.draws,
			"inset_us": _inset_cost(view, geometry)})
	view.queue_free()
	_report(rows)
	quit(0)

## Per-redraw cost of the gloss inset alone: offset_polygon for every piece's body polygon.
func _inset_cost(view: BoardViewV2, geometry: Dictionary) -> float:
	var bodies: Array = []
	for id in geometry.keys():
		var body := PackedVector2Array()
		for corner in view._silhouette(geometry[id]["offsets"]):
			body.append(Vector2(corner) * view._cell)
		bodies.append(body)
	var t := Time.get_ticks_usec()
	for _r in INSET_REPEATS:
		for body in bodies:
			Geometry2D.offset_polygon(body, -view._cell * 0.07, Geometry2D.JOIN_MITER)
	return float(Time.get_ticks_usec() - t) / float(INSET_REPEATS)

func _report(rows: Array) -> void:
	var draws: Array = rows.map(func(r): return r["draw_us"])
	var insets: Array = rows.map(func(r): return r["inset_us"])
	draws.sort()
	insets.sort()
	print("levels=%d frames/level=%d" % [rows.size(), FRAMES])
	print("_draw us/redraw: median %.1f  p90 %.1f  max %.1f" % [draws[draws.size() / 2], draws[int(draws.size() * 0.9)], draws[-1]])
	print("gloss inset us/redraw: median %.1f  p90 %.1f  max %.1f" % [insets[insets.size() / 2], insets[int(insets.size() * 0.9)], insets[-1]])
	rows.sort_custom(func(a, b): return a["cells"] > b["cells"])
	print("most complex levels (by piece cells):")
	for r in rows.slice(0, 5):
		print("  %s pieces=%d cells=%d draw=%.1f us inset=%.1f us (%.1f%% of draw)" % [r["level"], r["pieces"], r["cells"], r["draw_us"], r["inset_us"], 100.0 * r["inset_us"] / maxf(0.001, r["draw_us"])])
