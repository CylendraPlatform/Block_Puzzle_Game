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
