extends SceneTree
## Renders each advanced-mechanic level through BoardViewV2 to a PNG (desktop capture; the
## same renderer runs on device). Shows the resting visuals: counter badge + locked gate,
## hidden "?" tile + hatched blocker, color-switching gate colour.
##   godot --path . --script res://test/shot_advanced.gd

func _initialize() -> void:
	root.size = Vector2i(1080, 1200)
	await process_frame
	for p in AdvancedCatalog.list_paths():
		var defn := AdvancedCatalog.read_definition(p)
		var view := BoardViewV2.new()
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(view)
		view.show_state(defn, PuzzleState.from_definition(defn))
		for _i in 4:
			await process_frame
		var img := root.get_texture().get_image()
		var out := "res://build/qa/desktop_%s.png" % str(defn.get("id", "lvl"))
		img.save_png(out)
		print("shot ", out)
		view.queue_free()
		await process_frame
	quit()
