extends SceneTree
## Desktop screenshots of the v2 pilot. Not an Android device test.
## The board is drawn into a SubViewport so the image does not depend on the
## OS window fitting the requested phone size.
##   godot --path . --script res://test/test_v2_pilot_shots.gd

var _fails := 0

func _initialize() -> void:
	print("== test_v2_pilot_shots ==")
	var out := ProjectSettings.globalize_path("res://build/qa/pilot")
	DirAccess.make_dir_recursive_absolute(out)
	var packed: PackedScene = load("res://scenes/Pilot.tscn")
	SafeArea.use_simulation = true
	await _capture(packed, out, Vector2i(360, 800), Vector4.ZERO, 0, "360x800_v2_001.png")
	await _capture(packed, out, Vector2i(360, 800), Vector4.ZERO, 5, "360x800_v2_006.png")
	await _capture(packed, out, Vector2i(360, 800), Vector4.ZERO, 9, "360x800_v2_010.png")
	await _capture(packed, out, Vector2i(360, 800), Vector4.ZERO, 14, "360x800_v2_015.png")
	await _capture(packed, out, Vector2i(412, 915), Vector4.ZERO, 5, "412x915_v2_006.png")
	await _capture(packed, out, Vector2i(360, 800), Vector4(0, 96, 0, 48), 9, "360x800_cutout_v2_010.png")
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

func _capture(packed: PackedScene, dir: String, view_size: Vector2i, insets: Vector4, index: int, file_name: String) -> void:
	SafeArea.simulate_insets = insets
	var host := SubViewport.new()
	host.size = view_size
	host.disable_3d = true
	host.transparent_bg = false
	host.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(host)
	var pilot := packed.instantiate()
	pilot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(pilot)
	for _i in 4:
		await process_frame
	pilot._load(index)
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	print("  VIEW  ", file_name, " ", host.size)
	var menu := _find_button(pilot, "Menu")
	var safe := _find_safe(pilot)
	if menu == null or safe == null:
		_fails += 1
		print("  FAIL  Menu or safe area missing")
	else:
		var rect := menu.get_global_rect()
		var bounds := safe.get_global_rect()
		var inside := rect.position.x >= bounds.position.x - 1.0 and rect.position.y >= bounds.position.y - 1.0 and rect.end.x <= bounds.end.x + 1.0 and rect.end.y <= bounds.end.y + 1.0
		if inside:
			print("  PASS  Menu stays inside the safe area on ", file_name)
		else:
			_fails += 1
			print("  FAIL  Menu outside safe area ", rect, " bounds ", bounds)
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
		elif not _varied(image):
			_fails += 1
			print("  FAIL  blank framebuffer ", file_name)
		else:
			print("  SHOT  ", path)
	host.queue_free()
	await process_frame

func _varied(image: Image) -> bool:
	var first := image.get_pixel(4, 4)
	var probes := [Vector2i(image.get_width() / 2, 48), Vector2i(image.get_width() / 2, image.get_height() / 2), Vector2i(24, image.get_height() - 24)]
	for probe in probes:
		if image.get_pixelv(probe) != first:
			return true
	return false

func _find_safe(node: Node) -> Control:
	if node is SafeArea:
		return node
	for child in node.get_children():
		var found := _find_safe(child)
		if found:
			return found
	return null

func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text and (node as CanvasItem).is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found:
			return found
	return null
