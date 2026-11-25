# TD-3.6 P1 — eight benchmark puzzles

Hand-authored `levels_v2/td36/` files. Metrics from `PuzzleMetrics.evaluate` (SolverV2, cap 80 000 expansions). Godot 4.7.2, 2026-11-25. Human playtest: not run. P2–P5: not started.

## Instrumentation (P0)

`scripts/core/puzzle_metrics.gd` calls `SolverV2.solve` and does not change `PuzzleEngine` legality.

| Field | Meaning |
| --- | --- |
| `shortest_proven` | True only when status is `SOLVED`. `UNKNOWN_CAP_REACHED` does not claim a shortest length. |
| `solution_length` | Witness size after replay. |
| `explored_states` | SolverV2 expansions (pops). |
| `branching` | Legal-action counts along the witness. |
| `shortest_path_count` | Separate BFS with path weights, cap 80 000. Incomplete counts are lower bounds. |
| `dependencies` | Solo solve of each piece, then other pieces turned into walls. `dependency_proven` if any piece’s length or solvability changes. |
| `unreachable_cells` / `unreachable_gates` | Flood-fill from start cells. |

Ceilings: main search 80 000 expansions; path-count 80 000; counterfactual 5 000; no wall-clock kill.

Recompute: `godot --headless --path . --script res://test/test_td36_benchmarks.gd` (prints CSV).

## Tier table (observed)

| ID | Target | Length | Pieces | Explored | Paths | Meets target hypothesis | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| td36-001 | Easy | 5 | 3 | 334 | 9 | Yes (5–10 actions) | L-tromino, one wall pocket |
| td36-002 | Easy | 6 | 4 | 1831 | 16 | Yes | L plus bars. First action is an open L exit |
| td36-003 | Medium | 15 | 4 | 344 | 3 | Yes (10–20 actions) | 2 vs 2 siding. Piece count below 5–8 |
| td36-004 | Medium | 18 | 5 | 3384 | 3 | Yes | 3 vs 2 siding |
| td36-006 | Hard | 22 | 5 | 7548 | 54 | Yes (18–35) | 2 vs 3 siding |
| td36-007 | Hard | 27 | 6 | 12800 | 4 | Yes | 3 vs 3, pocket occupied at start |
| td36-005 | Expert | 29 | 6 | 12800 | 24 | No (hypothesis 30+) | 3 vs 3 packed start |
| td36-008 | Expert | 31 | 6 | 12811 | 84 | Yes on length; no on 8–12 pieces | 3 vs 3, east tile starts in pocket |

A 7-piece 4-vs-3 file on this siding was fully searched and **unsolvable** (capacity/parity). An 8–12 piece, 30-move puzzle was not certified inside the cap. That gap is a TD-4 mechanics or search-envelope issue, not a padded 2-move “Expert”.

## Witnesses (shortest, SolverV2)

### td36-001 Park First (5)
1. move blue up 1,1
2. exit blue blue_left
3. move green right 3,2
4. exit green green_bottom
5. exit red red_right

### td36-002 Lift the Bar (6)
1. exit purple purple_right
2. move blue down 1,2
3. exit blue blue_left
4. move yellow right 5,1
5. exit yellow yellow_bottom
6. exit red red_right

### td36-003 Passing Siding (15)
1. move orange right 5,1
2. move yellow left 2,1
3. move yellow up 2,0
4. move blue right 4,1
5. move red right 3,1
6. move yellow down 2,1
7. exit yellow west
8. move red left 0,1
9. move blue left 1,1
10. move orange left 2,1
11. move orange up 2,0
12. exit blue east
13. exit red east
14. move orange down 2,1
15. exit orange west

### td36-004 Three Against Two (18)
1. move orange right 7,1
2. move yellow left 3,1
3. move yellow up 3,0
4. move green right 6,1
5. move blue right 5,1
6. move red right 4,1
7. move yellow down 3,1
8. exit yellow west
9. move red left 0,1
10. move blue left 1,1
11. move green left 2,1
12. move orange left 3,1
13. move orange up 3,0
14. exit green east
15. exit blue east
16. exit red east
17. move orange down 3,1
18. exit orange west

### td36-005 Equal Traffic (29)
Same three-cycle shuttle as 008 without the two setup moves that take green out of the pocket. Full list is in the probe log and is replayed by `test_td36_benchmarks.gd`.

### td36-006 Two Against Three (22)
Blue parks in the pocket first so two westbound tiles can leave, then red parks so blue can finish east. Full list replayed in the benchmark test.

### td36-007 Pocket Occupied (27)
Yellow starts in the pocket. The eastbound file pulls right, yellow exits, then two more westbound cycles. Full list replayed in the benchmark test.

### td36-008 Held East Tile (31)
1. move green down 3,1
2. move green left 2,1
then the td36-005 shuttle (29 actions). Total 31.

## Screenshots

Desktop SubViewport 360×800 start positions: `build/qa/td36/td36_00N_start.png` (gitignored). Produced by `godot --path . --script res://test/test_td36_shots.gd`. Not device QA.

## Out of scope (stop here)

Remaining 22 levels, generator, QA scene, timer, APK, human playtest, public Play route, merges of PR #6 / #7 / #8.
