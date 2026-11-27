# Gate presentation — investigation and alternatives (owner review)

**Status: the owner chose B (cell doors); implemented in PR #26 (renderer only) with the
mocked defaults: door depth 80 % of the frame band, an arrow on every door, a 10 % cell gap at
each end of a door. Pearl D3 stays pending until the owner approves the result.** No level
data, rule, solver, scoring or save change.

Sheets: `gate_alternatives.png` (4 styles × 5 boards) and `gate_alternatives_zoom.png` (edge
detail at 1:1). Both are desktop renders at the Galaxy M31 canvas width from
`test/mockup_gates.gd`, not device captures.

## 1. What the level data says

`test/report_gate_spans.gd` (headless, read-only) over all 100 Classic levels after loading:

|Measure|Result|
|---|---|
|Gates|313|
|Spanning their whole edge (`lo` = 0, `hi` = edge − 1)|**313** (5/5 ×49, 6/6 ×237, 7/7 ×27)|
|Partial or single-cell gates|**0**|
|Levels by number of full-edge gates|1 gate: 3 levels, 2: 20, 3: 44, 4: 27, 5: 6|
|Edges carrying two gates of different colours|**8** (levels 6, 7, 90, 91, 94, 95, 97, 99), all overlapping the full edge|

Level 54: bottom 0..5 yellow, right 0..5 green, left 0..5 blue (each 6 of 6 cells).

## 2. Data or rendering?

- **Every long strip comes from the level data.** The exit rule (`PuzzleEngine` gate match,
  `puzzle_engine.gd:302-305`; legacy `rules.gd:74`) lets a piece leave through a gate when every
  one of its cells' coordinates along that edge is inside `lo..hi`. Every Classic gate is
  `0..edge−1`, so the whole edge is a valid exit. The renderer draws `lo..hi`, inset by a
  cosmetic pad of about 6 canvas units at each end, i.e. slightly *narrower* than the rule, never
  wider.
- **Rendering defect found: shared edges hide a colour.** On the 8 edges with two gates the
  renderer draws one bar on top of the other, so only the last colour is visible (Level 6's right
  edge shows blue; red can also leave there). This is in the shipped v2 renderer before and after
  PR #26 and should be fixed whatever style is chosen.

## 3. Constraints for any design

1. Mark exactly `lo..hi`: never narrower than the rule, never wider. (The current end pad would
   be removed.)
2. Every colour accepted on an edge is visible on that edge.
3. Inside the frame band (the frame stays one component; no cut through the outer rim).
4. Readable as an exit: position, colour, both range ends, direction out of the board.
5. Contrast: colour on the dark frame (all piece colours are light/saturated against the navy
   frame); a white arrow or tick so colour is not the only cue.
6. Works for 1-cell, partial and full-edge gates on all four sides, and for 5×5, 6×6, 7×6 boards.

## 4. Alternatives

|Style|Short gate|Full-edge gate|Shared edge|Pros|Cons|
|---|---|---|---|---|---|
|**Current**|small bar|long bar along the edge|last colour only|simple|reads as an edge line; hides a colour; end pad narrows the range|
|**A Recessed doorway**|dark cut-out with colour, light posts at both ends, arrow|one long doorway with an arrow per cell, posts in the corners|two thin colour lanes|clear range ends; one object per gate|full-edge gates still read as a long strip|
|**B Cell doors**|one door|one door per cell (6 on a 6-wide edge) on a dark rail|each door split into two colour lanes|reads as distinct openings; each door is a cell a piece can leave through; range ends are the first/last door; compact for Chapter 1|busier on boards with 4–5 full edges; gaps between doors sit on cell boundaries, which some players may read as walls (they are not exit positions in either case, since pieces move whole cells)|
|**C Rail + badge**|thin rail with end ticks and one badge|thin rail along the edge, one badge at the centre|two rails, two badges|quietest; badge gives a strong single "exit here" cue|the rail is still a line along the edge — the look the owner asked to move away from|

## 5. Recommendation

**B (cell doors)** for Classic, with the shared-edge fix included:

- It is the only option where a full-edge gate reads as a row of openings rather than one strip,
  while still showing the complete valid range (every cell of the edge has a door).
- It scales down naturally: Chapter 1's shorter, strategically placed gates become one to three
  doors with no special case.
- Shared edges: each door is split into one lane per colour, so both colours are visible on every
  cell.

Open choices for the owner (each is a parameter, no rule impact):
1. Door depth: currently 80 % of the frame band (about 22 canvas units on the M31). A wider frame
   band on gated sides would make doors larger.
2. Arrow on every door, or only on the middle door of a run.
3. Gap between doors: 10 % of a cell (as mocked) or smaller.

If the owner prefers a single object per gate, **A** is the fallback.

## 6. If approved: implementation scope

Renderer only (`BoardViewV2._draw_gate` and its slot helper). Tests to add to
`test_board_geometry.gd`: every cell in `lo..hi` has a door inside the frame band; no door
outside `lo..hi`; every colour on a shared edge is drawn; existing frame, margin and
touch-mapping checks unchanged. Then new renders, the M31 device capture (exclusive access only)
and owner review.

## 7. Validation of this proposal

- No change to `levels/`, `scripts/` or `project.godot`; `gameplay/engine` stays `legacy`.
- `validate_all` exit 0; `test_board_geometry` exit 0 (43,784 checks, frame bounds, margins,
  gate slots, touch mapping, real swipe).
- Mockups load every board through `LevelLoader`; synthetic short / medium boards exist only in
  `test/mockup_gates.gd` and are not levels.
