# M1.3 — Activation readiness assessment (launch phase 1: Classic on v2)

**Question:** is the project ready to flip `gameplay/engine` from `legacy` to `v2` so Play and
Levels open Classic on the v2 `GameScreen` (plan §4.2, phase 1)?

**Answer: not yet.** The code, saves and automated gates are ready, and after the round-3
device checks (§6) three items remain: merging the editor touch fix (PR #21, with which
Editor Test passed on the device — F5), the owner's Pearl sign-off, and the release note /
version-code plan.
Nothing here activates v2: `gameplay/engine` stays `legacy` on `main`.

**Baseline:** `main` at `f50eb8c` (M1.3-D merge). CI run 45961420196 on `f50eb8c`: `headless`
success, `classic-compat` success. Evidence: `docs/tasks/M1_3_D_DEVICE_QA.md` and PRs #16–#19.

## 1. Automated gates (plan §8.1)

|Criterion|Status|Evidence|
|---|---|---|
|All existing suites green (CI headless; local `test_layout` and shot tests)|Met|CI on `f50eb8c`; local run on `ac20803`: 21 headless + 4 windowed exit 0|
|M1.3-A `test_progress_store` (migration, crash points, dual-write, rollback with the real legacy `Catalog`, read-only newer version, `prepare_for_downgrade`)|Met|PR #16, CI|
|M1.3-B `test_classic_equivalence`: only the pass-through exit differs, in exactly 11 pinned levels; every level's shortest legacy length = `par`; a shortest legacy solution replays to a v2 win in `par` for every level (SolverV2 for 021/080/090)|Met|PR #17; CI `classic-compat`|
|M1.3-C `test_classic_score` (D2 scoring, stars never decrease)|Met|PR #18|
|M1.3-C `test_game_screen` (resume, gating, Next/Undo/Restart/Pause, editor Test isolation, save failure / read-only handling, exactly-once completion, exit settings, 48 dp sizing)|Met, except the "default campaign setting" item, which belongs to phase 3 (M1.3-E)|PRs #18, #19|
|Exit thresholds 0.34 / 0.12 asserted, configurable (D4)|Met|`test_v2_session`, `test_game_screen`|
|`validate_all` and benchmarks unchanged|Met|local runs, CI|

## 2. Physical Galaxy M31 (plan §8.2)

|Criterion|Status|Evidence / gap|
|---|---|---|
|`install -r` only; `firstInstallTime` unchanged; no clear/uninstall; menu label and stars recorded before and after|Met|Level 54 and all 53 star values preserved through every install|
|Existing progress visible; Play resumes; Levels gating and stars match; Next / Undo / Restart / Pause work|Met|`M1_3_D_DEVICE_QA.md`, `v2/01–19`|
|Undo during a level does not change stored stars|Met|049: Undo + win shows 2 stars, stored stays 3|
|Complete at least 3 Classic levels including one of 021/080/090|**Met** (round 3)|021 (par, 3 stars), 049 (2-star replay, stored 3) and 001 (par, 3 stars, `shots/03_level1_win`). Stored stars and unlock unchanged.|
|Editor Test plays a custom level and writes no progress (F5)|**Met on the device with the fix in PR #21 (not yet merged)**|Round 3 found the editor unusable on a touchscreen: one tap reached `EditorCanvas._gui_input` twice (`InputEventScreenTouch` plus the emulated mouse click) and the toggle tools undid themselves (`m13r_device/shots/12a`, `12b`; pre-existing since `1473bc4`). PR #21 skips the emulated copy (new `test_editor_input`, red → green). With that build on the M31: blocks and gates placed, Validate "SOLVABLE (min moves: 2)", Test opened "Custom Level" on the v2 GameScreen, won in 2 moves, Back to Editor returned, saves byte-identical, no files written (`build/qa/f5_device/`). F5 closes when PR #21 merges.|
|**Visual sign-off of the Pearl theme on the device (D3)**|**Open — owner decision**|Device screenshots after the F1–F4 fixes: `build/qa/m13d_device/fix/30–36` (menu, Pearl Level Select, game, pause).|
|Rollback rehearsal: legacy build `install -r` → confirm progress → play one Classic level → reinstall v2 → confirm the new progress is merged|**Met for the round trip; merge of new progress not exercised**|Round 3: legacy build over v2, level 001 won on the legacy route; the legacy `Catalog` wrote nothing (no improvement); v2 reinstalled, menu Level 54, Level Select stars equal, both save files byte-identical before and after. A merge of *new* legacy progress only happens when the legacy build records an improvement, which would change the player's stars or unlock on this device; that case is covered by `test_progress_store` with the real legacy `Catalog`, not on the device.|
|No crash / ANR / Godot script error in logcat|Met|v2, rollback, fix-build and round-3 sessions: 0 error lines|
|Commit handling time recorded|**Met** (round 3)|`[perf] commit_ms` (QA-only instrumentation, see §6): non-winning commits **5.7–10.0 ms** (12 samples); winning commits incl. both save writes **30.9–50.0 ms** (4 samples; 50.0 ms was the first, cold write). FPS is not claimed.|

## 3. Release and product items

|Item|Status|Note|
|---|---|---|
|**Release note for the strict-exit rule correction (D1)**|**Open**|Plan §3.2 requires it in the Classic release notes; no release-notes file exists yet. The rule ("a block exits only when nothing in the board is in its way") and the 11 affected levels are documented in `docs/LEVEL_SYSTEM.md`, which can serve as the source for player-facing wording.|
|Rollback path for players|Ready by design|A rollback ships as a new release built with `gameplay/engine = legacy`; `ProgressStore` stays in it and resyncs `progress.save` at startup (§5.5). Requires a higher Android `version/code` than the activation build (`export_presets.cfg` is still `version/code=1`).|
|How save failures are shown|Ready|`saved` / `partial` / `failed` (Next blocked, leave prompt) / `read_only` messages — see the QA report.|
|Level Select campaign tabs|Not needed for phase 1|Only Classic exists; tabs arrive with Chapter 1 (phase 2).|
|Legacy route visuals|Changed slightly|Shared 48 dp buttons and full-screen modal dim (PR #19) already apply to the legacy default.|

## 4. Risks if activated now

- **Strict exit is player-visible** in 11 Classic levels (021, 024, 044, 046, 061, 076, 080,
  081, 086, 088, 090): a move that worked before no longer exits. Every level stays winnable at
  its stored `par`; players who learned the shortcut may notice. Mitigation: the release note.
- **Bounded equivalence:** the rules were compared on bounded explorations (400 BFS states, a
  shortest solution and 12 seeded walks per level), not the full state space.
- **One device:** all physical evidence is from one Galaxy M31 (Android, 1080×2340, 420 dpi).
  Other aspect ratios are covered by desktop layout renders only.
- **Two engines in the tree** until the rollback window is closed by a separate PR.
- **Android rename atomicity** is covered by design and by successful on-device writes
  (`seq` 1 → 3 with `.bak` kept), not by a forced crash test on the device.

## 5. What remains before the activation PR

After the round-3 device checks (§6), three items remain:

1. **F5 — merge PR #21** (editor touch fix). Editor Test already passed on the M31 with it.
2. Owner visual sign-off of the Pearl theme on the device (D3).
3. Release note for the D1 strict-exit correction, and a `version/code` plan for release and
   rollback builds.

Optional: exercising the merge of *new* legacy progress on the device needs the legacy build to
record an improvement (for example raising a 1-star level), which changes the player's saved
stars; it is done only with the owner's approval.

When 1–3 are done, the activation PR is small: set `gameplay/engine="v2"` in `project.godot`,
update the test that asserts the shipped default, and re-run the full regression, CI and a
device smoke test. It needs its own approval and is not merged automatically. Chapter 1
(M1.3-E) is out of scope here.

## 6. Round 3 device checks (2026-11-27)

|Item|Value|
|---|---|
|Builds|From `367489b` (= `main` `f50eb8c` + this document): `BlockPuzzle-M1.3R-legacy-debug.apk` (default `legacy`) and `BlockPuzzle-M1.3R-v2perf-debug.apk`, exported with two temporary, uncommitted changes reverted right after export: `gameplay/engine="v2"`, and one `[perf] commit_ms` print in `GameScreen._on_commit` (same form as `pilot_game.gd:183`). The APK was checked to carry `engine=v2`.|
|Device / install|Galaxy M31, same signing certificate (`f3349434…`), `adb install -r` only, `firstInstallTime` unchanged (2026-11-25 18:09:18). No uninstall, no data clear.|
|Progress|Level 54 and all 53 star values unchanged throughout; four level 001 wins advanced `progress_v2.save` `seq` 3 → 7 with identical values; `progress.save` byte-identical throughout.|
|Evidence|`build/qa/m13r_device/` (gitignored): `baseline/`, `shots/` (01–24), `after_v2/`, `after_legacy/`, `after_roundtrip/`, logcats (0 error lines each).|
|Device left on|the legacy-default build|

**Unexplained once, not reproduced:** in the first attempt, after level 001's win card, the
next taps ended on Level 2 (the log shows commits on `legacy-2`), as if Next had fired instead
of Menu. Level 2 was not completed, so nothing was saved. Replaying the same taps and timing
twice, and dragging from the Next button, all behaved correctly (Menu → main menu, Play →
Level 54). Recorded for review; no cause found.
