# ADR-002: Deterministic puzzle state and v1 compatibility

**Status:** Accepted for TD-0 / TD-1 implementation, 2026-11-24.
**Source:** `docs/TECHNICAL_DESIGN_v2.0.md` sections 0–5 and 12–14.

## Context
Play, the editor, and the current solver each interpret sliding differently. v2 needs one authoritative transition, while the shipped 100 levels and `progress.save` must keep working.

## Decision
- The authoritative result of a puzzle action is `PuzzleEngine.transition(state, action, definition)`. It returns `{ok, next_state, events, error}` and does not touch scenes, audio, ads, or clocks.
- `BoardView` and `Rules` remain the live v1 play path. TD-1 does not move dragging onto the new engine.
- `PuzzleState` stores piece position, active, revealed, gate mode, counters, blockers, event counters, one-shot trigger flags, and move number. Level geometry stays on the definition. Timer and wallet stay outside the state hash.
- Serialization sorts identifiers and writes typed values. The hash is SHA-256 of that text.
- A rejected transition returns `ok: false`, `next_state: null`, and an error code. It does not modify the input state. A later successful transition must copy state with `PuzzleState.duplicate()` before writing, so undo can keep the full snapshot.
- `PuzzleEvent` is the ordered envelope (`type`, `subject_id`, `priority`). Effects sort by priority, then type, then subject id. One-shot triggers use `trigger_fired`. A cascade stops at `PuzzleEngine.MAX_CASCADE` (32) or on a repeated state. TD-1 does not run that pipeline.
- Movement and exit execution are not implemented here. Plain open-gate actions return `RULES_NOT_IMPLEMENTED`. Triggers, locked gates, counters, blockers, and hidden pieces return `UNSUPPORTED_FEATURE` at runtime even when their schema parses.
- Search status `UNKNOWN_CAP_REACHED` is distinct from `UNSOLVABLE`. Only a finished search with no solution may use `UNSOLVABLE`.
- Missing `schema_version` or version 1 uses `Level.from_dict`. `V1Adapter.to_v2` returns a new dictionary and never rewrites `levels/*.json` or `progress.save`.
- Legacy gates become `initial_state: open` with `accept: [color]`. Missing gate ids are `g{index}_{side}_{color}_{lo}_{hi}`. There is no side-wide fallback. Gates on one edge may share a span only when their accepted colors do not intersect.
- The v2 field for presentation is `reveal` (`visible` or `hidden`). The GDD sample name `visibility` is not accepted.
- Logical colors are `red`, `blue`, `green`, `yellow`, `orange`, `purple`.
- The legacy campaign stays a separate practice set identified by `legacy_index`. New v2 content will not reuse that index as its only id.

## Consequences
TD-2 must implement legal landings on this contract before any v2 level is called playable. Until then, schema fixtures are validation samples only.
