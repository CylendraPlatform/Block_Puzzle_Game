extends Node
## Autoload "Settings" — user preferences, persisted to user://settings.save.

signal changed

const SAVE_PATH := "user://settings.save"

var sfx := true
var music := true
var haptics := true

var selected_level := 0   ## transient: level index chosen in level-select (not persisted)

func _ready() -> void:
	_load()

func _load() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		sfx = bool(data.get("sfx", true))
		music = bool(data.get("music", true))
		haptics = bool(data.get("haptics", true))

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"sfx": sfx, "music": music, "haptics": haptics}))
	changed.emit()

func set_sfx(v: bool) -> void:
	sfx = v
	save()

func set_music(v: bool) -> void:
	music = v
	save()

func set_haptics(v: bool) -> void:
	haptics = v
	save()
