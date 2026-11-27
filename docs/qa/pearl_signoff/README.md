# Pearl theme — owner visual sign-off pack (decision D3), round 3

**Status: pending owner review.** Round 1 (`before/00_contact_sheet_round1.png`) was returned
with changes requested for the board's left/right edges, the strip under the board and the
board behind the Pause / Win dialogs. Round 2 corrected the board frame. The owner then asked
for gates to read as exit openings rather than edge strips and chose style **B, cell doors**
(`gates/GATE_DESIGN.md`). Round 3 (this pack) shows the frame fix plus cell doors. Presentation
only. `.gdignore` keeps these files out of the Godot project import.

**Gates (round 3).** Every Classic gate spans its whole edge in the level data (313 of 313),
so a gate is drawn as one door per cell over exactly the rule's exit range `lo..hi`, each with
an outward arrow, on a dark rail. Where two colours share an edge (levels 6, 7, 90, 91, 94, 95,
97, 99) each door is split into one lane per colour; before this, only the last colour was
visible.

**Start here: `00_contact_sheet.png`**, then `11_before_after.png` and `12_responsive.png`.

## What was wrong (root cause)

Measured on the round-1 Galaxy M31 captures (1080×2340, 1.5 px per canvas unit) and in
`scripts/game/board_view_v2.gd`:

1. **Cream strips at the board edges and under the board.** Each gate painted a "hole" rectangle
   in the page background colour (`TD35Theme.CANVAS`) from the frame's outer edge to the board
   edge, then drew the coloured gate bar on the inner part of it. The rest of the hole stayed
   cream, so the frame was cut open wherever a gate sat: a light sliver outside the left and right
   gates, and under a full-width bottom gate a cream line along the whole bottom edge (the
   "horizontal strip below the board"). It was part of the gate drawing, not an intended border.
   No element was drawn outside the frame rectangle; the frame itself was broken.
2. **Under the Pause / Win dim** the same cream cut-outs were darkened with everything else and
   read as disconnected partial borders.
3. **Frame not aligned with the HUD.** The board was fitted with a fixed 36-unit margin and the
   frame added outside it, so the frame's edges sat about 9 canvas units (14 device px) inside the
   Pause / Undo edges. Left and right margins were already equal.
4. **Piece gloss and shadow outside the piece.** The gloss copy of each piece was shifted up-left
   by up to 6 % of a cell, past the piece outline; the shadow was 8 % of a cell down, onto the
   frame / gate below a bottom-row piece.

The Pause / Win cards were already centred in the safe area (the available viewport): on the M31
they sit 28 canvas units below the screen centre because the status-bar inset is 56 units.
That is unchanged.

## What changed

- Gates sit inside the frame band as cell doors on a dark rail over exactly `lo..hi` (round 3;
  round 2 used one coloured bar). The outer 20 % of the frame band stays an unbroken rim on
  every side.
- The board and its frame are fitted together: the frame spans the board area's full width (the
  same edges as the Pause / Undo buttons) unless the height is the limit, and is centred with
  equal margins above and below.
- Piece gloss is the outline shrunk inwards; the shadow offset stays within the piece's own cells.
- No change to puzzle rules, scoring, saves, routing or touch thresholds. Touch-to-cell mapping
  uses the same origin / cell size as the drawing (`test/test_board_geometry.gd`).

## Files

|File|Screen|Source|
|---|---|---|
|`00_contact_sheet.png`|All of 01–10 on one sheet|composed|
|`01_menu.png`|Main menu|Galaxy M31 device capture (round 1, unchanged screen)|
|`02_level_select.png`|Level Select|Galaxy M31 device capture (round 1, unchanged screen)|
|`03_game.png`|Game screen, Level 54|desktop render, M31 canvas 720×1560|
|`04_pause.png`|Pause card|desktop render, M31 canvas|
|`05_win_card.png`|Win card (Level 1, 3 / 3 Stars)|desktop render, M31 canvas|
|`06_editor_test.png`|Editor Test: custom level on the game screen|desktop render, M31 canvas|
|`07_win_unsaved_desktop.png`|Win card when progress could not be saved|desktop render, 393×852|
|`08_leave_unsaved_desktop.png`|"Progress Not Saved" prompt|desktop render, 393×852|
|`09_game_four_gates.png`|Level 35: gates on all four sides|desktop render, M31 canvas|
|`10_game_tall_board.png`|Level 12: tall 5×6 board|desktop render, M31 canvas|
|`11_before_after.png`|Round-1 device captures vs round-2 renders; desktop 360×800 before / after|composed|
|`12_responsive.png`|360×800, 393×852, 411×891, M31 canvas × (Level 54, Level 35, Pause, Win)|composed from `responsive/`|
|`before/`|Round-1 files replaced by this round|device captures and desktop renders|

Notes
- **03–06 and 09–10 are desktop renders, not device captures.** The shared Galaxy M31 was not
  used (no exclusive access). Renders come from `test/shot_pearl.gd` with the M31 canvas size and
  a simulated 56-unit status-bar inset. A device capture of the corrected build is still to do
  when exclusive access is available.
- `01_menu.png` is a debug build, so it shows the developer entries. Player builds show only Play,
  Levels and Settings (verified with a release export; readiness report §7).
- 07 and 08 cannot be produced on a device without tampering with app storage; they come from
  `test/test_layout.gd`.
- The Settings and Editor screens still use the older dark style; they are not part of this
  sign-off.

## Sign-off checklist (owner)

- [ ] Board frame reads as one component; no strips or cut edges (03, 04, 05, 09, 10, 11)
- [ ] Left / right / top / bottom margins look balanced at every size (12)
- [ ] Colours, typography and spacing acceptable (01–10)
- [ ] Button sizes comfortable (48 dp minimum)
- [ ] Win, pause and save-problem dialogs readable (04, 05, 07, 08)
- [ ] Level Select readable at a glance (02)
- [ ] Approved for launch phase 1 / changes requested: ______________________
