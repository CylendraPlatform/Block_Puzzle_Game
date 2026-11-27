extends SceneTree
## Layout regression: safe-area insets and on-screen controls.
## Desktop window renders at the requested sizes. This is not an Android device test.
##   godot --path . --script res://test/test_layout.gd

const SCENES := [
	["menu", "res://scenes/MainMenu.tscn", ""],
	["levels", "res://scenes/LevelSelect.tscn", ""],
	["settings", "res://scenes/SettingsScreen.tscn", ""],
	["game", "res://scenes/Game.tscn", ""],
	["game_pause", "res://scenes/Game.tscn", "pause"],
	["game_win", "res://scenes/Game.tscn", "win"],
	["editor", "res://scenes/Editor.tscn", ""],
	["game_v2", "res://scenes/GameScreen.tscn", ""],
	["game_v2_pause", "res://scenes/GameScreen.tscn", "pause"],
	["game_v2_win", "res://scenes/GameScreen.tscn", "win"],
	["game_v2_win_unsaved", "res://scenes/GameScreen.tscn", "win_unsaved"],
	["game_v2_leave_unsaved", "res://scenes/GameScreen.tscn", "win_leave_unsaved"],
]
## GameScreen reads progress through the Progress autoload; point it at a throwaway folder.
const PROGRESS_DIR := "user://layout_qa_progress/"

var _fails := 0
var _shots := 0

func _ok(c: bool, m: String) -> void:
	if c:
		print("  PASS  ", m)
	else:
		print("  FAIL  ", m)
		_fails += 1

func _initialize() -> void:
	print("== test_layout ==")
	_check_inset_math()
	DevAccess.force = 0
	SafeArea.use_simulation = true
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	var out := ProjectSettings.globalize_path("res://build/qa/layout")
	DirAccess.make_dir_recursive_absolute(out)
	DirAccess.make_dir_recursive_absolute(PROGRESS_DIR)
	root.get_node("Progress").open_store(PROGRESS_DIR)

	var cases := [
		{"name": "360x800", "size": Vector2i(360, 800), "insets": Vector4(0, 96, 0, 48)},
		{"name": "393x852", "size": Vector2i(393, 852), "insets": Vector4(0, 100, 0, 56)},
		{"name": "412x915", "size": Vector2i(412, 915), "insets": Vector4(0, 108, 0, 64)},
		{"name": "360x900-punch", "size": Vector2i(360, 900), "insets": Vector4(0, 128, 0, 48)},
		{"name": "360x800-sides", "size": Vector2i(360, 800), "insets": Vector4(40, 80, 40, 48)},
	]
	for case in cases:
		SafeArea.simulate_insets = case["insets"]
		root.size = case["size"]
		DisplayServer.window_set_size(case["size"])
		for _i in 10:
			await process_frame
			if root.get_visible_rect().size == Vector2(case["size"]):
				break
		var view := root.get_visible_rect().size
		print("-- %s window=%s viewport=%s --" % [case["name"], case["size"], view])
		_ok(view.x <= float(case["size"].x) + 1.0 and view.y <= float(case["size"].y) + 1.0, "%s viewport matches requested size" % case["name"])
		for spec in SCENES:
			var node: Node = load(spec[1]).instantiate()
			root.add_child(node)
			for _i in 5:
				await process_frame
			if spec[2] == "pause":
				node._set_pause(true)
			elif spec[2].begins_with("win"):
				if spec[2].ends_with("unsaved"):
					node._recorded = true
					node._save_status = "failed"
					node._show_save_status()
				if spec[2] == "win_leave_unsaved":
					node._confirm_layer.visible = true
				node._win_name.text = "Level 1 — Layout"
				node._win_stars.text = "2 / 3 Stars"
				if node.has_method("_set_win"):
					node._set_win(true)
				else:
					node._win_layer.visible = true
			await process_frame
			await process_frame
			_check_scene(node, spec[0], case)
			await _shot(out, "%s_%s.png" % [case["name"], spec[0]])
			node.queue_free()
			await process_frame

	DevAccess.force = 1
	SafeArea.simulate_insets = Vector4(0, 96, 0, 48)
	root.size = Vector2i(360, 800)
	var menu: Node = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	for _i in 5:
		await process_frame
	_ok(_button_text(menu, "Editor"), "dev mode shows the Editor entry")
	_ok(_button_text(menu, "TD-3.6 QA"), "dev mode shows the TD-3.6 QA entry")
	_check_scene(menu, "menu_dev", {"name": "360x800-dev", "insets": Vector4(0, 96, 0, 48)})
	await _shot(out, "360x800_menu_dev.png")
	menu.queue_free()

	for f in DirAccess.get_files_at(PROGRESS_DIR):
		DirAccess.remove_absolute(PROGRESS_DIR + f)
	DirAccess.remove_absolute(PROGRESS_DIR.trim_suffix("/"))
	print("== screenshots: %d  failures: %d ==" % [_shots, _fails])
	quit(_fails)

func _check_inset_math() -> void:
	var safe := Rect2i(0, 140, 1080, 2100)
	var insets := SafeArea.insets_from_pixels(Vector2i(1080, 2400), safe, Vector2(720, 1600))
	_ok(is_equal_approx(insets.y, 140.0 * 720.0 / 1080.0), "top cutout inset converts into canvas pixels")
	_ok(is_equal_approx(insets.w, 160.0 * 720.0 / 1080.0), "bottom inset converts into canvas pixels")
	_ok(is_equal_approx(insets.x, 0.0) and is_equal_approx(insets.z, 0.0), "centered punch-hole adds no side inset")

func _check_scene(node: Node, scene_name: String, case: Dictionary) -> void:
	var safe := _find_safe(node)
	var tag := "%s/%s" % [case["name"], scene_name]
	_ok(safe != null, "%s has a safe area" % tag)
	if safe == null:
		return
	var content := safe.content_rect()
	var insets: Vector4 = case["insets"]
	var view := root.get_visible_rect()
	_ok(content.position.y >= insets.y + SafeArea.CONTENT_PAD - 2.0, "%s keeps the top inset" % tag)
	_ok(content.position.x >= insets.x + SafeArea.CONTENT_PAD - 2.0, "%s keeps the left inset" % tag)
	_ok(content.end.x <= view.end.x - insets.z - SafeArea.CONTENT_PAD + 2.0, "%s keeps the right inset" % tag)
	_ok(content.end.y <= view.end.y - insets.w - SafeArea.CONTENT_PAD + 2.0, "%s keeps the bottom inset" % tag)
	if scene_name.begins_with("menu") and scene_name != "menu_dev":
		_ok(not _button_text(node, "Editor"), "%s hides the editor from the player menu" % tag)
		_ok(not _button_text(node, "TD-3.6 QA"), "%s hides TD-3.6 QA from the player menu" % tag)
	var buttons: Array[Control] = []
	_collect(node, buttons)
	var allowed := content.grow(2.0)
	for button in buttons:
		var visible := _visible_rect(button)
		if visible.size.x < 1.0 or visible.size.y < 1.0:
			continue
		var text := ""
		if button is Button:
			text = button.text
		_ok(allowed.encloses(visible), "%s control '%s' stays inside the safe area %s vs %s" % [tag, text, visible, content])

func _visible_rect(c: Control) -> Rect2:
	if not c.is_visible_in_tree():
		return Rect2()
	var rect := c.get_global_rect()
	var n := c.get_parent()
	while n is Control:
		if n.clip_contents or n is ScrollContainer:
			rect = rect.intersection((n as Control).get_global_rect())
		n = n.get_parent()
	return rect.intersection(root.get_visible_rect())

func _collect(n: Node, out: Array[Control]) -> void:
	if n is BaseButton and (n as CanvasItem).is_visible_in_tree():
		out.append(n)
	for child in n.get_children():
		_collect(child, out)

func _find_safe(n: Node) -> SafeArea:
	if n is SafeArea:
		return n
	for child in n.get_children():
		var found := _find_safe(child)
		if found:
			return found
	return null

func _button_text(n: Node, text: String) -> bool:
	if n is Button and n.text == text and (n as CanvasItem).is_visible_in_tree():
		return true
	for child in n.get_children():
		if _button_text(child, text):
			return true
	return false

func _shot(dir: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var tex := root.get_texture()
	if tex == null:
		print("  SHOT  unavailable ", file_name)
		return
	var img := tex.get_image()
	if img == null:
		print("  SHOT  empty ", file_name)
		return
	var path := dir.path_join(file_name)
	var err := img.save_png(path)
	if err == OK:
		_shots += 1
		print("  SHOT  ", path, " ", img.get_width(), "x", img.get_height())
	else:
		print("  SHOT  failed ", file_name, " err=", err)
