# Positioned gates: game design specification (proposal)

**Status: proposal for owner review. Nothing here is implemented in the shipped game.**
The 100 Classic levels, their rules, scores and player progress are unchanged. The three
prototype levels live in `design/gate_proto/levels/` (a `.gdignore` folder: not imported, not
exported, not in any campaign, never read by the game or its saves).

## 1. Why the current Classic gates cannot be fixed visually

All 313 Classic gates span their whole edge (`test/report_gate_spans.gd`). Under the rules
that means "any block of this colour that reaches this edge leaves", so the gate's position
carries no information and creates no puzzle. Drawing it as one bar, doors or a recess does not
change that. A positioned exit has to be in the level data and enforced by the rules.

## 2. The rule (already in the engine)

A block **leaves** when the player slides it toward an edge and, at the frame, all of these hold:

1. there is an **open gate** on that edge that **accepts the block's colour**;
2. the **block's whole width across the slide direction** fits inside the gate's cells
   `lo..hi` (for a left/right gate: every row the block covers is in `lo..hi`; for a top/bottom
   gate: every column it covers);
3. exactly one gate matches (two gates of the same colour may not overlap on an edge; the
   validator rejects it).

Otherwise the block stops against the frame (an ordinary move). The alignment slide and the
exit are **one move**. Blocks keep their orientation (no rotation).

This is real enforcement, not cosmetic narrowing: `PuzzleEngine._matching_gates`
(`scripts/core/puzzle_engine.gd:266-308`) implements exactly this, and `SolverV2` searches
with it.

### Multi-cell and irregular blocks

The test is the block's **silhouette extent**, not only the cells touching the edge. What the
designer must know:

| Block | Exits left / right through | Exits top / bottom through |
|---|---|---|
| 1x1 | 1-cell gate | 1-cell gate |
| horizontal bar (2 wide) | 1-cell gate | 2-cell gate |
| vertical bar (2 tall) | 2-cell gate | 1-cell gate |
| L (2 wide, 2 tall) | 2-cell gate | 2-cell gate |
| T (3 wide, 2 tall) | 2-cell gate | 3-cell gate |
| I3 vertical | 3-cell gate | 1-cell gate |

A gate's width is therefore a statement about **which shapes may use it and from which side**.
A gate narrower than every block of its colour along that axis is unusable (an authoring
error; see the lint in `GAP_ANALYSIS.md`).

## 3. Gate grammar for the new campaign

**Placement**
- A gate covers whole cells `lo..hi` on one edge; its ends sit on cell lines.
- Width 1 to 3 cells. Full-edge gates are not used in the new campaign.
- A gate may include a corner cell, but two gates never meet at a corner.

**How many**
- **Simple levels: one gate per colour.** Every required block has one exit.
- Two gates for one colour only when a level teaches a choice (different sides or widths) or an
  advanced mechanic needs it (locked / counter / colour-switching gates, already supported by
  the engine). Never two overlapping gates of the same colour (validator rule).
- Different colours may share an edge but **do not overlap** in the new campaign (overlap stays
  legal in the engine for Classic). One opening on screen = one colour.

**Width as a design tool**
- *Tight* (gate width = block width): demands exact alignment; the main teaching tool.
- *Loose* (one cell wider): forgives one row or column; use to relax a late step.
- *Shape filter*: a 1-cell gate admits a bar only end-on, so the approach side matters.

**What makes it a puzzle**
- *Lane conflict*: one block's way to its gate crosses another block's (Level B).
- *Shape lock*: an irregular block's foot or arm closes another block's lane (Level C).
- *Parking*: a block must step aside to a cell that is not on its own way out (Level C, yellow).
- Every gate must be **binding**: widening it to the full edge must shorten the best solution
  (`test/proto_gates_check.gd`). A gate that does not change the solution is decoration.

## 4. Level quality bar (every level)

- Complete schema-v2 definition, validator clean.
- `SolverV2` minimum == authored par; the authored solution replays and wins.
- No block can exit on move 1 (tutorial levels excepted).
- Every gate binding; the all-full-edge minimum clearly below par.
- `PuzzleMetrics`: every gate reachable; optimal-sequence count and `genuine_multi_piece`
  recorded.
- Human playtest still required: a solver pass proves solvability, not fun.

## 5. Prototype levels (proof of concept)

All three pass `test/proto_gates_check.gd` (command and results in `README.md`).

### Level A "First Door" (5x5, par 2)
One tall red bar; one 2-cell red door on the right edge, rows 2-3. Sliding right from the start
only reaches the frame; the bar must drop two rows first. Teaches: *the exit is a place, and the
block must line up with it.* With a full-edge gate it would take 1 move.
Solution: red down to (1,2); red exits right.

### Level B "Who Goes First" (5x5, par 6)
Red door: top edge, columns 3-4. Blue door: left edge, rows 3-4. A red bar, a red dot and a blue
bar. The dot sits in the blue bar's escape row; the blue bar sits in the red bar's escape
column; the red bar, once lined up, closes the blue bar's way down. So the dot must step out of
row 4 before the blue bar comes down, and the blue bar must leave before the red bar can.
Teaches: *two colours, two places, order matters.* Widening the red door alone gives 4 moves,
the blue door alone 5, both 3.
Solution: dot right to (4,4); dot exits up; blue down to (3,3); blue exits left; red bar right to
(3,2); red bar exits up. `PuzzleMetrics`: 11 optimal move orders, pieces proven to depend on
each other.

### Level C "Turn the Corner" (6x6, par 9)
Red L (needs bottom columns 4-5), blue T (needs left rows 2-3), green I3 (needs top column 1),
yellow bar (needs right row 4). Yellow and the T block each other until yellow steps aside; the
L's foot closes the I3's column; the I3 closes the L's column. Teaches: *the shape decides
which opening fits, and blocks become obstacles.* Widening any one door alone gives 7 or 8
moves, all four 4. `PuzzleMetrics`: 65 optimal move sequences, no shorter solution,
pieces proven to depend on each other.
Solution: yellow right to (4,2); T up to (1,2); T exits left; L right to (4,0); I3 left to (1,3);
I3 exits up; yellow down to (4,4); yellow exits right; L exits down.

## 6. Player feedback (presentation only, no rule change)

- A block hitting the frame or a wrong-colour door: short bump (about 4 pt, 80 ms), no penalty.
- While a block is dragged along the edge that holds its door, the door's threshold brightens
  when the block is aligned (affordance).
- Exit: the block slides into the recess, passes under the frame lip and is gone; the door
  pulses once in its colour (`mockups/exit_storyboard.png`).
- Colour is never the only cue: each colour gets a glyph (proposed: circle, square, triangle,
  diamond, star, hexagon) drawn faintly on the block and on its door's lintel.

## 7. Out of scope here

The 20-level Chapter 1, a production renderer, editor changes, store or save changes, and
activation of v2. `GAP_ANALYSIS.md` lists what an implementation cycle would need.
