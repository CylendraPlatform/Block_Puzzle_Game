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
