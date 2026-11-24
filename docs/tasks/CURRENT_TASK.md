# BP-110 — Mobile layout foundation (visual rescue, phase 0)

**Status:** Layout foundation implemented. Visual quality is **not** approved. Not a beta or release candidate.
**Branch:** `rescue/mobile-safe-layout`
**Baseline:** `main` at `71432387bbca5ed73d234bd0bb621a5812b38c70`.

## Objective
Stop interactive UI from sitting under display cutouts or outside the portrait viewport, and record the visible defects before any premium art pass.

## Done this session
- [x] Document the layout defects in `docs/VISUAL_QA_MATRIX.md`.
- [x] Safe-area root (`scripts/ui/safe_area.gd`) uses `DisplayServer.get_display_safe_area()`, converted into canvas pixels, plus 16px content padding.
- [x] Menu, levels, settings, gameplay, pause, win, and the editor mount that root.
- [x] Level grid column count follows the safe width. Editor tools wrap. Gameplay HUD is Pause / level name / Undo. Restart and Main Menu are in Pause.
- [x] Player menu hides the level editor. It remains available in the Godot editor and when the game is launched with `--dev`.
- [x] `test/test_layout.gd` checks 360×800, 393×852, 412×915, a taller punch-hole inset, and side insets. Desktop renders: 36 screenshots, 0 failures.
- [x] `test_rules.gd`, `test_drag.gd`, `test_services.gd` exit 0. `validate_all.gd`: 100 levels, 0 failures.
- [x] Debug APK `build/android/BlockPuzzle-debug.apk` installed on `emulator-5554` (1344×2992, 480 dpi). Menu framebuffer `build/qa/device/menu2.png`: Play, Levels, Settings, no Editor, controls below the top inset. After Play, `build/qa/device/game.png` shows the Pause / title / Undo HUD. Drag, undo, and pause were not driven on the device.

## Not done
- [ ] Premium visual redesign (logo, dimensional blocks, gate art, win presentation).
- [ ] Directional gate-exit animation.
- [ ] Onboarding and a rebuilt difficulty curve.
- [ ] Product-owner approval.
- [ ] Full on-device interaction matrix and a second physical device.

## Do not do
No live ads, IAP, remote analytics, competitor assets, or merge to `main`.

## Handoff
Next bounded task: drive drag, undo, and pause on the emulator, then start the original visual pass. Do not mark the rescue complete from this layout foundation.
