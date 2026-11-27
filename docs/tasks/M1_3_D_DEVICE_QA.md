# M1.3-D — v2 GameScreen device QA (Classic on v2, flag-gated)

**Scope:** physical-device QA of the unified v2 `GameScreen` (M1.3-C) before any activation.
`gameplay/engine` stays `legacy` in the repository; v2 is **not** the default. Activation
(plan §9, "flip Play to Classic on v2") needs a separate approval.

## Setup (2026-11-27)

|Item|Value|
|---|---|
|Code under test|`main` at `fcae4ea` (M1.3-C merge), clean tree|
|v2 QA build|`build/android/BlockPuzzle-M1.3D-v2-debug.apk` — same commit, exported with `gameplay/engine="v2"` set only for the export and reverted before any commit (APK checked: `project.binary` holds `gameplay/engine = v2`)|
|Rollback build|`build/android/BlockPuzzle-M1.3D-legacy-debug.apk` — same commit, `gameplay/engine="legacy"`|
|Device|Samsung Galaxy M31 (SM-M315F, `R58R14KC1HZ`), 1080×2340, 420 dpi, Mali-G72|
|Signing|Both APKs and the installed app share certificate SHA-256 `f3349434…a00fea87d`|
|Install|`adb install -r` only. `firstInstallTime` unchanged (2026-11-25 18:09:18). No uninstall, no `pm clear`, no data reset.|
|Method|`adb shell input tap/swipe` + `adb exec-out screencap`; saves read with `run-as … cat` (read-only). Swipe paths for wins come from the v2 solver witness mapped to measured board geometry (QA helper, not shipped).|
|Evidence|`build/qa/m13d_device/` (gitignored, local): `baseline/`, `v2/` (screenshots 01–19), `after_win21/`, `after_v2/`, `rollback/`, `logcat_v2.txt`, `logcat_rollback.txt`|

Note: `adb logcat -c` (clears the device's log buffer, not app data) was run before the v2
launch and before the rollback launch so each log window covers one build.

## Progress preservation

Only levels that were already completed were won, so the Level 54 progress could not move.

|Point|Menu|`progress.save` (legacy)|`progress_v2.save`|
|---|---|---|---|
|Baseline (M1.3-C legacy build)|Level 54|unlocked 53, 53 star entries, md5 `38d174be…`|seq 1, classic unlocked 53, same 53 stars by stable id, chapter1 empty|
|After `install -r` of v2 build|Level 54|byte-identical|byte-identical|
|After the v2 session (3 wins, restart)|Level 54|values identical to baseline (re-serialized as ints, 386 bytes)|seq 3, unlocked 53, stars identical; `.bak` holds the previous version|
|After rollback to legacy build|Level 54|byte-identical to post-v2|unchanged (seq 3): the legacy route wrote nothing|

Every star value (1–53) and the unlock (53 → "Level 54") were preserved throughout.

## v2 GameScreen checks

|Check|Result|Evidence (`v2/`)|
|---|---|---|
|Startup on v2 build: menu shows Level 54 from the v2 store|PASS|`01_menu`|
|Play resumes at Level 54 — Clever Gate on the v2 screen (Pearl theme)|PASS|`02_play_level54`|
|One-cell drag lands on the last cell next to a gate without exiting (0.34 threshold)|PASS — Moves 1|`03_move_green_right`|
|Undo restores the board; score not refunded|PASS — Moves stays 1|`04_undo`|
|Exit gesture (+0.4 cell past the last cell)|PASS — green exits, Moves 2|`05_exit_green`, `06_after_exit`|
|Pause card (Resume / Restart / Levels / Main Menu)|PASS|`07_pause`|
|Restart resets board and score; saves untouched (md5 unchanged)|PASS — Moves 0|`08_restart`|
|App backgrounded by screen lock, then resumed|PASS — same board and score|`09b_after_unlock`|
|Level Select: 1–54 open, 55+ locked, stars by stable id match the save|PASS|`09_level_select`|
|**Strict-exit exception, level 021** (D1): after blue moves down one cell, a long left swipe stops at column 3 against the orange L — the legacy-only pass-through exit is not taken|PASS|`10_level21_open`, `11_level21_passthrough_attempt`|
|Level 021 won with the v2 solution in par 3 → "3 / 3 Stars"; saved (no warning note)|PASS|`13_level21_win_card`|
|Next opens Level 22|PASS|`14_next_level22`|
|Level 049: one wasted move + Undo, then the 4-move solution → Moves 5, "2 / 3 Stars"|PASS|`15_level49_wasted_undo`, `16_level49_worse_win`|
|Stored stars never decrease: 049 stays 3 stars|PASS — save and Level Select|`19_levels_after_restart`|
|Menu from the win card; app restart (force-stop + launch) keeps Level 54 and all stars|PASS|`17_menu_after_wins`, `18_menu_after_restart`, `19_levels_after_restart`|
|Safe area: HUD below the status bar, board and modals inside the screen on 1080×2340|PASS (visual)|all|
|Edge-zone exits (finger ends within the screen-edge zone: 021 left, 049 right)|PASS — exits accepted|`13_*`, `16_*`|

Levels exercised: 054 (6×6, wall), 021 (6×5, strict-exit exception), 022 (5×6), 049 (6×6,
walls, four exits). Animations were seen only as end states; mid-animation captures missed the
motion, and no frame-rate or timing claims are made.

## Rollback (return to the legacy route)

|Check|Result|Evidence (`rollback/`)|
|---|---|---|
|`install -r` of the legacy-default build over v2|PASS — Success, `firstInstallTime` unchanged|—|
|Menu still Level 54; Play opens the original legacy screen at Level 54 — Clever Gate|PASS|`20_legacy_menu`, `21_legacy_play`|
|Legacy and v2 saves unchanged by the legacy launch; values equal baseline|PASS|`rollback/*.save`|

The device was left on the legacy-default build, as before this QA.

## Logs

- v2 session (`logcat_v2.txt`, 09:03 → 09:16, 151,660 lines): no `SCRIPT ERROR`, `USER ERROR`,
  `FATAL`, ANR or Godot error line. The only "app died" entry is the deliberate
  `am force-stop` used for the restart test.
- Rollback launch (`logcat_rollback.txt`): no error lines.

## How unsuccessful and read-only saves are shown to players

Not reproducible on the device without tampering with app storage, so these paths are
covered by the headless failure-injection tests (`test_game_screen`, 103 checks) and the
desktop layout renders `build/qa/layout/*_game_v2_win_unsaved.png` and
`*_game_v2_leave_unsaved.png`.

|Save status|Win card|Next|Menu / Levels / Restart|
|---|---|---|---|
|`saved`|stars only|enabled|leave normally|
|`partial` (one of the two save files written; durable)|"Progress saved. A backup copy could not be written and will be retried." + **Retry Save**|enabled|leave normally (pending copy retried once)|
|`failed` (neither file written; not durable)|"Progress could not be saved. The next level stays locked until this win is saved. Tap Retry Save." + **Retry Save**|disabled|"Progress Not Saved" prompt: "This win could not be saved. If you leave now it will be lost when the game closes, unless a later save succeeds." → Retry Save / Leave Anyway / Stay|
|`read_only` (save from a newer version found)|"Progress is not being saved: this device has a save from a newer version of the game."|enabled (nothing can be saved on this device)|leave normally|

## Findings (no fixes made; for review)

|#|Finding|Severity|Note|
|---|---|---|---|
|F1|HUD Pause / Undo buttons are ~102×72 px ≈ 39×27 dp; modal and menu buttons are 84 px ≈ 32 dp tall — below the 48 dp touch-target guideline|Medium|All taps registered in testing; menu buttons are pre-existing (legacy menu)|
|F2|Level Select still uses the old dark theme and ASCII `***` stars, not Pearl|Medium|Shared by both routes; restyle would be visual-only|
|F3|Pause / win / prompt dim backdrop covers only the safe area; the status-bar strip and side margins stay light|Low|Cosmetic|
|F4|On v2 the board sits at the top with a large empty area; "Moves" is at the very bottom, far from the board|Low|Layout polish|
|F5|Editor Test on v2 was not exercised on the device (headless tests only)|Info|—|

## Not done

- v2 was **not** activated as the default; no activation PR was made.
- No save-failure or read-only state was forced on the device (see above).
- No performance or FPS measurement.
