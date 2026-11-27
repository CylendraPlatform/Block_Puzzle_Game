extends SceneTree
## Pearl sign-off renders of the v2 GameScreen (desktop window, not an Android device test).
## Writes build/qa/pearl/<size>_<scene>.png for 360x800, 393x852, 411x891 and the Galaxy M31
## game canvas (720x1560). Progress lives in a throwaway user:// folder that is removed at
## the end, so no player data is read or written.
##   godot --path . --script res://test/shot_pearl.gd

const SIZES := [
	{"name": "360x800", "size": Vector2i(360, 800), "insets": Vector4(0, 96, 0, 48)},
	{"name": "393x852", "size": Vector2i(393, 852), "insets": Vector4(0, 100, 0, 56)},
	{"name": "411x891", "size": Vector2i(411, 891), "insets": Vector4(0, 100, 0, 56)},
	# Galaxy M31: 1080x2340 at 1.5 px per canvas unit; insets estimated from device captures.
	{"name": "m31-720x1560", "size": Vector2i(720, 1560), "insets": Vector4(0, 56, 0, 0)},
]
## [file suffix, Classic index (-1 = editor test of level_006), overlay]
const SCENES := [
	["game_l54", 53, ""],
	["pause_l54", 53, "pause"],
	["win_l01", 0, "win"],
	["game_l35_four_sides", 34, ""],
	["game_l12_tall", 11, ""],
	["editor_test", -1, ""],
]
const PROGRESS_DIR := "user://pearl_qa_progress/"

var _shots := 0
var _fails := 0

func _initialize() -> void:
	print("== shot_pearl ==")
	DevAccess.force = 0
	SafeArea.use_simulation = true
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	var out := ProjectSettings.globalize_path("res://build/qa/pearl")
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.make_dir_recursive_absolute(PROGRESS_DIR)
	root.get_node("Progress").open_store(PROGRESS_DIR)
	var settings := root.get_node("Settings")
	for case in SIZES:
		SafeArea.simulate_insets = case["insets"]
		root.size = case["size"]
		DisplayServer.window_set_size(case["size"])
		for _i in 10:
			await process_frame
			if root.get_visible_rect().size == Vector2(case["size"]):
				break
		if root.get_visible_rect().size != Vector2(case["size"]):
			print("  FAIL  window is %s, wanted %s" % [root.get_visible_rect().size, case["size"]])
			_fails += 1
			continue
		for spec in SCENES:
			var index := int(spec[1])
			if index < 0:
				var custom: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_006.json"))
				custom["id"] = 0
				custom["name"] = "Custom"
				settings.custom_level = custom
			var node: Node = load("res://scenes/GameScreen.tscn").instantiate()
			root.add_child(node)
			for _i in 3:
				await process_frame
			settings.custom_level = null
			if index >= 0:
				node._load_index(index)
			for _i in 3:
				await process_frame
			if spec[2] == "pause":
				node._set_pause(true)
			elif spec[2] == "win":
				node._win_name.text = "Level 1 — First Slide"
				node._win_stars.text = "3 / 3 Stars"
				node._win_layer.visible = true
			await process_frame
			await process_frame
			await _shot(out, "%s_%s.png" % [case["name"], spec[0]])
			node.queue_free()
			await process_frame
	for f in DirAccess.get_files_at(PROGRESS_DIR):
		DirAccess.remove_absolute(PROGRESS_DIR + f)
	DirAccess.remove_absolute(PROGRESS_DIR.trim_suffix("/"))
	print("== screenshots: %d  failures: %d ==" % [_shots, _fails])
	quit(_fails)

func _shot(dir: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		print("  FAIL  empty ", file_name)
		_fails += 1
		return
	var path := dir.path_join(file_name)
	if img.save_png(path) == OK:
		_shots += 1
		print("  SHOT  ", path, " ", img.get_width(), "x", img.get_height())
	else:
		print("  FAIL  could not save ", file_name)
		_fails += 1
