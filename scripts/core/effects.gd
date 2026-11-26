class_name Effects
extends RefCounted
## Pure effect application for M1.1. Each effect mutates the candidate next-state in
## place (the engine only publishes it on full success) and appends ordered events.
## Returns false on an invalid target, which makes the whole transition roll back.
## Effect types are the canonical EFFECT_TYPES: reveal_piece, unlock_gate,
## decrement_counter, remove_blocker.

static func apply(effect: Dictionary, state: PuzzleState, events: Array) -> bool:
	match str(effect.get("type", "")):
		"reveal_piece":
			var pid := str(effect.get("piece_id", ""))
			if not state.pieces.has(pid):
				return false
			state.pieces[pid]["revealed"] = true
			events.append(PuzzleEvent.make(PuzzleEvent.PIECE_REVEALED, pid, 2))
			return true
		"unlock_gate":
			var gid := str(effect.get("gate_id", ""))
			if not state.gates.has(gid):
				return false
			if str(state.gates[gid]["mode"]) != "OPEN":
				state.gates[gid]["mode"] = "OPEN"
				events.append(PuzzleEvent.make(PuzzleEvent.GATE_UNLOCKED, gid, 2))
			return true
		"decrement_counter":
			var cgid := str(effect.get("gate_id", ""))
			if not state.gates.has(cgid):
				return false
			var remaining := int(state.gates[cgid]["counter_remaining"])
			if remaining > 0:
				state.gates[cgid]["counter_remaining"] = remaining - 1
				events.append(PuzzleEvent.make(PuzzleEvent.GATE_COUNTER_CHANGED, cgid, 2))
			return true
		"remove_blocker":
			var bid := str(effect.get("blocker_id", ""))
			if not state.blockers.has(bid):
				return false
			if bool(state.blockers[bid]["active"]):
				state.blockers[bid]["active"] = false
				events.append(PuzzleEvent.make(PuzzleEvent.BLOCKER_REMOVED, bid, 2))
			return true
	return false
