# TD-0 + TD-1 — v2 puzzle-state foundation

**Status:** Implemented on `feat/td0-td1-v2-foundation`. Not merged.
**Baseline:** `main` at `2403ab17f775931f2237404a7cc95115213d201c`.
**Spec:** `docs/tasks/TD-0_TD-1_IMPLEMENTATION.md`.
**Contracts:** `docs/decisions/ADR-002-deterministic-puzzle-state.md`, `docs/v2/SCHEMA_V2.md`, `docs/tasks/TD-0_TEST_MATRIX.md`.

## What this task delivered
Version-aware loading, strict schema_version 2 validation, a non-destructive v1 adapter, canonical `PuzzleState` hashing, event envelopes, and a transition skeleton that rejects unimplemented rules. Live play still uses `Rules` and `BoardView`. The 100 level files and `progress.save` are not rewritten.

## Evidence
Godot 4.7.2 stable (`D:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe`), Windows, 2026-11-24.

| Command | Exit |
| --- | --- |
| `--headless --script res://test/test_v2_foundation.gd` | 0 (`== done: 0 failure(s) ==`) |
| `--headless --script res://test/test_rules.gd` | 0 |
| `--headless --script res://test/validate_all.gd` | 0 (`validated 100 levels, 0 failure(s)`) |
| `--headless --script res://test/test_services.gd` | 0 |
| `--headless --script res://test/test_drag.gd` | 0 |
| `--script res://test/test_layout.gd` | 0 (`screenshots: 36  failures: 0`) |

Headless Godot still prints ObjectDB leak warnings on several scripts. Those warnings are not test failures. Layout screenshots are under `build/qa/layout/` and are not campaign assets. No Android device session was run for this change.

## Not in this task
TD-2 legal landings and solver witnesses, TD-4 event execution, timer/gold/undo session, BoardView migration, new levels, and monetization SDKs.

BP-101 release-readiness remains in `docs/tasks/BACKLOG.md`.
