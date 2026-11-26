extends SceneTree
## M1.3-B Classic compatibility. Exit code = failure count.
##
## 1. CampaignCatalog: the 100 Classic levels keep stable ids legacy-1..100 in save-index order.
## 2. For every legacy level, the legacy Play rules (Rules.slide_result: every landing of 1..max
##    steps, plus the exit) and the v2 PuzzleEngine (LevelLoader output) offer the same successor
##    states, compared on (a) a bounded BFS of BFS_CAP states, (b) every state of a shortest legacy
##    solution, which exercises every exit, and (c) WALKS seeded random walks per level.
## 3. The only allowed difference is the legacy pass-through exit (a block leaving through its
##    gate while a wall or block still sits in front of one of its cells; v2 corrects this, see
##    docs/LEVEL_SYSTEM.md). It must occur in exactly levels 021, 080 and 090, and v2 must still
##    solve those three in exactly their stored par, with a witness that replays to a win.
## Deterministic: fixed caps, fixed seeds, sorted keys. Writes nothing.

const BFS_CAP := 400
const SOLVE_CAP := 60000
const WALKS := 12
const WALK_LEN := 60
const SEED_BASE := 13000
const V2_SOLVE_CAP := 200000
## Legacy levels where a pass-through exit is reachable within the bounded exploration below
## (the corrected exit rule, D1, removes those moves in v2). Exact set: a change either way fails.
const PASS_THROUGH_LEVELS := [21, 24, 44, 46, 61, 76, 80, 81, 86, 88, 90]
## Levels whose shortest legacy (par) solution itself takes a pass-through exit.
const PAR_PATH_LEVELS := [21, 90]
## Levels whose v2 optimum is solved and compared with the stored par (M1.3-B scope).
const V2_PAR_LEVELS := [21, 80, 90]
const ROOT := "<root>"
const WIN := "<win>"

var _failures := 0
var _checks := 0

func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	_test_catalog()
	var differing: Array = []
	var par_path: Array = []
	var compared_total := 0
	var catalog := CampaignCatalog.levels(CampaignCatalog.CLASSIC)
	for entry in catalog:
		var row := _compare_level(entry)
		compared_total += int(row["compared"])
		if int(row["pass_through"]) > 0:
			differing.append(int(entry["legacy_id"]))
		if bool(row["path_needs_pass_through"]):
			par_path.append(int(entry["legacy_id"]))
		print("ROW %s compared=%d bfs=%d path=%d walk_steps=%d pass_through=%d par_path_needs_pass_through=%s" % [entry["id"], row["compared"], row["bfs"], row["path"], row["walk_steps"], row["pass_through"], str(row["path_needs_pass_through"])])
	differing.sort()
	_check(differing == PASS_THROUGH_LEVELS, "pass-through exits reachable in exactly %s (got %s)" % [str(PASS_THROUGH_LEVELS), str(differing)])
	_check(par_path == PAR_PATH_LEVELS, "shortest legacy solution needs a pass-through exit in exactly %s (got %s)" % [str(PAR_PATH_LEVELS), str(par_path)])
	for n in PAR_PATH_LEVELS:
		_check(n in V2_PAR_LEVELS, "level %d (par path changed) gets the v2 par check" % n)
	for n in V2_PAR_LEVELS:
		_test_v2_par(CampaignCatalog.find(CampaignCatalog.CLASSIC, "legacy-%d" % n))
	print("SUMMARY levels=%d compared_states=%d checks=%d failures=%d secs=%d" % [catalog.size(), compared_total, _checks, _failures, (Time.get_ticks_msec() - t0) / 1000])
	quit(_failures)

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("FAIL ", label)

# --- CampaignCatalog ---------------------------------------------------------------------------

func _test_catalog() -> void:
	var built := CampaignCatalog.build(CampaignCatalog.CLASSIC)
	var levels: Array = built["levels"]
	var paths := Catalog.list_paths()
	_check((built["diagnostics"] as PackedStringArray).is_empty(), "classic catalog has no diagnostics: %s" % str(built["diagnostics"]))
	_check(levels.size() == 100 and paths.size() == 100, "classic has 100 levels (got %d)" % levels.size())
	var ids_ok := true
	for i in levels.size():
		var e: Dictionary = levels[i]
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(paths[i]))
		if str(e["id"]) != "legacy-%d" % (i + 1) or str(e["id"]) != ProgressStore.classic_id(i) \
				or int(e["order"]) != i or str(e["path"]) != paths[i] or int(e["par"]) != int(raw["par"]) \
				or str(e["campaign"]) != CampaignCatalog.CLASSIC:
			ids_ok = false
			print("  bad entry ", e)
	_check(ids_ok, "every entry: id legacy-<index+1> == ProgressStore.classic_id, save order, path and par")
	_check(CampaignCatalog.build(CampaignCatalog.CLASSIC) == built, "build is deterministic")
	var e37 := CampaignCatalog.find(CampaignCatalog.CLASSIC, "legacy-37")
	_check(int(e37.get("order", -1)) == 36 and str(e37.get("path", "")).ends_with("level_037.json"), "find legacy-37 -> order 36, level_037.json")
	_check(CampaignCatalog.find(CampaignCatalog.CLASSIC, "legacy-101").is_empty(), "find unknown id -> {}")
	_check(CampaignCatalog.find(CampaignCatalog.CLASSIC, "legacy-01").is_empty(), "ids are not zero-padded")
	_check(CampaignCatalog.levels(CampaignCatalog.CHAPTER1).is_empty(), "chapter1 has no content yet")
	var unknown := CampaignCatalog.build("nope")
	_check((unknown["levels"] as Array).is_empty() and not (unknown["diagnostics"] as PackedStringArray).is_empty(), "unknown campaign -> no levels, one diagnostic")

# --- Successor sets ----------------------------------------------------------------------------

func _key_legacy(blocks: Array) -> String:
	var parts: Array[String] = []
	for b in blocks:
		parts.append("%s:%d,%d" % [b["id"], b["pos"].x, b["pos"].y])
	parts.sort()
	return "|".join(parts)

func _key_v2(state: PuzzleState) -> String:
	var parts: Array[String] = []
	for id in state.pieces.keys():
		var p: Dictionary = state.pieces[id]
		if bool(p["active"]):
			parts.append("%s:%d,%d" % [id, p["pos"].x, p["pos"].y])
	parts.sort()
	return "|".join(parts)

func _apply(blocks: Array, idx: int, pos: Vector2i, gone: bool) -> Array:
	var out: Array = []
	for j in blocks.size():
		if j == idx and gone:
			continue
		var b: Dictionary = blocks[j]
		out.append({"id": b["id"], "color": b["color"], "cells": b["cells"], "pos": pos if j == idx else b["pos"]})
	return out

## Legacy Play successors {key: {"blocks", "pass_through"}}: every landing 1..max, plus the exit.
func _legacy_succ(level: Level, blocks: Array) -> Dictionary:
	var out := {}
	for idx in blocks.size():
		var b: Dictionary = blocks[idx]
		for dir in Rules.DIRS.keys():
			var full := Rules.slide_result(level, blocks, b, dir, 9999)
			for k in range(1, int(full["steps"]) + 1):
				var ns := _apply(blocks, idx, Rules.slide_result(level, blocks, b, dir, k)["pos"], false)
				out[_key_legacy(ns)] = {"blocks": ns, "pass_through": false}
			if bool(full["exit"]):
				var ne := _apply(blocks, idx, full["pos"], true)
				out[_key_legacy(ne)] = {"blocks": ne, "pass_through": _is_pass_through(level, blocks, b, full["pos"], dir)}
	return out

## The legacy exit defect: the block exits although a wall or another block occupies an in-bounds
## cell directly in front of one of its cells.
func _is_pass_through(level: Level, blocks: Array, block: Dictionary, pos: Vector2i, dir: String) -> bool:
	var occ := Rules._occupancy(level, blocks, block["id"])
	for c in block["cells"]:
		var ahead: Vector2i = c + pos + Rules.dir_vec(dir)
		if Rules._in_bounds(level, ahead) and occ.has(ahead):
			return true
	return false

## Full slides and exits only (the move set Rules.solve_min_moves and par use).
func _legacy_full_succ(level: Level, blocks: Array) -> Dictionary:
	var out := {}
	for idx in blocks.size():
		var b: Dictionary = blocks[idx]
		for dir in Rules.DIRS.keys():
			var full := Rules.slide_result(level, blocks, b, dir, 9999)
			if bool(full["exit"]):
				var ne := _apply(blocks, idx, full["pos"], true)
				out[_key_legacy(ne)] = ne
			elif int(full["steps"]) > 0:
				var ns := _apply(blocks, idx, full["pos"], false)
				out[_key_legacy(ns)] = ns
	return out

func _v2_succ(defn: Dictionary, state: PuzzleState) -> Dictionary:
	var out := {}
	for action in PuzzleEngine.legal_actions(defn, state, ""):
		var applied: Dictionary = PuzzleEngine.transition(state, action, defn)
		if bool(applied["ok"]):
			out[_key_v2(applied["next_state"])] = applied["next_state"]
	return out

## Compares one state. Returns the number of allowed pass-through differences, or -1 on any
## other difference (which is printed).
func _compare(tag: String, key: String, ls: Dictionary, vs: Dictionary) -> int:
	var allowed := 0
	var bad: Array = []
	for k in ls.keys():
		if vs.has(k):
			continue
		if bool(ls[k]["pass_through"]):
			allowed += 1
		else:
			bad.append("legacy-only " + str(k))
	for k in vs.keys():
		if not ls.has(k):
			bad.append("v2-only " + str(k))
	if bad.is_empty():
		return allowed
	print("  %s at [%s]: %s" % [tag, key, str(bad.slice(0, 3))])
	return -1

# --- Per-level comparison ----------------------------------------------------------------------

func _compare_level(entry: Dictionary) -> Dictionary:
	var name := str(entry["id"])
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(entry["path"])))
	var level := Level.from_dict(raw)
	var loaded := LevelLoader.load_definition(raw)
	var row := {"compared": 0, "bfs": 0, "path": 0, "walk_steps": 0, "pass_through": 0, "path_needs_pass_through": false}
	_check(bool(loaded["ok"]), "%s loads as a v2 definition" % name)
	if not bool(loaded["ok"]):
		return row
	var defn: Dictionary = loaded["definition"]
	var start: Array = level.clone_blocks()
	var v2_start := PuzzleState.from_definition(defn)
	_check(_key_legacy(start) == _key_v2(v2_start), "%s start states match" % name)
	var ok := true
	# (a) Bounded BFS over all landings.
	var k0 := _key_legacy(start)
	var legacy_of := {k0: start}
	var v2_of := {k0: v2_start}
	var frontier: Array = [k0]
	var fi := 0
	while fi < frontier.size() and fi < BFS_CAP:
		var key: String = frontier[fi]
		fi += 1
		var ls := _legacy_succ(level, legacy_of[key])
		var vs := _v2_succ(defn, v2_of[key])
		var r := _compare(name + " bfs", key, ls, vs)
		if r < 0:
			ok = false
			break
		row["pass_through"] += r
		for nk in vs.keys():
			if not v2_of.has(nk) and nk != "":
				legacy_of[nk] = ls[nk]["blocks"]
				v2_of[nk] = vs[nk]
				frontier.append(nk)
	row["bfs"] = fi
	_check(ok, "%s BFS successor sets equal (%d states)" % [name, fi])
	# (b) Every state along a shortest legacy solution.
	var path := _shortest_legacy(level, start)
	_check(not path.is_empty(), "%s has a legacy solution within %d states" % [name, SOLVE_CAP])
	if not path.is_empty():
		var r2 := _follow(name + " path", level, defn, path, v2_start)
		row["path"] = path.size() - 1
		row["path_needs_pass_through"] = bool(r2["needs_pass_through"])
		_check(int(r2["allowed"]) >= 0, "%s shortest-solution successor sets equal and v2 wins (or the solution needs a pass-through exit)" % name)
		row["pass_through"] += maxi(int(r2["allowed"]), 0)
	# (c) Seeded random walks.
	var rng := RandomNumberGenerator.new()
	for w in WALKS:
		rng.seed = SEED_BASE + int(entry["legacy_id"]) * 100 + w
		var r3 := _walk(name + " walk %d" % w, level, defn, start, v2_start, rng)
		_check(int(r3["allowed"]) >= 0, "%s walk %d successor sets equal" % [name, w])
		row["walk_steps"] += int(r3["steps"])
		row["pass_through"] += maxi(int(r3["allowed"]), 0)
	row["compared"] = int(row["bfs"]) + int(row["path"]) + int(row["walk_steps"])
	return row

func _shortest_legacy(level: Level, start: Array) -> Array:
	var k0 := _key_legacy(start)
	var parent := {k0: ROOT}
	var store := {k0: start}
	var queue: Array = [k0]
	var head := 0
	while head < queue.size() and head < SOLVE_CAP:
		var key: String = queue[head]
		head += 1
		var succ := _legacy_full_succ(level, store[key])
		for nk in succ.keys():
			var sk: String = WIN if (succ[nk] as Array).is_empty() else nk
			if parent.has(sk):
				continue
			parent[sk] = key
			store[sk] = succ[nk]
			if sk == WIN:
				var out: Array = []
				var c := WIN
				while c != ROOT:
					out.push_front(store[c])
					c = parent[c]
				return out
			queue.append(sk)
	return []

## Follows a legacy block sequence in v2. allowed = pass-through differences seen, or -1 on any
## other difference; needs_pass_through = the sequence itself takes a pass-through exit, so v2
## cannot follow it (those levels get the SolverV2 par check).
func _follow(tag: String, level: Level, defn: Dictionary, path: Array, v2_start: PuzzleState) -> Dictionary:
	var allowed := 0
	var cur := v2_start
	for p in range(path.size() - 1):
		var key := _key_legacy(path[p])
		var ls := _legacy_succ(level, path[p])
		var vs := _v2_succ(defn, cur)
		var r := _compare(tag, key, ls, vs)
		if r < 0:
			return {"allowed": -1, "needs_pass_through": false}
		allowed += r
		var next_key := _key_legacy(path[p + 1])
		if not vs.has(next_key):
			if ls.has(next_key) and bool(ls[next_key]["pass_through"]):
				print("  %s: legacy solution step %d is a pass-through exit" % [tag, p + 1])
				return {"allowed": allowed, "needs_pass_through": true}
			print("  %s: v2 lacks legacy solution step %d" % [tag, p + 1])
			return {"allowed": -1, "needs_pass_through": false}
		cur = vs[next_key]
	if not PuzzleEngine.is_won(defn, cur):
		print("  %s: v2 not won at the end of the legacy solution" % tag)
		return {"allowed": -1, "needs_pass_through": false}
	return {"allowed": allowed, "needs_pass_through": false}

func _walk(tag: String, level: Level, defn: Dictionary, start: Array, v2_start: PuzzleState, rng: RandomNumberGenerator) -> Dictionary:
	var allowed := 0
	var blocks := start
	var cur := v2_start
	var steps := 0
	while steps < WALK_LEN and not blocks.is_empty():
		var key := _key_legacy(blocks)
		var ls := _legacy_succ(level, blocks)
		var vs := _v2_succ(defn, cur)
		steps += 1
		var r := _compare(tag, key, ls, vs)
		if r < 0:
			return {"allowed": -1, "steps": steps}
		allowed += r
		var keys: Array = vs.keys()
		if keys.is_empty():
			break
		keys.sort()
		var pick: String = keys[rng.randi_range(0, keys.size() - 1)]
		blocks = ls[pick]["blocks"]
		cur = vs[pick]
	return {"allowed": allowed, "steps": steps}

# --- Exception levels: v2 optimum == stored par --------------------------------------------------

func _test_v2_par(entry: Dictionary) -> void:
	var name := str(entry.get("id", "?"))
	_check(not entry.is_empty(), "%s is in the Classic catalog" % name)
	if entry.is_empty():
		return
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(entry["path"])))
	var defn: Dictionary = LevelLoader.load_definition(raw)["definition"]
	var start := PuzzleState.from_definition(defn)
	var t0 := Time.get_ticks_msec()
	var res := SolverV2.solve(defn, start, V2_SOLVE_CAP)
	var par := int(entry["par"])
	print("V2PAR %s status=%s length=%d explored=%d par=%d ms=%d" % [name, res["status"], res["solution_length"], res["explored_states"], par, Time.get_ticks_msec() - t0])
	_check(str(res["status"]) == PuzzleEngine.SOLVED, "%s v2 solves within %d states" % [name, V2_SOLVE_CAP])
	_check(int(res["solution_length"]) == par, "%s v2 shortest solution %d == stored par %d" % [name, res["solution_length"], par])
	var cur := start
	var replay_ok := (res["witness"] as Array).size() == par
	for action in res["witness"]:
		var applied: Dictionary = PuzzleEngine.transition(cur, action, defn)
		if not bool(applied["ok"]):
			replay_ok = false
			break
		cur = applied["next_state"]
	_check(replay_ok and PuzzleEngine.is_won(defn, cur), "%s witness (%d moves) replays to a win" % [name, (res["witness"] as Array).size()])
