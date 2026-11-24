# TD-3 — Playable v2 Geometry, Precise Gates, and 15 Authored Pilot Levels

**Status:** Implemented on `feat/td3-geometry-gates-pilot`. Solver replay and desktop screenshots are recorded in `docs/tasks/CURRENT_TASK.md`. Physical Android QA and a human playtest are not done, so this milestone is not fully accepted. The interactive v2 editor is deferred; the pilot screen is the preview.
**Branch:** `feat/td3-geometry-gates-pilot`
**Baseline:** `main` at `696b485375ec831fe4ff88f31313be250e762e8a`; verify remote main before work.
**Authority:** `docs/GDD_v2.0.md`, `docs/TECHNICAL_DESIGN_v2.0.md`, `docs/v2/SCHEMA_V2.md`, `docs/v2/SOLVER_V2.md`, `docs/decisions/ADR-002-deterministic-puzzle-state.md`.
**Milestone gate:** M01 connected piece presentation + M02 narrow/uneven precise gates PLAYABLE through PuzzleEngine, with 15 original curated solver-verified levels, editor/preview compatibility, regression and Android gesture QA. **No TD-4 mechanics.**

## 0. Before editing
Read `AGENTS.md`, `CLAUDE.md` if present, `.cursor/rules/*`, `.cursor/task.md`, `docs/tasks/CURRENT_TASK.md`, existing runbooks and all authority documents above. Inspect worktree/stashes and avoid discarding user work. Update the canonical task ledger/backlog when starting. Keep TD-2 solver semantics intact: every intermediate free landing and one straight EXIT (potentially from interior) per action; solve/replay must match actual gameplay. Always preserve legacy `Rules`/`Catalog` path and its 100 levels and progress.save.

## 1. Delivery architecture: separate v1 and v2
1. Implement an **opt-in, developer-testable** v2 gameplay path using `LevelLoader`, validated definition, `PuzzleState`, `PuzzleEngine.legal_actions/transition`, and solver. Do not feed v2 raw definitions through legacy `Level.from_dict` or silently change `Catalog.list_paths()` to include pilot stages.
2. Introduce `PuzzleSessionV2` (or equivalent) as owner of authoritative state, history, committed move count, undo, restart and win state. `BoardView` or a dedicated `BoardViewV2` is presentation + touch intent only: previews do not mutate the state; release commits exactly one legal action via `PuzzleEngine.transition`; no rule decisions in animations. Exit animation uses committed gate id/direction; lock interaction while animating.
3. Use separate stable pilot campaign identifiers (e.g. `v2-001`…`v2-015`) and paths under `levels_v2/pilot/`. Keep pilot progression isolated from existing `progress.save` (either no persistence or a new versioned pilot save with explicit contract/tests); **do not overwrite legacy unlocks/stars**. Make pilot discoverable through a clearly labeled, opt-in developer/test route (or dedicated QA scene). Do not expose an incomplete pilot as the default commercial campaign.
4. Integrate mouse and touch axis-locked dragging, precise grid landing on release, cancel/blocked drag feedback, true exit when finger drags outward, and lossless undo/restart. Test both slide and exits from interior. Use one committed action per gesture; reject out-of-bounds/no-op input without state mutation. Preserve `UIKit.mount`/SafeArea behavior.

## 2. M01 — cohesive polyomino visuals
- Render multi-cell pieces as a connected silhouette, not separated floating rounded cell tiles. At minimum support 1x1, bars, 2x2, L, T and S/Z and custom orthogonally connected shapes; apply one unified per-piece shadow, outline/highlight/selection, consistent color and visible boundary. Avoid seams, disconnected-looking art, and pieces overlapping other pieces or board UI.
- Design original visuals; no competitor asset/maps/audio copying. Use non-color indication (contour/pattern/shape label where needed) when possible. Prefer scalable vector/geometry rendering with low allocations, consistent frame times on mid-range Android. Existing single-cell legacy artwork must not regress.
- Document draw/drag transform (board coordinates, device pixels, animation position); render position should never be source of game logic.

## 3. M02 — exact gate presentation and mechanics
- Draw actual edge apertures for each `side,lo,hi`, including 1-cell narrow gates, multi-cell spans, multiple uneven gates on same side and color-specific overlaps allowed by TD-1 validator. Display a clear open border gap/portal at the correct location, not a generic side-wide glow.
- Ensure player can visually predict fit based on the **entire footprint projection**, matching `PuzzleEngine` exactly. Clearly distinguish blocked move, wrong-color, too-narrow, and valid exit affordances without misleading visuals.
- No gate width/position heuristics in `BoardViewV2` that can override the authoritative engine. Do not interpret any locked/trigger/counter/reveal mechanics as supported. Such levels must fail closed with a clear developer diagnostic.
- Existing rules accept one EXIT from interior along a clear straight ray; implement corresponding gesture UX without requiring an extra logical move to reach the edge.

## 4. 15 unique authored pilot stages
- Author 15 **original, human-reviewed** `schema_version:2` JSON stages under `levels_v2/pilot/`, names and stable ids. Content must be designed, not copied from existing commercial games and not mass generated. Every stage validates with strict `LevelValidator`; every stage returns `SOLVED` with a replayable witness via `SolverV2` within a documented, reasonable cap; the win result is correct; no TD-4 objects.
- Proposed progression (adjust thoughtfully and document): 01–03 single-piece/fundamental drag and direct exit; 04–06 off-axis alignment and narrow 1–2 cell gates; 07–09 connected L shapes and corridor planning; 10–12 T/S shapes, interference, temporary repositioning; 13–15 multi-piece dependencies and deliberate nonmaximal landings.
- **Quality over mere existence**: record witness length, explored states, number of distinct choices, explanation of intended decision, dead ends/alternative routes when discoverable, and difficulty hypothesis for each. Avoid repetitive direct one-move exits except tutorial. Flag boring/trivial stages for redesign; solve length alone is not difficulty.
- Player-facing tutorials and objectives in English only. A prompt such as “Drag to the matching exit” or “Align the entire shape” may be used; keep tutorials lightweight and dismissible. Every new mechanical idea must be introduced before combining it.
- Pilot content metrics and validation report should be committed as a reviewable document, not only terminal logs. No claim of human playtest signoff until testers actually play.

## 5. Editor and QA tooling
- Existing `scripts/editor/editor.gd` is a **legacy** editor currently using `Rules.solve_min_moves` and v1 JSON. Do not reuse this as a v2 validator by mistake. Add separate v2 pilot preview/inspection/diagnostics, or carefully version-gate editor support, with precise gates, custom polyominoes, v2 schema validation, solver witness replay and explicit `UNKNOWN_CAP_REACHED` vs `UNSOLVABLE`.
- If fully interactive v2 editing exceeds safe TD-3 scope, deliver a pilot content tool plus visual QA viewer and explicit deferral with reason; never label unsupported v2 authoring “complete editor integration.”
- Surface level id, current committed state, gate id, solver verdict, replay actions and failure diagnostics in a developer mode, not player HUD.

## 6. Quality gates and testing
- New `test/test_v2_pilot.gd`: enumerate exactly 15 unique authored level IDs; strict schema validation; solve each within recorded cap; replay every witness through `PuzzleEngine.transition` to Win; ensure all action intermediates legal and stored `move_number` correct; assert new content has actual gate variation / polyomino usage / nonmaximal landing dependency.
- New session tests: initial state, legal/illegal drag, exact move count, undo after MOVE and EXIT, restart, win/optional piece semantics, safe input lock during animation, independence of gameplay state from rendering.
- Rendering/layout tests/screenshots at portrait aspect ratios, cutouts, tiny and tall screens; touch and mouse input. Verify no clipping, incorrect hit mapping, false exits, ghost pieces or stale active states. Record screenshots and whether tests were desktop/emulator/physical device. Run physical Android gestures and safe-area QA when device is available; if unavailable, **do not mark TD-3 fully accepted** — record the block, do not fabricate proof.
- Regression: `test_v2_foundation.gd`, `test_v2_solver.gd`, `test_rules.gd`, `validate_all.gd` (100 v1), `test_services.gd`, `test_drag.gd`, `test_layout.gd`; avoid full legacy `test_v2_campaign.gd` unless specifically needed, because previous 100-level run was ~910s and capped 40 (not unsolvable).
- Capture Godot version, exact commands, exit codes, missing physical-device evidence, known warnings, deterministic witness transcript and any performance measurement. Solver cap exhaustion is not proof of unsolvability.

## 7. Prohibited changes / scope fence
No TD-4 conditions, counters, reveal, blockers or event cascades; no TD-5 campaign rewrite, TD-6 timer/gold/boosters, TD-7 release claims, monetization SDKs or remote analytics. Do not alter the original 100 level files, legacy campaign IDs, player progress.save, legacy star scores, or existing public game flow without a clearly gated v2 QA entrypoint. No wholesale UI rewrite; source code, assets and designs must be original.

## 8. Handoff and PR
- Implement via small auditable commits only on `feat/td3-geometry-gates-pilot`; PR into `main` and **do not merge automatically**.
- Update `docs/tasks/CURRENT_TASK.md`, level-design notes, runbook, and v2 visual+gameplay contracts. Preserve history of TD-0/1/2 and BP-101 backlog.
- Show feature summary, exact changed files, test logs/exit codes, 15-level validation table and representative visuals, pilot access steps, known issues and acceptance status.
- Product-owner review is needed for gameplay feel and level design; Android device evidence and playable demo are a real milestone gate, not merely solver success.
