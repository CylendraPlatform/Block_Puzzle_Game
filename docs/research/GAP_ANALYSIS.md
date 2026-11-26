# Godot Gap Analysis — v2 engine vs Color Block Jam (Phase REA-02)

How our existing Godot/GDScript project compares to the reference feature inventory.
"Ours" is verified by source inspection on branch `feat/td36-puzzle-depth-production`
(files cited). Reference items carry the confidence tags from the inventory.

## Our current implemented capability (verified)
- **`PuzzleEngine`** (`scripts/core/puzzle_engine.gd`): pure, deterministic, immutable
  `transition()`; `MOVE` (intermediate landings) and `EXIT` (straight slide to the unique
  **open, color-matching** gate, then leave). Multi-cell polyomino offsets, wall +
  boundary collision, gate matching by `side` + `[lo,hi]` span + `accept` colors.
- **`PuzzleState`** (`scripts/core/puzzle_state.gd`): pieces `{pos, active, revealed}`,
  gates `{mode: OPEN|LOCKED, counter_remaining}`, blockers, `event_counters`,
  `trigger_fired`, `move_number`; canonical hash + `search_key` (move-count-agnostic).
- **`SolverV2`** (`scripts/core/solver_v2.gd`): BFS shortest committed-move search,
  witness-replay verified, cap-bounded (`SOLVED` / `UNSOLVABLE` / `UNKNOWN_CAP_REACHED`).
- **Schema v2** (`docs/v2/SCHEMA_V2.md`, `scripts/core/level_validator.gd`): integer-strict;
  already *defines* `gates.initial_state` (open/locked), `gates.counter`, `triggers`,
  `blockers`, `pieces.reveal` (visible/hidden), `pieces.required`, `rules.rotation`,
  `rules.timer_seconds` (rejected non-null), `unlock_when`, `chapter`.
- **Content:** 100-level v1 campaign + 15-level v2 pilot (`levels_v2/pilot/`), plus TD-3.6
  polyomino benchmark fixtures and difficulty instrumentation (`puzzle_metrics.gd`).
- **Presentation:** TD-3.5 premium visual system; `board_view_v2.gd` continuous drag.

### Critical boundary (verified in code)
`PuzzleEngine._unsupported_reason()` / `_uses_unimplemented_mechanics()` **fail-closed**:
any level using triggers, blockers, locked gates, gate counters, hidden pieces, rotation,
or a non-null timer is **rejected at runtime and excluded from the solver**. So these
mechanics are *schema-modeled and state-tracked but not executed*. This is the single most
important fact for planning: the data contract is ahead of the runtime.

## Parity matrix

| Reference capability | Conf | Ours today | Gap | Schema change? | Priority | Complexity |
|---|---|---|---|---|---|---|
|Slide colored multi-cell blocks to matching open gate|PD/TI|**Implemented**|none|no|P0|—|
|Walls / fixed obstacles|INF|**Implemented** (`board.walls`)|none|no|P0|—|
|Shortest-solution verification|—|**Implemented** (SolverV2)|none|no|P0|—|
|Stars / progression / save|—|**Implemented** (original, v1 catalog)|port to v2 campaign|minor|P0|M|
|**Countdown timer + timeout fail**|PD/TI|schema stub only (`timer_seconds` rejected)|**execute timer; fail state**|unfreeze field|P2|M|
|Locked gates that open on a condition|TI(ours)|state-modeled, **not executed**|**trigger/effect runtime**|already in schema|P1|M|
|Counters / triggers / effects|—|state-modeled, **not executed**|**execution + cascade (MAX_CASCADE exists)**|already in schema|P1|H|
|Blockers (clearable obstacles)|TI|state-modeled, **not executed**|**runtime + solver support**|already in schema|P1|H|
|Hidden/revealed pieces|TI|state-modeled, **not executed**|**reveal runtime**|already in schema|P1|M|
|**Color-switching gates / laser doors**|TI|none|**new gate behavior + solver state (gate color over time)**|new fields|P1|H|
|**Sticky pieces** (drag neighbors)|TI|none|**new movement rule (grouped drag)**|new piece flag|P1|H|
|**Magnet / drain** (auto-pull)|TI|none|**non-player forced motion each step**|new object type|P2|H|
|**Grinder** (destroy/transform on contact)|TI|none|**new interaction + solver effect**|new object type|P2|H|
|**Locks / joined locks** (key-gated)|TI|partial (locked gate concept)|**lock objects + keys**|new fields|P1|M|
|**Crates / covers** (reveal underneath)|TI|none|**layered cell contents**|new fields|P2|M|
|**Feeders**: dispenser/spawner/elevator|TI|none|**dynamic piece spawn; infinite-ish state**|new object type|P3|H|
|**Timer bomb on exit**|TI|none|**timed hazard + fail**|new object type|P3|H|
|Boosters (rocket, extra-time, pre, continue)|TI|none (ads/iap stubs exist)|**booster framework, inventory, UI**|save schema|P2|H|
|Hearts / lives / regen|TI|none|**lives system + gating + UI**|save schema|P2|M|
|Give-up / continue / fail window|TI|basic win popup only|**fail + continue flow**|minor|P2|M|
|Hints|PD(low)|none|**hint = reuse SolverV2 next-move**|none|P2|M|
|Coins / rewards economy|TI/PD|none|**wallet + reward grants**|save schema|P3|M|
|Collection album / daily tasks|TI|none|**meta-progression systems**|save schema|P4|H|
|PvP duel vs bots / leagues / tournaments|TI|none|**new modes; bots; possibly server**|large|P4+|XH|
|Season / battle pass|TI|none|**live-ops pass**|large|P4+|XH|
|Real ads / IAP / analytics|TI|**stubbed, off (by policy)**|integrate only on approval|—|P5|M|

## Reusability verdict
- **Reuse as-is:** `PuzzleEngine` MOVE/EXIT core, `PuzzleState`, `SolverV2`, schema
  validator, metrics, v2 pilot content, TD-3.5 visuals, continuous drag.
- **Extend (schema already supports; needs runtime):** locked gates, counters/triggers,
  blockers, hidden pieces — this is the natural P1 because the data model is done.
- **New state representation required (solver-affecting):** color-switching gates,
  sticky-group movement, magnets, grinders, feeders. Each adds dimensions to the search
  key and must stay deterministic for SolverV2 to remain sound.
- **Out of core scope:** lives/boosters/economy (meta), live-ops modes, monetization.

## Mechanics that change solver state representation (must be designed carefully)
`PuzzleState.search_key()` currently hashes pieces, gates (mode+counter), blockers,
counters, triggers. Adding the following **expands the key** and the branching factor:
1. **Gate color over time** (color-switching/laser) → gate state needs current color +
   phase; or model as deterministic function of `move_number` (cheaper, stays sound).
2. **Sticky groups** → movement couples pieces; legal-action generation changes.
3. **Magnets/feeders** → introduce *forced* post-move transitions; the engine must apply
   them deterministically inside `transition()` so BFS still explores a well-defined graph.
4. **Timer** → if timer is move-count-based it can stay in the key; if real-time it leaves
   the deterministic search model and becomes a presentation/fail concern only.

These are called out so TD-4+ does not casually break solver soundness or determinism.
