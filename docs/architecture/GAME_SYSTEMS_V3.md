# Game Systems Architecture V3 (Phase REA-02 proposal — for review)

Goal: reach broad *functional* parity with the reference's single-player gameplay depth
while keeping our **deterministic, solver-verified, original** foundation. This proposal
**extends** the v2 engine; it does **not** rewrite it. Live-ops/monetization layers are
designed as optional and off by default.

## Principles (unchanged from v2, restated)
1. **Core logic is engine-agnostic and deterministic.** `PuzzleEngine.transition()` stays
   pure and immutable; every mechanic resolves to a deterministic state transition so
   `SolverV2` can prove solvability. No real-time randomness in core.
2. **Presentation reacts to state/events; it never owns rules.** `board_view_v2` renders
   from `PuzzleState` + emitted `PuzzleEvent`s.
3. **Schema-first.** A mechanic lands in `SCHEMA_V2`/validator before runtime, behind the
   existing fail-closed gate, so half-built mechanics can't ship in levels.
4. **Monetization/analytics stay stubbed and off** until explicitly approved (AGENTS.md).

## Layered architecture
```
content/        levels_v2/*.json  (data-driven; validated)
 └─ core/       PuzzleState · PuzzleEngine · effects/ · SolverV2 · LevelValidator   [pure]
     └─ session/ PuzzleSessionV2 · TimerPolicy · FailPolicy · HintService           [pure-ish]
         └─ game/ board_view_v2 · game controller · input                           [Godot]
             └─ meta/ Wallet · Lives · Boosters · Progression (save: user:// JSON)   [optional]
                 └─ services/ ads · iap · analytics  (no-op stubs, OFF)              [gated]
```

## Core engine evolution (TD-4 "mechanics runtime")
The schema already declares triggers/effects/blockers/locked-gates/hidden-pieces. V3 adds
the **execution layer** that the engine currently fail-closes:

- **Effect system** (`scripts/core/effects/`): pure functions `apply(effect, state, ctx)
  -> {state, events}` for `open_gate`, `lock_gate`, `decrement_counter`, `reveal_piece`,
  `clear_blocker`, `set_gate_color`. Triggers fire on events (`piece_exited`,
  `piece_moved`, `counter_zero`) with the existing `MAX_CASCADE=32` guard, resolved in a
  deterministic order (sorted ids) so BFS stays reproducible.
- **Forced post-move transitions**: after a player `MOVE`/`EXIT`, the engine applies
  deterministic world reactions (magnet pull, feeder dispense, gate color tick) *inside*
  `transition()` and folds them into the returned next-state, keeping the search graph
  well-defined.
- **Solver stays authoritative**: `SolverV2` expands only engine-produced actions, so any
  new mechanic is automatically covered once its transition is deterministic. The
  `search_key()` must include every new state dimension (see Gap Analysis §"solver state").

### New mechanic modeling (original implementations)
| Mechanic | State representation | Determinism approach |
|---|---|---|
|Color-switching gate|`gates[id].color_phase` or derive color from `move_number`|derive from move count → no extra key growth|
|Laser door|gate with a scheduled open/closed pattern by move index|deterministic schedule|
|Sticky piece|`pieces[id].sticky=true`; movement couples adjacent same-group|legal-action generation couples the group|
|Lock + key|`blockers` of kind `lock`; key piece exit clears via trigger|reuse effect system|
|Grinder|cell hazard; piece entering is transformed/removed via effect|deterministic on entry|
|Crate/cover|cell has `cover` layer; removed reveals piece (reveal effect)|deterministic|
|Magnet|object pulls nearest movable each committed move, fixed rule|deterministic forced step|
|Feeder (dispenser/spawner/elevator)|queue of typed pieces; emits on condition|deterministic queue|
|Timer bomb|move-indexed countdown on a cell; fail on reach|move-count based|

> Recommendation: implement the **schema-ready four first** (locked gates, triggers/
> counters, blockers, hidden pieces) because they need *no new schema* — only the effect
> runtime — then add the new object types one at a time, each with solver tests.

## Timer & session policy (TD-6)
- `rules.timer_seconds` is unfrozen as an **integer**. Two timer models, chosen per level:
  - **Move budget** (`rules.move_limit`): stays inside the deterministic search; solver
    can assert "solvable within N moves". Preferred for solver-verifiable difficulty.
  - **Real-time countdown** (`timer_seconds`): a *presentation + fail* concern in
    `TimerPolicy`, outside the search graph. Solver verifies solvability ignoring the
    clock; balance tooling estimates par-time from solution length.
- `FailPolicy`: timeout / give-up → fail window → continue (spend life/booster) or lose.

## Meta systems (optional, off by default, original)
- **Lives (hearts)**, **Wallet (coins)**, **Boosters** (rocket/extra-time/pre/continue),
  **Hint** (reuse `SolverV2` to reveal the next optimal move). All persisted in local
  `user://` JSON with **versioned migrations**; never block core play in dev builds.
- Boosters act through the **same effect/action API** (e.g. extra-time adds to TimerPolicy;
  rocket = scripted clear effect) so they can't bypass deterministic rules in a way the
  solver can't model.

## Save data & migrations
Single `user://save.json` with `save_version`. Add fields additively; write a migration
per version bump; never hard-break existing campaign progress or stars (AGENTS.md).
v2 pilot/campaign progress must survive the V3 rollout.

## Asset & Android pipeline (unchanged, original)
Original art/audio only; TD-3.5 design system. Android debug/release via existing
`export_presets.cfg` (`permissions/vibrate=true`); no reference assets ever imported.

## Explicitly deferred (not in this architecture's build scope)
PvP duels/bots, leagues, tournaments, season/battle pass, collection albums, daily tasks,
leaderboards, real ads/IAP/analytics. Listed in the roadmap as P4+ with their own designs
and (for PvP/leagues) a server-cost decision.
