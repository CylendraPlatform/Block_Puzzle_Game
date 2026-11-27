# Pearl theme — owner visual sign-off pack (decision D3)

Screenshots of the v2 screens as players would see them after activation. Device captures are
from a Samsung Galaxy M31 (1080×2340, 420 dpi) running QA builds of `main` with
`gameplay/engine = v2` set only for the export. `.gdignore` keeps these files out of the Godot
project import.

**Start here: `00_contact_sheet.png`** — all eight screens on one page (row 1: the six Galaxy
M31 captures; row 2: the two desktop renders of the save-problem dialogs).

|File|Screen|Source|
|---|---|---|
|`00_contact_sheet.png`|All of the below, labelled, on one sheet|composed from 01–08|
|`01_menu.png`|Main menu|device|
|`02_level_select.png`|Level Select (stars drawn, current level green, locked levels muted)|device|
|`03_game.png`|Game screen, Level 54 (centred board, 48 dp Pause/Undo, moves under the title)|device|
|`04_pause.png`|Pause card (full-screen dim)|device|
|`05_win_card.png`|Win card (Level 1, 3 / 3 Stars)|device|
|`06_editor_test.png`|Editor Test: custom level on the game screen|device|
|`07_win_unsaved_desktop.png`|Win card when progress could not be saved (Next locked, Retry Save)|desktop render, 393×852|
|`08_leave_unsaved_desktop.png`|"Progress Not Saved" prompt|desktop render, 393×852|

Notes
- `01_menu.png` is a debug build, so it shows the developer entries (Editor, v2 Pilot,
  TD-3.6 QA, Advanced QA). Player builds show only Play, Levels and Settings — confirmed with a
  real release export (see the readiness report, §7).
- 07 and 08 cannot be produced on a device without tampering with app storage; they come from
  `test/test_layout.gd`.
- The Settings and Editor screens still use the older dark style; they are not part of this
  sign-off.

## Sign-off checklist (owner)

- [ ] Colours, typography and spacing acceptable on the device captures (01–06)
- [ ] Button sizes comfortable (48 dp minimum)
- [ ] Win, pause and save-problem dialogs readable (04, 05, 07, 08)
- [ ] Level Select readable at a glance (02)
- [ ] Approved for launch phase 1 / changes requested: ______________________
