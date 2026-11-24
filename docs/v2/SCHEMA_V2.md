# Schema version 2 (frozen for TD-1)

Authoritative contract: `docs/decisions/ADR-002-deterministic-puzzle-state.md`.
Files under `test/fixtures/v2/` are schema fixtures. They are not solver-proven levels.

## Required shape
- `schema_version`: 2
- `id`: non-empty string
- `name`: string
- `board.cols`, `board.rows`: positive integers
- `board.walls`: unique in-bounds `[x, y]`
- `pieces[]`: unique `id`, logical `color`, `pos`, orthogonally connected `cells`, `reveal` of `visible` or `hidden`
- `gates[]`: unique `id`, `side` of `left`, `right`, `top`, or `bottom`, inclusive `lo`..`hi` on that edge, non-empty `accept`, `initial_state` of `open` or `locked`. Spans may coincide only when their `accept` colors are disjoint, which is how legacy color gates share an edge. The same color on an overlapping span is rejected.
- Optional `unlock_when` and `triggers[]` use typed conditions: `piece_exited`, `color_exits_at_least`, `all`, `any`
- Optional effects: `reveal_piece`, `unlock_gate`, `decrement_counter`, `remove_blocker`
- `goals.all_required_pieces_exited` is the only goal key

Unknown top-level fields, colors, condition names, and effect names fail validation. Version 1 or a missing version does not enter this validator until `V1Adapter.to_v2` builds a new document.

## State versus definition
`PuzzleState` keeps positions, active/revealed flags, gate mode, counters, blocker flags, event counters, trigger-fired flags, and `move_number`. It does not copy cell geometry into the hash.
