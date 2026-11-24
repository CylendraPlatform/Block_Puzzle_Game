# Schema version 2 (frozen for TD-1)

Authoritative contract: `docs/decisions/ADR-002-deterministic-puzzle-state.md`.
Files under `test/fixtures/v2/` are schema fixtures. They are not solver-proven levels.

## Numbers
Coordinates, board size, gate spans, counts, and counters must be integers before any conversion. JSON whole numbers such as `1.0` are integers. Fractions, numeric strings, and booleans are rejected. A value is never truncated into a nearby cell.

## Required
- `schema_version`: integer 2
- `id`: non-empty string
- `name`: string
- `board.cols`, `board.rows`: integers greater than 0
- `pieces`: non-empty array. Each piece needs string `id`, logical `color`, `pos` of length 2, and a non-empty `cells` array of length-2 integer pairs
- `gates`: array, which may be empty. Each gate needs string `id`, `side`, integer `lo` and `hi`, and a non-empty `accept` list

## Optional defaults
- `board.walls`: `[]`
- `rules`: `{rotation: false, timer_seconds: null}`. Present `rotation` must be a boolean. Any non-null timer is rejected in TD-1.
- `pieces[].reveal`: `visible`
- `pieces[].required`: `true`
- `gates[].initial_state`: `open`
- `triggers`: `[]`
- `blockers`: none
- `goals`: `{all_required_pieces_exited: true}`
- `chapter` and `legacy_index`: absent. When present they are integers of at least 0
- `unlock_when` and `counter`: absent

`goals.all_required_pieces_exited`, when present, must be the boolean `true`.

## References and objects
Piece, gate, trigger, and blocker ids share one namespace. `piece_id` must name a piece, `gate_id` a gate, and `blocker_id` a blocker. `decrement_counter` also requires that gate's `counter.remaining`. A condition is `all`, `any`, or one event, not a mixture. `count` is an integer of at least 1. `counter.remaining` is an integer of at least 0.

Unknown fields inside level, board, rules, piece, gate, trigger, effect, condition, blocker, and counter objects are rejected. `visibility` is one of those rejected names.

## Deferred checks
- Keys inside `authored_metrics` are not allowlisted. They are notes and do not change transitions. The object itself must be a dictionary. TD-2 and TD-6 have not frozen a metric schema.
- Trigger cycles are not rejected. TD-4 owns execution, one-shot firing, and the cascade limit.
- A non-null `timer_seconds` is rejected as unsupported rather than parsed as a duration. TD-6 owns that schema.
- The v1 adapter may convert whole legacy JSON numbers. Those files are not schema_version 2 documents, and the adapter still does not rewrite them.

## Geometry
- `pieces[]` cells are orthogonally connected
- Gate `side` is `left`, `right`, `top`, or `bottom`. Spans may coincide only when their `accept` colors are disjoint. The same color on an overlapping span is rejected.
- Conditions are `piece_exited`, `color_exits_at_least`, `all`, and `any`
- Effects are `reveal_piece`, `unlock_gate`, `decrement_counter`, and `remove_blocker`

Unknown top-level fields, colors, condition names, and effect names fail validation. Version 1 or a missing version does not enter this validator until `V1Adapter.to_v2` builds a new document.

## State versus definition
`PuzzleState` keeps positions, active/revealed flags, gate mode, counters, blocker flags, event counters, trigger-fired flags, and `move_number`. It does not copy cell geometry into the hash.
