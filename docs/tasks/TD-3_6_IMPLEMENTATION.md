# TD-3.6 — Puzzle Depth & Gameplay Production
Status: P0 provisionally accepted. P1 solver validity accepted; original eight fixtures rejected as generator seeds. Eight additional polyomino candidates are on `feat/td36-puzzle-depth-production` (PR #8) for product playtest. P2–P5 not started.
Working branch: `feat/td36-puzzle-depth-production`
Parent: `feat/td35-premium-playful-visuals` / PR #7 (itself stacked on open PR #6).
Read this file and `docs/v2/TD36_LEVEL_DESIGN.md`, `docs/v2/TD36_GENERATOR_EVALUATION.md`, `docs/v2/TD36_PLAYTEST_ACCEPTANCE.md` before implementation. Read AGENTS/CLAUDE/.cursor and existing docs/runbooks first.

## Goal
Produce a reviewable **30-level v2 candidate campaign** with real dependency, obstruction, varied connected shapes/colors and meaningful decision-making; one developer QA route can launch it. Keep existing 15 pilot and 100 legacy levels intact. This is a vertical slice, not a premature 100-level shipping campaign.

## Non-negotiable scope
1. Keep `PuzzleEngine` transition semantics and strict v2 schema authoritative. Solver status `UNKNOWN_CAP_REACHED` is **not** UNSOLVABLE. Preserve reproducibility, winning witness replay and legality checks.
2. Do not overwrite, rename or reassign `levels/`, `levels_v2/pilot/`, `user://progress.save` or `user://pilot_v2.save`. New campaign uses `levels_v2/td36/` and separate `user://td36_qa.save` with namespace and version. No writes to production progression.
3. Complexity must be measured from state graph / action branch behavior and validated by small human playtests, not moves alone. A solver finding 30 moves does NOT prove 5-minute human difficulty.
4. Never add fake gold/stars; any scoring UI must use tested measured elapsed time and actual moves. Timer cannot override/alter puzzle engine legality.
5. Optional timed mode is a separate presentation/session policy (pause/resume, app background, undo policy, failure/retry) and **no forced countdown** in normal mode. Do not merge TD-4 mechanics prematurely; only use mechanics supported by current schema/engine.
6. Do not auto-promote this QA campaign into public Play flow until product owner approves. Prefer a clearly labeled `TD-3.6 QA` dev menu route, and evaluate default Play routing separately; legacy Play stays unchanged during QA.
7. Preserve design system and base TD-3.5 visual work while recording open deficiencies. Do not let visual polish distract from level design.

## Sequential deliverables / checkpoints
**P0 — Instrumentation:** deterministic solver batch runner, depth metrics, unique state hash, legal-action counts, shortest witness length, explored states, elapsed search, cap outcome and replay. Export human-readable JSON/CSV report. Add checks for unreachable geometry and truly invalid states. Document resource ceilings; avoid arbitrarily claiming exact shortest path when search terminates early.

**P1 — Hand-authored benchmark puzzles:** construct and audit 8 strong reference puzzles (at least 2 each Easy/Medium/Hard/Expert targets, subject to observed playtest reality), involving mandatory blocker relocation / exit ordering / multiple colors / connected nontrivial shapes. Show step-by-step verified witness and per-level design rationale. If Expert target infeasible under current mechanics, report the blocker and escalate as TD-4 dependency rather than fabricating difficulty.

**P2 — Candidate generator:** implement deterministic seed-based reverse-play/constructive generation or solver-guided mutation, under hard guards for board size, occupancy, number of pieces, legal exact gate fit, connectivity and color distribution. No raw random sampling-only approach. Reject identical states, trivial direct exits, and disjoint independent puzzles. Deduplicate by canonical level signature and near-duplicate structural fingerprint. Generation report must provide seed and rejection reasons. Reject no-witness/UNKNOWN levels for the accepted 30 set.

**P3 — Curate 30 candidate JSONs:** audit with v2 validator and shortest witness replay. Suggested initial distribution: 4 Tutorial, 8 Easy, 10 Medium, 6 Hard, 2 Expert; **adjust to tested actual difficulty**. Provide varied board sizes and shape types, 3–12 pieces where geometry permits, multiple exits/colors. Minimum constraints, targets and no-fake-difficulty rules: `docs/v2/TD36_LEVEL_DESIGN.md`. Each level stores QA-only authoring metrics separately from engine schema, without invalid/unrecognized fields.

**P4 — QA scene:** dev-only route selecting/restarting 30 levels, accurate moves and actual timer display (count-up normal mode), optional clock challenge, replay/restart after win. Use current `PuzzleSessionV2`, `BoardViewV2`; never recreate a second game engine. QA progress separate, legacy Save unaffected. Debug diagnostics appear only in dev mode.

**P5 — Review evidence:** headless v2 tests, legacy regression suite, 30/30 SOLVED with verified witnesses, no unseen UNKNOWN counted as solved, varied-device screenshots, actual emulator gestures, Android APK, measured performance, and 5+ human participant sessions if practical (or explicitly state unavailable). Recommend (not assert) product acceptance based on recorded results.

## First handoff
Cursor/Claude Code should implement **P0 and P1 first**, commit, attach metric report and eight level proofs, then stop for review rather than generate all 30 blindly. Subsequent P2–P5 only after acceptance of benchmark difficulty and generator quality.

## Pull request policy
Create stacked draft PR with base `feat/td35-premium-playful-visuals` while #7 remains unmerged, with explicit dependency #7 -> #6. Do not merge or force-push any existing PR. Report exact test commands, results and limitations. Do not call TD-3.6 complete before human difficulty review.
