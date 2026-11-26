# M1.2 Final Integration Readiness — PR #6 to PR #12

Date: 2026-11-26. Reviewed tip: PR #12 at `df03dbb`; this audit adds `1f39af6` (code) on
`feat/m1.2-visual-integration`. No PR was merged. `main` was not modified: `origin/main` is
still `696b485` (PR #5 merge); local `main` is a stale ancestor of it (0 local-only commits).

## 1. Dev-solve lifecycle audit (PilotGame + WorkerThreadPool)

| Scenario | Before (`df03dbb`) | After (`1f39af6`) | Evidence |
|---|---|---|---|
|Quit app while a dev solve runs (desktop)|exit blocked 7,084 ms, then **segfault, exit 139**|exit in 120 ms, exit 0|`test_m1_2_dev_solve_lifecycle` + timed wrapper|
|Quit app while adv-001 solves (Galaxy M31, Back key)|would wait out a ~27 s solve on shutdown|process gone 896 ms after Back; no `Fatal signal`/tombstone/ANR|`build/qa/m12f/02_advqa_solving.png`, `logcat_quit.txt`|
|Leave the QA screen mid-solve|task left running, collected by a later screen|cancelled in 13 ms; nothing cached; re-solved next visit|lifecycle test|
|Screen freed while its solve is still queued (busy pool)|task started after its screen was gone|cancelled on exit; next screen solves normally|lifecycle test|
|Reopen the QA screen|collected the orphaned result|solves again, correct verdict|lifecycle test|
|Rapid level switching|max one solve in flight|unchanged: one in flight; the level on screen gets its verdict; a skipped level is solved when shown again|lifecycle test|

Root cause: solver script code kept running on a worker while the engine shut down.
Fix: `SolverV2.solve()` takes an optional `cancel: Semaphore` (thread-safe `try_wait()`
once per expansion; `null` for every gameplay/metric/benchmark caller, so their behaviour
is unchanged — proven by identical benchmark output). The dev task belongs to its
`PilotGame` screen; `_exit_tree()` posts cancel and waits (returns within one expansion).
Task/result fields are per-screen; only the verdict cache is static.

## 2. Development diagnostics in production builds

- The only runtime `SolverV2.solve` call is the dev task (`PuzzleMetrics` has no runtime
  callers). Every dev path — task start, status readout, `[perf]` logging, the level
  selector — is gated by `DevAccess.enabled()`.
- `DevAccess.enabled()` is false in a release export: no `editor` feature,
  `OS.is_debug_build()` false, no `--dev` argument.
- The Pilot and Advanced QA scenes are reachable only from the dev-gated main-menu buttons.
- Executed check with `DevAccess.force = 0` (release behaviour): the menu shows only
  Play / Levels / Settings; a QA screen opened directly starts no task, shows no selector
  and no dev readout (`test_m1_2_dev_solve_lifecycle`, 3 checks).
- **Not executed:** an actual signed release APK — the Android preset has no release
  keystore configured.

## 3. Local regression (code at `1f39af6`)

Godot 4.7.2, Windows, headless unless noted. All exit 0.

`test_rules`, `validate_all` (100 levels, 0 failures), `test_services`, `test_drag`,
`test_v2_foundation`, `test_v2_solver`, `test_v2_session`, `test_v2_pilot`,
`test_v2_campaign` (solved=60, cap=40 budget limits, failed=0), `profile_v2_search`,
`test_m1_1_phase_a/b/c/d`, `test_m1_1_fixes`, `test_m1_2_view`, `test_m1_2_sequencing`
(43 checks), `test_m1_2_dev_solve_lifecycle` (20 checks, run separately on the same code),
`test_td36_benchmarks`, `test_td36_metrics`, `solve_benchmarks`, `solve_advanced_benchmarks`;
windowed: `test_v2_pilot_shots`, `test_layout` (36 screenshots, 0 failures),
`test_td35_shots`, `test_td36_shots`.

Benchmarks vs `df03dbb` (run in a throwaway worktree): identical lengths, explored-state
counts and `replay=OK` — bm-001 5/9910, bm-002 4/414, bm-003 5/29666, adv-001 4/1501,
adv-002 3/48, adv-003 3/8.

## 4. Advanced levels through the presentation path

- Headless: every committed move of adv-001/002/003 replays through the presentation queue
  and lands exactly on the authoritative state; all three witnesses win
  (`test_m1_2_sequencing`).
- Galaxy M31, `install -r` of the `1f39af6` build (`firstInstallTime` unchanged; menu still
  "Level 36"): adv-001, adv-002, adv-003 completed at 4 / 3 / 3 moves; commit handling
  2.4–6.4 ms; no crash, ANR or Godot error in logcat (`build/qa/m12f/`). The full
  per-mechanic device QA (rejections, Undo, Restart, colour switching, intermediate states)
  is in `M1_2_DEVICE_QA.md`; the presentation code it exercised is unchanged since.

## 5. PR #6–#12 dependency and merge plan

### Branch ancestry (verified with `git merge-base --is-ancestor`)
```
main (696b485, PR #5 merge, 2026-11-24)
└─ #6  feat/td3-geometry-gates-pilot           (+4 commits)
   └─ #7  feat/td35-premium-playful-visuals    (+3)
      └─ #8  feat/td36-puzzle-depth-production (+4)
         └─ #9  research/reference-parity-rea02 (+4)
            └─ #10 feat/m1.1-effect-runtime     (+11)
               ├─ #11 plan/m1.2-visual-integration (+2, docs only)
               └─ #12 feat/m1.2-visual-integration (+7 on origin, plus this audit)
```
Every base is an ancestor of its head and no base has commits its child lacks — a clean
linear stack; #11 and #12 are siblings with disjoint files.

### Exact merge order
1. #6 → `main`
2. #7 (retarget base to `main`) → `main`
3. #8 → `main`
4. #9 → `main`
5. #10 → `main`
6. #11 → `main` (docs only)
7. #12 → `main`

Use **"Create a merge commit"** (the repo's existing style, e.g. the PR #5 merge). Do not
squash or rebase-merge a lower PR: its descendants would then carry the original commits
again and need rebasing. Mark drafts #7–#12 ready for review first. #11 and #12 may merge
in either order.

### Potential conflicts
Simulated with `git merge-tree` (no refs written): `main` + whole stack + #12 is clean,
`main` + stack + #11 is clean, #11 + #12 together is clean. No textual conflicts expected.

### Files edited by more than one PR (check behaviour, not text)
| File | PRs | Reconciliation |
|---|---|---|
|`docs/tasks/CURRENT_TASK.md`|#6 #7 #8|**Stale**: still describes TD-3.6 and says "Do not merge PR #6, #7, or #8". Update when the stack lands.|
|`docs/tasks/BACKLOG.md`|#6 #10|Confirm `REQ-SAVE-REPLAY` survives on `main`.|
|`docs/BUILD.md`|#6 #8|Sequential edits; confirm build steps still match.|
|`scripts/game/board_view_v2.gd`, `scripts/game/pilot_game.gd`|#6 #7 #12|Final version is #12's; covered by pilot/TD-3.5 shot tests and M1.2 tests.|
|`scripts/ui/main_menu.gd`|#6 #7 #8 #12|Four dev QA routes; covered by `test_layout` (dev and release menus).|
|`scripts/core/solver_v2.gd`|#10 #12|Optional cancel parameter only; benchmarks identical.|
|`test/solve_benchmarks.gd`|#9 #10|Sequential; passes.|

### Required post-merge regression (on `main` after step 7)
`godot --headless --path . --import`, then the full list in §3, the benchmark diff against
this report's numbers, a debug Android export, and a non-destructive `adb install -r` smoke
of Main Menu, v2 Pilot, TD-3.6 QA and Advanced QA (adv-001/002/003 to completion) with a
logcat crash scan.

## 6. GitHub CI / checks (separate from local results)

No GitHub Actions workflows exist on `main` or on the stack tip (`.github/workflows/`
absent; 0 registered workflows). Every PR head (#6 `e575bcc`, #7 `8578182`, #8 `7b612d6`,
#9 `65653ab`, #10 `0709fe5`, #11 `c29eb4d`, #12 `df03dbb`) has 0 check runs and 0 commit
statuses; GitHub shows the combined status as "pending" only because nothing reported.
**No CI has validated any of these PRs**; all results above are local runs.

## 7. Blockers and open items

- **Blockers: none** in code or tests.
- Before merging: push this audit's commits to PR #12 (awaiting approval); mark drafts ready.
- Recommended: update the stale `CURRENT_TASK.md`; add a CI workflow (none exists).
- Known limits: no signed release APK built (no keystore); no FPS profiling; on a locked
  counter gate the number badge covers the padlock glyph; with a ~27 s adv-001 dev solve in
  flight, the dev readout for the next level shown waits for it (dev builds only).
