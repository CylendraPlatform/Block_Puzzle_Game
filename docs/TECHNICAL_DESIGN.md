# Technical Design

## Engine & platform
- **Godot 4.7.2 stable**, GDScript, 2D, mobile renderer. Portrait 720×1280 reference,
  `canvas_items` stretch, `expand` aspect. Target Android (SDK 35/36, NDK 27). See
  [BUILD.md](BUILD.md).

## Architecture (clean separation)
```
scripts/
  core/      pure logic & data (engine-agnostic)
    level.gd      Level data model + from_dict / clone
    rules.gd      slide / collision / exit + BFS solver (solve, solve_min_moves)
    catalog.gd    level discovery + progress persistence
    settings.gd   [autoload Settings] preferences + transient nav state
    level_loader.gd, level_validator.gd, v1_adapter.gd
                  v2 schema validation and non-destructive v1 adapter
    puzzle_state.gd, puzzle_action.gd, puzzle_event.gd, puzzle_engine.gd, puzzle_search_context.gd, solver_v2.gd
                  canonical state, legal landings, open-gate exits, and shortest-move search
    See docs/decisions/ADR-002-deterministic-puzzle-state.md, docs/v2/SCHEMA_V2.md, and docs/v2/SOLVER_V2.md.
    Live play still calls rules.gd. The v2 engine is not wired into BoardView.
  game/
    board_view.gd rendering + touch-drag + easing (the only input surface)
    game.gd       controller: level flow, HUD, pause, undo, win, analytics hooks
  ui/
    main_menu.gd, level_select.gd, settings_ui.gd   screens (built in code)
    safe_area.gd  display-cutout padding
    ui_kit.gd     shared buttons, modals, screen mount
    dev_access.gd editor entry gate (`--dev` or the Godot editor)
  editor/
    editor_canvas.gd  renders editable state + reports cell/edge taps
    editor.gd         tools, validate (real solver), save/load, test-play
  audio/
    audio_manager.gd  [autoload Audio] SFX pool, music, haptics
  services/
    analytics.gd   [autoload Analytics] privacy-first local event sink
    ads_service.gd [autoload Ads] testable ad interface (no SDK)
    iap_service.gd [autoload IAP] purchase architecture (no billing)
scenes/   thin .tscn wrappers binding a Control root to its script
levels/   level_001..100.json (data)
assets/audio/  original generated WAVs
test/     headless SceneTree tests + generator tool
```

The **core** layer has no scene/node dependencies and is unit-testable headless.
Presentation (`board_view`) owns the mutable working state and emits signals
(`move_made`, `block_exited`, `won`, `grabbed`, `bumped`); the controller
(`game.gd`) reacts (undo snapshots, audio, analytics). Rules, visuals, content, and
monetization can each change independently.

## Data model
A level is a plain dictionary (see [LEVEL_SYSTEM.md](LEVEL_SYSTEM.md)): `cols`, `rows`,
`walls[]`, `blocks[]` (`id`, `color`, `cells[]`, `pos`), `gates[]`
(`color`, `side`, `lo`, `hi`). `Level.from_dict` parses JSON into typed fields;
`block_cells()` yields absolute occupied cells.

## Movement & collision (rules.gd)
`slide_result(level, blocks, block, dir, desired)` advances a block cell-by-cell in
`dir` up to `desired` steps, stopping at walls/blocks/edges; if blocked by the edge
and the block is flush against a matching-color gate spanning its crossing cells, it
returns `exit:true`. `max_slide` and `is_won` are helpers.

## Solver (rules.gd)
BFS over block configurations keyed by sorted positions. `solve()` returns
`{solvable, states}`; `solve_min_moves(level, cap)` returns the shortest solution
length (BFS depth) or -1 if unsolvable/over the cost cap. Used by tests, the level
editor's Validate, and the generator to guarantee solvable content.

## Input
Touch/drag handled only in `board_view._gui_input`. On press, hit-test picks a block
and snapshots state (undo). On drag, the dominant axis locks and the block moves the
clamped number of cells from its grab position (recomputed each event - deterministic).
On release, exits animate (scale pop) and `won` fires when the board clears. Blocks
ease toward their grid position each frame for a settle feel.

## Persistence (all local JSON under user://)
- `progress.save` - `{"unlocked": int}`
- `settings.save` - `{"sfx","music","haptics","analytics_opt_out"}`
- `entitlements.save` - `{"entitlements":{...}, "coins": int}`
- `custom_level.json` - editor save slot
No cloud, no accounts.

## Autoload order
`Settings -> Analytics -> IAP -> Ads -> Audio` (later ones depend on earlier). All are
null-guarded at call sites so scenes also run in isolation (e.g. screenshot tooling).

## Android specifics
Export preset `com.blockpuzzle.game`, arm64-v8a + armeabi-v7a, `use_gradle_build=false`
(repacks the prebuilt template - no Android Studio needed). Permissions: VIBRATE
(haptics); INTERNET off. Immersive mode on (Android shows a one-time full-screen hint).

## Safe area
`SafeArea` (`scripts/ui/safe_area.gd`) reads `DisplayServer.get_display_safe_area()`
and converts that window-pixel rectangle into the stretched viewport. Every screen
mounts it through `UIKit.mount`, so backgrounds can paint edge to edge while buttons
stay inside the inset plus 16px padding. Tests set `SafeArea.use_simulation`; shipping
builds do not hardcode a phone model. The level editor is omitted from the player
menu unless the process has the `editor` feature or the user argument `--dev`.
