# Positioned gates: visual proposals (for owner review)

Three directions, all drawn from the same prototype level data
(`mockups/render_mockups.py`, Pillow artwork, not game code and not device captures).

| Sheet | Shows |
|---|---|
| `mockups/visual_directions.png` | Level C in all three directions |
| `mockups/mobile_composition.png` | Full phone screen (390x844 pt) in all three directions |
| `mockups/levels_board_mockups.png` | Levels A, B, C start positions in the recommended direction |
| `mockups/exit_storyboard.png` | Exit sequence on Level A |
| `mockups/level_{a,b,c}_board.png` | Single boards at full size |

## Shared rules (every direction)

- **Solid frame.** The frame is one continuous bevelled piece. It is cut **only** where a gate
  is, exactly over the gate's cells `lo..hi`; the cut goes through the outer rim, so a door is a
  real opening, not a painted strip.
- **Recessed opening.** Dark tunnel floor that takes on the door colour toward the outside,
  light posts on the cell lines at both ends, a coloured threshold strip on the board edge, and
  one chevron per opening pointing out. One door = one object, however wide.
- **Block and door match** by colour on the threshold, tunnel tint and chevron (plus the colour
  glyph proposed in the spec, for colour-blind players).
- **Blocks.** One rounded body per piece with seamless joins (L, T and bars read as a single
  object), a darker lower band for thickness, a gloss lip on every upward-facing edge, a soft
  contact shadow.
- **Play well.** The grid sits in a recessed well with an inner shadow; cells are soft tiles,
  so the grid reads without lines.

## 1. Carved Pearl (recommended)

Ivory frame, deep blue well, candy-gloss blocks. Closest to the current Pearl palette
(`TD35Theme`), so menus and dialogs keep working; the board gains depth and real openings.
- Pros: highest contrast between frame, opening and block; reads well at 360 pt wide; calm.
- Cons: ivory frame on a cream page is low contrast; the board's drop shadow carries the edge.

## 2. Midnight Glass

Navy page and frame, glossier blocks, doors that glow in their colour.
- Pros: most premium feel; the glow makes doors very easy to find.
- Cons: a new dark theme for every screen; glow / blur cost GPU on low-end phones; colours need
  retuning for contrast on dark.

## 3. Toy Workshop

Wooden tray, painted matte blocks, carved notches for doors.
- Pros: warm, tactile, distinctive.
- Cons: wood texture adds noise behind the doors; matte blocks lose some depth; needs texture
  assets (more art work).

## Mobile composition

HUD on top (pause, level name, moves / par, hint), board centred and as wide as the safe area
allows, two large actions (Undo, Restart) in thumb reach at the bottom. On phones the board
size is set by the width.

## Exit animation (proposal)

| Phase | Duration | Notes |
|---|---|---|
| Slide to the frame | about 90 ms per cell, ease-out | existing move timing |
| Pass through the opening | about 180 ms | block clipped under the frame lip, so it disappears into the recess, never over the frame |
| Door pulse | about 250 ms | colour halo on the door, light haptic tick |

Reduced-motion setting: skip the pass-through, keep a short fade.

## Performance note

The current v2 board redraws every frame and its device cost is unmeasured. A production
version of any direction should pre-render the frame with its openings and the cell tiles once
per level (rebuilt on resize / safe-area change) and draw only blocks and effects per frame.
