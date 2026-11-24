extends SceneTree
## Rough desktop FPS probe for the Game scene (NOT a device measurement).
##   godot --path . --script res://test/profile_fps.gd
## Prints average FPS over ~2s of rendering with vsync off.

var _frame := 0
var _accum := 0.0
var _samples := 0
var _scene: Node

func _initialize() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(720, 1280)
	_scene = load("res://scenes/Game.tscn").instantiate()
	root.add_child(_scene)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 30:   # warm-up
		_accum += Engine.get_frames_per_second()
		_samples += 1
	if _frame >= 150:
		var avg := _accum / maxf(1.0, float(_samples))
		print("avg_fps=%.0f over %d samples (desktop, vsync off)" % [avg, _samples])
		return true
	return false
