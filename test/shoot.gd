extends SceneTree
## Render a scene for a few frames and save a screenshot.
## Run (windowed, NOT headless):
##   godot --path . --script res://test/shoot.gd -- res://scenes/Game.tscn out.png
## Defaults to Game.tscn -> user://shot.png

var _frame := 0
var _scene: Node
var _out := "user://shot.png"

func _initialize() -> void:
	root.size = Vector2i(720, 1280)
	var scene_path := "res://scenes/Game.tscn"
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		scene_path = args[0]
	if args.size() >= 2:
		_out = args[1]
	_scene = load(scene_path).instantiate()
	root.add_child(_scene)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 24:
		var img := root.get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		return true
	return false
