# TD-3 — Playable v2 geometry, precise gates, and 15 pilot levels

**Status:** Implemented on `feat/td3-geometry-gates-pilot`. Not fully accepted. No physical Android session was run, and no human playtest has signed off.
**Baseline:** `origin/main` at `696b485` (merge of TD-2).
**Spec:** `docs/tasks/TD-3_IMPLEMENTATION.md`.
**Level notes:** `docs/v2/PILOT_LEVELS.md`.

## What this task delivered

An opt-in developer path plays schema v2 through `PuzzleEngine`. `PuzzleSessionV2` owns state, history, undo, restart, and win. `BoardViewV2` draws connected silhouettes and gate bars from `side`/`lo`/`hi`, and turns a drag into one `PuzzleAction`. The commercial campaign still uses `Rules`, `BoardView`, `levels/`, and `user://progress.save`.

The pilot is `scenes/Pilot.tscn`. It is on the main menu only when `DevAccess.enabled()` is true (the Godot editor, or a player build launched with `--dev`). Progress for the pilot is `user://pilot_v2.save` and stores an index only.

Fifteen original levels live in `levels_v2/pilot/`. All fifteen solved and replayed to a win. See the table in `docs/v2/PILOT_LEVELS.md`.

The legacy editor was not extended. It still validates v1 levels. Calling that a v2 editor would be wrong. The pilot HUD is the preview and the diagnostic: level id, committed moves, and the solver status of the authored start.

An exit slides the silhouette out along the committed direction while input is locked. Pixel position is not read back into the rules.

## How to play the pilot

1. Open the project in the Godot 4.7.2 editor, or launch the game with the user argument `--dev`.
2. On the main menu, press **v2 Pilot**.
3. Drag a piece along a row or column. Release on a grid landing. Drag past the edge to take a matching gate.
4. Undo and Restart restore committed state. Menu returns to the main menu and does not write campaign progress.

## Evidence

Godot 4.7.2 stable (`D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`), Windows, 2026-11-24.

| Command | Exit |
| --- | --- |
| `--headless --script res://test/test_v2_session.gd` | 0 (`== done: 0 failure(s) ==`) |
| `--headless --script res://test/test_v2_pilot.gd` | 0 (15 `SOLVED`, witnesses replayed, cap 20000) |
| `--headless --script res://test/test_v2_foundation.gd` | 0 |
| `--headless --script res://test/test_v2_solver.gd` | 0 |
| `--headless --script res://test/test_rules.gd` | 0 |
| `--headless --script res://test/validate_all.gd` | 0 (`validated 100 levels, 0 failure(s)`) |
| `--headless --script res://test/test_services.gd` | 0 |
| `--headless --script res://test/test_drag.gd` | 0 |
| `--script res://test/test_layout.gd` | 0 (`screenshots: 36  failures: 0`) |
| `--script res://test/test_v2_pilot_shots.gd` | 0 (6 varied PNGs, Menu inside the safe area) |

Pilot solver results from `test_v2_pilot.gd`:

| Id | Moves | Explored |
| --- | --- | --- |
| v2-001 | 1 | 1 |
| v2-002 | 1 | 1 |
| v2-003 | 1 | 1 |
| v2-004 | 2 | 7 |
| v2-005 | 2 | 6 |
| v2-006 | 2 | 5 |
| v2-007 | 2 | 5 |
| v2-008 | 2 | 6 |
| v2-009 | 4 | 13 |
| v2-010 | 2 | 3 |
| v2-011 | 2 | 4 |
| v2-012 | 2 | 4 |
| v2-013 | 4 | 90 |
| v2-014 | 2 | 3 |
| v2-015 | 5 | 56 |

Desktop screenshots, not device photos, are under `build/qa/pilot/` (gitignored): `360x800_v2_001.png`, `360x800_v2_006.png`, `360x800_v2_010.png`, `360x800_v2_015.png`, `412x915_v2_006.png`, `360x800_cutout_v2_010.png`. The cutout uses simulated insets `(0, 96, 0, 48)`. A 720×1280 OS window was taller than the desktop framebuffer and produced an empty image, so those files are not evidence. The shot script draws into a `SubViewport` instead.

Headless Godot printed ObjectDB leak warnings and `1 resources still in use` on several scripts. Those warnings are not assertion failures. `test_v2_campaign.gd` was not rerun. The previous result remains solved=60, cap=40, failed=0 at cap 2500.

## Not accepted yet

- No physical Android device. Touch, cutout, and gesture QA on hardware are NOT RUN.
- No external playtest. Solver success is not a difficulty signoff.
- No interactive v2 level editor. Authoring stays in JSON plus the pilot preview.
- TD-4 conditions, counters, hidden color, timers, gold, and monetization are not in this branch.

## TD-2 history

Implemented on `feat/td2-complete-solver` and merged as PR #5 (`696b485`). `PuzzleEngine` enumerates every free cardinal landing and one straight open-gate exit. `SolverV2` replays that witness. Live campaign play stayed on `Rules` and `BoardView`.

Godot 4.7.2, 2026-11-24, before merge:

| Command | Exit |
| --- | --- |
| `--headless --script res://test/test_v2_foundation.gd` | 0 |
| `--headless --script res://test/test_v2_solver.gd` | 0 |
| `--headless --script res://test/test_rules.gd` | 0 |
| `--headless --script res://test/validate_all.gd` | 0 (`validated 100 levels, 0 failure(s)`) |
| `--headless --script res://test/test_services.gd` | 0 |
| `--headless --script res://test/test_drag.gd` | 0 |
| `--script res://test/test_layout.gd` | 0 (`screenshots: 36  failures: 0`) |
| `--headless --script res://test/test_v2_campaign.gd` | 0 (`CAMPAIGN solved=60 cap=40 failed=0`, about 910 seconds, cap 2500) |
| `--headless --script res://test/profile_v2_search.gd` | 0 |

The 40 cap results are levels 036, 044, 045, 050, 057, 061, 062, 064, 065, 067–072, 074, 075, 077–084, and 086–100. Those levels were not v2-solver verified. None returned `UNSOLVABLE` or a replay failure. All 100 adapters passed schema validation. The first eight levels were solved and replayed. Search expansions per second on the profiled levels rose from 114–211 to 324–494 with the same explored counts. Enumeration is the dominant cost.

## TD-0 / TD-1 history

Implemented on `feat/td0-td1-v2-foundation` and merged as PR #4 (`5a7d9d3`). Strict v2 validation and a non-destructive v1 adapter. Gameplay, BoardView, the legacy solver, and saves were unchanged on that branch. `authored_metrics` keys are not allowlisted. Trigger cycles stay with TD-4. A non-null timer is rejected rather than parsed.

BP-101 release-readiness remains in `docs/tasks/BACKLOG.md`.
