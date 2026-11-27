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

## Contents

| Path | What |
|---|---|
| `levels/proto_a.json` | Level A "First Door", 5x5, one 2-cell door, par 2 |
| `levels/proto_b.json` | Level B "Who Goes First", 5x5, two colours, par 6 |
| `levels/proto_c.json` | Level C "Turn the Corner", 6x6, four irregular shapes, par 9 |
| `mockups/*.png` | Board mockups and visual directions (Pillow renders, not device captures) |
| `mockups/render_mockups.py` | Regenerates the mockups: `python design/gate_proto/mockups/render_mockups.py` |
| `../../test/proto_gates_check.gd` | Validation of the three levels |

## Validation (2026-11-27, Godot 4.7.2 headless, Windows desktop)

```
godot --headless --path . --script res://test/proto_gates_check.gd
```
Exit code 0: 26 checks, 0 failures. Per level: schema-v2 load clean; `SolverV2` minimum ==
authored par; the authored solution replays through `PuzzleEngine.transition` and wins; every
gate reachable (`PuzzleMetrics`); each gate binding (widening it alone to the full edge
shortens the best solution); all gates full-edge is much shorter.

| Level | Par (SolverV2) | States | All doors full-edge | One door full-edge | Optimal sequences | Pieces interdependent |
|---|---|---|---|---|---|---|
| A | 2 | 3 | 1 | 1 | 1 | n/a (one piece) |
| B | 6 | 5,841 | 3 | 4 / 5 | 11 | yes |
| C | 9 | 50,230 | 4 | 8 / 7 / 8 / 7 | 65 | yes |

Not done: human playtests, device rendering, any production implementation.
