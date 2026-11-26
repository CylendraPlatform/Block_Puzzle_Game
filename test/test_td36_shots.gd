extends SceneTree
## Desktop captures of the eight TD-3.6 start positions.
## Not an Android device test.
##   godot --path . --script res://test/test_td36_shots.gd

var _fails := 0

func _initialize() -> void:
	print("== test_td36_shots ==")
	var out := ProjectSettings.globalize_path("res://build/qa/td36")
	DirAccess.make_dir_recursive_absolute(out)
	print("  DIR  ", out)
	var names: Array[String] = []
	var folder := DirAccess.open("res://levels_v2/td36")
	folder.list_dir_begin()
	var file_name := folder.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			names.append(file_name)
		file_name = folder.get_next()
	folder.list_dir_end()
	names.sort()
	for name in names:
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels_v2/td36/" + name))
		var loaded := LevelLoader.load_definition(raw)
		if not bool(loaded["ok"]):
			_fails += 1
			print("  FAIL  schema ", name)
			continue
		var definition: Dictionary = loaded["definition"]
		var shot_name := str(definition["id"]).replace("-", "_") + "_start.png"
		await _board(out, definition, shot_name)
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

func _board(dir: String, definition: Dictionary, file_name: String) -> void:
	var host := SubViewport.new()
	host.size = Vector2i(360, 800)
	host.disable_3d = true
	host.transparent_bg = false
	host.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(host)
	var root_ui := Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(root_ui)
	root_ui.add_child(TD35Theme.make_bg())
	var title := Label.new()
	title.text = "%s — %s" % [definition["id"], definition["name"]]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", TD35Theme.NAVY)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 8
	title.offset_bottom = 40
	root_ui.add_child(title)
	var board := BoardViewV2.new()
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.offset_top = 44
	root_ui.add_child(board)
	board.show_state(definition, PuzzleState.from_definition(definition))
	for _i in 4:
		await process_frame
	RenderingServer.force_draw()
	var tex := host.get_texture()
	if tex == null:
		_fails += 1
		print("  FAIL  no texture ", file_name)
	else:
		var image := tex.get_image()
		var path := dir.path_join(file_name)
		if image == null or image.save_png(path) != OK:
			_fails += 1
			print("  FAIL  shot ", file_name)
		else:
			print("  SHOT  ", path, " ", image.get_size())
	host.queue_free()
	await process_frame
