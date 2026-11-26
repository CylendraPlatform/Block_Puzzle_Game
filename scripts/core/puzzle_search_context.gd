class_name PuzzleSearchContext
extends RefCounted
## One search's validation scope. Schema checks are skipped only when this
## object is passed into that search after a successful validate_v2 call.
## There is no process-wide bypass.

var schema_checked := false
var geometry := {}
var walls := {}
var bounds := Vector2i.ZERO
var checked_key := ""
var trusted := {}
## True when the level has no triggers, blockers, hidden pieces, or lockable/
## counter/color-switching gates: the post-action resolution loop is then a no-op and
## the solver skips it. Set by SolverV2; never set for untrusted play.
var simple := false

func trust(action: PuzzleAction, key: String) -> void:
	trusted["%d|%s" % [action.get_instance_id(), key]] = action.canonical_text()

func owns(action: PuzzleAction, key: String) -> bool:
	var token := "%d|%s" % [action.get_instance_id(), key]
	return trusted.has(token) and str(trusted[token]) == action.canonical_text()
