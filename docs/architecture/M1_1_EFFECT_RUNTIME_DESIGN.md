# M1.1 — Effect / Trigger Runtime: Technical Design (rev 2, conditional-approval pass)

Status: **design only. Do NOT implement until reviewed.** No PR (#6/#7/#8/#9) merged.
Rev 2 corrects rev 1 against the **actual** `LevelValidator` contract and answers the seven
review items. Original implementation only — no reference code/assets.

## 0. Corrections to rev 1 (no silent changes)
Rev 1 invented names that do **not** exist in `scripts/core/level_validator.gd`. They are
retracted and replaced by the real contract (§1):
| rev 1 (wrong) | canonical (authoritative) |
|---|---|
|`effects: [ ... ]` array|**singular** `effect: { ... }`|
|`open_gate`|`unlock_gate`|
|`clear_blocker`|`remove_blocker`|
|`lock_gate`|**removed** — no re-lock effect exists in M1.1|
|`set_gate_color`|**removed** — color-switching is data (`color_schedule`), not an effect|
|events `piece_moved`/`counter_zero`/`gate_opened`|**removed** — only `piece_exited` and `color_exits_at_least` exist|

## 1. Canonical schema contract (authoritative — read from `LevelValidator`)
Constants (verbatim): `COLORS = [red,blue,green,yellow,orange,purple]`,
`SIDES = [left,right,top,bottom]`, `GATE_STATES = [open,locked]`,
`REVEALS = [visible,hidden]`, `CONDITION_EVENTS = [piece_exited, color_exits_at_least]`,
`EFFECT_TYPES = [reveal_piece, unlock_gate, decrement_counter, remove_blocker]`.

- **Trigger** = `{id, when, effect}` (fields `TRIGGER_FIELDS`). Exactly **one** `effect`.
- **Condition** (`when`, and gate `unlock_when`):
  - compound: `{all:[...]}` or `{any:[...]}` (non-empty, not both);
  - leaf: `{event|type: "piece_exited", piece_id}` or
    `{event|type: "color_exits_at_least", color, count≥1}` (`event` and `type` are synonyms).
- **Effect** (singular): `reveal_piece{piece_id}` · `unlock_gate{gate_id}` ·
  `decrement_counter{gate_id}` (gate must own a `counter`) · `remove_blocker{blocker_id}`.
- **Gate** = `{id, side, lo, hi, accept[], initial_state∈{open,locked}, unlock_when?, counter?}`;
  `counter = {remaining:int≥0}`.
- **Blocker** = `{id, cell:[x,y], counter_remaining?}` — occupies **one** cell.
- **Piece** = `{id, cells, pos, color, required?, reveal∈{visible,hidden}}`.

This is the single canonical contract. M1.1 **executes** it; it does not rename it.

## 2. Schema changes M1.1 introduces (explicit, additive, migration-tested)
Only **one** additive change is required; everything else is already in the contract.

**2a. Color-switching gate — new optional fields** (needed for §6 / review item 4):
- Add to `GATE_FIELDS`: `color_schedule` (array of `COLORS`, length ≥ 1) and `period`
  (int ≥ 1, default = `color_schedule.length`).
- Validation: if present, `color_schedule` entries must be in `COLORS`; `accept` **stays
  required** and must equal the set of `color_schedule` colors (consistency check) so static
  tooling and `accept`-based references keep working.
- `_reject_unknown` currently blocks these fields → the validator change is explicit here.
- **Compatibility:** absent `color_schedule` ⇒ today's static gate, byte-for-byte unchanged.
- **Migration tests (2a):** (i) every existing `levels_v2/**` and `test/fixtures/v2/**`
  level still validates unchanged; (ii) a gate with a valid `color_schedule` validates;
  (iii) `color_schedule` with an unknown color, empty list, bad `period`, or
  `accept`≠schedule-set is rejected with a precise diagnostic.

No other schema change. `counter`, `unlock_when`, `reveal`, `blocker`, `trigger.effect`
are used **as already defined**. Re-locking and author priority are **not** added in M1.1.

## 3. Trigger semantics (review item 3 — exhaustive)
Event model: the engine keeps per-level **cumulative** `event_counters` (e.g. exits per
color) plus the **current committed action's** events. A trigger's `when` is evaluated after
each committed player action against (cumulative counters ∪ this action's events).

- **`once=true` (default):** fires at most once per level. On fire, `trigger_fired[id]=true`;
  never re-evaluated to fire again.
- **`once=false`:** may fire on multiple committed actions, **at most once per committed
  action**, on each action whose event set satisfies `when`. To keep this sound, M1.1
  **requires effects to be idempotent when `once=false`.** `unlock_gate`, `reveal_piece`,
  `remove_blocker` are idempotent. `decrement_counter` is **not** → the validator **requires
  `once=true` (or omitted) for any trigger whose effect is `decrement_counter`** (new
  validator rule, migration-tested). `once` itself is not yet a schema field; adding it is a
  second explicit additive change (`TRIGGER_FIELDS += "once"`, default true) with the same
  migration-test treatment as §2a. If review prefers zero new trigger fields in M1.1, drop
  `once=false` entirely and treat **all** triggers as `once=true` (simplest; recommended).
- **Repeated events:** `piece_exited` for piece X fires its trigger only on the action where
  X exits (X exits once). `color_exits_at_least{color,count}` is a **threshold on the
  cumulative counter**; it becomes—and stays—satisfied once `counter[color] ≥ count`.
- **`all` / `any`:** `all` = every subcondition currently satisfied; `any` = at least one.
  Evaluated against the same cumulative+action state; no short-circuit side effects.
- **Event history scope:** whole-level cumulative for `color_exits_at_least`; current-action
  for `piece_exited`. Stored in `event_counters` (now a first-class, serialized part of
  state — see §4/§5).
- **Conflicting effects:** triggers are resolved in **sorted trigger-id order**; effects
  apply sequentially in that order. All M1.1 effects are monotonic (unlock, reveal, remove)
  or guarded `once=true` (decrement), so order yields one deterministic result; there is no
  true conflict. **No author-defined priority in M1.1.**
- **Cascade counting & termination:** one *pass* over all triggers = one cascade step; the
  loop repeats while a pass fired at least one new trigger, bounded by the existing
  `MAX_CASCADE = 32`. Termination is guaranteed by monotonic progress (the fired-set grows
  and counters only decrease, both finite); `MAX_CASCADE` is a safety net. Exceeding it is a
  hard engine reject `CASCADE_LIMIT` (surfaced as INVALID_LEVEL to the solver).
- **Atomic failure & rollback:** resolution builds a **candidate** next-state; if any effect
  references a missing target or violates an invariant, the **entire committed action is
  rejected** (`transition` returns `ok=false`) and the **input state is returned unchanged**
  — rollback is free because the engine is immutable and only ever publishes a fully-resolved
  next-state. Partial effect application can never be observed.

## 4. Color schedules (review item 4 — Option A)
- Phase is derived from the **committed-action count** (`move_number`), not wall-clock.
- `accepted_color(gate, move_number) = color_schedule[ move_number % period ]`,
  `period = color_schedule.length` unless a concrete need justifies a distinct `period`.
- **Resolution timing (pre-action):** when deciding whether a candidate EXIT is legal, the
  gate color is resolved at the **pre-action** phase `move_number % period` — the phase the
  player sees at the moment of the move. The action then commits and `move_number` increments,
  advancing the phase for the **next** action. This is specified so the solver and the UI
  agree on which color a move must match.
- **Search-key representation (mandatory, §5):** for every color-switching gate, the key
  includes `move_number % period`. Two boards identical except for phase are distinct search
  states; omitting phase makes `SolverV2` unsound. Because `period` is small, the state-space
  multiplier is bounded.

## 5. Dynamic state validation (review item 2 — the core correction)
**Problem (verified):** `PuzzleEngine._state_problem()` compares live gate `mode`/
`counter_remaining` against `_expected_gates(definition)` (the **initial** values), blockers
against `_expected_blockers` (initial), the trigger-id set against the definition, and
**rejects any non-empty `event_counters`**. So a legitimately mutated state (gate unlocked,
counter decremented, blocker removed, piece revealed, cumulative exits recorded) is rejected
as `STATE_MISMATCH`. This is the real reason advanced mechanics are fail-closed.

**Redesign — validate integrity by invariants, not equality-to-initial:**
`_state_problem` is split into **structural** checks (unchanged) and **value** checks
(relaxed from equality to monotonic bounds):
- Structural (keep): `schema_version==2`, `level_id` matches, piece-id set == geometry,
  gate/blocker/trigger id **sets** == definition, positions integer & in-bounds, active
  pieces don't overlap walls or each other, correct value types.
- Value invariants (new, accept any *reachable* mutation, reject the impossible):
  - gate `mode ∈ {OPEN,LOCKED}`; `counter_remaining ∈ [0, initial_remaining]` (monotone
    non-increasing); a gate with **no unlock path** (not `initial open`, no `unlock_when`,
    no `counter`) must not be `OPEN` (structurally impossible → reject).
  - blocker `active ∈ {true,false}`; `counter_remaining ∈ [0, initial]`.
  - piece `revealed`: a piece authored `visible` must stay `revealed=true`; an authored
    `hidden` piece may be either (reject a `visible` piece that is `revealed=false`).
  - `trigger_fired[id] ∈ {true,false}` for exactly the definition's trigger ids.
  - `event_counters`: **now permitted**; keys ⊆ `COLORS` (+ reserved internal keys),
    values are integers in `[0, total required pieces of that color]`. Non-empty is legal.
- **Reachable-state integrity without breaking SolverV2:** full reachability (that a state is
  actually reachable from the initial state) is **not** proven per call — that would be as
  expensive as solving. Instead:
  - **Solver / in-search states are trusted by construction.** `SolverV2` only ever holds
    states produced by `transition()` from the initial state, under a `PuzzleSearchContext`
    with `schema_checked=true`. The relaxed invariant check is cheap and never rejects an
    engine-produced state, so solver soundness and performance are preserved.
  - **Externally-supplied states (loaded save / resumed session) get integrity, not a
    reachability proof.** The invariant check above rejects fabricated/structurally-impossible
    states (out-of-range counters, illegally-open gates, revealed-visible contradictions,
    overlaps, id-set mismatch). For tamper-resistance where it matters, the save stores the
    **initial definition id + the committed action log**; on load the engine **replays the
    log from `from_definition`** and compares `canonical_hash()` — this *proves* reachability
    cheaply (replay is linear in moves) without changing the solver. Replay-on-load is the
    authoritative integrity gate; the invariant check is the fast first filter.
- This removes the fail-close for the implemented mechanics while making forged states
  (e.g. "all gates open, counters at 0, nothing exited") detectable.

## 6. Hidden pieces, counters, unlock_when, required completion (review item 5)
- **Hidden pieces occupy cells before reveal.** An authored `reveal:hidden` piece is present
  on the board and **blocks movement** (counted in `_occupied`) from the start, but is
  **not movable and cannot exit** until revealed. `legal_actions`/`_actions_for_piece` skip
  pieces with `revealed=false`. `reveal_piece` sets `revealed=true`, after which it behaves
  as an ordinary piece. (Rejected alternative: ghost pieces that don't occupy — inconsistent
  with the current occupancy model and less interesting; documented as rejected.)
- **`unlock_when`:** a declarative condition on a gate. A gate that is `initial_state:locked`
  (or counter-locked) becomes OPEN as soon as its `unlock_when` holds, evaluated
  **deterministically after each committed action** against cumulative+action events. It needs
  **no trigger**. Precedence: a gate is OPEN iff `(initial_state==open AND counter satisfied)`
  OR `unlock_when` satisfied OR its `counter.remaining==0`.
- **Counters & "counter zero":** a gate's `counter.remaining` starts the gate **counter-locked**
  (not a valid exit) while `remaining>0`. A trigger whose effect is `decrement_counter`
  lowers it on `piece_exited`/`color_exits_at_least`. When `remaining` reaches **0** the gate
  becomes OPEN (the internal "counter-zero" rule) — there is **no author-facing
  `counter_zero` condition**, so no new condition type is added. Decrement at 0 is a no-op.
- **Required-piece completion:** `is_won` requires every `required` piece to have exited.
  Extension: a `required` **hidden** piece counts as incomplete until it is **revealed and
  exited**; an unrevealed required piece keeps the level unwon. Non-required pieces never
  block the win. (Hidden pieces still occupy cells regardless of required.)

## 7. Solver performance strategy (review item 6)
Baseline (from `solve_benchmarks`): bm-003 = 29,666 expansions in 157.9 s (~5 ms/state).
Root cause: per-expansion re-derivation (occupancy rebuilt per piece/direction; `_state_problem`
re-run on key change) despite cached geometry/walls/bounds. Correctness-preserving plan:
1. **Trust in-search states:** skip `_state_problem` for states produced inside the solver
   (already partially gated by `PuzzleSearchContext`); formalize a `trusted` flag set only on
   engine-produced successors.
2. **Memoize occupancy** per state once (not per piece×direction); reuse across the four
   directions and the exit scan.
3. **Incremental `search_key`** (update the changed piece/gate lines instead of rebuilding
   the whole canonical text + SHA per state).
4. **Resource caps, honest reporting:** keep `max_states`; add an optional **wall-clock
   budget** and **explored-state budget**; on exceed return `UNKNOWN_CAP_REACHED` — recorded
   as a limitation, **never** labeled unsolvable (review item 4 of the prior round).
5. **Profiling mode:** a `--profile` path in the benchmark runner that reports time split
   across `legal_actions` / `transition` / hashing, committed as evidence.
**Gate:** an advanced level is only accepted into content if the solver verifies it within a
defined budget (target: well under the current per-state cost after 1–3) **or** it is
explicitly flagged `UNKNOWN_CAP_REACHED` with the profile attached. No expensive advanced
level ships unverified.

## 8. Undo / restart compatibility
Unchanged from rev 1 and consistent with the above: the controller keeps an **undo stack of
whole post-cascade `PuzzleState` snapshots**; one committed action (incl. its cascade) = one
undo entry; undo restores the previous snapshot (gates, counters, blockers, reveals,
`trigger_fired`, `event_counters` all revert together). Restart = `from_definition`. Because
state is immutable and effects are folded into the committed next-state, undo/restart need no
special per-mechanic logic.

## 9. SolverV2 integration
`SolverV2` expands only engine actions and replays the witness. Narrow
`_uses_unimplemented_mechanics()` to fail-close **only** out-of-scope mechanics (magnets,
grinders, feeders, sticky, rotation, real-time timer); the implemented subset (locked/
conditional gates, triggers, counters, blockers, hidden reveal, color schedules) is allowed.
The relaxed `_state_problem` (§5) never rejects engine-produced states, so the BFS, witness
replay, and `SOLVED/UNSOLVABLE/UNKNOWN_CAP_REACHED` contract are unchanged.

## 10. Acceptance & regression test matrix (review item 7)
Headless fixtures under `test/fixtures/v2/` + runners (pattern of `solve_benchmarks.gd`):
1. **Schema compatibility:** all existing levels validate unchanged; canonical names
   (`effect`, `unlock_gate`, `remove_blocker`, …) accepted; rev-1 names rejected.
2. **Schema additions:** `color_schedule`/`period` (and `once`, if adopted) validate; bad
   variants rejected with precise diagnostics (migration tests §2a / §3).
3. **Locked gate + trigger** ("Gatekeeper"): `piece_exited` → `unlock_gate` → SOLVED, known
   length, witness replay.
4. **Counter gate:** `decrement_counter` to 0 opens the gate → SOLVED; decrement-at-0 no-op.
5. **`unlock_when` gate:** `color_exits_at_least` opens a gate with no trigger → SOLVED.
6. **Blocker clear** ("…"): `remove_blocker` frees a lane → SOLVED.
7. **Hidden reveal** ("Hidden Hand"): hidden piece occupies+blocks, is immovable until
   `reveal_piece`, then must exit; `is_won` false while a required hidden piece is unrevealed.
8. **Color phases** ("Shiftgate"): pre-action color resolution; key includes `move%period`;
   determinism (identical hash/witness across runs); distinct phases never collide.
9. **Trigger semantics:** `once=true` fires once; `once=false` (if adopted) idempotent-only;
   `all`/`any`; repeated events; **effect conflict** resolves by sorted id deterministically.
10. **Rollback:** an effect with a missing target rejects the whole action; state hash
    unchanged (byte-identical to pre-action).
11. **Legitimate mutation accepted / forged state rejected:** `_state_problem` accepts a
    replayed mutated state; rejects fabricated states (illegally-open gate, out-of-range
    counter, revealed-visible contradiction, id-set mismatch, "all-open/all-zero").
12. **Undo / restart:** move→undo returns the exact prior `canonical_hash`; restart = initial.
13. **Deterministic solver replay:** solving a fixture twice yields identical witness, length,
    and explored count.
14. **Performance:** a profiled benchmark meets its state/time budget, or is flagged
    `UNKNOWN_CAP_REACHED` with the profile recorded.
15. **Legacy regression:** `test_rules`, `validate_all`, `test_services`, `test_drag`,
    `test_v2_*`, `solve_benchmarks` all green; out-of-scope mechanics still fail-closed.

## 11. Open decisions for final review
- **`once` field:** adopt `once=false` (idempotent-only, validator-enforced) **or** keep all
  triggers `once=true` for M1.1. Recommendation: **all `once=true`** (simplest, zero new
  trigger field) unless a benchmark needs repetition.
- **Save integrity depth:** fast invariant filter only, or invariant filter **plus**
  replay-on-load hash check. Recommendation: **both** (§5), replay-on-load authoritative.
- **`period` ≠ schedule length:** allowed by schema but discouraged; enable only on a
  concrete level need.

## 12. Remaining risks
- `_state_problem` relaxation must not become so permissive it accepts an unreachable state as
  valid outside the solver → mitigated by replay-on-load (§5) as the authoritative gate.
- Color-phase key growth → bounded by small `period` + phase-in-key; watched via §7 caps.
- Performance work (§7) must land **before** dense advanced levels, or those levels exceed the
  solver budget → sequence §7 ahead of advanced content in the implementation PR.
- Scope creep into out-of-scope mechanics → explicit narrowed fail-close + regression test 15.
