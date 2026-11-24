# TD-0 + TD-1 — v2 Puzzle Engine Foundation

**Status:** READY FOR IMPLEMENTATION — no implementation claimed yet.
**Branch:** `feat/td0-td1-v2-foundation`
**Baseline:** `main` at `2403ab17f775931f2237404a7cc95115213d201c` (verify latest before coding).
**Authoritative source:** `docs/TECHNICAL_DESIGN_v2.0.md`, sections 0–5 and 12–14; `docs/GDD_v2.0.md`.
**Scope:** TD-0 architecture contracts and TD-1 v2 data foundation / deterministic engine skeleton. Do not start TD-2 or later.

## Agent startup
Read `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/*`, `.cursor/task.md`, `docs/tasks/CURRENT_TASK.md`, relevant runbooks and v2 product/technical docs. Inspect branch, working tree, previous commits and current rules/level/catalog/test code. Preserve others' changes. Update `docs/tasks/CURRENT_TASK.md` and backlog to reflect active TD-0/TD-1 only when the implementation starts; preserve historical BP-101 details as a backlog entry or archival task rather than deleting history.

## TD-0 — design contracts first
- Record ADR for shared deterministic authoritative state transition, presentation/session boundary, frozen v1 behavior, and v1/v2 save/level compatibility.
- Freeze versioned JSON v2 schema: explicit `schema_version`, stable level/piece/gate/trigger IDs, connected polyomino geometry, bounds/non-overlap, unique gate spans, open/locked mode, fixed logical colors, hidden/revealed presentation, typed conditions and typed event/effect records.
- Define immutable level definition versus mutable canonical `PuzzleState` including piece positions/active/revealed, gate state/counters, blockers, event counters, trigger-fired flags, move number. Define stable deterministic state serialization/hash (sorted identifiers, typed values).
- Specify `PuzzleAction` and pure `transition(state, action, definition) -> {next_state, ordered_events, error}` contract. Define rejected action semantics, atomicity, deterministic event ordering, one-shot triggers, cycle/cascade guard and full snapshot semantics.
- Document compatibility and migration: missing/1 schema uses legacy parser; `v1_to_v2` is non-destructive; never rewrite old level files or silently reset `progress.save`, unlocked or best stars.
- Write a test matrix and golden v1 fixtures before behavior changes. Highlight current BFS maximum-slide and cap/unsolvable ambiguity; defer complete solver work to TD-2.

## TD-1 — implement foundation only
- Add version-aware level loader/validator and descriptive typed diagnostics; retain existing v1 `Level.from_dict` behavior and existing 100 files.
- Add pure v1-to-v2 adapter preserving geometries, locations, color, gate spans and IDs (generate deterministic stable gate IDs when absent). Every legacy gate maps to OPEN; no side-wide fallback.
- Add isolated data classes/modules for canonical state, actions and event envelopes plus deterministic deep copy/canonical serialization/hash; do not add mutable presentation state to solver hash.
- Add an engine transition skeleton with explicit unsupported-feature diagnostics where mechanics are not yet implemented. A transition must never partially mutate an input state or signal success for an unimplemented rule.
- Keep v1 gameplay and drag flow intact. Do not migrate `BoardView` to the new engine or introduce the TD-2 complete solver in this PR. No new gameplay mechanics, visual overhaul, paid SDKs, level replacements, or mobile UI regressions.
- If full event/conditional mechanics are not yet supported, validate and parse their schema but reject runtime execution explicitly and test that behavior rather than silently pretending they work.

## Required acceptance tests
- All existing test scripts, including `test_rules.gd`, `validate_all.gd` (100 existing levels), `test_services.gd`, `test_drag.gd` and `test_layout.gd`, pass or failures documented with actual logs.
- Round-trip all 100 v1 levels through adapter, compare piece coordinates/occupancy, gate intervals/colors and relevant playable legacy outcomes against golden fixtures.
- v2 schema rejects missing/duplicate IDs, disconnected pieces, out-of-bounds/overlap, invalid/overlapping gates, unsupported version/mechanic IDs, malformed triggers and invalid colors with actionable diagnostics.
- Verify deterministic `PuzzleState` serialization independent of dictionary iteration order; deep-copy isolation; state hash includes all relevant gate/reveal/trigger/counter flags; no mutation on rejected moves.
- Test that `UNKNOWN_CAP_REACHED` is not reported as `UNSOLVABLE` in new API placeholders; do not alter legacy API semantics accidentally.
- Provide sample v2 schema fixtures, explicitly labeled **schema fixtures**, not solver-proven playable levels.
- Record exact commands, exit codes, tested environment, change list, compatibility evidence and remaining TD-2+ gaps.

## Delivery and boundaries
Work in small auditable commits on this branch; create a PR against `main`, do not merge without review. Keep original artwork/levels intact. No real ads, purchases or remote analytics. All player-facing text English. Do not claim device QA unless actually run. If TD-0 findings demand a schema decision, document it and choose the stated defaults in the technical design; do not silently expand scope.

## Review gate
TD-0 is complete after reviewable ADR/contracts/test matrix. TD-1 is complete only after versioned parsing/validation, adapter/state skeleton and tests with evidence. TD-2 (complete legal landing enumeration and solver witness paths) is a distinct next task.
