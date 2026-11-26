extends SceneTree
## M1.3-A ProgressStore: migration from progress.save, crash-safe writes and recovery at every
## interruption point, v1 max-merge, dual-write and its failure handling, rollback, read-only
## newer versions. Every case uses its own folder under user://m13a_test/; the player's real
## user://progress.save and user://progress_v2.save are checked to be untouched.
##   godot --headless --path . --script res://test/test_progress_store.gd

const ROOT := "user://m13a_test/"
var _fails := 0

func _ok(condition: bool, message: String) -> void:
	if condition:
		print("  PASS  ", message)
	else:
		print("  FAIL  ", message)
		_fails += 1

func _initialize() -> void:
	print("== test_progress_store ==")
	var real := _real_digest()
	_remove_tree(ROOT)
	_fresh()
	_migration_and_idempotency()
	_malformed_v1()
	_completion_and_dual_write()
	_recovery()
	_dual_write_failure()
	_v2_write_failure()
	_rollback_merge()
	_newer_version_read_only()
	_repeated_saves()
	_separate_campaigns()
	_remove_tree(ROOT)
	_ok(_real_digest() == real, "the real user://progress.save and progress_v2.save are untouched")
	print("== done: %d failure(s) ==" % _fails)
	quit(_fails)

# --- helpers -------------------------------------------------------------------------

func _case(name: String) -> String:
	var path := ROOT + name + "/"
	DirAccess.make_dir_recursive_absolute(path)
	return path

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _md5(path: String) -> String:
	return FileAccess.get_md5(path) if FileAccess.file_exists(path) else "absent"

func _json(path: String) -> Variant:
	return JSON.parse_string(_read(path))

## A valid v2 file text, as the store would write it.
func _v2_text(seq: int, campaigns: Dictionary) -> String:
	var payload := {"save_version": 2, "seq": seq, "campaigns": campaigns, "migration": {}, "checksum": ProgressStore._checksum(seq, campaigns)}
	return JSON.stringify(payload, "", true)

func _camps(classic_unlocked: int, classic_stars := {}) -> Dictionary:
	return {"classic": {"unlocked": classic_unlocked, "stars": classic_stars}, "chapter1": {"unlocked": 0, "stars": {}}}

func _real_digest() -> String:
	return "%s|%s" % [_md5("user://progress.save"), _md5("user://progress_v2.save")]

func _remove_tree(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	d.include_hidden = true
	for sub in d.get_directories():
		_remove_tree(path.path_join(sub) + "/")
	for f in d.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path.trim_suffix("/"))

# --- cases ---------------------------------------------------------------------------

func _fresh() -> void:
	var dir := _case("fresh")
	var s := ProgressStore.open(dir)
	_ok(s.load_source == "fresh" and s.unlocked("classic") == 0 and s.unlocked("chapter1") == 0, "no files: fresh empty store")
	_ok(FileAccess.file_exists(dir + "progress_v2.save") and not FileAccess.file_exists(dir + "progress.save"), "fresh store writes progress_v2.save only")
	_ok(ProgressStore.open(dir).load_source == "primary", "the written file reloads as primary")

func _migration_and_idempotency() -> void:
	var dir := _case("migrate")
	_write(dir + "progress.save", JSON.stringify({"unlocked": 36, "stars": {"0": 3, "1": 2, "35": 1}}))
	var v1_md5 := _md5(dir + "progress.save")
	var s := ProgressStore.open(dir)
	_ok(s.load_source == "migrated", "v1 only: migrated")
	_ok(s.unlocked("classic") == 36 and s.stars("classic", "legacy-1") == 3 and s.stars("classic", "legacy-2") == 2 and s.stars("classic", "legacy-36") == 1, "v1 index i maps to legacy-(i+1); unlocked copied")
	_ok(_md5(dir + "progress.save") == v1_md5, "migration does not rewrite progress.save")
	_ok(str(s.migration.get("source_sha256", "")) != "" and int(s.migration.get("source_version", 0)) == 1, "migration metadata recorded")
	var v2_md5 := _md5(dir + "progress_v2.save")
	var again := ProgressStore.open(dir)
	_ok(again.load_source == "primary" and again.seq == s.seq, "reopen: loads primary, no new write")
	_ok(JSON.stringify(again.campaigns, "", true) == JSON.stringify(s.campaigns, "", true) and _md5(dir + "progress_v2.save") == v2_md5, "reopen is idempotent (same campaigns, file unchanged)")

func _malformed_v1() -> void:
	var dir := _case("malformed")
	_write(dir + "progress.save", JSON.stringify({"unlocked": "x", "stars": {"a": 3, "-1": 2, "5": 9, "6": 0, "7": 2.5, "8": 2, "250": 3}}))
	var s := ProgressStore.open(dir)
	_ok(s.unlocked("classic") == 0, "non-integer unlocked becomes 0")
	_ok(s.stars("classic", "legacy-6") == 3 and s.stars("classic", "legacy-9") == 2, "star 9 clamps to 3; valid star kept")
	_ok(s.stars("classic", "legacy-7") == 0 and s.stars("classic", "legacy-8") == 0 and s.campaigns["classic"]["stars"].size() == 2, "zero, fractional, negative, non-numeric and out-of-range entries skipped")
	_ok(s.warnings.size() >= 5, "each skipped value is reported (%d warnings)" % s.warnings.size())
	var big := _case("malformed_big")
	_write(big + "progress.save", JSON.stringify({"unlocked": 500, "stars": {}}))
	_ok(ProgressStore.open(big).unlocked("classic") == 100, "unlocked is clamped to the Classic level count")
	var junk := _case("malformed_junk")
	_write(junk + "progress.save", "{{{ not json")
	var j := ProgressStore.open(junk)
	_ok(j.load_source == "fresh" and j.unlocked("classic") == 0 and j.warnings.size() > 0, "unparseable progress.save: fresh store, warning, no crash")

func _completion_and_dual_write() -> void:
	var dir := _case("complete")
	_write(dir + "progress.save", JSON.stringify({"unlocked": 36, "stars": {"0": 3, "1": 2, "35": 1}}))
	var s := ProgressStore.open(dir)
	var r := s.record_completion("classic", "legacy-36", 35, 3)
	_ok(int(r["v2"]) == OK and int(r["v1"]) == OK, "record_completion writes v2 and dual-writes v1")
	s.record_completion("classic", "legacy-36", 35, 1)
	_ok(s.stars("classic", "legacy-36") == 3, "a worse replay never lowers stars")
	s.record_completion("classic", "legacy-37", 36, 2)
	_ok(s.unlocked("classic") == 37, "completing the next level raises unlocked")
	s.record_completion("chapter1", "ch1-01", 0, 3)
	var v1: Variant = _json(dir + "progress.save")
	var legacy_shape: bool = v1 is Dictionary and v1.size() == 2 and v1.has("unlocked") and v1.has("stars")
	_ok(legacy_shape and int(v1["unlocked"]) == 37 and int(v1["stars"]["35"]) == 3 and int(v1["stars"]["36"]) == 2 and int(v1["stars"]["0"]) == 3, "progress.save stays in the exact legacy format with the new Classic progress")
	_ok(not JSON.stringify(v1).contains("ch1-01"), "Chapter 1 never leaks into progress.save")
	var reopened := ProgressStore.open(dir)
	_ok(reopened.stars("classic", "legacy-36") == 3 and reopened.stars("chapter1", "ch1-01") == 3 and reopened.unlocked("classic") == 37, "progress survives an app restart")

func _recovery() -> void:
	var c5 := _camps(5)
	var c6 := _camps(6)
	# Torn .tmp (crash during step 1): primary wins.
	var a := _case("rec_torn_tmp")
	_write(a + "progress_v2.save", _v2_text(5, c5))
	_write(a + "progress_v2.save.tmp", _v2_text(6, c6).substr(0, 40))
	var sa := ProgressStore.open(a)
	_ok(sa.load_source == "primary" and sa.unlocked("classic") == 5, "torn .tmp is ignored; primary loads")
	# Valid newer .tmp next to primary (crash after step 1 or inside step 3).
	var b := _case("rec_newer_tmp")
	_write(b + "progress_v2.save", _v2_text(5, c5))
	_write(b + "progress_v2.save.tmp", _v2_text(6, c6))
	var sb := ProgressStore.open(b)
	_ok(sb.load_source == "tmp" and sb.unlocked("classic") == 6, "a complete newer .tmp wins over primary")
	_ok(ProgressStore.open(b).load_source == "primary" and ProgressStore.open(b).unlocked("classic") == 6, "recovery self-heals: primary rewritten from .tmp")
	# No primary, .bak old + .tmp new (crash after step 3, before step 4).
	var c := _case("rec_between_renames")
	_write(c + "progress_v2.save.bak", _v2_text(5, c5))
	_write(c + "progress_v2.save.tmp", _v2_text(6, c6))
	var sc := ProgressStore.open(c)
	_ok(sc.load_source == "tmp" and sc.unlocked("classic") == 6 and FileAccess.file_exists(c + "progress_v2.save"), "missing primary: newest of .tmp/.bak loads and primary is restored")
	# Corrupt primary, valid .bak.
	var d := _case("rec_corrupt_primary")
	_write(d + "progress_v2.save", _v2_text(6, c6).substr(0, 25))
	_write(d + "progress_v2.save.bak", _v2_text(5, c5))
	var sd := ProgressStore.open(d)
	_ok(sd.load_source == "backup" and sd.unlocked("classic") == 5, "truncated primary: .bak loads")
	var kept_bak: Variant = _json(d + "progress_v2.save.bak")
	_ok(kept_bak is Dictionary and int(kept_bak["seq"]) == 5 and ProgressStore.open(d).load_source == "primary", "self-heal drops the corrupt primary and keeps the good .bak")
	# Checksum tamper: valid JSON, edited value.
	var e := _case("rec_tamper")
	var tampered: Dictionary = JSON.parse_string(_v2_text(6, c6))
	tampered["campaigns"]["classic"]["unlocked"] = 99
	_write(e + "progress_v2.save", JSON.stringify(tampered))
	_write(e + "progress_v2.save.bak", _v2_text(5, c5))
	var se := ProgressStore.open(e)
	_ok(se.load_source == "backup" and se.unlocked("classic") == 5, "checksum mismatch rejects an edited file")
	# Every v2 file bad, v1 present: never an empty store.
	var f := _case("rec_all_bad")
	_write(f + "progress_v2.save", "garbage")
	_write(f + "progress_v2.save.bak", "")
	_write(f + "progress.save", JSON.stringify({"unlocked": 12, "stars": {"11": 2}}))
	var sf := ProgressStore.open(f)
	_ok(sf.load_source == "migrated" and sf.unlocked("classic") == 12 and sf.stars("classic", "legacy-12") == 2, "all v2 files invalid: re-migrates from progress.save, not empty")

func _dual_write_failure() -> void:
	var dir := _case("dual_fail")
	var s := ProgressStore.open(dir)
	DirAccess.make_dir_absolute(dir + "progress.save.tmp")  # makes the v1 write fail
	var r := s.record_completion("classic", "legacy-1", 0, 3)
	_ok(int(r["v2"]) == OK and int(r["v1"]) != OK and s.pending_v1, "v1 dual-write failure: v2 still saved, pending_v1 set")
	_ok(ProgressStore.open(dir).stars("classic", "legacy-1") == 3, "the completion is durable in v2 despite the v1 failure")
	DirAccess.remove_absolute(dir + "progress.save.tmp")
	var r2 := s.save()
	var v1: Variant = _json(dir + "progress.save")
	_ok(int(r2["v1"]) == OK and not s.pending_v1 and v1 is Dictionary and int(v1["stars"]["0"]) == 3, "next save retries v1 and clears pending_v1")

func _v2_write_failure() -> void:
	var dir := _case("v2_fail")
	var s := ProgressStore.open(dir)
	DirAccess.make_dir_absolute(dir + "progress_v2.save.tmp")  # makes the v2 write fail
	var r := s.record_completion("classic", "legacy-3", 2, 2)
	_ok(int(r["v2"]) != OK and int(r["v1"]) == OK, "v2 write failure: v1 is still written")
	_ok(s.stars("classic", "legacy-3") == 2, "in-memory progress is kept after a failed write")
	DirAccess.remove_absolute(dir + "progress_v2.save.tmp")
	var restarted := ProgressStore.open(dir)
	_ok(restarted.stars("classic", "legacy-3") == 2 and restarted.unlocked("classic") == 3, "on restart the merge recovers the progress from progress.save")

func _rollback_merge() -> void:
	var dir := _case("rollback")
	var s := ProgressStore.open(dir)
	s.record_completion("classic", "legacy-40", 39, 2)
	s.record_completion("chapter1", "ch1-05", 4, 3)
	# A rolled-back legacy build plays on and writes progress.save the old way (in place).
	var legacy: Dictionary = JSON.parse_string(_read(dir + "progress.save"))
	legacy["unlocked"] = 42
	legacy["stars"]["41"] = 3
	legacy["stars"]["39"] = 3
	_write(dir + "progress.save", JSON.stringify(legacy))
	var upgraded := ProgressStore.open(dir)
	_ok(upgraded.unlocked("classic") == 42 and upgraded.stars("classic", "legacy-42") == 3 and upgraded.stars("classic", "legacy-40") == 3, "re-upgrade merges progress made on the rolled-back build")
	_ok(upgraded.stars("chapter1", "ch1-05") == 3 and upgraded.unlocked("chapter1") == 5, "Chapter 1 progress survives the rollback round trip")
	legacy["unlocked"] = 1
	legacy["stars"] = {"39": 1}
	_write(dir + "progress.save", JSON.stringify(legacy))
	var later := ProgressStore.open(dir)
	_ok(later.unlocked("classic") == 42 and later.stars("classic", "legacy-40") == 3, "an older progress.save never lowers v2 progress")

func _newer_version_read_only() -> void:
	var dir := _case("newer")
	_write(dir + "progress_v2.save", JSON.stringify({"save_version": 3, "seq": 9, "campaigns": {"classic": {"unlocked": 9, "stars": {}}}}))
	_write(dir + "progress.save", JSON.stringify({"unlocked": 2, "stars": {}}))
	var before := "%s|%s" % [_md5(dir + "progress_v2.save"), _md5(dir + "progress.save")]
	var s := ProgressStore.open(dir)
	_ok(s.read_only and s.load_source == "newer_version" and s.unlocked("classic") == 9, "newer save_version: read-only, data shown")
	var r := s.record_completion("classic", "legacy-1", 0, 3)
	_ok(int(r["v2"]) == ERR_UNAUTHORIZED and int(r["v1"]) == ERR_UNAUTHORIZED, "read-only store refuses to write")
	_ok("%s|%s" % [_md5(dir + "progress_v2.save"), _md5(dir + "progress.save")] == before and not FileAccess.file_exists(dir + "progress_v2.save.tmp"), "files from the newer build are untouched")

func _repeated_saves() -> void:
	var dir := _case("repeat")
	var s := ProgressStore.open(dir)
	var start_seq := s.seq
	var all_ok := true
	for i in 3:
		var r := s.record_completion("classic", ProgressStore.classic_id(i), i, 2)
		all_ok = all_ok and int(r["v2"]) == OK and int(r["v1"]) == OK
	var primary: Variant = _json(dir + "progress_v2.save")
	var bak: Variant = _json(dir + "progress_v2.save.bak")
	_ok(all_ok and s.seq == start_seq + 3, "three consecutive saves succeed (no rename onto an existing file)")
	_ok(primary is Dictionary and bak is Dictionary and int(primary["seq"]) == s.seq and int(bak["seq"]) == s.seq - 1, ".bak always holds the previous version")
	_ok(not FileAccess.file_exists(dir + "progress_v2.save.tmp") and not FileAccess.file_exists(dir + "progress.save.tmp"), "no .tmp left behind after successful saves")

func _separate_campaigns() -> void:
	var dir := _case("campaigns")
	var s := ProgressStore.open(dir)
	s.record_completion("chapter1", "ch1-01", 0, 3)
	s.record_completion("classic", "legacy-1", 0, 1)
	_ok(s.stars("chapter1", "ch1-01") == 3 and s.stars("classic", "legacy-1") == 1 and s.stars("classic", "ch1-01") == 0, "Classic and Chapter 1 stars are independent")
	_ok(s.unlocked("chapter1") == 1 and s.unlocked("classic") == 1, "each campaign tracks its own unlocked count")
