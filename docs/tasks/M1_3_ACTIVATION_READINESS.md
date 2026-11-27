# M1.3 — Activation readiness assessment (launch phase 1: Classic on v2)

**Question:** is the project ready to flip `gameplay/engine` from `legacy` to `v2` so Play and
Levels open Classic on the v2 `GameScreen` (plan §4.2, phase 1)?

**Answer: not yet.** The code, saves and automated gates are ready and every device criterion
is met (F5 closed by PR #21). Remaining blockers (§5, §7): issue #23 not yet concluded (the
round-4 run was compromised by another client on the shared device), Pearl D3 sign-off pending,
the owner's confirmation of the highest distributed versionCode, a release keystore, and review
of the release-metadata PR #24.
Nothing here activates v2: `gameplay/engine` stays `legacy` on `main`.

**Update:** PR #21 (editor touch fix) merged as `cf123fb`; main CI run 45977194875 on `cf123fb`:
`headless` success, `classic-compat` success. Owner review of PR #20 at `1ce8b8d`: release note
D1 content **approved**; versionCode 2 / 3 **provisionally approved** (subject to verifying the
highest distributed code and reproducible release metadata); Pearl D3 **pending** visual review;
issue #23 must be investigated before activation. Round-4 results: §7.

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
|Editor Test plays a custom level and writes no progress (F5)|**Met — F5 CLOSED** (PR #21 merged as `cf123fb`, main CI green)|Round 3 found the editor unusable on a touchscreen: one tap reached `EditorCanvas._gui_input` twice (`InputEventScreenTouch` plus the emulated mouse click) and the toggle tools undid themselves (`m13r_device/shots/12a`, `12b`; pre-existing since `1473bc4`). PR #21 skips the emulated copy (new `test_editor_input`, red → green). With that build on the M31: blocks and gates placed, Validate "SOLVABLE (min moves: 2)", Test opened "Custom Level" on the v2 GameScreen, won in 2 moves, Back to Editor returned, saves byte-identical, no files written (`build/qa/f5_device/`). Closed after PR #21 merged and main CI run 45977194875 passed.|
|**Visual sign-off of the Pearl theme on the device (D3)**|**Open — owner decision**|Review pack with checklist: `docs/qa/pearl_signoff/` (device: menu, Level Select, game, pause, win card, Editor Test; desktop: save-problem dialogs).|
|Rollback rehearsal: legacy build `install -r` → confirm progress → play one Classic level → reinstall v2 → confirm the new progress is merged|**Met for the round trip; merge of new progress not exercised**|Round 3: legacy build over v2, level 001 won on the legacy route; the legacy `Catalog` wrote nothing (no improvement); v2 reinstalled, menu Level 54, Level Select stars equal, both save files byte-identical before and after. A merge of *new* legacy progress only happens when the legacy build records an improvement, which would change the player's stars or unlock on this device; that case is covered by `test_progress_store` with the real legacy `Catalog`, not on the device.|
|No crash / ANR / Godot script error in logcat|Met|v2, rollback, fix-build and round-3 sessions: 0 error lines|
|Commit handling time recorded|**Met** (round 3)|`[perf] commit_ms` (QA-only instrumentation, see §6): non-winning commits **5.7–10.0 ms** (12 samples); winning commits incl. both save writes **30.9–50.0 ms** (4 samples; 50.0 ms was the first, cold write). FPS is not claimed.|

## 3. Release and product items

|Item|Status|Note|
|---|---|---|
|Release note for the strict-exit rule correction (D1)|**Drafted — awaiting review**|`docs/release/M1_3_ACTIVATION_RELEASE_NOTE.md`|
|Rollback path for players|**Plan drafted — awaiting review**|`docs/release/ANDROID_VERSIONING_AND_ROLLBACK.md`: rollback = new release (code 3) built with `gameplay/engine = legacy`; `ProgressStore` stays in it and resyncs `progress.save` at startup (§5.5). Needs a release keystore first.|
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

After the round-3 device checks (§6):

1. ~~F5 — merge PR #21~~ **Done:** merged as `cf123fb`, main CI green; F5 closed.
2. **Owner visual sign-off of the Pearl theme (D3)** — **pending.** Review pack:
   `docs/qa/pearl_signoff/00_contact_sheet.png` (one page: six M31 captures + two desktop
   save-problem dialogs) and the individual files with a checklist.
3. ~~Release note~~ — **content approved** (D1).
4. **versionCode and rollback plan** — **provisionally approved.** Open conditions:
   - highest previously distributed versionCode: the repository shows only code 1 on debug-
     signed dev / QA builds; the Play Console cannot be checked from here — **owner confirms**;
   - reproducible release metadata: **implemented in draft PR #24** (tracked
     `export_presets.cfg`, `docs/release/RELEASES.md` ledger, CI guard, release build script);
   - release keystore: **not created** (owner, per `docs/release/ANDROID_SIGNING.md` in #24).
5. **Issue #23 investigation** — **not concluded** (§7): the round-4 repetition run was
   compromised by another client taking over the device. Must be re-run.

Done in round 4: player builds hide developer / QA entries (§7, verified with a real release
export).

Tracked separately, not blocking: issue #22 (editor contents lost when returning from Test).

Optional: exercising the merge of *new* legacy progress on the device needs the legacy build to
record an improvement (for example raising a 1-star level), which changes the player's saved
stars; it is done only with the owner's approval.

When 2–5 are done, the activation PR is small: set `gameplay/engine="v2"` in `project.godot`,
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
Level 54). No cause found; tracked as issue #23, to be investigated before default activation.

## 7. Round 4 (2026-11-27) — owner review follow-ups

### D. Player builds hide developer / QA entries — verified
- Code: `DevAccess.enabled()` is true only with the `editor` feature, `OS.is_debug_build()`, or a
  `--dev` user argument. Editor, v2 Pilot, TD-3.6 QA, Advanced QA and the dev readouts are all
  behind it.
- **Real release export:** `--export-release` of `main` `cf123fb` for Windows (same
  `OS.is_debug_build()` gate; scratch copy with a temporary probe autoload, never committed)
  reported `is_debug_build=false editor_feature=false dev_enabled=false`; main menu buttons:
  **Play, Levels, Settings**. An Android release export needs the release keystore.
- CI test `test_m1_2_dev_solve_lifecycle` now also asserts the release-mode menu hides
  **Editor** and keeps Play / Levels / Settings (draft PR #24).
- Side effect: running the probe created an empty-progress `progress_v2.save` in this PC's
  Godot dev data folder (`app_userdata/Block Puzzle Game`); no device involved.

### B. Release signing and metadata — prepared in draft PR #24 (no secrets)
- Godot 4.7.2 source (`platform/android/export/export_plugin.{h,cpp}`, tag `4.7.2-stable`):
  keystore options are `PROPERTY_USAGE_SECRET` (saved in `.godot/export_credentials.cfg`) and
  can come from `GODOT_ANDROID_KEYSTORE_RELEASE_{PATH,USER,PASSWORD}`.
- `export_presets.cfg` tracked (checked: no keystore, password or machine path), version ledger,
  CI guard (tested: secret line, preset/ledger mismatch and reused code all fail), release build
  script that refuses unsafe states and records commit / version / cert / APK hashes.
- **Signature mismatch:** a release-signed APK cannot update the debug-signed installs (incl. the
  M31); never uninstall or clear data to work around it; release-candidate QA on a device or
  profile without the debug install, or via Play internal testing. No release keystore was
  created; the owner creates it (`docs/release/ANDROID_SIGNING.md`).

### C. Pearl contact sheet — prepared
`docs/qa/pearl_signoff/00_contact_sheet.png` (2328×1856): row 1 the six Galaxy M31 captures,
row 2 the two desktop save-problem dialogs, each labelled. D3 remains **pending**.

### A. Issue #23 — not concluded; run compromised
- Method: QA-only build of `cf123fb` with temporary `[qa]` logging (touch / emulated-mouse
  input with device id and visible layers, every `GameRoute.go` with its caller, Level Select
  taps, `_load_index` with its caller, win card shown, Next / Menu actions), `gameplay/engine`
  set to `v2` for the export only; both reverted immediately (patch kept outside the repo).
  Installed with `adb install -r`, same certificate, `firstInstallTime` unchanged.
- A sanity check before the run logged the expected path: Play → `selected=-1 unlocked=53` →
  `load idx=53`.
- A loop of 30 repetitions (Pause → Levels → Level 1 → win → wait 0.1–2.5 s → Menu → Play →
  swipe → Undo) was started. **At 13:31:56 another adb client (not this session) started
  `com.dilmart.spike.capacitor/.MainActivity` on the same device and attached a debugger;
  the game was paused and the loop's remaining taps (≈ repetitions 16–30) went to that app.**
  The loop was stopped and no further input was sent.
- The heavy input logging also rotated the device log buffer, so no `[qa]` lines from the
  repetitions that did run on the game were kept.
- **Result: no evidence either way; no cause is claimed and no fix was made.** Re-run when the
  device is not shared, with the log streamed to a file during the run (not read afterwards
  from the ring buffer) and a foreground-app check before every repetition.
