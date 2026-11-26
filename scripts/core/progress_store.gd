class_name ProgressStore
extends RefCounted
## Versioned, crash-safe player progress (M1.3-A, docs/architecture/M1_3_UNIFIED_GAMEPLAY_PLAN.md §5).
## Not wired to gameplay yet: the live route still uses Catalog and progress.save.
##
## Files in `dir`: progress_v2.save is authoritative (+ .tmp / .bak from the write protocol).
## progress.save is the legacy v1 file: never deleted, max-merged into Classic on every load,
## and dual-written for Classic while the rollback window is open.

const SAVE_VERSION := 2
const V2_FILE := "progress_v2.save"
const V1_FILE := "progress.save"
const CLASSIC := "classic"
const CHAPTER1 := "chapter1"
const MAX_STARS := 3

var dir := "user://"
var classic_count := 100
## Classic completions are also written to progress.save in the legacy format.
var dual_write_v1 := true
## {campaign: {"unlocked": int, "stars": {level_id: int}}}
var campaigns := {}
var seq := 0
var migration := {}
## A newer save_version was found: nothing is written.
var read_only := false
## primary | tmp | backup | migrated | fresh | newer_version
var load_source := ""
## The last v1 dual-write failed; the next save retries it.
var pending_v1 := false
var warnings: PackedStringArray = []

## Loads (with recovery, migration and the v1 merge) from `base_dir`.
static func open(base_dir := "user://", classic_levels := 100) -> ProgressStore:
	var store := ProgressStore.new()
	store.dir = base_dir if base_dir.ends_with("/") else base_dir + "/"
	store.classic_count = classic_levels
	store._load()
	return store

static func classic_id(index: int) -> String:
	return "legacy-%d" % (index + 1)

func unlocked(campaign: String) -> int:
	return int(_campaign(campaign)["unlocked"])

func stars(campaign: String, level_id: String) -> int:
	return int(_campaign(campaign)["stars"].get(level_id, 0))

## Records a completed level: stars only ever improve; `unlocked` becomes at least
## order_index + 1 (order_index is the level's 0-based position in its campaign).
## Returns save() results.
func record_completion(campaign: String, level_id: String, order_index: int, earned: int) -> Dictionary:
	if read_only:
		return {"v2": ERR_UNAUTHORIZED, "v1": ERR_UNAUTHORIZED}
	var c := _campaign(campaign)
	var s := clampi(earned, 1, MAX_STARS)
	if s > int(c["stars"].get(level_id, 0)):
		c["stars"][level_id] = s
	c["unlocked"] = maxi(int(c["unlocked"]), order_index + 1)
	return save()

## Writes v2, then (Classic dual-write) v1. The two writes are independent: a failure of one
## never prevents the other, and a failed v1 write is retried on the next save.
## Returns {"v2": Error, "v1": Error or -1 when dual-write is off}.
func save() -> Dictionary:
	if read_only:
		return {"v2": ERR_UNAUTHORIZED, "v1": ERR_UNAUTHORIZED}
	var v2 := _write_v2()
	if v2 != OK:
		warnings.append("progress_v2.save write failed (%s); state kept in memory" % error_string(v2))
	var v1 := -1
	if dual_write_v1:
		v1 = _write_v1()
		pending_v1 = v1 != OK
		if pending_v1:
			warnings.append("progress.save dual-write failed (%s); will retry" % error_string(v1))
	return {"v2": v2, "v1": v1}

# --- loading -------------------------------------------------------------------------

func _load() -> void:
	var best := {}
	var best_source := ""
	for item in [["", "primary"], [".tmp", "tmp"], [".bak", "backup"]]:
		var path := _path(V2_FILE + str(item[0]))
		if not FileAccess.file_exists(path):
			continue
		var parsed := _parse_v2(FileAccess.get_file_as_string(path))
		if parsed.has("newer"):
			# Never write over data from a newer build.
			read_only = true
			load_source = "newer_version"
			var raw_campaigns = parsed["raw"].get("campaigns", {})
			campaigns = raw_campaigns if raw_campaigns is Dictionary else {}
			warnings.append("%s has save_version %d > %d; read-only" % [path.get_file(), int(parsed["version"]), SAVE_VERSION])
			_ensure_campaigns()
			return
		if parsed.is_empty():
			warnings.append("%s is invalid; ignored" % path.get_file())
			continue
		if best.is_empty() or int(parsed["seq"]) > int(best["seq"]):
			best = parsed
			best_source = str(item[1])
	var changed := false
	if best.is_empty():
		var v1 := _read_v1()
		campaigns = {}
		_ensure_campaigns()
		if not v1.is_empty():
			_merge_classic(v1)
			load_source = "migrated"
		else:
			load_source = "fresh"
		migration = {
			"from": V1_FILE,
			"source_version": 1,
			"source_sha256": FileAccess.get_sha256(_path(V1_FILE)) if FileAccess.file_exists(_path(V1_FILE)) else "",
			"at_unix": int(Time.get_unix_time_from_system()),
		}
		changed = true
	else:
		campaigns = best["campaigns"]
		seq = int(best["seq"])
		migration = best["migration"]
		load_source = best_source
		_ensure_campaigns()
		if best_source != "primary":
			warnings.append("recovered progress from %s" % best_source)
			changed = true
		if _merge_classic(_read_v1()):
			changed = true
	if changed:
		var err := _write_v2()
		if err != OK:
			warnings.append("could not persist loaded progress (%s)" % error_string(err))

## Max-merge of legacy progress into Classic. Returns true when anything grew.
func _merge_classic(v1: Dictionary) -> bool:
	if v1.is_empty():
		return false
	var c := _campaign(CLASSIC)
	var grew := false
	if int(v1["unlocked"]) > int(c["unlocked"]):
		c["unlocked"] = int(v1["unlocked"])
		grew = true
	for id in v1["stars"].keys():
		if int(v1["stars"][id]) > int(c["stars"].get(id, 0)):
			c["stars"][id] = int(v1["stars"][id])
			grew = true
	return grew

## Reads progress.save into {"unlocked", "stars": {legacy-N: 1..3}}; {} if missing/unreadable.
## Malformed values are skipped or clamped with a warning, never fatal.
func _read_v1() -> Dictionary:
	var path := _path(V1_FILE)
	if not FileAccess.file_exists(path):
		return {}
	var raw: Variant = _parse_json(FileAccess.get_file_as_string(path))
	if not raw is Dictionary:
		warnings.append("progress.save is not valid JSON; ignored")
		return {}
	var out := {"unlocked": 0, "stars": {}}
	var u: Variant = _whole(raw.get("unlocked", 0))
	if u == null or int(u) < 0:
		warnings.append("progress.save unlocked is invalid; using 0")
	else:
		out["unlocked"] = mini(int(u), classic_count)
	var raw_stars: Variant = raw.get("stars", {})
	if raw_stars is Dictionary:
		for key in raw_stars.keys():
			var index := str(key)
			var value: Variant = _whole(raw_stars[key])
			if not index.is_valid_int() or int(index) < 0 or int(index) >= classic_count:
				warnings.append("progress.save star key %s skipped" % index)
				continue
			if value == null or int(value) <= 0:
				warnings.append("progress.save star value for %s skipped" % index)
				continue
			out["stars"][classic_id(int(index))] = mini(int(value), MAX_STARS)
	elif raw_stars != null:
		warnings.append("progress.save stars is not a map; ignored")
	return out

## Validates one v2 file. Returns {} when invalid, {"newer": true, ...} for a newer version,
## otherwise {"seq", "campaigns", "migration"}.
func _parse_v2(text: String) -> Dictionary:
	var raw: Variant = _parse_json(text)
	if not raw is Dictionary:
		return {}
	var version: Variant = _whole(raw.get("save_version"))
	if version == null:
		return {}
	if int(version) > SAVE_VERSION:
		return {"newer": true, "version": int(version), "raw": raw}
	if int(version) != SAVE_VERSION:
		return {}
	var s: Variant = _whole(raw.get("seq"))
	if s == null or int(s) < 0:
		return {}
	var camps: Variant = _normalize_campaigns(raw.get("campaigns"))
	if camps == null:
		return {}
	if str(raw.get("checksum", "")) != _checksum(int(s), camps):
		return {}
	var mig: Variant = raw.get("migration", {})
	return {"seq": int(s), "campaigns": camps, "migration": mig if mig is Dictionary else {}}

## Integer-normalised copy of a campaigns map, or null when its shape is wrong.
static func _normalize_campaigns(value: Variant) -> Variant:
	if not value is Dictionary:
		return null
	var out := {}
	for name in value.keys():
		var c: Variant = value[name]
		if not c is Dictionary:
			return null
		var u: Variant = _whole(c.get("unlocked"))
		if u == null or int(u) < 0 or not c.get("stars") is Dictionary:
			return null
		var st := {}
		for id in c["stars"].keys():
			var v: Variant = _whole(c["stars"][id])
			if v == null or int(v) < 1 or int(v) > MAX_STARS:
				return null
			st[str(id)] = int(v)
		out[str(name)] = {"unlocked": int(u), "stars": st}
	return out

static func _checksum(save_seq: int, camps: Dictionary) -> String:
	var canonical := {"save_version": SAVE_VERSION, "seq": save_seq, "campaigns": camps}
	return JSON.stringify(canonical, "", true).sha256_text()

## Parses JSON without logging engine errors (a damaged save is an expected, handled case).
static func _parse_json(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data

## int, or a float with no fractional part, as int; anything else null.
static func _whole(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value):
		return int(value)
	return null

# --- writing -------------------------------------------------------------------------

func _write_v2() -> Error:
	seq += 1
	var camps: Variant = _normalize_campaigns(campaigns)
	if camps == null:
		return ERR_INVALID_DATA
	var payload := {
		"save_version": SAVE_VERSION,
		"seq": seq,
		"campaigns": camps,
		"migration": migration,
		"checksum": _checksum(seq, camps),
	}
	return _atomic_write(V2_FILE, JSON.stringify(payload, "", true), func(text: String) -> bool:
		var parsed := _parse_v2(text)
		return not parsed.is_empty() and not parsed.has("newer"))

## Legacy format exactly as Catalog writes it: {"unlocked", "stars": {"<0-based index>": n}}.
func _write_v1() -> Error:
	var c := _campaign(CLASSIC)
	var legacy_stars := {}
	for id in c["stars"].keys():
		var text := str(id)
		if not text.begins_with("legacy-"):
			continue
		var number := text.trim_prefix("legacy-")
		if not number.is_valid_int() or int(number) < 1 or int(number) > classic_count:
			continue
		legacy_stars[str(int(number) - 1)] = int(c["stars"][id])
	var payload := {"unlocked": mini(int(c["unlocked"]), classic_count), "stars": legacy_stars}
	return _atomic_write(V1_FILE, JSON.stringify(payload), func(text: String) -> bool:
		var parsed: Variant = _parse_json(text)
		return parsed is Dictionary and parsed.has("unlocked") and parsed.has("stars"))

## Crash-safe replace (plan §5.3): write .tmp, read it back (must match byte for byte), move
## the current file to .bak, then rename .tmp into place. Never renames onto an existing file.
## `is_valid(text)` decides whether the current file is worth keeping as .bak: a corrupt
## current file is deleted instead, so it never replaces a good backup.
func _atomic_write(name: String, text: String, is_valid: Callable) -> Error:
	var target := _path(name)
	var tmp := target + ".tmp"
	var bak := target + ".bak"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		var open_err := FileAccess.get_open_error()
		return open_err if open_err != OK else ERR_CANT_OPEN
	file.store_string(text)
	file.flush()
	var write_err := file.get_error()
	file.close()
	if write_err != OK:
		return write_err
	if FileAccess.get_file_as_string(tmp) != text:
		return ERR_FILE_CORRUPT
	if FileAccess.file_exists(target):
		if bool(is_valid.call(FileAccess.get_file_as_string(target))):
			if FileAccess.file_exists(bak):
				var remove_err := DirAccess.remove_absolute(bak)
				if remove_err != OK:
					return remove_err
			var aside_err := DirAccess.rename_absolute(target, bak)
			if aside_err != OK:
				return aside_err
		else:
			var drop_err := DirAccess.remove_absolute(target)
			if drop_err != OK:
				return drop_err
	return DirAccess.rename_absolute(tmp, target)

# --- helpers -------------------------------------------------------------------------

func _path(name: String) -> String:
	return dir + name

func _campaign(name: String) -> Dictionary:
	if not campaigns.has(name) or not campaigns[name] is Dictionary:
		campaigns[name] = {"unlocked": 0, "stars": {}}
	return campaigns[name]

func _ensure_campaigns() -> void:
	_campaign(CLASSIC)
	_campaign(CHAPTER1)
