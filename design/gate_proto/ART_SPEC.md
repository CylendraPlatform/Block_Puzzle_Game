# Art direction: Carved Pearl (recommendation and visual specification)

**Status: recommendation for owner approval. Not implemented.** All static values below
(palette, board, openings, blocks, shadows, HUD sizes) are the ones
`mockups/render_mockups.py` uses, so the mockups are renderings of this spec. Colour glyphs,
the drag lift and all motion are specified here only (not shown in the still mockups).
Units: `c` = cell size, `f` = frame band = `0.42 c`, `pt` = layout points (390x844 reference
phone). Colours are sRGB hex.

## Why Carved Pearl

Compared side by side in `mockups/art_direction_comparison.png` (same level, same 84 pt cell,
same crops):

| | Carved Pearl | Midnight Glass | Toy Workshop |
|---|---|---|---|
| Door visibility | high: dark tunnel in a light frame | highest: glowing doors | medium: dark notch in brown wood |
| Block / door colour match | clear on the blue well | clear; the glow helps | weaker: colours on warm wood and beige |
| Grid readability | high (tiles on deep blue) | medium (dark on dark) | medium (beige on beige) |
| Fit with the current game | keeps the Pearl palette (`TD35Theme`); menus, dialogs, Level Select unchanged | needs a new dark theme for every screen | needs a new theme and wood textures |
| Cost on low-end phones | flat fills plus one pre-baked frame | glow / blur effects | texture memory |
| Main risk | ivory frame vs cream page: needs the board shadow | contrast tuning, GPU cost | visual noise around doors |

Recommendation: **Carved Pearl**. Clearest doors and grid at 360 pt, lowest cost, and every
already-approved Pearl screen stays as it is.

## Palette

| Role | Hex |
|---|---|
| Page | `#FFF6EC` |
| Frame body / highlight / shade | `#E8DED2` / `#FCF7F0` / `#C4B6A6` |
| Play well | `#404E6E` |
| Cell tile / tile top band | `#4E5D80` / `#5C6C92` |
| Opening base | `#181E2E`, mixed 22 % toward the door colour |
| Text primary / secondary | `#283450` / `#786E64` |
| Blocks: red, blue, green, yellow, orange, purple | `#EE525C`, `#3A9CF0`, `#60C45C`, `#FFC434`, `#FF8E3C`, `#9C68E6` |

Colour glyphs (spec only): circle, square, triangle, diamond, star, hexagon in that colour
order, white at 18 % on the block's top face and on its door's posts, so colour is never the
only cue.

## Board

- Frame: one piece, outer radius `1.2 f`; bevel = body inset `0.1 f` (sides), `0.12 f` (top),
  `0.22 f` (bottom) over a highlight and a shade layer, so the lower lip reads as thickness.
- Board drop shadow (required; it separates the ivory frame from the page): offset `0, 0.12 c`,
  blur `0.18 c`, black 47 %.
- Play well: radius `0.16 c`; inner shadow on the top / left edges: offset `0.06 c, 0.08 c`,
  blur `0.05 c`, black 45 %.
- Cells: tiles inset `0.06 c`, radius `0.14 c`, top 18 % in the tile top colour. No grid lines.

## Openings (gates)

- Exactly over the gate's cells `lo..hi`, inset `0.04 c` at each end so the posts sit on the
  cell lines. The cut goes through the whole frame and `0.2 f` past its outer edge.
- Corner radius `0.1 c`; base fill = opening base colour.
- Tunnel floor: 8-step gradient from the board edge (darkest) outward, ending at the opening
  base mixed 75 % toward the door colour.
- Threshold strip on the board edge: `0.22 f` thick, inset `0.05 c` at each end, full door
  colour.
- Posts at both ends: `0.2 f` wide, frame highlight mixed 25 % toward white, rounded.
- One chevron per opening (never per cell): size `0.26 f`, door colour mixed 55 % toward white,
  pointing out of the board, centred in the tunnel.
- The frame outside openings is never cut, tinted or interrupted.

## Blocks

- One body per piece: cells inset `0.07 c` only on sides without a neighbour, so joins are
  seamless; corners rounded to about `0.22 c`.
- Thickness: whole body in the block colour darkened 30 %; top face = body shifted up `0.08 c`
  in the block colour; the darker band left at the bottom is the block's side.
- Gloss: a lip along every upward-facing edge of the top face (inner offset `0.1 c`, height
  `0.2 c`, blur `0.05 c`, white 41 %); a soft diagonal sheen (offset `0.35 c`, blur `0.12 c`,
  white 10 %); a rim `0.03 c` wide, block colour mixed 50 % toward white, at 60 %.
- Contact shadow: offset `0.04 c, 0.10 c`, blur `0.08 c`, black 35 %.
- While dragged (spec only): shadow offset and blur x1.5; no scale change.

## Transitions (spec only)

| Event | Motion | Duration / easing |
|---|---|---|
| Move | slide cell to cell | 90 ms per cell, max 300 ms, ease-out cubic |
| Blocked (frame or wrong door) | 4 pt bump toward the obstacle and back | 80 ms |
| Exit | slide to the frame, continue into the opening; the block is clipped to the play well plus the opening, so it disappears under the frame lip (`mockups/exit_storyboard.png` frame 3) | 180 ms after reaching the frame, ease-in |
| Door pulse | halo in the door colour (blur `0.3 c`), alpha 100 % to 0 (frame 4) | 250 ms, ease-out; light haptic tick |
| Aligned hint | threshold strip brightens 20 % while a matching block is aligned with it | 120 ms fade |
| Reduced motion | no bump, no pass-through: the exit is a 150 ms fade; the pulse stays | |

## Mobile HUD (390x844 pt reference, `mockups/mobile_composition.png`)

- Respect the safe area on every side (`SafeArea`); the mockup has no insets.
- Top bar: Pause (left) and Hint (right) buttons 46x46 pt, radius 14 pt, frame colour, centred
  40 pt from the screen edges; title centred, 22 pt semibold, text primary; "Moves n / Par p" below
  it, 15 pt, text secondary.
- Board: centred, as wide as the safe width allows minus about 20 pt per side; on very tall
  boards the height limits it instead.
- Bottom actions: Undo and Restart, 130x50 pt, radius 20 pt, frame colour, centres 150 pt
  apart, centred 100 pt above the safe-area bottom.
- Every touch target at least 48 dp. Text English only.

## Performance rules

Bake the frame with its openings and the cell tiles once per level into a texture (rebuild on
resize / safe-area change); per frame draw only blocks, the dragged block's shadow and active
effects. Measure on the Galaxy M31 with the Godot profiler before the implementation is
approved (only with exclusive device access).
