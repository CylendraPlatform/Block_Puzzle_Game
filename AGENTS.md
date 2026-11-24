# Agent Engineering Guide — Block Puzzle Game

This is the shared entry point for Claude Code, Cursor, Codex, and other agents. Read this before editing.

## Project
Original English-only Godot 4.7.2/GDScript Android sliding-block puzzle game. Colored polyomino pieces move on a grid and exit via matching-color gates. Color Block Jam is a gameplay-feel benchmark, not a source of code, art, names, audio, or levels.

## Session startup
1. Read `AGENTS.md`, `docs/tasks/CURRENT_TASK.md`, relevant `docs/runbooks/` and documentation, and tool-specific rules.
2. Inspect `git status --short`, branch, latest commits, environment, and implementation before making a change.
3. Preserve uncommitted changes; never overwrite other agents' work.
4. Work on one bounded task with acceptance criteria; do not expand scope silently.
5. Record verification commands, exit codes, remaining issues, and task status.

## Canonical references
- Active task: `docs/tasks/CURRENT_TASK.md`; backlog: `docs/tasks/BACKLOG.md`.
- Product: `docs/GDD.md`, `docs/REFERENCE_SPEC.md`, `docs/LEVEL_SYSTEM.md`.
- Engineering: `docs/TECHNICAL_DESIGN.md`, `docs/VISUAL_DESIGN_SYSTEM.md`.
- Evidence: `docs/PRODUCTION_UPGRADE_REPORT.md`, `docs/LEVEL_QUALITY_REPORT.md`.
- Build: `docs/BUILD.md`; quality: `docs/TEST_PLAN.md`.
Documentation is not proof; verify code/runtime behavior and record discrepancies.

## Source map
- Core puzzle rules, BFS solver: `scripts/core/rules.gd`
- Level parsing and content: `scripts/core/level.gd`, `scripts/core/catalog.gd`, `levels/`
- Input and rendering: `scripts/game/board_view.gd`; controller: `scripts/game/game.gd`
- UI: `scripts/ui/`, `scenes/`, `themes/`
- Service adapters: `scripts/services/` (ads, IAP, analytics are not live)
- Verification: `test/`

## Required checks
Run from repo root using the actual installed Godot binary:
```sh
godot --headless --path . --script res://test/test_rules.gd
godot --headless --path . --script res://test/validate_all.gd
godot --headless --path . --script res://test/test_services.gd
godot --headless --path . --script res://test/test_drag.gd
```
The 100-level validator checks solver reachability, not fun or balance. Headless tests are not Android performance or visual QA.

## Safety and scope
- Never force-push, reset others' work, merge to `main`, or change global agent settings without approval.
- Do not commit secrets, keystores, APK/AAB outputs, caches, or unlicensed assets.
- In-game text must remain English only.
- Keep rules deterministic and UI separate from game state. Protect undo, save-data compatibility and solver correctness.
- Do not enable live ads, billing, remote analytics, or network SDKs without explicit approval.
- Use original/licensed assets; no reuse of competitors' proprietary code, assets, UI artwork or level sets.
- Changes require tests and truthful evidence. If a test cannot be run, mark it NOT RUN.

## Definition of done
Acceptance criteria met; relevant tests run; documentation/task ledger updated; changes reviewed; no unrelated modifications; UI/device checks performed when relevant. Builds alone do not establish store readiness.
