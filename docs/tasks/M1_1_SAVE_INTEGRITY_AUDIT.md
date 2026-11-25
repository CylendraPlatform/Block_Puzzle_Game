# M1.1 Save / Load Integrity Audit (PR #10 final check)

**Question:** is the design's authoritative "action-log replay-on-load" integrity gate
implemented? **Answer: NO — and it is currently moot, because no mid-puzzle board state is
ever persisted or loaded.** This is documented so save integrity is not claimed as complete.

## What actually persists (grep of `scripts/`, verified)
| File | Writes | Content |
|------|--------|---------|
| `scripts/core/catalog.gd` | `user://progress.save` | `{unlocked: int, stars: {...}}` — campaign progress only |
| `scripts/core/settings.gd` | `user://settings.save` | `{sfx, music, haptics, analytics_opt_out}` |
| `scripts/game/pilot_catalog.gd` | `user://pilot_v2.save` | `{index: int}` — current pilot level index only |
| `scripts/game/td36_catalog.gd` | `user://td36_qa.save` | `{index, ns, v}` — dev QA index only |
| `scripts/editor/editor.gd` | `user://custom_level.json` | an authored level *definition* (not a mid-solve state) |

**No file persists an in-progress `PuzzleState`** (piece positions, gate modes, counters,
reveals, trigger flags, exit counters). `PuzzleSessionV2` (`scripts/core/puzzle_session_v2.gd`)
holds only an in-memory `history` (undo stack) and `state`; `open()` / `restart()` always
rebuild via `PuzzleState.from_definition(definition)` from a trusted, schema-validated level
definition. There is **no action log**, **no replay-on-load**, and **no disk load of a
`PuzzleState`**.

## Integrity posture today (honest)
- Every `PuzzleState` in use is either solver-produced (trusted by construction) or built
  fresh from a validated definition. **No externally-supplied mid-puzzle state is loaded**,
  so there is currently no surface for a forged/tampered mid-puzzle save.
- `PuzzleEngine._state_problem` enforces structural + monotonic invariants on any state it
  is given (accepts legitimate mutation, rejects impossible state). This is the *only*
  integrity check; it is a filter, **not** a reachability proof.
- Therefore the "replay-on-load is authoritative" statement in
  `docs/architecture/M1_1_EFFECT_RUNTIME_DESIGN.md` §5/§10 describes an **intended future**
  gate, not a shipped one. Save integrity for mid-puzzle resume is **not implemented and not
  claimed**.

## Tracked follow-up (required before mid-puzzle resume ships)
**REQ-SAVE-REPLAY (owner: a future milestone, not M1.1):** if/when resume-mid-puzzle save
is added (persisting an in-progress board so a player can close and reopen a level), the
load path MUST reconstruct the state by **replaying the committed action log from
`from_definition` and comparing `canonical_hash()`**, and reject on mismatch — the fast
`_state_problem` invariant filter is not sufficient on its own. End-to-end tests (save →
reload → hash match; tampered log/state → rejected) are part of that requirement. Until then,
no mid-puzzle state is persisted, so the gap is latent, not active. Also recorded in
`docs/tasks/BACKLOG.md`.
