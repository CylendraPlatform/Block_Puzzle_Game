class_name Catalog
extends RefCounted
## Shared level discovery + progress persistence (used by Game and LevelSelect).

const LEVELS_DIR := "res://levels"
const SAVE_PATH := "user://progress.save"

static func list_paths() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(LEVELS_DIR)
	if d:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.ends_with(".json"):
				out.append(LEVELS_DIR + "/" + f)
			f = d.get_next()
		d.list_dir_end()
	out.sort()
	if out.is_empty():
		for i in range(1, 201):
			var p := "%s/level_%03d.json" % [LEVELS_DIR, i]
			if FileAccess.file_exists(p):
				out.append(p)
	return out

static func load_level(path: String) -> Level:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return Level.from_dict(data)

static func load_unlocked() -> int:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return 0
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY and data.has("unlocked"):
		return int(data["unlocked"])
	return 0

## Full progress dict: {"unlocked": int, "stars": {idxStr: int}}.
static func load_progress() -> Dictionary:
	var out := {"unlocked": 0, "stars": {}}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return out
	var data: Variant = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		out["unlocked"] = int(data.get("unlocked", 0))
		if data.get("stars", null) is Dictionary:
			out["stars"] = data["stars"]
	return out

static func save_progress(p: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(p))

static func save_unlocked(n: int) -> void:
	var p := load_progress()
	p["unlocked"] = n
	save_progress(p)

static func get_stars(index: int) -> int:
	return int(load_progress()["stars"].get(str(index), 0))

## Record stars for a level (only upgrades an existing rating).
static func set_stars(index: int, stars: int) -> void:
	var p := load_progress()
	var key := str(index)
	if stars > int(p["stars"].get(key, 0)):
		p["stars"][key] = stars
		save_progress(p)

## Star rating from moves taken vs the level's par (shortest solution).
static func star_rating(moves: int, par: int) -> int:
	if par <= 0:
		return 3
	if moves <= par:
		return 3
	if moves <= par + maxi(2, int(ceil(par * 0.5))):
		return 2
	return 1
