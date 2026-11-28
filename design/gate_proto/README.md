# Positioned gates: design proposal (owner review)

**Proposal only. No production code, level, rule, save or flag changed.** The 100 Classic
levels and player progress are untouched; `gameplay/engine` stays `legacy`. This folder has a
`.gdignore`, so Godot neither imports nor exports it and no campaign or save reads it.

## Read in this order

1. `GAME_DESIGN_SPEC.md`: the gate rule, gate grammar, quality bar, the three prototype levels.
2. `GAP_ANALYSIS.md`: what PuzzleEngine / PuzzleState / LevelLoader / SolverV2 / the schema
   already support, and what an implementation cycle would change.
3. `VISUAL_PROPOSALS.md` with `mockups/`: three visual directions, mobile composition, exit
   storyboard.
4. `LEVEL_C_REVIEW.md`: what Level C's 65 optimal sequences are, and its place in Chapter 1.
5. `ART_SPEC.md`: recommended art direction (Carved Pearl) and its visual specification;
   side-by-side comparison in `mockups/art_direction_comparison.png`.
6. `MILESTONE_GP1.md`: the minimal implementation milestone (three levels, isolated dev route).
7. `art_selection/README.md`: art direction selection package (Carved Pearl vs Midnight Glass,
   layered concept mockups of Level C at identical scale; Toy Workshop kept as reference).
8. `GP1_IMPLEMENTATION_PLAN.md`: owner decision (Pearl default, Glass second, selectable
   themes) turned into the GP-1 plan: theme architecture, files, rendering, budgets,
   isolation, acceptance, rollback.

Owner review of `cf493760` (2026-11-27): gameplay model provisionally approved; visual
direction and implementation not yet approved. This PR stays a design reference, not a feature
merge. PR #27 (cell doors) is superseded and stays unmerged.

## Contents

| Path | What |
|---|---|
| `levels/proto_a.json` | Level A "First Door", 5x5, one 2-cell door, par 2 |
| `levels/proto_b.json` | Level B "Who Goes First", 5x5, two colours, par 6 |
| `levels/proto_c.json` | Level C "Turn the Corner", 6x6, four irregular shapes, par 9 |
| `mockups/*.png` | Board mockups and visual directions (Pillow renders, not device captures) |
| `mockups/render_mockups.py` | Regenerates the mockups: `python design/gate_proto/mockups/render_mockups.py` |
| `../../test/proto_gates_check.gd` | Validation of the three levels (quality bar + gate grammar) |
| `../../test/proto_level_analysis.gd` | Enumerates every optimal sequence of a level (Level C review) |

## Validation (2026-11-28, Godot 4.7.2 headless, Windows desktop)

```
godot --headless --path . --script res://test/proto_gates_check.gd
```
Exit code 0: 72 checks, 0 failures. Per level:
- schema-v2 load clean; `SolverV2` minimum == authored par; the authored solution replays
  through `PuzzleEngine.transition` and wins;
- `PuzzleMetrics`: agrees on the minimum, every gate reachable, optimal-sequence count complete,
  and in B and C the pieces are proven to depend on each other and to interact;
- no block can exit on move 1;
- gate grammar: 1-3 cells, one colour per gate, one gate per colour, no overlap on an edge, no
  two gates sharing a corner, every required block fits through a gate of its colour;
- each gate binding (widening it alone to the full edge shortens the best solution); all gates
  full-edge is much shorter.

A self-test feeds the grammar checks a level with 5 planted violations and requires all 5 to be
caught (they are; those FAIL lines in the log are expected and not counted).

| Level | Par (SolverV2) | States | All doors full-edge | One door full-edge | Optimal sequences | Pieces interdependent |
|---|---|---|---|---|---|---|
| A | 2 | 3 | 1 | 1 | 1 | n/a (one piece) |
| B | 6 | 5,841 | 3 | 4 / 5 | 11 | yes |
| C | 9 | 50,230 | 4 | 8 / 7 / 8 / 7 | 65 | yes |

Not done: human playtests, device rendering, any production implementation.
