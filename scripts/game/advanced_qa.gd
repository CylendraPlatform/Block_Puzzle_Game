extends PilotGame
## Dedicated QA screen for the advanced-mechanic levels. Reuses the pilot player UI but
## loads AdvancedCatalog and writes no progress, so it stays separate from the campaign.

func _level_paths() -> Array[String]:
	return AdvancedCatalog.list_paths()

func _read_level(path: String) -> Dictionary:
	return AdvancedCatalog.read_definition(path)

func _saved_index() -> int:
	return 0

func _save_index(_index: int) -> void:
	pass

func _screen_title(index: int) -> String:
	return "Advanced QA %d" % (index + 1)

## Developer-only direct level selector: open any advanced level without finishing the
## earlier ones. Loading goes through _load(), whose _save_index() is a no-op here, so it
## never writes campaign progress or touches existing saves.
func _add_tools(column: Control) -> void:
	if not DevAccess.enabled():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in _paths.size():
		var pick := UIKit.button(_paths[i].get_file().get_basename().replace("_", "-"), _load.bind(i))
		TD35Theme.style_compact(pick)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(pick)
	column.add_child(row)
