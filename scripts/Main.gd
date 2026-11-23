extends Control
## Smoke-test boot scene for the engine-setup checkpoint.
## Real gameplay (grid, blocks, gates, levels) replaces this in the next milestone.

func _ready() -> void:
	print("Block Puzzle Game booted — Godot ", Engine.get_version_info().string)
	var label := Label.new()
	label.text = "Block Puzzle Game"
	label.add_theme_font_size_override("font_size", 64)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)

	# Headless CI/smoke path: boot, confirm, quit cleanly.
	if DisplayServer.get_name() == "headless":
		print("headless smoke OK")
		get_tree().quit(0)
