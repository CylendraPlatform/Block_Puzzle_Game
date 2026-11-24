# BLOCK PUZZLE GAME — GAME DESIGN DOCUMENT v2.0

**Status:** Product design proposal / NOT implementation approval  
**Date:** 2026-11-24  
**Audience:** Product owner, Game Designer, Cursor, Claude Code, Godot Engineering, QA  
**Platform:** Android first; iOS later  
**Language:** English only for all player-facing UI  
**Target:** Mainly 18+ adults; may include 16–17-year-old users only with age-appropriate design, store policies and appropriate privacy/ad controls  
**Engine:** Preserve existing Godot/GDScript architecture unless evidence justifies change  
**Inspiration:** Spatial sliding-block color-exit puzzle genre. **Create original identity, art, levels, names, interfaces, audio and implementation; never reproduce a competitor's proprietary content.**

## 0. Executive product decision

**Current state:** The existing project is a working technical foundation with 100 JSON levels, deterministic sliding rules, a BFS-based solvability checker, local progress, stars, and a level editor. Its prior production-grade claims are NOT accepted as evidence of a commercially compelling game. Mobile-safe layout improvements are in progress/on a dedicated branch; visual polish and game depth remain distinct projects.

**Version 2 direction:** Transform a direct color-matching exercise into a **sequence-planning spatial puzzle**. The player must reason about movement order, narrow gate alignment, temporarily blocked routes, conditional gate unlocking, delayed color reveal and limited time. Motivation comes from achievements, stars, in-game gold, escalating mastery and optional assistance. Purchases/ads must NOT be required to solve a level or continue the game.

**Priority:** Prove compelling puzzle design and player comprehension before implementing live monetization or mass content generation. This GDD is a product specification; no game code is changed by this document.

## 1. Design pillars and player promise

1. **Think before you move:** Order matters; clearing one block may unlock or obstruct the next.
2. **Simple touch, deep reasoning:** One-finger translation, no arbitrary control complexity.
3. **Readable change:** The player clearly sees which event opened a gate, revealed a color or released an obstacle.
4. **Fair challenge:** Every level is verified solvable without paid items; timer variants offer a realistic free completion path.
5. **Mastery and momentum:** Stars, gold and chapters reward persistence without degrading the puzzle into a payment funnel.
6. **Premium presentation:** Connected polyomino silhouettes, precise gates, clear touch feedback, legible HUD and safe screen layout.

**Core player loop:** Inspect board and objective → plan sequence → drag rigid pieces → trigger gate/obstacle events → adapt to newly revealed information → clear target blocks → earn stars/gold → unlock the next challenge.

**Secondary loop:** Accumulate gold from successful play, spend some on optional hints/time extensions, complete optional achievements, revisit levels for more stars. Ads and purchases are optional future services, not prerequisites.

## 2. Definitions and rule vocabulary

- **Board:** Orthogonal cell grid with walls, exit gates, movable pieces and conditional objects.
- **Piece/Block:** Connected polyomino with a persistent ID, geometry offsets, position and logical color (possibly hidden from player).
- **Translation:** A piece moves along one cardinal axis without rotation, unless a future rule explicitly introduces rotation.
- **Gate:** Border aperture occupying a defined interval of cells on left/right/top/bottom; has an accept rule, span, lock state and optional staged-opening state.
- **Event:** Atomic change after a committed move/exit (e.g., block exit, counter decrement, gate unlocked, color revealed).
- **Dependency:** Condition that must be satisfied before an object changes state.
- **Timer:** Optional level mode measuring allowed active gameplay time. Never active during tutorials or blocking overlays.
- **Star:** Persistent mastery rating (1–3); never consumed.
- **Gold:** Soft currency earned from gameplay; can optionally purchase convenience actions. No real-money purchase implementation in the initial mechanics milestone.
- **Booster:** A strictly optional, explicit action such as reveal hint or time extension, with clear cost and deterministic outcome.

## 3. Core rules — compatible baseline

### 3.1 Movement

Touch and drag a single rigid piece on the grid. It may occupy one or more cells of any supported **connected** shape: bar, square, L, T, zig-zag and custom polyomino. Piece cells move together with no rotation. Motion stops at other pieces, walls or board edges. No overlap/pushing/teleportation by default. Visual motion may be continuous; logical state must remain deterministic.

A **committed move** is a release that changes a piece's grid position or exits a gate; canceling a drag does not consume a move. Undo restores **all** affected state and must not silently refund a purchased consumable unless the design explicitly specifies that behavior.

### 3.2 Exit

The piece must approach a border, align its crossing cells fully within the gate span, match the gate's accepted color and meet gate-open conditions. It exits **fully in the direction of movement**. The piece remains logically active until the exit transaction commits; the animation follows the transaction, not vice versa. Other pieces may not overlap a departing piece during unresolved animations.

### 3.3 Win/fail

A level is complete when **all required pieces** have exited and any explicit objective conditions hold. Auxiliary static obstacles are not counted. Failure occurs only under explicitly enabled mechanics (timer or impossible-state rules); otherwise player may undo or restart freely. No unavoidable dead end should prevent a free restart.

## 4. Advanced mechanics — product specification

Each mechanic needs tutorial introduction, unique visual language, solver support, regression tests and a content budget. Do NOT introduce all at once.

### M01 — Variable piece geometry (foundation)
- Shapes: 1×1, 1×2, 1×3, 2×2, L, T, S/Z, connected custom shapes; prohibit disconnected piece definitions.
- A piece is rendered as a **single coherent silhouette** rather than isolated floating rounded cells.
- Narrow corridors and other pieces create spatial dependencies.
- Never rotate pieces unless rotation is intentionally designed and solver-covered in a later version.

### M02 — Precise nonuniform gates (foundation)
- Gates have **side, start cell, end cell, accepted color and state**.
- Spans can be 1–N cells; positioning is uneven and may include multiple gates on a side.
- Gate geometry must be valid, non-overlapping in conflicting configurations, and visually obvious.
- Example: a two-cell-wide piece cannot leave through a one-cell-wide horizontal aperture unless orientation and crossing footprint permit it.

### M03 — Conditional gates (advanced)
- A gate may start `LOCKED` and transition to `OPEN` when a specific trigger is fulfilled.
- Supported triggers for first implementation: `exit_piece(piece_id)` and `exit_color(color, count>=n)`; optionally all-of / any-of groups.
- Clear feedback: lock icon/chain, brief opening animation, accessible signal beyond color.
- Must never require a piece's exit through its own locked gate as an impossible circular dependency.

### M04 — Progressive opening / counters (advanced)
- A gate or obstacle can have a counter representing **defined events**, not ambiguous numbers. Example: decrement by 1 for every successfully exited block of any color; opens at zero.
- Trigger type and progress must be communicated explicitly through animation and a compact badge.
- Counters change only on committed events and are fully reversible by Undo.
- Define exact behavior for simultaneous multiple exits and queued animations.

### M05 — Hidden/revealed piece color (advanced)
- A piece has an immutable logical color but can start `HIDDEN` to the player.
- Its color becomes visible when a defined event occurs (e.g., another piece exits; a lock opens; a group threshold is reached).
- A hidden-color piece **cannot exit before reveal** in v2 unless another explicit rule says otherwise; this avoids guessing as a forced gameplay mechanism.
- Mystery state must be visually distinguishable and learnable; no misleading color cues.
- Include carefully designed clue levels so hidden information feels like deduction rather than arbitrary chance.

### M06 — Movable/conditional blockers (later candidate)
- Stationary obstacles that disappear on a trigger, or large movable neutral pieces that cannot exit until conditions met.
- Choose one clear subtype per chapter. Do not add destructible, frozen, chained and teleporting objects together.

### M07 — Optional timed puzzles (controlled rollout)
- Timers are **not enabled in onboarding levels** and do not exist in every level initially.
- Countdown starts after the interactive tutorial and pauses in OS background, pause menu, confirmation dialogs and advertisements.
- On expiry, show **Retry Free**, optionally **Use Earned Gold**, or **Watch Rewarded Ad** if online, consented, available, eligible and configured.
- A purchase may never be the only continuation path. Avoid repeated pay pressure, fabricated scarcity, deceptive ads or targeting minors for payment conversion.
- Timer allowance is calibrated using playtest solve-time distributions, not artificially tuned to create payment demand.

## 5. Example event-driven interaction

**Original illustrative level concept (not a competitor level):**

- Three colors (red, blue, green); a narrow blue gate is locked.
- Exiting red piece `R1` emits `PIECE_EXITED(R1)`, unlocking the blue gate.
- Exiting blue piece `B1` emits `PIECE_EXITED(B1)`, revealing green piece `G1` previously shown as unknown.
- Green piece must be repositioned to align with a two-cell gate after clearing the blocking path.
- Level clears when R1, B1 and G1 have exited.

**Mandatory event order:** validate drag → commit move → emit exit → update counters/locks/reveal → evaluate win/fail → render feedback. Persist the whole event-resolved state atomically. Avoid re-entrant signals that mutate the solver's state unpredictably.

## 6. Proposed state model (design sketch, not drop-in code)

```json
{
  "schema_version": 2,
  "id": 101,
  "board": { "cols": 7, "rows": 7, "walls": [[2, 3]] },
  "blocks": [
    { "id": "R1", "cells": [[0,0],[1,0]], "pos": [1,1], "color": "red", "visibility": "shown", "required": true },
    { "id": "B1", "cells": [[0,0],[0,1]], "pos": [4,2], "color": "blue", "visibility": "shown", "required": true },
    { "id": "G1", "cells": [[0,0],[1,0],[0,1]], "pos": [3,4], "color": "green", "visibility": "hidden", "required": true }
  ],
  "gates": [
    { "id": "GR", "side": "left", "lo": 1, "hi": 2, "accept": ["red"], "state": "open" },
    { "id": "GB", "side": "right", "lo": 2, "hi": 3, "accept": ["blue"], "state": "locked", "unlock_when": { "type": "piece_exited", "piece_id": "R1" } },
    { "id": "GG", "side": "bottom", "lo": 3, "hi": 4, "accept": ["green"], "state": "open" }
  ],
  "reveals": [ { "block_id": "G1", "when": { "type": "piece_exited", "piece_id": "B1" } } ],
  "timer": { "enabled": false },
  "rewards": { "base_gold": 25, "max_stars": 3 }
}
```

This sample is **illustrative schema only** and is **not validated as a solvable puzzle**. Actual sample levels must be authored and solver-checked. Preserve backwards-compatible loading of v1 levels with explicit migration or version dispatch.

## 7. Puzzle engine and solver contract

### 7.1 Single source of rules

Use one authoritative rules engine shared by gameplay, level editor, generation, verification and solver. Visual animations cannot introduce a separate rule interpretation.

### 7.2 Complete state

Include piece positions/removed flags; gate state and counters; reveal flags; blocker state; events relevant to dependencies; timer only in time-dependent verification when needed. IDs stable. The solver state hash must include all gameplay-relevant mutable flags.

### 7.3 Solver correctness

Current BFS primarily searches maximum-distance slides and thus is not a general complete enumeration of all player-reachable intermediate positions. Upgrade move enumeration to consider all legal landing positions and exits, and verify any state bound separately from `UNSOLVABLE` (use statuses `SOLVED`, `UNSOLVABLE`, `UNKNOWN_CAP_REACHED`). Use caps/heuristics or A* where measured complexity warrants it.

Perform property-based invariants: no overlapping pieces; valid transitions; Undo restores all state; deterministic event resolution; no circular unsatisfiable lock conditions; every released level has a fully verified solution path. Protect play progression from accidental data corruption.

### 7.4 Difficulty and design quality

A level's `minimum_moves` alone is insufficient. Capture at least: solution path length; branching factor; reachable state count; dead-end ratio; number of interdependent exits; required temporary repositioning; number of unlock/reveal decisions; clarity of next logical action; median solve time and retry rate from actual testers. Use solver metrics to generate candidates; use human testing to certify engaging play.

## 8. Level progression — first 100 v2 levels (design targets)

| Levels | Introduced concept | Player learning outcome | Typical notes |
|---|---|---|---|
| 1–10 | Touch, drag, matching gate, simple 2-cell shapes | Understand controls and win condition | No timer/paid prompts; short tutorial |
| 11–20 | L/T and connected multi-cell pieces | Predict whole-piece collision and clearance | No hidden surprises |
| 21–35 | Narrow and uneven gates | Align piece's exit footprint, not merely color | Distinct gate placement |
| 36–50 | Piece order and crowded layouts | Plan 2–4 dependent actions | Use dead-end recovery and Undo |
| 51–65 | Conditional unlocking | Understand exit-triggered changes | One trigger per tutorial first |
| 66–80 | Gradual counters and reveal | Track state and plan after new information | Events explained visually |
| 81–90 | Optional timer variants | Maintain reasoning under fair pressure | Tune by tested solve times |
| 91–100 | Mixed mechanic mastery | Multi-stage strategic planning | No pay-dependent solutions |

This table is a **design allocation**, not a claim that existing levels meet it. Existing 100 levels may be retained as a legacy practice set; the v2 campaign requires re-authoring and independent QA. Do not bulk-replace a user's progress without migration/reconciliation.

## 9. Time, stars, gold and boosters — initial economy proposal

### 9.1 Separation of roles

- **Stars:** permanent mastery, 1–3 per completed level. They are **never consumed**. Can unlock optional milestone rewards.
- **Gold:** earned soft currency, tracked in a ledger (source and sink), optional use for convenience and retries. Purchasable gold is a future authorized feature only.
- **Time:** difficulty dimension in selected levels; not a synthetic punishment in every level.

### 9.2 Rating proposal

Untimed levels: 1 star for completing, 2 for reasonable move efficiency, 3 for an excellent solution. Timed levels: completion always earns at least 1 star; efficiency/time may raise rating. Exact formulas require test tuning and must not penalize players for using accessibility settings. Preserve best stars on replay.

### 9.3 Example economy numbers — placeholders, not approved prices

- Standard completion: 25 gold base; bonus 0–15 based on stars and chapter milestones (avoid excessive currency inflation).
- Hint: 40 gold; one deterministic useful suggestion, never a misleading nudge.
- Optional time extension: 60 gold for +30 seconds, used only in levels designed for timers.
- Optional rewarded advertisement: one explicit equivalent benefit, no forced watch, frequency-capped and eligible only when SDK/privacy setup is approved.
- Retry: free without limit; no forced gold fee.

All numbers are **hypotheses requiring balance simulations and user testing**. Model inflation, average gold earned/spent per 10 levels, booster demand, gold balance distribution and progression speed. Protect against negative balances and double-grants after crashes.

### 9.4 Ethical and compliance boundaries

No deliberately impossible timers, misleading countdowns, fabricated failures, forced ads, hidden real-money costs, or purchasing pressure targeted at minors. Show clear costs and require explicit confirmation before spending gold. Purchases must use store-compliant payment processing and appropriate privacy/age protections when enabled later.

## 10. UX, visual and information design

- English-only user-facing text.
- Safe-area-aware portrait-first UI on all screens, including cutouts and system bars.
- Board takes visual priority. Level title, timer, stars and gold should not obscure pieces or exits.
- Connected multi-cell bodies, visible edge alignment, clean gate widths, meaningful status icons for locked/revealed/counter states.
- Preview each newly introduced rule in a short playable tutorial with a single new concept.
- Fail state uses plain language: `Time's up`, `Retry`, `Use 60 Gold`, `Watch Ad` only when legitimately available.
- Keep the level editor inaccessible in player builds, accessible in developer mode.
- Build a distinct original brand and art direction; visual quality reference does not authorize asset cloning.

## 11. Audio, feel and accessibility

Responsive drag, low-latency settle, fully directional exit, gate unlock cues, reveal animation, subtle haptics with toggle, sound/music toggle. Color is never the sole indicator of gate/piece state: use shapes, symbols, labels or patterns where practical. Avoid animation effects that delay control unreasonably. Provide timer accessibility alternative or untimed progression route for players who need it.

## 12. Product analytics and commercial validation

Instrument locally first: tutorial start/finish, level start, time spent, time remaining, move count, undo, restart, hint offered/used, gate unlock event, color reveal, timer expiration, free retry, gold earned/spent, ad offer/accept/completion, purchase offer/transaction outcome (later). Define event schema and data minimization before any remote collection.

**Pre-beta quality gates:** full solver verification; 0 critical softlocks; 100% screen safe-area controls; real Android gesture QA; onboarding comprehension; visual sign-off; no monetization dependency for completion.

**Early playtest metrics (hypotheses):** 10–20 external testers for qualitative feedback; compare median solve time, hint dependency and frustration points by chapter. Later controlled acquisition cohorts to measure D1/D7 retention and eventual LTV vs CPI. Do not assert success based on downloads or test counts alone.

## 13. Phased implementation proposal

**Track A — Visual foundation (already delegated to Cursor):** Fix safe areas, rendering, player UI and directional exit feedback. Verify on real devices. This is distinct from v2 mechanics.

**Phase V2-A — Engine design:** Freeze event schema, condition model, v1→v2 data migration and solver state specification. Write unit tests before implementation.

**Phase V2-B — Foundation mechanics:** Coherent multi-cell shapes; uneven narrow gates; author 15 original levels introducing these rules. Gameplay/solver/editor all agree.

**Phase V2-C — Event mechanics:** Conditional gates, progressive counters and color reveal, including deterministic undo/save/restart. Author another 15 canonical test levels.

**Phase V2-D — Campaign:** Curate 100 levels to progression map, with complexity measurements and human playtests. Do not substitute a fully random generator for game design.

**Phase V2-E — Motivation economy:** Star rating, gold ledger, optional boosters, selected timed modes, free retries. Integrate only after quality gates; keep live ads and real billing disabled.

**Phase V2-F — Release quality:** Android device matrix, performance, privacy/store policy review, localization checks, crash/analytics consent, external playtest and release candidate approval.

Each phase needs source changes, deterministic regression tests, sample-level recordings, relevant Android screenshots and a written product-owner acceptance decision. No direct main merge without review.

## 14. Non-goals for v2.0 mechanics

No PvP or multiplayer, no backend account requirement, no loot boxes, no gambling-like random purchase outcomes, no pay-to-win obligatory actions, no mass AI-generated unreviewed stages, no real-money monetization as part of the initial mechanics implementation.

## 15. Open decisions (must be validated before code expansion)

1. **Goal:** All required blocks exit vs chapter-specific special-object objectives. Default all required blocks.
2. **Hidden color:** Trigger-based reveal only vs discover through deduction. Default trigger-based, with clues.
3. **Counter definition:** Exit count, color count or other event; explicit per-object metadata.
4. **Timer rollout:** Optional selected stages, not universal; calibrate from solve-time data.
5. **Star formula:** Moves-only legacy vs moves + time + hint usage; backward compatibility required.
6. **Gold values:** Prices/rewards above are placeholders pending economy modelling.
7. **Gate geometry:** How to visually merge adjacent apertures and prevent ambiguous color overlaps.
8. **Undo with time/booster:** Timer may continue while playing; no unintended refunds or exploit paths.
9. **Progress migration:** Keep earned stars/unlocks from v1; decide whether old stages become a legacy chapter.
10. **Age and compliance:** Main monetized cohort adults; respect policies when app is available to minors.

## 16. Acceptance criteria for GDD v2.0 approval

- Product owner approves the six principal mechanics and time/reward philosophy.
- A technical design proves rule/solver/editor support without breaking v1 saves.
- At least three **original** representative puzzle level designs are playable and solver-validated: narrow-gate, conditional-gate and hidden-color.
- Each mechanic has tutorial and explicit state feedback.
- Timer and gold never become mandatory completion requirements.
- Visual experience verified on real Android, not just desktop render.
- Metrics/known limitations and deferred services honestly documented.

---

**Recommended project follow-up documents:** `docs/TECHNICAL_DESIGN_V2.md`, `docs/LEVEL_DESIGN_V2.md`, `docs/ECONOMY_DESIGN_V2.md`, `docs/TEST_PLAN_V2.md`; update `docs/tasks/CURRENT_TASK.md` only when V2 execution is formally started. The legacy `docs/GDD.md` remains a factual description of v1 until v2 is approved.