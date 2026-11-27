extends SceneTree
## Gate-span report for the 100 Classic levels (read-only; prints, writes nothing).
## For every gate after LevelLoader conversion: side, lo..hi, span vs the edge length, and
## whether other gates share the same edge (overlapping ranges for different colours).
##   godot --headless --path . --script res://test/report_gate_spans.gd

func _initialize() -> void:
	var files := DirAccess.get_files_at("res://levels")
	files.sort()
	var total := 0
	var by_class := {"full": 0, "partial": 0, "single": 0}
	var by_ratio := {}
	var levels_with_partial: Array = []
	var shared_edges := 0
	var overlapping := 0
	var per_level_full := {}
	var example := ""
	for f in files:
		if not f.ends_with(".json"):
			continue
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/" + f))
		var defn: Dictionary = LevelLoader.load_definition(raw if raw is Dictionary else {})["definition"]
		var cols := int(defn["board"]["cols"])
		var rows := int(defn["board"]["rows"])
		var sides := {}
		var full_here := 0
		for gate in defn.get("gates", []):
			total += 1
			var side := str(gate["side"])
			var lo := int(gate["lo"])
			var hi := int(gate["hi"])
			var edge := rows if side == "left" or side == "right" else cols
			var span := hi - lo + 1
			var klass := "full" if span == edge else ("single" if span == 1 else "partial")
			by_class[klass] += 1
			var key := "%d/%d" % [span, edge]
			by_ratio[key] = int(by_ratio.get(key, 0)) + 1
			if klass != "full" and not levels_with_partial.has(f.get_basename()):
				levels_with_partial.append(f.get_basename())
			if klass == "full":
				full_here += 1
			if not sides.has(side):
				sides[side] = []
			for prev in sides[side]:
				shared_edges += 1
				if lo <= int(prev[1]) and int(prev[0]) <= hi:
					overlapping += 1
			sides[side].append([lo, hi])
			if f == "level_054.json":
				example += " %s %d..%d (%d/%d, accept %s)" % [side, lo, hi, span, edge, gate.get("accept", [])]
		per_level_full[full_here] = int(per_level_full.get(full_here, 0)) + 1
	print("gates=%d  full-edge=%d  partial=%d  single-cell=%d" % [total, by_class["full"], by_class["partial"], by_class["single"]])
	var keys := by_ratio.keys()
	keys.sort()
	print("span/edge counts: ", ", ".join(keys.map(func(k): return "%s x%d" % [k, by_ratio[k]])))
	print("levels with any non-full gate: %d %s" % [levels_with_partial.size(), levels_with_partial])
	print("gate pairs sharing an edge: %d (overlapping ranges: %d)" % [shared_edges, overlapping])
	var counts := per_level_full.keys()
	counts.sort()
	print("levels by number of full-edge gates: ", ", ".join(counts.map(func(k): return "%d:%d" % [k, per_level_full[k]])))
	print("level_054:", example)
	quit(0)
