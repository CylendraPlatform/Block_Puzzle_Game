# TD-2 — Complete legal movement and Solver v2

**Status:** Implemented on `feat/td2-complete-solver`. Not merged.
**Baseline:** `origin/main` at `5a7d9d3` (merge of TD-0/TD-1). This branch starts at `b97b3d0`.
**Spec:** `docs/tasks/TD-2_IMPLEMENTATION.md`.
**Contract:** `docs/v2/SOLVER_V2.md`.

## What this task delivered
`PuzzleEngine` enumerates every free cardinal landing and a single straight open-gate exit. `SolverV2` searches those actions with breadth-first search and replays the witness through `transition`. Live play still uses `Rules` and `BoardView`. The 100 level files, progress saves, safe-area layout, and monetization stubs are unchanged.

An EXIT is one committed move along the gate's outward direction, including the slide from the interior when the ray is clear. Intermediate stops are MOVE actions. Collision blocks an exit. Search keys omit `move_number`. `UNKNOWN_CAP_REACHED` is not reported as `UNSOLVABLE`.

## Evidence
Godot 4.7.2 stable (`D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`), Windows, 2026-11-24.

| Command | Exit |
| --- | --- |
| `--headless --script res://test/test_v2_foundation.gd` | 0 (`== done: 0 failure(s) ==`) |
| `--headless --script res://test/test_v2_solver.gd` | 0 (`== done: 0 failure(s) ==`) |
| `--headless --script res://test/test_rules.gd` | 0 |
| `--headless --script res://test/validate_all.gd` | 0 (`validated 100 levels, 0 failure(s)`) |
| `--headless --script res://test/test_services.gd` | 0 |
| `--headless --script res://test/test_drag.gd` | 0 |
| `--script res://test/test_layout.gd` | 0 (`screenshots: 36  failures: 0`) |
| `--headless --script res://test/test_v2_campaign.gd` | 0 (`CAMPAIGN solved=60 cap=40 failed=0`, about 910 seconds, expansion cap 2500) |

The 40 cap results are levels 036, 044, 045, 050, 057, 061, 062, 064, 065, 067–072, 074, 075, 077–084, and 086–100. Those levels were not v2-solver verified. None returned `UNSOLVABLE` or a replay failure. All 100 adapters passed schema validation inside `test_v2_solver.gd`. The first eight levels were solved and replayed inside that script, and level 1's exit length matches `Rules.solve_min_moves`.

Headless Godot printed ObjectDB leak warnings and `1 resources still in use` on the solver and campaign scripts. Those warnings are not assertion failures. No Android device session was run. Desktop renders are not device QA.

## Hardening pass
State checks now require the level id, schema, piece and gate sets, blocker and trigger sets, in-bounds footprints, walls, active-piece occupancy, gate mode, and gate counter to agree with the definition. A cleared board that fails those checks is `INVALID_LEVEL` with `STATE_MISMATCH`, not `SOLVED`. Rejected actions leave the input state unchanged.

`PuzzleEngine.assume_valid` is gone. One `PuzzleSearchContext` is passed through a single search. Replay and later public calls validate the schema again.

The same five levels were timed before and after, cap 2500, Godot 4.7.2. Explored counts and statuses did not change. Expansions per second rose from 114–211 to 324–494 (about 2.2× to 2.8×). On level 32, 200 public `legal_actions` calls took 191 ms, 200 public `transition` calls took 110 ms, 200 search keys took 4 ms, and 40 schema validations took 6 ms. Enumeration is the dominant cost. Schema validation is not, once a search holds a context. The queue no longer deletes its front element, witnesses are rebuilt from parent links, and geometry is cached. Move rules are unchanged.

`UNKNOWN_CAP_REACHED` remains separate from `UNSOLVABLE`. The 40 campaign levels that stopped at 2500 expansions are still not claimed solved. That full campaign was not repeated after this pass. `test_layout.gd` was not repeated; presentation code did not change.

Hardening rerun, same Godot binary, 2026-11-24:

| Command | Exit |
| --- | --- |
| `--headless --script res://test/test_v2_solver.gd` | 0 |
| `--headless --script res://test/test_v2_foundation.gd` | 0 |
| `--headless --script res://test/test_rules.gd` | 0 |
| `--headless --script res://test/validate_all.gd` | 0 (`validated 100 levels, 0 failure(s)`) |
| `--headless --script res://test/test_services.gd` | 0 |
| `--headless --script res://test/test_drag.gd` | 0 |
| `--headless --script res://test/profile_v2_search.gd` | 0 |

## Not in this task
TD-3 art, editor, and content. TD-4 trigger and event execution. BoardView migration. New levels. Ads, IAP, remote analytics.

## TD-0 / TD-1 history
Implemented on `feat/td0-td1-v2-foundation` and merged as PR #4 (`5a7d9d3`). Evidence from that branch, Godot 4.7.2, 2026-11-24, after strict validation hardening:

| Command | Exit |
| --- | --- |
| `--headless --script res://test/test_v2_foundation.gd` | 0 |
| `--headless --script res://test/test_rules.gd` | 0 |
| `--headless --script res://test/validate_all.gd` | 0 (`validated 100 levels, 0 failure(s)`) |
| `--headless --script res://test/test_services.gd` | 0 |
| `--headless --script res://test/test_drag.gd` | 0 |
| `--script res://test/test_layout.gd` | 0 (`screenshots: 36  failures: 0`) |

The same six commands were rerun on this branch and are listed in the TD-2 evidence table. Deferred from TD-1: `authored_metrics` keys are not allowlisted; trigger cycles stay with TD-4; a non-null timer is rejected rather than parsed.

BP-101 release-readiness remains in `docs/tasks/BACKLOG.md`.
