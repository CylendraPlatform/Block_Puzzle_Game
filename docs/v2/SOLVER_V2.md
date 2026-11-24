# Solver v2 movement and search

Live play still uses `Rules` and `BoardView`. `PuzzleEngine` and `SolverV2` are the v2 authority for tests and later milestones. They do not rewrite `levels/` or `progress.save`.

## Actions

`legal_actions` lists every in-bounds free landing of an active piece along a cardinal ray, including intermediate cells and the furthest cell. A landing at the piece's current cell is not an action. The piece is a rigid set of cells. Every cell of the footprint is tested at every step. Walls and other active pieces block. Inactive pieces do not occupy cells. Rotation, diagonals, pushing, and teleporting are not actions.

Order is piece id, then direction (`left`, `right`, `up`, `down`), then Manhattan distance, then MOVE before EXIT, then gate id.

## Exit

An EXIT is one committed move. Its direction is the outward direction of the gate side (`left`, `right`, `up` for `top`, `down` for `bottom`). The piece slides in that direction until the next step is not free. The exit is legal only when that next step leaves the board and no footprint cell of that step lands on an occupied in-bounds cell. A collision blocks the exit. At least one footprint cell must sit on the outer edge. Every perpendicular coordinate of the footprint must lie in the gate's inclusive `lo..hi` span. The gate must be OPEN and its `accept` list must contain the piece color. Zero matching gates, or more than one, means no exit. Distinct colors may share a span; only the gate that accepts the piece color is chosen. There is no full-side fallback.

An EXIT does not change axis. If the piece must change row or column before it lines up with the gate, that alignment is a MOVE, and the exit is a later action. When the piece is already on the ray, one EXIT includes the continuous slide to the edge and the removal. It increments `move_number` by one. If the alignment cell differs from the start cell, the events are `PieceMoved` then `PieceExited`. If the piece is already aligned, the only event is `PieceExited`. The stored position is the last in-bounds cell, and `active` becomes false.

This matches a straight legacy slide into an open gate, including level 1. It does not match a legacy exit that would leave while the next step also overlaps another piece. v2 refuses that exit.

## Transition

`transition` checks the action kind, the piece, unsupported mechanics, schema validity, and state identity, then accepts the action only when its canonical text is in `legal_actions` for that piece. It deep-copies the state, commits one MOVE or EXIT, and leaves the input state unchanged. A rejection returns `ok: false`, `next_state: null`, `events: []`, and an error code. Codes include `INVALID_ACTION`, `UNKNOWN_PIECE`, `UNSUPPORTED_FEATURE`, `INVALID_LEVEL`, `ILLEGAL_ACTION`, and `STATE_MISMATCH`.

Triggers, blockers, hidden pieces, locked gates, counters, rotation, and a non-null timer stay `UNSUPPORTED_FEATURE`. The solver returns `INVALID_LEVEL` for those puzzles and does not return `SOLVED`.

## Win

Every piece whose `required` flag is not explicitly false must be present and inactive. Legacy pieces are required. An optional piece may stay active. An empty required set is a vacuous win. Active flags are not ignored.

## Search

`SolverV2.solve(definition, initial_state, max_states)` is breadth-first on committed moves. It calls `PuzzleEngine.legal_actions` and `PuzzleEngine.transition`. `max_states` counts expanded states (pops). An already-won start returns `SOLVED` with an empty witness and zero expansions, including when `max_states` is 0. Otherwise the search stops with `UNKNOWN_CAP_REACHED` before a pop that would pass the budget. A win found on a child is accepted without expanding that child. `UNSOLVABLE` is returned only when the queue empties inside the budget. The witness is replayed through `transition` before `SOLVED` is returned. Replay failure becomes `INVALID_LEVEL`.

The seen set uses `PuzzleState.search_key()`, which is the canonical snapshot without the `move=` line. `canonical_hash()` still includes `move_number`. Gate mode, counters, blockers, reveal flags, and event counters stay in the key. TD-2 does not change those fields during a simple move.

`PuzzleEngine.assume_valid` is an internal speed flag. `solve` sets it only around the search, after one schema check, and clears it before witness replay. Public callers leave it false.

## What this does not prove

A `SOLVED` campaign line means that witness was replayed to a win under the cap used for that run. `UNKNOWN_CAP_REACHED` is not a proof that the level is unsolvable. Legacy `Rules.solve_min_moves` remains the campaign generator's check. Desktop tests are not Android device QA. Headless Godot may print ObjectDB leak warnings; those are not assertion failures.
