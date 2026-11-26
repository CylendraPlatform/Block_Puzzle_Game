class_name GateRules
extends RefCounted
## Canonical gate configuration + state-transition semantics (M1.1 Phase A).
##
## A gate's effective openness is a deterministic function of its authored config
## and the live state. Ambiguous or contradictory configs are rejected at
## validation time rather than silently resolved.
##
## Transition table (initial_state x unlock_when x counter):
##   open   + no mechanism            -> STATIC_OPEN   (always open)
##   open   + unlock_when or counter  -> CONFLICT      (open gate needs no unlock)
##   locked + no mechanism            -> CONFLICT      (no way to ever open)
##   locked + unlock_when only        -> UNLOCK_WHEN   (opens when condition holds)
##   locked + counter only            -> COUNTER       (opens when remaining == 0)
##   locked + unlock_when AND counter -> CONFLICT      (ambiguous: two mechanisms)

const STATIC_OPEN := "static_open"
const UNLOCK_WHEN := "unlock_when"
const COUNTER := "counter"
const CONFLICT := ""

## Classify a schema-valid gate's unlock mechanism. Returns CONFLICT ("") for an
## ambiguous or contradictory configuration (which validate_config rejects).
static func classify(gate: Dictionary) -> String:
	var initial := str(gate.get("initial_state", "open"))
	var mechanisms := int(gate.has("unlock_when")) + int(gate.has("counter"))
	if initial == "open":
		return STATIC_OPEN if mechanisms == 0 else CONFLICT
	if mechanisms == 0 or mechanisms > 1:
		return CONFLICT
	return UNLOCK_WHEN if gate.has("unlock_when") else COUNTER

## Append a GATE_STATE_CONFLICT diagnostic (shape {code, path, message}) when the
## gate's open/locked + unlock_when + counter combination is ambiguous.
static func validate_config(gate: Dictionary, path: String, diags: Array) -> void:
	var initial := str(gate.get("initial_state", "open"))
	var has_unlock := gate.has("unlock_when")
	var has_counter := gate.has("counter")
	# Self-only contradictions (independent of triggers). The locked-gate "needs a
	# source" and "exactly one source" checks live in the validator's cross-reference
	# pass, because an external unlock_gate trigger can also be a gate's unlock source.
	if initial == "open" and (has_unlock or has_counter):
		diags.append(_diag(path, "An open gate must not define unlock_when or counter."))
	elif initial == "locked" and has_unlock and has_counter:
		diags.append(_diag(path, "A locked gate must not define both unlock_when and counter."))

static func _diag(path: String, message: String) -> Dictionary:
	return {"code": "GATE_STATE_CONFLICT", "path": path, "message": message}

## A color-switching gate accepts one color per phase (period = schedule length).
static func is_color_switching(gate: Dictionary) -> bool:
	return gate.has("color_schedule")

## The accepted color at a given phase. phase advances one per committed action.
static func scheduled_color(gate: Dictionary, phase: int) -> String:
	var schedule: Array = gate["color_schedule"]
	return str(schedule[phase % schedule.size()])
