extends SceneTree
## Design aid for the positioned-gate proposal: enumerates every optimal move sequence of a
## prototype level and summarises them (exit orders, distinct plans, and how many of the legal
## moves at each step keep an optimal solution). Read-only.
##   godot --headless --path . --script res://test/proto_level_analysis.gd -- proto_c.json

const DIR := "res://design/gate_proto/levels/"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var file := args[0] if args.size() > 0 else "proto_c.json"
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + file))
	var defn: Dictionary = LevelLoader.load_definition(raw)["definition"]
	var ctx := PuzzleSearchContext.new()
	ctx.schema_checked = true
	ctx.geometry = PuzzleEngine._geometry(defn)
	ctx.walls = PuzzleEngine._wall_cells(defn)
	ctx.bounds = PuzzleEngine._bounds(defn)
	ctx.simple = PuzzleEngine.is_simple(defn)
	var start := PuzzleState.from_definition(defn)
	# Forward BFS by layers; every state keeps all predecessors one layer up.
	var depth_of := {start.search_key(): 0}
	var preds := {}          # key -> [[pred_key, text], ...]
	var layer: Array = [start]
	var depth := 0
	var wins: Array = []     # [pred_key, text]
	var legal_count := {}    # key -> number of legal actions
	while wins.is_empty() and not layer.is_empty():
		var next_layer: Array = []
		for st in layer:
			var key: String = st.search_key()
			var legal := PuzzleEngine.legal_actions(defn, st, "", ctx)
			legal_count[key] = legal.size()
			for a in legal:
				var nxt: PuzzleState = PuzzleEngine.transition(st, a, defn, ctx)["next_state"]
				var text := _text(a)
				if PuzzleEngine.is_won(defn, nxt, ctx):
					wins.append([key, text])
					continue
				var nk := nxt.search_key()
				if not depth_of.has(nk):
					depth_of[nk] = depth + 1
					preds[nk] = []
					next_layer.append(nxt)
				if int(depth_of[nk]) == depth + 1:
					preds[nk].append([key, text])
		layer = next_layer
		depth += 1
	var par := depth
	var sequences: Array = []
	for w in wins:
		for prefix in _paths_to(str(w[0]), preds, start.search_key()):
			sequences.append(prefix + [w[1]])
	print("== %s: par %d, %d optimal sequences, %d states within par-1 ==" % [file, par, sequences.size(), depth_of.size()])
	# Exit orders, and plans (a plan = the set of moves, ignoring their order).
	var orders := {}
	var plans := {}
	for seq in sequences:
		var exits := PackedStringArray()
		for t in seq:
			if str(t).ends_with(" exit"):
				exits.append(str(t).split(" ")[0])
		var order := " > ".join(exits)
		orders[order] = int(orders.get(order, 0)) + 1
		var sorted_moves: Array = seq.duplicate()
		sorted_moves.sort()
		var plan := " | ".join(PackedStringArray(sorted_moves))
		plans[plan] = int(plans.get(plan, 0)) + 1
	print("-- exit orders (%d)" % orders.size())
	for o in orders.keys():
		print("   %3d  %s" % [orders[o], o])
	print("-- distinct plans, order ignored (%d)" % plans.size())
	for p in plans.keys():
		print("   %3d  %s" % [plans[p], p])
	# Decision pressure: at each move, over the states lying on some optimal sequence, how many
	# legal moves there are and how many of them keep an optimal finish.
	var by_depth := {}
	for seq in sequences:
		var st := start
		for i in seq.size():
			var key := st.search_key()
			if not by_depth.has(i):
				by_depth[i] = {}
			if not by_depth[i].has(key):
				by_depth[i][key] = {}
			by_depth[i][key][seq[i]] = true
			if i < seq.size() - 1:
				st = _apply(defn, st, str(seq[i]), ctx)
	print("-- decision pressure (move: states on optimal paths, legal moves, optimal moves)")
	for i in by_depth.keys():
		var legal := 0
		var good := 0
		for key in by_depth[i].keys():
			legal += int(legal_count.get(key, 0))
			good += (by_depth[i][key] as Dictionary).size()
		print("   move %d: %d state(s), %d legal, %d optimal (%.0f%%)" % [i + 1, by_depth[i].size(), legal, good, 100.0 * good / maxf(1.0, legal)])
	quit(0)

func _paths_to(key: String, preds: Dictionary, start_key: String) -> Array:
	if key == start_key:
		return [[]]
	var out: Array = []
	for link in preds[key]:
		for prefix in _paths_to(str(link[0]), preds, start_key):
			out.append(prefix + [link[1]])
	return out

func _apply(defn: Dictionary, st: PuzzleState, text: String, ctx: PuzzleSearchContext) -> PuzzleState:
	for a in PuzzleEngine.legal_actions(defn, st, "", ctx):
		if _text(a) == text:
			return PuzzleEngine.transition(st, a, defn, ctx)["next_state"]
	return st

func _text(a: PuzzleAction) -> String:
	return "%s exit" % a.piece_id if a.kind == PuzzleAction.EXIT else "%s %s(%d,%d)" % [a.piece_id, a.direction, a.landing.x, a.landing.y]
