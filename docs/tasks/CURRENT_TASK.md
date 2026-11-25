# TD-3.6 — Puzzle depth & gameplay production (P0–P1 corrections)

**Status:** P0 provisionally accepted. P1 solver validity accepted; fixture design rejected as generator seeds. Eight additional polyomino candidates are on `feat/td36-puzzle-depth-production` (PR #8) for product playtest. No human playtest. P2–P5 not started. Do not merge PR #6, #7, or #8. Do not bulk-generate.
**Parent:** `feat/td35-premium-playful-visuals` / PR #7 (unmerged), stacked on PR #6.
**Spec:** `docs/tasks/TD-3_6_IMPLEMENTATION.md`, `docs/v2/TD36_*.md`.
**Proofs:** `docs/v2/TD36_P1_BENCHMARKS.md`, `docs/v2/TD36_P1_CANDIDATES.md`, `docs/v2/td36_level_cards.json`, `levels_v2/td36/`.

`PuzzleMetrics` still times `SolverV2.solve` (cap 80 000). It now also labels `mechanism_family`, `interaction_pattern`, `genuine_multi_piece`, shape classes (including S/Z vs L), structural fingerprints, and pairwise similarity. `human_difficulty` is always `unmeasured`. `UNKNOWN_CAP_REACHED` is not treated as unsolvable.

`td36-001`–`008` stay technical fixtures (lengths 5, 6, 15, 18, 29, 22, 27, 31). `td36-009`–`016` are connected polyomino candidates (T, S, Z, I, L, plus). Shortest lengths 5, 5, 4, 5, 6, 5, 4, 6. None is `siding_1d`. Pairwise similarity among candidates is below 0.80. Dev menu **TD-3.6 QA** uses `user://td36_qa.save` only. `levels/`, `levels_v2/pilot/`, `user://progress.save`, `user://pilot_v2.save`, and the Play route are unchanged.

Godot 4.7.2, Windows, 2026-11-25 (Asia/Baghdad):

| Command | Exit |
| --- | --- |
| `--headless --script res://test/test_td36_metrics.gd` | 0 |
| `--headless --script res://test/test_td36_benchmarks.gd` | 0 (16 SOLVED, fixtures lengths unchanged, candidates not siding, no candidate near-duplicates, catalog 100, pilot 15, no progress.save) |
| `--script res://test/test_td36_shots.gd` | 0 (16 PNGs, 360×800) |
| `--script res://test/test_layout.gd` | 0 (player menu hides TD-3.6 QA; debug menu shows it in the safe area) |
| `--headless --script res://test/test_v2_pilot.gd` | 0 (15 SOLVED) |
| `--headless --script res://test/test_v2_session.gd` | 0 |
| `--headless --script res://test/validate_all.gd` | 0 (`validated 100 levels, 0 failure(s)`) |

Debug APK published as prerelease `td36-qa-debug` at commit `467b2d7`: https://github.com/CylendraPlatform/Block_Puzzle_Game/releases/tag/td36-qa-debug . File `BlockPuzzle-TD36-QA-debug.apk`, 63,082,110 bytes. Local SHA-256 `614FB3E1A569F669CEB385E3B564793CCE795F26D517E1F2306478F6F93DF08E`. `apksigner` verified v2 and v3. Pack contains 16 `levels_v2/td36/*.json` files. Not in git. The same release holds 16 desktop start-position PNGs.

Desktop PNGs: `build/qa/td36/` (gitignored). P2 not started. Human difficulty unmeasured. Do not merge PR #6, #7, or #8.

# TD-3.5 — Premium playful visuals

**Status:** Implemented on `feat/td35-premium-playful-visuals`. Not accepted. No physical Android device session and no owner visual sign-off.
**Parent:** `feat/td3-geometry-gates-pilot` (PR #6, unmerged). Design pack and this implementation update PR #7. Neither PR is merged.
**Spec:** `docs/tasks/TD-3_5_IMPLEMENTATION.md` and `docs/design/TD35_*.md`.

The pilot board, main menu, and pilot clear card use `TD35Theme` (pearl canvas, navy frame, token piece colors). Pieces are one connected silhouette with a shadow, a darker edge, and a shifted gloss. Gates cut a canvas opening through the frame and draw a colored mouth on the inner edge. The exit gesture is unchanged: 0.34 cell past the last landing, or 0.12 cell inside the screen-edge zone. A drag also draws a 0.15-opacity landing preview. `PuzzleEngine`, the 100 legacy levels, and `user://progress.save` are unchanged. The legacy campaign board stays on the dark `Style` palette. The pilot clear card says "Level Complete!" and does not add stars, gold, or a best score. The legacy campaign win screen still shows its real star count.

Desktop SubViewport captures are in `build/qa/td35/` (gitignored): menu at 360×800 and 412×915, pilot levels 1, 6, 10, 11, and 15 (level 15 with the clear card), plus synthetic 1×5, 5×1, 5×5, and 9×9 boards. These are not device screenshots.

Godot 4.7.2, Windows, 2026-11-24, after the visual edits:

| Command | Exit |
| --- | --- |
| `--headless --script res://test/test_v2_session.gd` | 0 |
| `--headless --script res://test/test_v2_pilot.gd` | 0 (15 `SOLVED`) |
| `--headless --script res://test/test_v2_foundation.gd` | 0 |
| `--headless --script res://test/test_rules.gd` | 0 |
| `--headless --script res://test/validate_all.gd` | 0 (`validated 100 levels, 0 failure(s)`) |
| `--headless --script res://test/test_services.gd` | 0 |
| `--headless --script res://test/test_drag.gd` | 0 |
| `--script res://test/test_layout.gd` | 0 (`screenshots: 36  failures: 0`) |
| `--script res://test/test_td35_shots.gd` | 0 (11 PNGs, real renderer; `--headless` cannot read the viewport texture) |

`test_v2_solver.gd` and `test_v2_campaign.gd` were not rerun. The campaign search is unchanged and last exited 0 on the parent branch.

Debug APK, test signing, published as prerelease `td35-qa-debug` at commit `4c28624`: https://github.com/CylendraPlatform/Block_Puzzle_Game/releases/tag/td35-qa-debug . File `BlockPuzzle-TD35-QA-debug.apk`, 59,772,779 bytes. Local SHA-256 `E952CD3A2AB398F75ED63785BDEB7DF6A9A9801ACC3454E497CB25CF36793540`. The downloaded asset and GitHub's asset digest match that hash. The same release holds the 11 desktop PNGs at their original sizes and the emulator captures below. This is not the TD-3 prerelease.

Emulator `emulator-5554`, Pixel_10_Pro_XL, 1344×2992, x86_64 image running the arm64 APK. Fresh captures: main menu, Level 6 L, Level 10 T, Level 11 S, and Level 15 with the Level Complete dialog. On Level 1, piece motion measured a 288 px cell. Releases about 0.10, 0.20, and 0.30 cell past the last in-board landing stayed on that cell. A swipe from the first cell to about 0.54 cell past the last landing opened Level Complete at Moves 1. Those shorter releases were outside the screen-edge band, so the 0.12 edge rule was not separately reached: on this board the band begins only after the finger has already passed 0.34 cell. Undo restored a one-cell move. Restart restored the start before a win. After the clear dialog, taps on Undo and Restart left the dialog and Moves 1 in place. A second swipe sent immediately after the 70 ms exit swipe did not add a move. `user://progress.save` was not present on the emulator after the session.

`dumpsys gfxinfo` during menu startup recorded 15 frames: 50th 46 ms, 90th 85 ms, 95th 97 ms, 7 of 15 janky. The GPU histogram put 4 of those samples in a 4950 ms bucket, which is an emulator outlier. A later sample during play reported 0 frames, so Godot's Vulkan surface is not a steady HWUI frame-time source on this emulator. No physical device frame times.

Differences from the written art direction: the board sits toward the top of the play area so a 5×1 strip is not stranded in the vertical center; gate mouths are flat vector cuts, and on a pearl page the outer punch blends into the background; gloss is a shifted polygon, not a licensed texture; buttons are themed Godot buttons, not the SVG files; no embedded font; debug builds still print the solver line because `DevAccess` is on; the clear dialog still covers the board, so the HUD Undo button is not reachable until the dialog closes.

# TD-3 — Playable v2 geometry, precise gates, and 15 pilot levels

**Status:** Implemented on `feat/td3-geometry-gates-pilot`. Not fully accepted. No physical Android session was run, and no human playtest has signed off.
**Baseline:** `origin/main` at `696b485` (merge of TD-2).
**Spec:** `docs/tasks/TD-3_IMPLEMENTATION.md`.
**Level notes:** `docs/v2/PILOT_LEVELS.md`.

## What this task delivered

An opt-in developer path plays schema v2 through `PuzzleEngine`. `PuzzleSessionV2` owns state, history, undo, restart, and win. `BoardViewV2` draws connected silhouettes and gate bars from `side`/`lo`/`hi`, and turns a drag into one `PuzzleAction`. The commercial campaign still uses `Rules`, `BoardView`, `levels/`, and `user://progress.save`.

The pilot is `scenes/Pilot.tscn`. It is on the main menu when `DevAccess.enabled()` is true: the Godot editor, a debug export, or a launch with `--dev`. A release export hides it. Progress for the pilot is `user://pilot_v2.save` and stores an index only.

Fifteen original levels live in `levels_v2/pilot/`. All fifteen solved and replayed to a win. See the table in `docs/v2/PILOT_LEVELS.md`.

The legacy editor was not extended. It still validates v1 levels. Calling that a v2 editor would be wrong. The pilot HUD is the preview and the diagnostic: level id, committed moves, and the solver status of the authored start.

An exit slides the silhouette out along the committed direction while input is locked. Pixel position is not read back into the rules.

## How to play the pilot

1. Open the project in the Godot 4.7.2 editor, or launch the game with the user argument `--dev`.
2. On the main menu, press **v2 Pilot**.
3. Drag a piece along a row or column. Release on a grid landing. Push about a third of a cell past the last landing to leave through a clear matching gate. A release on the last cell stays there.
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

## QA debug APK

Godot 4.7.2 exported a debug APK on 2026-11-24. The command was:

`Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-debug "Android" build/android/BlockPuzzle-TD3-QA-debug.apk`

Exit 0. `apksigner` verified APK Signature Scheme v2 and v3. The signer is the local debug keystore. That keystore and the APK are not in git.

| Field | Value |
| --- | --- |
| File | `build/android/BlockPuzzle-TD3-QA-debug.apk` |
| Size | 59,360,653 bytes |
| SHA-256 | `00d8e8dd1fbf7a3bdc04bb497cc8931650f6a62ae79ec8d7d01b3e63b5fb1a27` |
| Package | `com.blockpuzzle.game` |
| Contents | 100 `levels/level_*.json` files and 15 `levels_v2/pilot/v2_*.json` files |

`OS.is_debug_build()` shows **Editor** and **v2 Pilot** on this debug package. A release export does not. The local export preset, which is gitignored, includes `levels_v2/pilot/*.json`.

Installed on the already running `Pixel_10_Pro_XL` emulator (`sdk_gphone16k_x86_64`, ABI list `x86_64,arm64-v8a`, 1344×2992). This is an emulator session, not a physical phone.

| Check | Result |
| --- | --- |
| Main menu opens | Pass. Existing campaign label still read Level 11. |
| v2 Pilot visible | Pass. Debug menu shows Editor and v2 Pilot. |
| Level loads | Pass. v2-001, solver line `SOLVED (1)`, move count 0. |
| Drag | Pass. A one-cell swipe moved the piece and raised the count to 1. |
| Undo | Pass. The piece and the count returned to the start. |
| Restart | Pass. After another one-cell move, Restart restored the start. |
| Exit | Pass. A second drag from the last cell through the gate opened **Pilot Clear**. The count was 2 because the first drag stopped on the last cell. |
| Crashes | None in the recent error log. |

A single swipe from the first cell to the right edge stopped on the last cell instead of exiting. The exit committed when the next drag crossed the gate. Screenshots are in `build/qa/android/` and are not committed.

## Exit gesture

`BoardViewV2.steps_for_drag` interprets the finger. `PuzzleEngine` is unchanged.

A drag commits an exit only when that exit is already legal and the finger has traveled **0.34 cell past the furthest in-board landing**. Releasing on that landing, or up to 0.33 cell past it, stays a move. Inside the screen-edge zone (`max(48 px, 0.45 cell)` from the control border in the drag direction) the same exit needs only **0.12 cell** past the landing, so a system gesture band does not force a second drag. A blocked path still stops on the last free cell.

`test_v2_session.gd` covers short and long swipes, the two thresholds, one-cell and multi-cell pieces, all four directions, a wall in front of a gate, and undo after the exit. Exit code 0 on 2026-11-24.

The rebuilt debug APK was installed on the same `Pixel_10_Pro_XL` emulator. On v2-001, a short swipe moved one cell and left the count at 1. A swipe that ended on the last cell stayed there, still one move, with no win. After Undo, one swipe from the first cell through the gate opened **Pilot Clear** at move 1. The clear dialog covers the board, so the on-screen Undo button did not receive that tap. Undo after an exit is covered by `test_v2_session.gd`. This is still an emulator, not a physical phone.

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
