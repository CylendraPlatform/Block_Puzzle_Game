# M1.3 — Activation readiness assessment (launch phase 1: Classic on v2)

**Question:** is the project ready to flip `gameplay/engine` from `legacy` to `v2` so Play and
Levels open Classic on the v2 `GameScreen` (plan §4.2, phase 1)?

**Answer: not yet.** The code, saves and automated gates are ready. Six items from the plan's
own acceptance list (§8.2) or release process are still open; four are short device tasks.
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
|**Complete at least 3 Classic levels including one of 021/080/090**|**Open — 2 of 3**|021 (par, 3 stars) and 049 were won; 022 was opened but not completed. 080/090 are locked on this device; 021 satisfies the "one of" part. Needs one more completed, already-unlocked level (won at or below its stored stars so nothing changes).|
|**Editor Test plays a custom level and writes no progress (F5)**|**Open**|Headless tests only (`test_game_screen` editor isolation).|
|**Visual sign-off of the Pearl theme on the device (D3)**|**Open — owner decision**|Device screenshots after the F1–F4 fixes: `build/qa/m13d_device/fix/30–36` (menu, Pearl Level Select, game, pause).|
|**Rollback rehearsal: legacy build `install -r` → confirm progress → play one Classic level → reinstall v2 → confirm the new progress is merged**|**Partly done**|Done: legacy build over v2, progress confirmed, legacy route opens Level 54, nothing written. Not done: a Classic level played on the legacy build, then the v2 reinstall and merge check.|
|No crash / ANR / Godot script error in logcat|Met|v2, rollback and fix-build sessions: 0 error lines|
|**Commit handling time recorded**|**Open**|Not measured on the M31 for `GameScreen`. FPS is not claimed.|

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

Device tasks (non-destructive, `install -r` only, completed levels only so no progress moves):

1. Editor Test on the M31 with a custom level; confirm no save change (closes F5).
2. Complete one more already-unlocked Classic level on v2 (3rd completion).
3. Finish the rollback rehearsal: play one Classic level on the legacy build, reinstall the v2
   build, confirm the progress merges.
4. Record commit handling time on the device (instrumented debug build or timestamped input
   and frame logs; no FPS claim without a profiler).

Owner / release tasks:

5. Owner visual sign-off of the Pearl theme on the device (D3).
6. Release note for the D1 strict-exit correction, and a `version/code` plan for release and
   rollback builds.

When 1–6 are done, the activation PR is small: set `gameplay/engine="v2"` in `project.godot`,
update the test that asserts the shipped default, and re-run the full regression, CI and a
device smoke test. It needs its own approval and is not merged automatically. Chapter 1
(M1.3-E) is out of scope here.
