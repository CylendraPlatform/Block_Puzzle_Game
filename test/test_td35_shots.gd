extends SceneTree
## Desktop captures of the TD-3.5 pilot, menu, and synthetic board sizes.
## Not an Android device test.
##   godot --path . --script res://test/test_td35_shots.gd

var _fails := 0

func _initialize() -> void:
	print("== test_td35_shots ==")
	var out := ProjectSettings.globalize_path("res://build/qa/td35")
	DirAccess.make_dir_recursive_absolute(out)
	print("  DIR  ", out)
	SafeArea.use_simulation = true
	SafeArea.simulate_insets = Vector4.ZERO
	print("  LOAD menu")
	var menu: PackedScene = load("res://scenes/MainMenu.tscn")
	print("  LOADED menu")
	await _scene(menu, out, Vector2i(360, 800), "360x800_menu.png")
	await _scene(menu, out, Vector2i(412, 915), "412x915_menu.png")
	var pilot: PackedScene = load("res://scenes/Pilot.tscn")
	await _pilot(pilot, out, Vector2i(360, 800), 0, "360x800_v2_001.png", false)
	await _pilot(pilot, out, Vector2i(360, 800), 5, "360x800_v2_006.png", false)
	await _pilot(pilot, out, Vector2i(412, 915), 9, "412x915_v2_010.png", false)
	await _pilot(pilot, out, Vector2i(360, 800), 10, "360x800_v2_011.png", false)
	await _pilot(pilot, out, Vector2i(360, 800), 14, "360x800_v2_015.png", true)
	await _board(out, Vector2i(360, 800), 1, 5, "360x800_1x5.png")
	await _board(out, Vector2i(412, 915), 5, 1, "412x915_5x1.png")
	await _board(out, Vector2i(360, 800), 5, 5, "360x800_5x5.png")
	await _board(out, Vector2i(412, 915), 9, 9, "412x915_9x9.png")
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

func _scene(packed: PackedScene, dir: String, view_size: Vector2i, file_name: String) -> void:
	print("  SCENE ", file_name)
	var host := _host(view_size)
	print("  HOST ", file_name)
	var node := packed.instantiate()
	print("  NODE ", file_name)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(node)
	print("  ADDED ", file_name)
	for _i in 6:
		await process_frame
	print("  FRAMED ", file_name)
	RenderingServer.force_draw()
	_save(host, dir, file_name)
	host.queue_free()
	await process_frame

func _pilot(packed: PackedScene, dir: String, view_size: Vector2i, index: int, file_name: String, show_win: bool) -> void:
	var host := _host(view_size)
	var node := packed.instantiate()
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(node)
	for _i in 4:
		await process_frame
	node._load(index)
	if show_win:
		node._win_layer.visible = true
	for _i in 4:
		await process_frame
	RenderingServer.force_draw()
	_save(host, dir, file_name)
	host.queue_free()
	await process_frame

func _board(dir: String, view_size: Vector2i, cols: int, rows: int, file_name: String) -> void:
	var host := _host(view_size)
	var root_ui := Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(root_ui)
	root_ui.add_child(TD35Theme.make_bg())
	var board := BoardViewV2.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(board)
	var definition := _definition(cols, rows)
	board.show_state(definition, PuzzleState.from_definition(definition))
	for _i in 4:
		await process_frame
	RenderingServer.force_draw()
	_save(host, dir, file_name)
	host.queue_free()
	await process_frame

func _definition(cols: int, rows: int) -> Dictionary:
	var pieces: Array = [
		{"id": "red", "color": "red", "cells": [[0, 0], [1, 0], [0, 1]], "pos": [0, 0], "required": true},
		{"id": "blue", "color": "blue", "cells": [[0, 0], [1, 0], [2, 0], [1, 1]], "pos": [mini(2, cols - 3), mini(1, rows - 2)], "required": true},
		{"id": "green", "color": "green", "cells": [[0, 0], [1, 0], [1, 1], [2, 1]], "pos": [maxi(0, cols - 3), maxi(0, rows - 2)], "required": true},
	]
	if cols < 3 or rows < 2:
		pieces = [{"id": "red", "color": "red", "cells": [[0, 0]], "pos": [0, 0], "required": true}]
	var span_limit := rows - 1 if cols >= rows else cols - 1
	return {
		"schema_version": 2,
		"id": "td35-shot",
		"name": "Shot",
		"board": {"cols": cols, "rows": rows, "walls": []},
		"pieces": pieces,
		"gates": [
			{"id": "red_gate", "side": "right" if cols >= rows else "bottom", "lo": 0, "hi": mini(2, span_limit), "accept": ["red"], "initial_state": "open"},
		],
		"goals": {"all_required_pieces_exited": true},
	}

func _host(view_size: Vector2i) -> SubViewport:
	var host := SubViewport.new()
	host.size = view_size
	host.disable_3d = true
	host.transparent_bg = false
	host.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(host)
	return host

func _save(host: SubViewport, dir: String, file_name: String) -> void:
	var tex := host.get_texture()
	if tex == null:
		_fails += 1
		print("  FAIL  no texture ", file_name)
		return
	var image := tex.get_image()
	var path := dir.path_join(file_name)
	if image == null or image.save_png(path) != OK:
		_fails += 1
		print("  FAIL  shot ", file_name)
	elif image.get_width() != host.size.x or image.get_height() != host.size.y:
		_fails += 1
		print("  FAIL  size ", file_name, " ", image.get_size())
	else:
		print("  SHOT  ", path, " ", image.get_size())
