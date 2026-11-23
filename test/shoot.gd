extends SceneTree
## Render the real Game scene for a few frames and save a screenshot.
## Run (windowed, NOT headless):
##   godot --path . --script res://test/shoot.gd
## Output: user://shot.png

var _frame := 0
var _scene: Node

func _initialize() -> void:
	root.size = Vector2i(720, 1280)
	_scene = load("res://scenes/Game.tscn").instantiate()
	root.add_child(_scene)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 20:
		var img := root.get_texture().get_image()
		img.save_png("user://shot.png")
		print("saved user://shot.png")
		return true   # quit
	return false
