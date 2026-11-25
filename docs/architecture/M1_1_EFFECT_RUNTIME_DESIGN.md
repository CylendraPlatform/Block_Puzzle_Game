# M1.1 — Effect / Trigger Runtime: Technical Design (for review)

Status: **design only. Do NOT implement until reviewed.** No PR (#6/#7/#8/#9) merged.
Scope: turn the mechanics the engine currently *fail-closes* into executable, deterministic,
solver-covered runtime. Original implementation only — no reference code/assets.

## 1. Context & boundary (verified)
`PuzzleEngine._uses_unimplemented_mechanics()` today rejects any level using triggers,
blockers, locked gates, gate counters, hidden pieces, rotation, or a non-null timer, and
`SolverV2` refuses them. `PuzzleState` already *stores* the relevant fields
(`gates{mode,counter_remaining}`, `blockers{active,counter_remaining}`, `trigger_fired`,
`pieces{revealed}`, `event_counters`). Schema v2 already *declares* them. **M1.1 adds only
the execution layer**; it does not change the data contract except where noted in §9.

### In scope for M1.1
Locked / conditional gates · triggers + event execution order · counters · blockers
(clearable obstacles) · hidden-piece reveal · **color-switching gate** state transitions.

### Explicitly out of scope (later milestones)
Magnets/drain, grinders, feeders (dispenser/spawner/elevator), sticky pieces, real-time
timer, rotation. These stay **fail-closed** after M1.1. M1.1 must not silently enable them.

## 2. Effect model
An **effect** is a pure data record applied to a `PuzzleState`, returning a new state +
emitted events. Proposed module `scripts/core/effects.gd`:

```
Effect = { "type": String, "target": String, "args": Dictionary }
apply(effect, state, defn, ctx) -> { "state": PuzzleState, "events": Array[PuzzleEvent] }
```

M1.1 effect types (each deterministic, no RNG, no real time):
| type | target | result |
|------|--------|--------|
|`open_gate`|gate id|`gates[id].mode = OPEN`; emit `GATE_OPENED`|
|`lock_gate`|gate id|`gates[id].mode = LOCKED`; emit `GATE_LOCKED`|
|`decrement_counter`|gate id|`counter_remaining -= 1` (floor 0); emit `COUNTER_ZERO` when it hits 0|
|`reveal_piece`|piece id|`pieces[id].revealed = true`; emit `PIECE_REVEALED`|
|`clear_blocker`|blocker id|`blockers[id].active = false`; emit `BLOCKER_CLEARED`|
|`set_gate_color`|gate id|replace `gates[id]` accepted color/phase (color-switching, §7)|

Effects validate their target exists; an unknown target is an engine reject (fail-closed),
never a silent no-op.

## 3. Trigger model & event execution order
A **trigger** fires effects in response to events. Schema already allows a condition that is
`all` / `any` / a single event, a `count`, and `decrement_counter` tied to a gate counter.

```
Trigger = { "id": String, "when": Condition, "once": bool (default true), "effects": [Effect] }
Condition = { "event": "piece_exited"|"piece_moved"|"counter_zero"|"gate_opened",
              "piece"?: id, "color"?: str, "gate"?: id, "count"?: int>=1 }
          | { "all": [Condition] } | { "any": [Condition] }
```

**Execution order (deterministic, the core of M1.1):**
1. Player action commits (`MOVE`/`EXIT`) → base events (`PIECE_MOVED`/`PIECE_EXITED`).
2. Enter a **resolution loop** (inside `transition()`, folded into the returned next-state):
   a. Collect the current pending event set.
   b. Evaluate **all** triggers in **sorted trigger-id order**; a trigger whose `when` is
      satisfied by the accumulated event history and not yet fired (`trigger_fired[id]`,
      when `once`) is selected.
   c. Apply selected triggers' effects in `(trigger-id, effect-index)` order; mark fired;
      collect newly emitted events.
   d. Repeat from (a) with the new events until no new trigger fires.
3. **Cascade guard:** the loop is bounded by the existing `MAX_CASCADE = 32` iterations;
   exceeding it is an engine reject (`CASCADE_LIMIT`), surfaced as INVALID_LEVEL to the
   solver so no infinite/ambiguous level can ship.
Determinism rules (mandatory): sorted-id iteration everywhere, no dictionary-order reliance,
no RNG, no wall-clock. Same input state + action ⇒ byte-identical next state and event list.

## 4. Counters
`gates[id].counter_remaining` already in state. `decrement_counter` lowers it; reaching 0
emits `COUNTER_ZERO`, which a trigger typically maps to `open_gate` (the canonical
"exit N blue pieces to open the red gate" pattern). Counter never goes negative; a
decrement at 0 is a no-op that emits nothing (documented, deterministic).

## 5. Locked / conditional gates
`initial_state: locked` starts `mode = LOCKED`; a locked gate is **not** a valid exit in
`_matching_gates` (already checks `mode == "OPEN"`). A gate opens only via an `open_gate`
effect fired by a trigger/counter. Conditional gates are thus just locked gates + a trigger.
No new matching logic needed beyond honoring `mode`.

## 6. Blockers & hidden pieces
- **Blocker:** a cell-occupying obstacle with `active` + optional `counter_remaining`. While
  active it occupies cells (added to `_occupied`), blocking slides; `clear_blocker` (via a
  trigger, possibly counter-gated) deactivates it. Solver treats a cleared blocker as freed
  space in subsequent states.
- **Hidden piece:** `reveal: hidden` starts `revealed = false`. A hidden piece is **inert**
  (not movable, not required-satisfying) until a `reveal_piece` effect sets `revealed`. On
  reveal it becomes an ordinary active piece. `is_won` must count a required hidden piece as
  unsatisfied until revealed-and-exited (today `is_won` counts required pieces by active
  flag; extend to require revealed+exited).

## 7. Color-switching gate — state transitions (highest-risk item)
Two modeling options; **recommend Option A** for solver soundness.

- **Option A — derive from move index (recommended).** The gate's accepted color is a pure
  function of a *bounded* phase: `color = schedule[(move_number) % period]`. No extra stored
  gate state; but because it depends on `move_number`, the search key MUST include
  `move_number % period` (see §8). Fully deterministic; bounded phase keeps the search finite.
- **Option B — explicit stored phase.** Store `gates[id].phase` in state, advanced by a
  forced post-move effect. More flexible (event-driven switching) but grows the key and risks
  larger search. Use only if a level needs non-periodic switching.

Schema addition (needed, §9): `gates[].color_schedule: [color,...]` (non-empty) and optional
`gates[].period` (defaults to schedule length). `accept` remains the static case
(schedule absent). A gate is color-switching **iff** `color_schedule` is present.
`_matching_gates` consults the current scheduled color instead of static `accept` for such
gates. "Laser door" is a schedule of open/closed phases — modeled later; M1.1 does the
color schedule only.

## 8. Deterministic state hashing
`PuzzleState.canonical_text()` / `search_key()` already serialize pieces (pos/active/
revealed), gates (mode/counter), blockers (active/counter), counters, triggers.
Extensions for M1.1:
- Color-switching Option A: append `gate <id> phase=<move_number % period>` to **`search_key`**
  (which otherwise excludes `move_number`). This is essential — two boards identical except
  for gate phase are different search states; omitting it makes the solver unsound.
- Color-switching Option B: append `gate <id> phase=<stored phase>`.
- No other field changes; `revealed`, blocker `active`, `trigger_fired` already serialized.
Acceptance: a determinism test asserts `canonical_hash()` is identical across repeated runs
and that two distinct phases never collide.

## 9. Minimal schema changes
Nearly all fields already exist. New, additive, behind the validator:
- `gates[].color_schedule` (array of color strings, len ≥ 1) and `gates[].period` (int ≥ 1).
- Allowlist these in `LevelValidator` (unknown-field rejection currently blocks them).
- Everything else (locked gates, counters, triggers, blockers, hidden) needs **no** schema
  change — only lifting the runtime fail-close for the *implemented* subset.
Migration: additive; existing v2 pilot/campaign/benchmark levels remain valid unchanged.

## 10. Undo / restart compatibility
`PuzzleEngine.transition()` returns a full immutable next-state; the game controller keeps an
**undo stack of whole `PuzzleState` snapshots** (it already stores prior states for v1).
Because effects are folded into the committed next-state, one committed action = one undo
entry, even if it cascaded multiple effects. Undo = restore the previous snapshot (gates,
counters, blockers, reveals, trigger_fired all revert together — they are in the state).
Restart = `PuzzleState.from_definition(defn)`. Requirement: the undo stack must store the
**post-cascade** state per move (not intermediate effect states) so undo is move-granular and
consistent with the solver's one-action-per-edge model.

## 11. SolverV2 integration
- `SolverV2` expands only engine-produced actions and verifies the witness; once
  `_uses_unimplemented_mechanics()` stops rejecting the **implemented** subset, the solver
  covers these mechanics automatically with no solver algorithm change.
- `_uses_unimplemented_mechanics()` is narrowed to still fail-close **only** the
  out-of-scope mechanics (magnets, grinders, feeders, sticky, rotation, real-time timer).
- State-explosion guard: color-switching multiplies states by `period`; keep schedules short
  (≤4) in M1.1 content and keep the `max_states` cap honest — report
  `UNKNOWN_CAP_REACHED` as a recorded limitation, never as unsolvable.

## 12. Regression & acceptance tests
New fixtures under `test/fixtures/v2/` + a runner (pattern of `test/solve_benchmarks.gd`):
1. **Locked gate + trigger** ("Gatekeeper"): exit color-A opens color-B's gate → SOLVED,
   known length, witness replays; fail-close lifted only for this.
2. **Counter gate**: exit N pieces → `COUNTER_ZERO` → `open_gate` → SOLVED.
3. **Blocker clear**: trigger clears a blocker that frees a lane → SOLVED.
4. **Hidden reveal** ("Hidden Hand"): reveal via effect, revealed piece must exit → SOLVED;
   `is_won` false while hidden-required unrevealed.
5. **Color-switching gate** ("Shiftgate", Option A): piece must reach gate on the matching
   phase → SOLVED; **determinism test** (identical hash/witness across runs) + key-includes-
   phase test + no-collision test.
6. **Cascade guard**: a pathological trigger loop hits `MAX_CASCADE` → `CASCADE_LIMIT` reject.
7. **Regression**: existing `test_rules`, `validate_all`, `test_v2_pilot`, `test_v2_solver`,
   `solve_benchmarks` stay green; out-of-scope mechanics still fail-closed.
8. **Undo/restart**: scripted move→undo returns the exact prior hash; restart = initial hash.
Acceptance for M1.1 = all above pass headless; no regression; determinism proven; fail-close
intact for deferred mechanics. On-device/APK verification follows per roadmap M0.2/M3.

## 13. Risks (carried from RISKS_AND_FEASIBILITY)
Cascade ambiguity (mitigated by sorted order + MAX_CASCADE), key growth from color phase
(mitigated by short bounded schedules + phase-in-key), and accidental enablement of
out-of-scope mechanics (mitigated by explicit narrowed fail-close + regression test 7).

## 14. Deliverable of this milestone
Reviewed design (this doc) → implementation PR (separate, not started) containing:
`scripts/core/effects.gd`, engine resolution loop, narrowed fail-close, `LevelValidator`
color-schedule allowlist, `search_key` phase extension, fixtures + runners, and the three
advanced benchmarks (Gatekeeper / Hidden Hand / Shiftgate) solver-verified.
