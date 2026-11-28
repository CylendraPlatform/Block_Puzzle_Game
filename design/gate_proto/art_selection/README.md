# Art direction selection: owner-review package

**Status: for owner decision. Nothing here is implemented.** No game code, level, rule, save,
setting or feature flag changed; `gameplay/engine` stays `legacy`. No APK was built or
installed.

**Every image in this folder is a concept mockup** drawn offline with Pillow by
`render_art_selection.py`. None of them is a gameplay screenshot or a device capture. The
original PR #28 mockups (v1) are in `../mockups/` and are unchanged.

## What to look at

Start with `renders/comparison_sheet.png`. It shows both shortlisted directions side by side
at identical scale, then the v1 originals, including Toy Workshop, as a reference.

| Deliverable | Carved Pearl (A) | Midnight Glass (B) |
|---|---|---|
| Gameplay screen, 390x844 pt (1x and @2x) | `renders/pearl_game_390x844.png`, `..@2x.png` | `renders/glass_game_390x844.png`, `..@2x.png` |
| Win screen, board visible behind the result card | `renders/pearl_win_390x844.png`, `..@2x.png` | `renders/glass_win_390x844.png`, `..@2x.png` |
| Positioned gate and its frame opening, close-up | `renders/pearl_gate_closeup.png` | `renders/glass_gate_closeup.png` |
| L and T blocks, close-up | `renders/pearl_blocks_closeup.png` | `renders/glass_blocks_closeup.png` |
| Four-frame exit storyboard | `renders/pearl_exit_storyboard.png` | `renders/glass_exit_storyboard.png` |
| Contrast numbers and geometry check | `renders/metrics.json` | same file |

Toy Workshop is kept as a reference only: it appears in the v1 sheet at the bottom of the
comparison and in `../mockups/visual_directions.png`. It was not redrawn.

## Same level, same framing

- **Level:** prototype Level C "Turn the Corner" (`../levels/proto_c.json`), read by the
  script. Board size, every piece's cells and position, and every gate's side and `lo..hi`
  come from that file. Nothing is hand-placed.
- **Same output in both directions:**
  - the same render function, with only the colour and material tokens differing;
  - the same cell size: 51.7 pt in the phone screens (the board is 358 pt wide on a 390 pt
    screen), 130 px in the close-ups, 48 px in the storyboards;
  - the same crops, states and HUD layout.
- **Storyboard:** shows solution moves 2-3. The blue T lines up with rows 2-3 and leaves
  through the left door. The positions are those after move 1, with yellow parked at (4,2).
- **Win screen:** every block has left. The red L leaves last (move 9), so its door pulses.

### Geometry check

Each run of the script samples the frame next to every edge cell. It checks that the frame
is open exactly on the gate cells, solid everywhere else, and that no gate spans a full
edge. Run on 2026-11-28 (Windows desktop, Python + Pillow), with the same result for both
directions, on both the phone board and the close-up board:

```
left edge: open cells [2, 3] of 6      (blue_left  lo 2 hi 3)
right edge: open cells [4] of 6        (yellow_right lo 4 hi 4)
top edge: open cells [1] of 6          (green_top  lo 1 hi 1)
bottom edge: open cells [4, 5] of 6    (red_bottom lo 4 hi 5)
all geometry checks: PASS (exit code 0)
```

So each gate has one opening, posts on the cell lines, and no repeated or full-edge doors.

## What is new compared with the v1 mockups

The v1 boards were mostly flat fills with a simple bevel. Both new concepts use one shared
layered build, with a single light from the top-left and one shadow direction for every
element:

1. **Slab:** the board is a raised slab with a visible thickness and a soft ambient shadow
   plus a tight contact shadow on the page.
2. **Recessed well:** the well sits below the frame. The frame casts an inner shadow into
   it, and the frame's south-facing lip shows as a thin band at the top of the well.
3. **Cells:** each cell is a shallow dimple with its own inner shade.
4. **Openings:** each gate cuts through the frame. The opening is part of the recess, so the
   frame's bevel wraps around its posts, the jambs cast occlusion onto the channel floor,
   and an exiting block passes *under* the lip (storyboard frame 3).
   - In Pearl the channel falls away into shadow.
   - In Glass light comes in through the opening and spills onto the page.
   - Each opening has one coloured threshold strip, one outward chevron and the colour glyph.
5. **Blocks:**
   - extruded bodies with a darker side face, a contact and an ambient shadow, a double
     bevel and a specular lip;
   - seamless joins inside L and T shapes;
   - an embossed colour glyph (circle, square, triangle, diamond).
   - Pearl adds an enamel sheen.
   - Glass is translucent, with a lit inner edge, a darker core, a diagonal specular streak
     and a coloured glow underneath.

## Side-by-side comparison

| | Carved Pearl (A) | Midnight Glass (B) |
|---|---|---|
| Character | warm, calm, tactile porcelain and enamel; daytime | dramatic, premium, night-time; lit glass |
| Door read | dark tunnel cut into an ivory frame; opening floor vs tray **8.83:1** | doors emit coloured light; door strip vs tray **4.23-8.62:1**, but the opening floor is close to the tray (**1.52:1**), so the glow carries the read |
| Block read | colour on a mid-blue well: luminance contrast is low (**1.58-3.48:1**); hue, side face, shadow and glyph carry the read | bright blocks on a near-black well: **4.89-9.98:1** |
| Grid and board edge | cell vs tray **4.61:1**: the board edge is obvious | cell vs tray **1.16:1**: the edge relies on the cyan rim light |
| Text | title 11.74:1, secondary 4.99:1, buttons 10.3:1 | title 13.71:1, secondary 6.48:1, buttons 11.01:1 |
| Fit with existing screens | matches the current Pearl theme; menus, dialogs and Level Select can stay | every screen needs a new dark theme |
| Colour-vision safety | glyphs required (red vs green block contrast is low) | glyphs still required; the glow colour alone is not enough |

Contrast is the WCAG ratio between flat token colours, from `renders/metrics.json`. It
ignores gradients, shadows and glyphs, so it understates how readable the shaded blocks are.
It is still the right warning sign: in Pearl, block colour on the well is a hue difference
more than a brightness difference.

### Android performance implications (estimates, not measured)

No device was used and no frame rate is claimed. These follow from how each look would be
built in Godot 4.7 (Compatibility renderer, the current Android export).

- **Pearl:**
  - Everything here is static, so it can be baked:
    - one board texture per level: slab, well, cells, openings, shadows;
    - one pre-rendered sprite per piece shape and colour, or 9-slice parts tinted at
      runtime.
  - Per frame: a handful of textured quads. No shaders, no blur, no screen reads.
  - The exit clip under the frame lip is a draw-order trick: draw the frame lip on top of
    the moving block. It needs no mask shader.
- **Glass:**
  - Needs the same baking, plus:
    - translucent blocks (alpha blending over the board: more overdraw);
    - glow sprites under every block and at every door;
    - additive light spill;
    - a blurred backdrop for the result card.
  - Glows must be pre-baked sprites. A real-time blur or a screen-texture read
    (`BackBufferCopy` / `hint_screen_texture`) would be the expensive part on Mali-class
    GPUs such as the Galaxy M31's.
  - Dark UI saves power on AMOLED screens.
- Both need the existing pre-bake approach from `../ART_SPEC.md`. The current
  every-frame redraw would be too costly for either look.

### Estimated implementation complexity (prototype route only, per `../MILESTONE_GP1.md`)

| | Pearl | Glass |
|---|---|---|
| Board, openings, blocks renderer with baking | medium | medium-high (translucency order, glow atlases, spill) |
| Theme work outside the board | small: reuses the current Pearl screens | large: a dark theme for every screen and dialog |
| Contrast and accessibility risk | block-on-well contrast needs a check on a device | board edge and opening floor depend on effects |
| Rough effort for GP-1 visuals | about 4-6 developer days | about 7-10 developer days |

The effort figures are planning estimates, not measurements.

## Design tokens

Both palettes are defined in `TOKENS` in `render_art_selection.py`, and the swatches are on
the comparison sheet. Geometry tokens are shared by both directions, in units of the cell
size `c`:

| Token | Value |
|---|---|
| Frame band | 0.46 c |
| Tray thickness | 0.07 c |
| Well corner radius | 0.20 c |
| Cell inset | 0.05 c |
| Cell corner radius | 0.16 c |
| Block inset (free sides only) | 0.075 c |
| Block corner radius | 0.22 c (Pearl), 0.18 c (Glass) |
| Block thickness | 0.11 c |
| Opening inset at each end (posts on cell lines) | 0.045 c |
| Threshold strip width | 0.075 c |
| Contact shadow | offset 0.02, 0.14 c; blur 0.05 c |
| Ambient shadow | offset 0.05, 0.25 c; blur 0.18 c |

## Recommendation (the decision is the owner's)

**Carved Pearl**, with two conditions:

1. Glyphs are mandatory on blocks and doors.
2. The block-on-well contrast is checked on a real phone before the art is locked, for
   example by lightening the well one step if needed.

Reasons for Pearl:
- it has the clearest door and board-edge read;
- every effect can be baked, so the Android cost is lowest;
- it keeps the approved Pearl screens.

Midnight Glass is the stronger "premium" look and has the best block contrast. Choose it if
the dark identity matters more than the extra theme work and the reliance on glow effects.

## Regenerate

```
python design/gate_proto/art_selection/render_art_selection.py
```

This needs Python 3 with Pillow and takes about 2 minutes. It rewrites `renders/` and exits
non-zero if the geometry check fails.

## Not done

- No device capture or human playtest; contrast is computed, not observed on a screen.
- The motion is described by four still frames, not animated.
- Orange and purple (star and hexagon glyphs) are not in Level C, so they are not shown.
