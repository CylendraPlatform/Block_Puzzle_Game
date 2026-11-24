# Visual QA matrix — layout rescue, phase 0

Desktop evidence only, from `test/test_layout.gd` on Godot 4.7.2 (exit 0, 36 PNGs under `build/qa/layout/`).
The simulated insets are canvas pixels applied by `SafeArea.use_simulation`. They are not a live Android cutout.
**Visual quality is not approved.** The premium art pass has not started.

| Defect | Where it showed up | Fix in this branch | Proof |
| --- | --- | --- | --- |
| Buttons and titles draw from the top of the window, under a punch-hole or status bar | Menu, HUD, level select, settings, editor | `SafeArea` pads from `DisplayServer.get_display_safe_area()` plus 16px | Layout test, top inset 96–128px. Example: `360x900-punch_game.png` keeps Pause/Undo below the reserved band |
| Gameplay HUD is four text buttons on the first row and crowds the board | `scripts/game/game.gd` | One row: Pause, level name, Undo. Restart and Main Menu are in Pause | `360x800_game.png`, `393x852_game_pause.png` |
| Level-select header sits on the top edge and the 5×92 grid leaves a side gap | `scripts/ui/level_select.gd` | Safe-area header. Columns and cell size follow the safe width | `360x800_levels.png` shows 4 readable columns (1–28 visible) inside the width |
| Editor tool rows extend past the right edge | `scripts/editor/editor.gd` | `HFlowContainer` inside the safe area, compact labeled buttons | `360x800_editor.png` wraps Back/Validate/… and Cols-/Rows+ on screen |
| Win and pause panels use a fixed size and a manual negative position | `scripts/game/game.gd` | Modal card centered in the safe rect, width capped at 520 | `360x800_game_win.png`, `393x852_game_pause.png` |
| Level editor is a player-facing menu item | `scripts/ui/main_menu.gd` | Hidden unless the Godot editor feature or `--dev` is set | Test asserts no Editor button on the player menu; `360x800_menu_dev.png` shows it only in dev mode |
| Square board floats in the vertical middle of a tall phone | `board_view.gd` | Grid stays width-fitted and is pinned under the HUD, with gate clearance | `360x800_game.png`. Empty space remains below the board on tall aspect ratios |
| Settings rows use a 240px label minimum with no cutout padding | `settings_ui.gd` | Safe area, wrapping labels, scroll | `412x915_settings.png` |

## Still open (not claimed fixed)

- Blocks still read as separate rounded cells, not one silhouette.
- No original logo, branded home art, or dimensional lighting pass.
- Exit feedback is still the existing scale-down. Directional gate travel is not implemented.
- No guided onboarding or rebuilt challenge curve.
- Product owner has not reviewed the player experience.
- Emulator `emulator-5554` (1344×2992) menu and gameplay HUD: `build/qa/device/menu2.png`, `build/qa/device/game.png`. Drag, undo, and pause were not driven on device.
