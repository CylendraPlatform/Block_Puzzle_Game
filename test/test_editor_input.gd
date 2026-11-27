extends SceneTree
## Level editor touch input. On Android one tap reaches EditorCanvas._gui_input twice: as an
## InputEventScreenTouch and as the mouse click Godot emulates from it
## (device == InputEvent.DEVICE_ID_EMULATION). The editor tools toggle, so handling both
## placed and immediately removed every block and gate. One tap must act exactly once.
##   godot --headless --path . --script res://test/test_editor_input.gd

var _fails := 0

func _ok(condition: bool, message: String) -> void:
	if condition:
		print("  PASS  ", message)
	else:
		print("  FAIL  ", message)
		_fails += 1

func _initialize() -> void:
	print("== test_editor_input ==")
	_canvas_events()
	await _editor_taps()
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

func _touch(pos: Vector2, pressed := true) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	return e

func _mouse(pos: Vector2, device: int, pressed := true) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.device = device
	return e

## A device tap: touch down + emulated mouse down, then both releases.
func _device_tap(target: Control, pos: Vector2) -> void:
	target._gui_input(_touch(pos))
	target._gui_input(_mouse(pos, InputEvent.DEVICE_ID_EMULATION))
	target._gui_input(_touch(pos, false))
	target._gui_input(_mouse(pos, InputEvent.DEVICE_ID_EMULATION, false))

func _canvas_events() -> void:
	var canvas := EditorCanvas.new()
	canvas.size = Vector2(700, 700)
	canvas.set_state({"cols": 6, "rows": 6, "walls": [], "blocks": [], "gates": []})
	canvas._layout()
	var cells: Array = []
	var edges: Array = []
	canvas.cell_tapped.connect(func(c: Vector2i) -> void: cells.append(c))
	canvas.edge_tapped.connect(func(side: String, perp: int) -> void: edges.append([side, perp]))
	var center := canvas._px(Vector2i(2, 3)) + Vector2.ONE * canvas._cell * 0.5
	_device_tap(canvas, center)
	_ok(cells == [Vector2i(2, 3)], "device tap (touch + emulated mouse) reports the cell once (got %s)" % [cells])
	cells.clear()
	canvas._gui_input(_mouse(center, 0))
	_ok(cells == [Vector2i(2, 3)], "a real mouse click (desktop) reports the cell once")
	cells.clear()
	canvas._gui_input(_touch(center))
	_ok(cells == [Vector2i(2, 3)], "a touch alone reports the cell once")
	var left_edge := canvas._px(Vector2i(0, 1)) + Vector2(-canvas._cell * 0.5, canvas._cell * 0.5)
	_device_tap(canvas, left_edge)
	_ok(edges == [["left", 1]], "device tap on the left edge reports the gate slot once (got %s)" % [edges])
	canvas.free()

## Through the real editor scene: block and gate tools must place on one tap and remove on the next.
func _editor_taps() -> void:
	var editor: Control = load("res://scenes/Editor.tscn").instantiate()
	root.add_child(editor)
	while not editor.is_node_ready():
		await process_frame
	var canvas: EditorCanvas = editor._canvas
	canvas.size = Vector2(700, 700)
	canvas._layout()
	var cell := canvas._px(Vector2i(2, 3)) + Vector2.ONE * canvas._cell * 0.5
	_device_tap(canvas, cell)
	_ok(editor._st["blocks"].size() == 1, "one device tap with the Block tool places one block")
	_device_tap(canvas, cell)
	_ok(editor._st["blocks"].is_empty(), "a second tap on it removes it")
	_device_tap(canvas, cell)
	editor._tool = "gate"
	_device_tap(canvas, canvas._px(Vector2i(0, 3)) + Vector2(-canvas._cell * 0.5, canvas._cell * 0.5))
	_ok(editor._st["gates"].size() == 1 and str(editor._st["gates"][0]["side"]) == "left", "one device tap with the Gate tool adds one gate")
	editor._on_validate()
	_ok(str(editor._status.text).begins_with("SOLVABLE"), "the placed block and gate form a solvable level (%s)" % editor._status.text)
	root.remove_child(editor)
	editor.free()
