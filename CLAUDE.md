# CLAUDE.md — repository development guide

Block Puzzle Game — an original Android sliding-block puzzle built in **Godot 4.7.2**
(GDScript). This file is the quick reference for working in this repo.

## Golden rules
- **Original only.** No proprietary/competitor code, art, audio, fonts, or level data.
- **English-only UI.** All user-facing strings in English.
- **Monetization/analytics stay off** until real providers are integrated and
  explicitly approved. Default providers are no-op/stub, no network.
- Every shipped level must be **solver-verified** (`validate_all.gd` = 0 failures).

## Layout
- `scripts/core/` — pure logic/data (no scene deps; unit-tested): `level`, `rules`
  (slide + BFS solver), `catalog`, `settings`.
- `scripts/game/` — `board_view` (render + touch input), `game` (controller).
- `scripts/ui/` — menu, level select, settings screens.
- `scripts/editor/` — level editor + canvas.
- `scripts/services/` — `analytics`, `ads_service`, `iap_service` (autoloads).
- `scripts/audio/` — `audio_manager` (autoload).
- `scenes/` — thin `.tscn` wrappers; `levels/` — 100 JSON levels; `assets/audio/` — WAVs.
- `test/` — headless tests + generator; `docs/` — design docs.

See `docs/TECHNICAL_DESIGN.md`, `docs/LEVEL_SYSTEM.md`, `docs/MONETIZATION.md`.

## Tooling (verified machine paths)
- Godot editor (console): `D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`
- Android SDK: `D:\Android\Sdk` (platforms 35/36, NDK 27, build-tools 36). JDK 21.
- Export templates: installed under `%APPDATA%\Godot\export_templates\4.7.2.stable`.

## Common commands
```bash
GODOT="D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
# import (regenerate .godot) after a clean checkout
"$GODOT" --headless --path . --import
# run tests (exit code = failures)
"$GODOT" --headless --path . --script res://test/test_rules.gd
"$GODOT" --headless --path . --script res://test/validate_all.gd
"$GODOT" --headless --path . --script res://test/test_services.gd
# regenerate the 100 levels (seeded, solver-verified)
"$GODOT" --headless --path . --script res://test/gen_levels.gd
# build a debug APK (see docs/BUILD.md)
"$GODOT" --headless --path . --export-debug "Android" build/android/BlockPuzzle-debug.apk
```

## Conventions
- GDScript, tabs for indentation, typed vars where practical. Small focused files.
- Core logic stays engine-agnostic and testable; presentation reacts to `board_view`
  signals. Keep rules/visuals/content/monetization independently swappable.
- Persistence is local JSON under `user://` (no cloud/accounts).
- Add a new test to `test/` for any new core behavior; keep `validate_all` green.

## Gotchas
- A directly-run `--script` cannot reference autoload global names at compile time;
  fetch autoloads via `root.get_node("<Name>")` in such scripts (see `test_services.gd`).
- Screenshots for QA go to a scratch/`build/` path, not into `res://` game assets.
- Haptics need the VIBRATE permission in the export preset.
