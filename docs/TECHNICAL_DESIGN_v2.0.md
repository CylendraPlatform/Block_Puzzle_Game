# BLOCK PUZZLE GAME — TECHNICAL DESIGN DOCUMENT v2.0

**Status:** Architecture proposal — review required, no implementation authorized by this document  
**Date:** 2026-11-24  
**Companion:** `Block_Puzzle_Game_GDD_v2.0.md`  
**Repository:** `CylendraPlatform/Block_Puzzle_Game`  
**Baseline reviewed:** `main` at `470d534` (agent-ready merge); Cursor's safe-area work exists separately on `rescue/mobile-safe-layout` at `a0ba86a` as last verified during this design exercise. Recheck HEAD and reconcile before implementation.  
**Engine:** Preserve Godot/GDScript. **Player-facing language:** English only.

## 0. Engineering decision

Build **one deterministic state-transition engine** shared by play, editor, solver, replay, validation and content tooling. Treat UI rendering, sound, particles, timer presentation, reward offers and external commercial providers as adapters **outside** the authoritative puzzle rules. Introduce v2 functionality behind level schema versioning; preserve all existing v1 levels and saved player progress. No wholesale rewrite, no mass replacement of levels, no live ads/purchases now.

**Done means:** the rules and data model reproduce the same outcome for the same initial state and ordered action sequence, solver discovers actual legal moves, undo/restart work for all new mechanics, and Android visual tests prove the current safe-area problems do not return.

## 1. Grounded inventory and compatibility

| Current source | Present role | Plan |
|---|---|---|
| `scripts/core/level.gd` | Parses grid, walls, pieces, simple gate intervals, `par` | Add versioned parser and strict validators; retain v1 reader |
| `scripts/core/rules.gd` | Sliding, collision, color-exit and BFS solver | Separate authoritative step/transition from move enumeration; extend solver |
| `scripts/game/board_view.gd` | Touch dragging and visuals; holds mutable blocks | Move authoritative state to session/controller while preserving a compatibility bridge; draw state, no business-rule mutation in view |
| `scripts/game/game.gd` | UI, undo, wins, progression | Orchestrate session and event-backed feedback; defer any reward grant until durable win |
| `scripts/core/catalog.gd` | Enumerates levels, persists unlocked progress/stars | Versioned save migrations; preserve existing stars and unlocked level index |
| `scripts/editor/*` | Edit blocks/walls/gates; solver test | Add conditional-object editing and diagnostics after mechanics stabilize |
| `levels/level_001..100.json` | Existing v1 campaign | Freeze as legacy; don't silently overwrite or renumber |
| `test/*` | Rules/drag/services/100-level validation | Keep all passing; add transition/solver/event/undo/migration/property tests |
| `scripts/services/ads_service.gd`, `iap_service.gd` | Stub providers | Keep disabled; no billing or SDK integration in this project phase |
| `.cursor/`, `.claude/`, `AGENTS.md` | Agent instructions and task continuity | Follow; update task before implementation and maintain acceptance evidence |

**Known architectural constraints from inspection:** The existing BFS in `rules.gd` enqueues full-distance slide outcomes, not every legal intermediate landing. The legacy gate schema already expresses an interval `lo..hi` but existing generated levels often use entire-side spans. The existing block geometry stores arbitrary `cells[]`; the apparent one-square-per-cell rendering is a visual issue rather than evidence of missing geometry data. Do not duplicate these capabilities.

## 2. Source architecture and ownership

Proposed directories are **targets**, not instructions to move files immediately:

```text
scripts/core/
  level.gd                  # existing v1 model + v2 adapter
  rules.gd                  # existing rules facade / legacy tests
  puzzle_state.gd           # immutable-ish deep-copyable authoritative state
  puzzle_action.gd          # intent and normalized move result
  puzzle_engine.gd          # pure transition() + stable event ordering
  conditions.gd             # condition parser/evaluator
  solver_v2.gd              # complete move enumeration + bounded search
  difficulty_analyzer.gd    # multi-metric analysis
  level_validator.gd        # strict schema, geometry and dependency checks
scripts/game/
  puzzle_session.gd         # state, undo, timer, win orchestration
  board_view.gd             # input + presentation only (migrate incrementally)
scripts/economy/
  economy_ledger.gd         # offline idempotent gold transaction ledger
scripts/ui/
  ... existing SafeArea/UI files after branch integration
test/v2/
  ... transition, solver, migration, timer and ledger tests
levels_v2/
  tutorial/ ...              # 15 curated levels; then advanced pilot
```

### Authority contract

- **Pure model**: Given `state`, `action`, `ruleset`, return `{next_state, events, error}`; do not invoke Godot scenes, signals, ads, clocks or audio in it.
- **Session**: Validates input, commits a transition, stores a deep history snapshot or deterministic event log, emits **already committed** events, saves progress, and drives timer lifecycle.
- **View**: Draws shapes/gates and animates from previous to committed state; it cannot unilaterally delete a block or open a gate.
- **Solver**: Calls exactly the same transition code as the game, without separate approximations.
- **Editor**: Calls the same level validator and solver, never its own interpretation.

## 3. Level format v2: strict, expressive and backwards compatible

The data below is **an illustrative schema sample, NOT a verified playable level**. Integer grid positions, stable IDs and explicit semantics are required.

```json
{
  "schema_version": 2,
  "id": "v2-015",
  "name": "Signal Chain",
  "chapter": 2,
  "board": { "cols": 6, "rows": 6, "walls": [[2, 3]] },
  "rules": { "rotation": false, "timer_seconds": null },
  "pieces": [
    { "id": "r1", "cells": [[0,0],[1,0]], "pos": [1,1], "color": "red", "required": true, "reveal": "visible" },
    { "id": "b1", "cells": [[0,0]], "pos": [3,2], "color": "blue", "required": true, "reveal": "visible" },
    { "id": "g1", "cells": [[0,0],[0,1]], "pos": [4,3], "color": "green", "required": true, "reveal": "hidden" }
  ],
  "gates": [
    { "id": "red_exit", "side": "left", "lo": 1, "hi": 1, "accept": ["red"], "initial_state": "open" },
    { "id": "blue_exit", "side": "right", "lo": 2, "hi": 2, "accept": ["blue"], "initial_state": "locked", "unlock_when": { "event": "piece_exited", "piece_id": "r1" } },
    { "id": "green_exit", "side": "bottom", "lo": 4, "hi": 4, "accept": ["green"], "initial_state": "open" }
  ],
  "triggers": [
    { "id": "reveal_green", "when": { "event": "piece_exited", "piece_id": "b1" }, "effect": { "type": "reveal_piece", "piece_id": "g1" } }
  ],
  "goals": { "all_required_pieces_exited": true },
  "authored_metrics": { "difficulty_target": "intro_dependency" }
}
```

**Schema details:**

1. All `pieces[].cells` are unique **connected** grid offsets (orthogonal connectivity); no disconnected silhouettes, duplicate cells, overlapping initial occupancy, or out-of-bounds cells.
2. `gates` must have valid `side`, `lo`, `hi`; span is inclusive in the perpendicular grid axis. Reject conflicting overlapping apertures unless an explicit prioritization rule is introduced later.
3. `initial_state` is `open` or `locked`; staged counters are separately typed (not overloaded into `locked`).
4. Colors are stable logical IDs, separate from rendered palette; hidden presentation does **not** change logical color.
5. Every mutable mechanic must have a stable ID and a fully typed transition rule.
6. Reject unknown required fields and unknown mechanics with a diagnostic, not a silent v1 fallback.
7. `schema_version` 1/absent loads through an untouched v1 compatibility path; v2 files never silently rewrite legacy assets.

### Content schema evolution

Use a converter `v1_to_v2(level)` that maps v1 `blocks`→`pieces`, `walls`→`board.walls`, `gates.color`→`accept[]`, preserves IDs/coordinates and marks every legacy gate `open`. Compare old/new behavior on golden state fixtures before migrating game scenes. Keep original v1 JSON files and IDs, and avoid changing player-facing level numbering without an explicit progress migration.

## 4. Canonical puzzle state

The state hash must capture every gameplay-relevant mutable field:

```text
PuzzleState {
  schema_version
  level_id
  pieces: piece_id -> {pos, active, revealed}
  gates: gate_id -> {mode: OPEN|LOCKED, counter_remaining?}
  blockers: obstacle_id -> {active, counter_remaining?}
  event_counters: predicate_id -> integer
  trigger_fired: trigger_id -> bool      # needed for one-shot transitions
  move_number
}
```

Immutable level definitions (geometry, gate spans, original colors, condition definitions) are referenced by ID and not duplicated into every state key. The state hash sorts keys and uses canonical integers/booleans, not JSON insertion order. Timer and wallet are **session state**, not part of the spatial solver, except for separately bounded time-feasibility analyses. Ensure every state that can alter a transition is represented in the solver's hash.

### Transaction and deterministic event pipeline

```text
USER_RELEASE / SOLVER_ACTION
   -> normalize action
   -> verify allowed movement and current gate state
   -> apply move to temporary state
   -> commit piece exit (if any)
   -> enqueue primary event: PieceMoved or PieceExited
   -> resolve triggered effects to fixed point, stable ID order
   -> validate invariants / reject invalid cyclic cascade
   -> commit next state and ordered events
   -> session history + persistence
   -> UI/sound/particles consume ordered events
```

No animation callback is allowed to trigger a second, hidden rules transition. Event handling must be atomic; all effects are visible to Undo. Stop recursion by explicit one-shot triggers plus cycle validation and an upper-bound on transitions per action. Distinguish counter decrements (`GateCounterChanged`) from an actual `GateUnlocked` event. Trigger definitions must not create self-referential impossible dependencies.

## 5. Movement, precise gates and exits

### Move API

```text
legal_actions(state, piece_id) -> [Move(piece_id, direction, landing_pos), Exit(piece_id, gate_id)]
transition(state, action) -> Success(state, events) | Rejected(reason)
```

- Enumerate **every legal reachable landing position** in each cardinal direction, including intermediate stopping cells; do not limit the solver to maximum slides.
- For each step check the entire polyomino's moved footprint against walls, pieces and board boundary.
- Exit is legal only when a piece's crossing footprint aligns completely to the designated open gate span, its logical color is accepted, its reveal state allows exit, and it can depart in the outward direction without competing gate ambiguity.
- Return an explicit `gate_id` on exit; use it to direct animation through the actual aperture.
- Define move accounting: one committed drag/release that changes piece position is one move, regardless of distance. An exit is one move. A cancelled/invalid drag is zero moves.
- Ensure visual finger-follow does not commit intermediate grid states or repeatedly consume moves during a single gesture; a preview state is distinct from committed state.
- During exit animation, lock interactions on that piece until the committed state transition has rendered; queued input must not mutate stale state.

**Important solver issue:** The current `Rules.solve_min_moves` searches maximal slides; before trusting v2 ratings, implement complete legal landing enumeration and compare solver results against exhaustive small-board reference fixtures. `CAP_REACHED` must not be labeled `UNSOLVABLE`.

## 6. Advanced mechanic contracts

| ID | Rules contract | Observable feedback | Tests |
|---|---|---|---|
| M01 connected polyomino | Rigid no-rotation `cells[]`, connectivity checked | One continuous body and footprint highlight | Connectedness, collision at every cell |
| M02 uneven gates | Precise inclusive aperture; no side-wide fallback | Actual opening width and edge alignment | 1-cell and multi-cell crossing cases |
| M03 conditional gate | `unlock_when` dependency evaluated on committed exit event | Lock→unlock animation and cue | trigger ordering, Undo, circular dependency |
| M04 counter | Counter decrements only on specified committed events; opens at zero | Compact number + changed state | no duplicate decrement, reset, Undo |
| M05 reveal | Logical color stays fixed, display state hidden→revealed | Neutral mystery surface + explicit reveal | pre-reveal exit rejected, reveal transition |
| M06 blocker | Active obstruction until event removes/unlocks it | Object disappearance/opening | dynamic occupancy and solver hash |
| M07 timer | Session-managed active-time budget; explicit pause policy | HUD countdown; time-up modal | pause/background, restore, expiry races |

### Conditional gates and counters

Use a small declarative condition AST, e.g. `piece_exited`, `color_exits_at_least`, `all`, `any`. No arbitrary script embedded in level JSON. Counters subscribe to exact event types. When multiple effects activate on one exit, sort by trigger priority then stable ID; resolve once per event and test that result is independent of dictionary order.

### Hidden pieces

A hidden piece is not an unknown logical state to the solver; it is **unknown information to the player**. Explicitly document the reveal trigger and clues. In v2, no exit before reveal; moving a hidden piece may be allowed if otherwise legal. A stage must not force random guessing about its true color in order to succeed.

### Undo/restart

Store full pre-transaction snapshots including gates, counters, reveals, trigger flags and move count. Replay the inverse from authoritative state, not by reversing particle animations. Restart restores original stage state. Undo must not undo real gold purchases or time extensions by default; the session tracks spent boosts separately to block refund exploits.

## 7. Solver v2 and difficulty analysis

### Correctness contract

`solve(level, initial_state, max_states, timeout_budget)` returns one of:

```text
SOLVED(solution_path, explored_states, best_cost)
UNSOLVABLE(explored_states)                  # only after complete search
UNKNOWN_CAP_REACHED(explored_states)
INVALID_LEVEL(diagnostics)
```

Never conflate exhausted search budget with proof of impossibility. Store the exact version of rules used for validation. Every released level must have a reproducible path of **actual legal player actions**, replayed against the engine to a Win state.

Use BFS for small-stage shortest-move reference results; consider A* only with documented admissible heuristic if shortest path is claimed. Add search pruning/caching with measurable benefit and without changing correctness. A generator candidate is never automatically a publishable stage because a solver returned `SOLVED`.

### Difficulty and quality metrics

For every v2 stage record minimum legal moves; max/median branching along reference solutions; explored/reachable states; dead-end fraction; forced-order dependencies; temporary reposition moves; unlock/reveal count; number of equivalent solutions; time spent in user tests; failure/restart rate; median hint use. Distinguish deterministic solver metrics from human playtest metrics.

A stage can have a short solution but still be difficult; conversely long solution paths may be repetitive. Establish chapter-specific acceptance targets **after** testing at least 15 curated stages.

## 8. Timer, scoring and economy boundaries

### Timer

The timer is a monotonic, session-owned gameplay clock. It runs only while the stage is actively controllable, pauses for app background/pause overlays/rewarded ads/required system UI, and resumes without duplicate timers. Persist remaining time during process death; choose and document whether a killed app retains the remaining budget or restarts the level (default: restore budget without charging background time). Time expiry must create one immutable `TimeExpired` outcome and disable normal moves until player chooses Retry Free or eligible optional assistance.

### Stars and gold

- Stars remain the **best permanent 1–3 result per level**, not a spendable balance. Preserve legacy progress and stars.
- Gold is a separately maintained soft-currency ledger with unique `transaction_id`, reason, level ID, amount, resulting balance, and idempotency key. Never grant the same level-completion reward twice on reload/replay unless a repeat-reward policy is explicitly defined.
- Phase 1 of the economy is simulated/local only; no purchase button should imply real payment when Billing is inactive.
- Trial figures from GDD v2 (e.g. 25 base gold, hint 40, +30 seconds for 60) remain **unapproved tuning placeholders**.
- Hint must derive from an actual legal solution of the **current** state, not random guidance.
- Gold deduction and grant of a hint/time extension are one durable transaction; handle crash between deduction and effect.
- The free retry must remain available, even when gold is zero, rewarded ads are unavailable, or payments fail.

### Monetization isolation

Keep provider adapters for ads/IAP `none` or test stub in v2 mechanic prototyping. No live ad SDK, remote collection or payment implementation without separate approval, privacy/consent review, store-product configuration and testing. This plan targets meaningful engagement and optional conversion, not forced-failure payment funnels.

## 9. Save data migration

Propose `save_version: 2`; maintain reader for old `progress.save` (`unlocked` and `stars`), settings and entitlement stubs. Never use level-list index as the sole identity for new v2 content: stable chapter/level IDs avoid unlock corruption when ordering changes. Build an explicit mapping between legacy indices and v2 progression or keep two separately labeled campaigns. Make migration repeatable, backed up and idempotent. Test old → new → app restart → replay, and preserve best stars. No automatic downgrade that destroys v2 data; handle incompatible versions gracefully.

## 10. Level editor / developer tools

Extend editor capabilities **after** engine and validator stabilise: paint connected polyominoes; position narrow gates; edit `unlock_when`; place counters; set reveal conditions; simulate dependency events; run complete solver and replay its witness path; show `UNKNOWN_CAP_REACHED` separately from unsolvable; export validated JSON with schema version. Editor remains developer-only (never in player menu). Add a level visualization/diff tool to compare one authored stage against v1/v2 expected paths.

## 11. Mobile UX, visual rule cues, and accessibility

Cursor's safe-area layer is the UI baseline, but its current screenshots and source are **not** approval of final appearance. Keep all player controls inside actual Android insets on every screen and test them on device. Draw backgrounds edge-to-edge, not controls. Multi-cell pieces must be a connected silhouette, narrow gates depict actual opening geometry, and state changes (locked, counter, hidden) need clear non-color indicators. Add a short tutorial interaction for every new mechanic. Use English only for every player-facing string. Maintain a legible timer with an alternative untimed progression path when accessibility needs require it.

## 12. Testing architecture and acceptance evidence

### New deterministic test suites

1. **Schema:** required fields, old v1 importer, malformed/ambiguous gates, invalid geometry and unsupported mechanic IDs.
2. **Movement properties:** translation invariance where applicable, overlap-free occupancy, all intermediate legal slides, no side exit through incorrect width/color/state.
3. **Events:** order independence, one-shot firing, counter boundaries, chained dependencies, rollback consistency.
4. **State:** deep copy, canonical state hashes include all mutable flags, save/restart/undo restores gates/reveal/counters.
5. **Solver:** compare with exhaustive tiny-board reference; witness-path replay; `UNKNOWN_CAP_REACHED` distinct from unsolvable.
6. **Time:** pause/background/expiry/restore and race conditions under injected fake monotonic clock.
7. **Gold:** idempotent grants/deductions, zero balance, crashes, no invalid negative balances, no regrant exploit.
8. **Regression:** all existing v1 levels still validate/play; existing rules/drag/services tests stay green.

### Evidence matrix

| Verification | Minimum acceptance |
|---|---|
| v1 regression | All existing test scripts pass; behavior snapshots unchanged or explicitly approved |
| Pilot v2 levels | 15 original levels, full solver witnesses replay to win; at least one example per introduced mechanic |
| Advanced pilot | 15 original levels for gated/reveal/counter mechanics, all solver-validated |
| Android | Actual APK install/launch/gestures, undo/restart, camera cutout and multiple portrait devices/resolutions |
| Performance | Valid frame-time measurement on actual game scene, not headless script FPS |
| Player test | Qualitative comprehension and frustration notes from 10–20 external testers; no invented retention claims |
| Economy | No double grants, free retry always available, stubs only until explicit commercial approval |

Maintain evidence paths, tool versions, test commands, exit codes and open defects in `docs/tasks/CURRENT_TASK.md` or linked QA reports. Never label a desktop simulated-inset screenshot as physical-device QA.

## 13. Delivery plan and explicit gates

| Milestone | Scope | Exit gate |
|---|---|---|
| TD-0 | Architecture ADR, state/schema/event definitions, baseline test matrix | Reviewed contracts; no code changes needed for design approval |
| TD-1 | v2 parser + validator + v1 adapter + engine transition skeleton | Backward-compatible tests; deterministic serialized states |
| TD-2 | Complete legal move enumeration + solver and witness replay | Reference correctness fixtures pass; cap semantics correct |
| TD-3 | M01 connected visuals + M02 narrow gate gameplay/editor; 15 authored levels | Android gesture QA and solver-backed playthroughs |
| TD-4 | M03 gate conditions + M04 counters + M05 reveal; 15 advanced levels | Full event/undo/restart/solver test coverage |
| TD-5 | 100-level v2 campaign, measured progression and onboarding | Human playtest approval; versioned content plan |
| TD-6 | Time, best stars, local gold ledger and optional hints/extension | No payment dependency or economy duplication; balance reviewed |
| TD-7 | Release validation, real-device matrix, instrumentation policy decision | Product-owner sign-off; live commercial SDKs remain separate approval |

Each milestone is one bounded Cursor/Claude task or PR. Merge latest `main` into the active Cursor branch before changing the same source files; do not lose the agent-ready infrastructure. Preserve baseline and write explicit migration tests before any save/schema change.

## 14. Open engineering decisions requiring sign-off

- Whether v1 remains a playable **Practice** campaign or is mapped into a separate v2 chapter (recommended: separate legacy practice until new campaign proves itself).
- Reveal event and clues: trigger-only first; do not permit unknown-color exit.
- Limits on conditional chains and simultaneous events; proposed one-shot cascade bound and fixed event priority.
- Timer lifecycle on app kill vs suspension; proposed restore remaining budget.
- Gold repeat-play rewards and booster refunds; proposed once-per-level base reward until tested.
- Final connected-body render technique (mesh/polygon or shader); needs real-device performance comparison.
- UI design identity and game name (working name only; distinct brand required).

## 15. Non-goals / IP boundaries

Do not copy Color Block Jam's level maps, artwork, branded UI, audio, source code, or proprietary data. Do not introduce PvP, login/backend, loot-box monetization, forced ads, mandatory purchase, unreviewed AI-generated campaign levels, or real-time remote analytics in the first v2 engine milestones.

**Approval recommendation:** Accept this TDD as the design basis, then implement TD-0/TD-1 on a dedicated branch with automated tests and a reviewable PR. Do not authorize all milestones in one unverified coding run.