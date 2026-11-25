# M1.2 — Advanced Mechanics Visual Integration (implementation plan, for review)

Status: **plan only. Do NOT implement until reviewed. No PR merged.** Builds on the frozen
M1.1 engine baseline (`feat/m1.1-effect-runtime`); **no engine/schema/solver changes** are in
M1.2 scope — it is presentation + interaction only.

## Goal
Render and interact with the five M1.1 mechanics on the Samsung Galaxy M31 (SM-M315F):
locked / conditional gates, gate counters, blockers, hidden pieces, and color-switching
gates — so a player can see and play a level that uses them, not just have the solver verify it.

## M1.1 freeze
M1.1 (engine effect/trigger runtime, invariant validation, phase-aware solver, profiling +
time-budget cap, advanced benchmark fixtures, the six PR #10 fixes) is the frozen baseline.
M1.2 does not modify `puzzle_engine.gd`, `effects.gd`, `conditions.gd`, `gate_rules.gd`,
`solver_v2.gd`, `level_validator.gd`, or `puzzle_state.gd`. If a genuine engine gap is found,
it is raised as a separate change against M1.1, not folded into M1.2.

## Current renderer gaps (verified in `scripts/game/board_view_v2.gd`)
- `_draw_gate(gate)` draws the **static** `accept` color and ignores live gate state — it
  does not read `state.gates[id]` `mode` (locked/open), `counter_remaining`, or `phase`.
- **Blockers are not drawn at all.**
- `_draw_piece` draws every geometry piece; **hidden pieces are not distinguished** and an
  unrevealed piece is visually indistinguishable / appears draggable.
- The view already receives committed `PuzzleEvent`s from the engine
  (`GATE_UNLOCKED`, `GATE_COUNTER_CHANGED`, `PIECE_REVEALED`, `BLOCKER_REMOVED`,
  `PIECE_MOVED`, `PIECE_EXITED`) — M1.2 drives transition animations from these rather than
  diffing state.

## Design principles (unchanged from the project)
- Presentation reacts to `PuzzleState` + emitted events; it never owns rules. The board view
  reads state for the static picture and events for transitions.
- Original art only; English-only UI; keep rendering allocation-aware (reuse the pooled
  StyleBox approach already in `board_view`). No new autoloads.
- Determinism is an engine property and is untouched; the view is free to tween/animate.

## Per-mechanic visual + interaction spec
| Mechanic | Static visual (from state) | Transition (from event) | Interaction |
|---|---|---|---|
| **Locked / conditional gate** | gate drawn in a "locked" style (desaturated + lock glyph) while `mode==LOCKED`; normal gate when OPEN | on `GATE_UNLOCKED`, play an unlock flash and swap to the open style | a locked gate is not a drop target (engine already rejects the exit); show a subtle "locked" bump on an attempted exit |
| **Gate counter** | show `counter_remaining` as a small badge on the gate while `>0` | on `GATE_COUNTER_CHANGED`, tick the badge down; on reaching 0 it chains into the gate-unlock flash | informational only |
| **Blocker** | draw each active blocker cell as a distinct obstacle tile | on `BLOCKER_REMOVED`, play a clear/shatter and stop drawing it | occupies a cell (already in engine occupancy); blocks drags visually and mechanically |
| **Hidden piece** | draw an unrevealed piece as an obscured "?" tile (occupies its cell, no color shown) | on `PIECE_REVEALED`, reveal animation to its real color | not draggable until revealed (engine rejects; view shows it inert — no grab) |
| **Color-switching gate** | draw the gate in `scheduled_color(gate, state.gates[id].phase)`; optionally a small schedule indicator | the accepted color changes as `phase` advances each committed action; animate the color swap | a piece only exits on the matching phase (engine enforces); view shows the current accepted color so the player can time it |

## Work breakdown (phased, each with on-device evidence)
- **M1.2-A — State-driven gate/blocker/hidden rendering.** `_draw_gate` reads live gate
  state (locked style, counter badge, scheduled color); add `_draw_blocker`; `_draw_piece`
  renders hidden pieces as obscured and suppresses their grab. Headless render-smoke
  (load each advanced benchmark into the view, assert no error) + desktop screenshots.
- **M1.2-B — Event-driven transitions.** React to the six events for unlock flash, counter
  tick, blocker clear, reveal, color swap. Desktop capture of each.
- **M1.2-C — Interaction correctness.** Drag/attempt-exit against locked gates, hidden
  pieces, blockers behaves (no illegal grab; "locked" feedback). The engine remains the
  authority; the view only reflects accepted/rejected actions.
- **M1.2-D — Playable advanced level in the app.** Wire an advanced level set (the adv_*
  benchmarks or a small M1.2 pilot) into a screen so the mechanics can be played end-to-end,
  not only solved headlessly.
- **M1.2-E — Device QA on the M31 (non-destructive).** Build debug APK; `adb install -r`
  (no `pm clear`, no `uninstall`); play a level exercising each mechanic; screenshots +
  clean logcat. Follows the device-safety policy: on a signing mismatch, STOP and report;
  never reset device data without approval.

## Tests
- Headless render-smoke per advanced benchmark (view instantiation + `show_state` without
  error) for each mechanic.
- Interaction unit checks: an unrevealed piece yields no grab; a locked gate is not a valid
  drop; a blocker cell rejects entry — all consistent with `PuzzleEngine.legal_actions`.
- Visual QA by screenshot (desktop + M31); no FPS claim without a real on-device profiler.
- Full M1.1 headless regression stays green (M1.2 must not change any solver outcome).

## Risks
- SurfaceView black-frame captures on some devices (seen before) — retry/settle before
  screenshot.
- Visual clarity of five overlapping mechanics on a small screen — needs a design pass
  (iconography/legibility), tracked within M1.2-A.
- Scope creep into engine behavior — guard: M1.2 touches only `scripts/game/` + `scripts/ui/`
  + themes/assets; any engine need is a separate M1.1 change.

## Review revisions (PR #11 feedback — required before implementation)

### R1. Event animation sequencing (deterministic presentation queue)
- A single **presentation queue** holds committed engine events in the engine's emitted,
  priority-sorted order (`PuzzleEvent.sort_stable`). One commit may emit several events
  (unlock + counter-change + blocker-removal + reveal); they are enqueued as one ordered
  batch and played in that fixed order, so the sequence is deterministic and reproducible.
- **Visual state never gets ahead of animation:** the board renders the *authoritative*
  `PuzzleState` for geometry, but gate/blocker/piece *presentation flags* (locked→open,
  counter value shown, blocker visible, hidden→revealed, gate color) advance only as each
  queued event is consumed. The queue is the single source of "what the player has seen so far".
- **Interruption / fast-forward:** a fast-forward drains the queue instantly — applying every
  pending event's end-visual immediately — which, by construction, lands exactly on the
  authoritative `PuzzleState`. It changes no `PuzzleState`; it only skips tweens. Undo/Restart
  trigger a fast-forward-then-reset (see R2).

### R2. Interaction during transitions (input lock + reconciliation)
- While any board-affecting animation is active, input is **locked** via the existing
  `PuzzleSessionV2.input_locked` / `BoardViewV2.set_locked`, so a drag/tap cannot begin.
- **No duplicate actions:** an action is committed once on drag-release; the board locks
  immediately on commit and unlocks only when the presentation queue drains. Taps/drags during
  the lock are ignored (not queued).
- **Undo / Restart** cancel pending animations: they fast-forward/clear the queue, then
  redraw from the authoritative state (`session.undo()` restores the previous snapshot;
  `restart()` rebuilds from_definition). The view always **reconciles to the authoritative
  state** after any interruption — a `reconcile()` that drops queued tweens and redraws the
  current `PuzzleState` as the fully-settled picture.
- Tests: rapid tapping, mid-animation drag attempts, interruption via Undo/Restart, and
  repeated/rapid actions commit at most one action per intended input and never desync.

### R3. Visual clarity & accessibility (not color alone)
- **Shape + symbol, not color alone:** locked gate = lock glyph + desaturated frame;
  blocker = a distinct hatched/obstacle tile shape; hidden piece = a "?" tile with a neutral
  fill; color-switching gate = the current color **plus** a small cycle indicator. Each
  mechanic is identifiable in greyscale.
- **Counter badge legibility on 1080×2340:** a minimum badge size and font relative to the
  cell size, with an outline/background for contrast; verified by screenshot on the M31.
- **Contrast + hit targets:** maintain readable contrast against the board; keep piece hit
  targets at full cell size; locked gates/blockers are non-interactive but clearly marked.
- **Original artwork and animation only** — no reference assets; reuse the TD-3.5 token/theme
  system and the pooled StyleBox approach.

### R4. Playable on-device mechanic QA (separate from the campaign)
- A **dedicated, clearly-marked QA entry point** (e.g. a menu button "Advanced QA" or an
  entry under the existing dev screens) loads the advanced mechanic levels — kept **separate
  from the production campaign** (its own catalog/scene, like `td36_qa`), with its own save
  namespace so it never writes campaign progress.
- On the physical M31, exercise **all five mechanics**: verify successful interaction, an
  illegal action (e.g. attempting to move a hidden/locked piece), **Undo**, **Restart**, and a
  **win** state for each. Capture **actual device screenshots** and relevant **logcat** runtime
  logs. Device QA is **non-destructive**: `adb install -r` only; on a signing mismatch STOP and
  report; never `pm clear`/`uninstall`/reset without explicit approval.

### Cross-cutting requirements (restated, binding)
- **M1.1 is the frozen gameplay authority.** No rules are duplicated inside `BoardViewV2`:
  the view asks `PuzzleEngine.legal_actions` / commits via `PuzzleSessionV2` and renders state
  — it never decides legality, openness, or win itself. Static visuals derive from
  `PuzzleState`; animations derive from committed events; after any interruption the view
  reconciles to the authoritative state.
- **Preserve existing v1 and v2 gameplay paths** (campaign via adapter, v2 pilot) — M1.2 adds
  rendering/QA without changing them.
- **Run the full M1.1 regression suite** each phase; M1.2 must not change any solver outcome.
- If an engine contract change becomes necessary, **document and review it separately** (a
  change against the frozen M1.1), not folded into M1.2.

## Out of scope
Monetization/analytics, new mechanics, level-content expansion beyond a small playable set,
and the deferred solver `search_key`/`duplicate` optimization. Resume-mid-puzzle save
(REQ-SAVE-REPLAY) is separate and not required for M1.2.

## Deliverable of this milestone
This reviewed plan → an implementation PR (separate, not started) delivering the renderer +
interaction changes, headless render-smoke + interaction tests, and non-destructive M31 QA
evidence.
