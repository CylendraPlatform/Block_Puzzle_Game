# Level System

## Coordinate system
Grid of square cells. Origin top-left. `x` = column (0..cols-1, +x right),
`y` = row (0..rows-1, +y down).

## Level JSON schema (`levels/level_NNN.json`)
```json
{
  "id": 1,
  "name": "First Slide",
  "cols": 5,
  "rows": 5,
  "walls": [[2,2]],
  "blocks": [
    { "id": "b1", "color": "red", "cells": [[0,0],[1,0]], "pos": [0,2] }
  ],
  "gates": [
    { "color": "red", "side": "right", "lo": 2, "hi": 2 }
  ]
}
```
- **walls**: `[x,y]` cells that block movement.
- **blocks**: `id` (unique), `color` (one of red/blue/green/yellow/orange/purple),
  `cells` = shape offsets relative to `pos`, `pos` = `[x,y]` of the shape origin.
- **gates**: `side` is left/right/top/bottom; `lo`..`hi` is the span of perpendicular
  cells it covers (rows for left/right, columns for top/bottom). A block exits a side
  only through a same-color gate whose span covers all of the block's crossing cells.

Colors are logical names mapped to palette values in the view; add a color by
extending the palette maps in `board_view.gd` / `editor_canvas.gd`.

## Exit rule
A block leaves the board when, moving toward a side, it is flush against that edge
and every crossing cell's perpendicular coordinate falls within a matching-color
gate's `[lo,hi]`. Then the whole block slides off and is removed.

### Intentional rule correction in the v2 engine (M1.3 decision D1)
The legacy `Rules.slide_result` checks the exit only after the next step is blocked, and
does not ask *why* it is blocked. So a block whose cell touches the gate edge exits even
when a wall or another block sits directly in front of one of its other cells (a
"pass-through" exit). The v2 `PuzzleEngine`, which Classic will run on from M1.3-C, does
not allow this: a block exits only when nothing in the board is in its way.

This is a deliberate correction, not a regression. `test/test_classic_equivalence.gd`
pins its exact impact on the 100 shipped levels:

- For every level, the legacy Play move set (every landing plus exits) and the v2 move
  set produce the same successor states on a bounded BFS (400 states), along a shortest
  legacy solution (which exercises every exit), and on 12 seeded random walks.
- The only difference allowed is a legacy-only pass-through exit. Within that bounded
  exploration it is reachable in exactly 11 levels: **021, 024, 044, 046, 061, 076,
  080, 081, 086, 088, 090**. A new or vanished difference anywhere fails the test.
- Every level's shortest legacy solution length equals its stored `par`.
- In 9 of the 11, the selected shortest legacy solution (the first one BFS finds) avoids
  the pass-through exit, replays unchanged in v2 and wins in `par` moves. Only in **021
  and 090** does that selected solution use one. This describes one witness per level,
  not every optimal solution.
- 021, 080 and 090 are solved by `SolverV2` in v2: shortest length equals the stored
  `par` (021: 3, 080: 7, 090: 5) and the witness replays to a win, so their star
  thresholds stay valid. (080 was flagged by the first, narrower M1.3 audit.)

Classic levels have stable ids `legacy-<file id>` (`CampaignCatalog`), equal to the save
index + 1 used by `progress.save`; the test fails if a file is renamed or reordered.

## Solvability guarantee
`Rules.solve(level)` (BFS) proves a level is clearable. `Rules.solve_min_moves` gives
the shortest solution length, used as a difficulty signal. **Every shipped level is
verified**; `test/validate_all.gd` re-checks all 100 (0 failures).

## Difficulty tiers (generator)
`test/gen_levels.gd` is seeded and deterministic. It places random walls/blocks/gates,
then keeps a candidate only if the solver confirms it solvable within a cost cap and
meets the tier's minimum move count (else keeps the best solvable found).

| Levels | Board | Blocks | Colors | Walls | Target min-moves |
|-------:|:-----:|:------:|:------:|:-----:|:----------------:|
| 1-10   | 5x5   | 1-2    | 1-2    | 0     | 2 |
| 11-30  | 5-6   | 2-3    | 2-3    | 0-1   | 3 |
| 31-60  | 6x6   | 3-4    | 3-4    | 1-2   | 4 |
| 61-85  | 6x6   | 4-5    | 3-4    | 2-3   | 5 |
| 86-100 | 6-7   | 5      | 4-5    | 3-4   | 5 |

Shipped spread of shortest-solution length: ~1->9 moves. Gates are full-side bars per
color (distinct sides when <=4 colors), chosen for reliable solvability; narrower,
hand-tuned gates can be authored in the editor.

## Level editor
Main Menu -> Editor. Tools: **Block** (place/remove current shape+color), **Wall**,
**Gate** (tap an edge cell to add/remove a 1-cell gate of the current color), **Erase**;
plus Shape cycle, Cols±/Rows± (3-9). **Validate** runs the real solver and reports
solvable + min-moves. **Save/Load** uses `user://custom_level.json`. **Test** plays the
custom level in the real game engine. Custom playtests never affect level progress.

## Adding hand-authored levels
Drop a `level_NNN.json` into `levels/` following the schema, run `validate_all.gd` to
confirm solvability, and it appears in Level Select automatically (sorted by filename;
bundled into the APK via the `levels/*.json` include filter).
