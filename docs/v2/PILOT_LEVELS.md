# v2 pilot levels

Fifteen original levels in `levels_v2/pilot/`. They are not part of the commercial catalog. `Catalog.list_paths()` still returns the 100 files under `levels/`. Pilot progress is `user://pilot_v2.save` and stores only the last opened index. It does not write `user://progress.save`.

Godot 4.7.2, 2026-11-24. `test/test_v2_pilot.gd` loaded each file through `LevelLoader`, solved it with `SolverV2` at a 20000 expansion cap, and replayed the witness through `PuzzleEngine.transition` until `is_won`. Every level returned `SOLVED`. No human playtest has signed off on feel or difficulty.

Levels 1–3 are one-move tutorials. A straight free slide of several cells is one MOVE, so a two-move solution is usually one alignment plus one EXIT.

| Id | Name | Moves | Explored | What it asks |
| --- | --- | --- | --- | --- |
| v2-001 | First Drag | 1 | 1 | Drag one cell straight into a matching one-cell gate. |
| v2-002 | Straight Down | 1 | 1 | The same gesture on the vertical axis. |
| v2-003 | One Bar | 1 | 1 | A connected three-cell bar leaves as one piece. |
| v2-004 | Match the Row | 2 | 7 | Change rows before the one-cell gate will accept the piece. |
| v2-005 | Tall Enough | 2 | 6 | A two-cell piece needs a two-cell gate. A one-cell gate of another color is a decoy. |
| v2-006 | Whole Shape | 2 | 5 | A one-cell gate is too narrow for the L. The two-cell side gate fits after the piece moves up. |
| v2-007 | Around the Wall | 2 | 5 | The L has to rise before it can reach the gate. |
| v2-008 | Make Room | 2 | 6 | Move the blocking piece out through its own gate. |
| v2-009 | The Detour | 4 | 13 | A bar goes over a wall and comes back down at the gate. |
| v2-010 | Stop Short | 2 | 3 | The T fits the wide gate at one column. The furthest slide misses it. |
| v2-011 | Turn the Bend | 2 | 4 | The S fits the gate after one step, not after the longest slide. |
| v2-012 | Two Exits | 2 | 4 | Blue leaves downward, then the L can use the side gate. |
| v2-013 | Right Order | 4 | 90 | Two pieces block each other's lane and one must leave first. |
| v2-014 | Red Must Leave | 2 | 3 | Yellow is optional. Red must stop on the gate column. |
| v2-015 | Last Corridor | 5 | 56 | A wall splits the board. Both shapes must reach a gate that matches their full width. |

Prompts are English and dismissible. The design intent for each file is the `authored_metrics.intent` string.

## What is not in these levels

No locked gates, counters, triggers, hidden colors, timers, or blockers. Those stay fail-closed in `PuzzleEngine` and are TD-4 work. The legacy level editor still validates v1 JSON with `Rules`. It is not a v2 authoring tool. The pilot screen is the preview: it shows the level id, committed move count, and the solver verdict for the authored start.
