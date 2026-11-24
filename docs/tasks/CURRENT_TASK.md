# BP-101 — Release Readiness & Gameplay Quality Gate

**Status:** Not started (awaiting implementation).  
**Baseline inspected:** `main` at `71432387bbca5ed73d234bd0bb621a5812b38c70` on 2026-11-24. Revalidate current HEAD.  
**Source:** `docs/PRODUCTION_UPGRADE_REPORT.md`.

## Objective
Make the current Godot puzzle game verifiably ready for a limited external Android beta, without adding speculative features or live monetization.

## Scope / acceptance
- [ ] Reconcile README and build instructions with actual repository and toolchain.
- [ ] Create reproducible clean-checkout debug Android export with nonsecret configuration; never commit signing secrets.
- [ ] Rerun automated rules/services/drag tests and validate 100 levels; capture exit codes.
- [ ] Verify screens, gestures, undo, pause, restart, persistence, settings and editor in emulator/physical Android sessions.
- [ ] Check multiple aspect ratios and safe-area/cutout behavior.
- [ ] Measure actual frame times/FPS using a valid runtime profiler.
- [ ] Improve exiting-block animation if comparison tests demonstrate weak feedback.
- [ ] Evaluate progressive level challenge through deeper metrics and external playtests.
- [ ] Report blockers and remaining gaps; do not mark release approved without evidence.

## Do not do
No new game modes, live ads, IAP, telemetry, global tool changes, copied competitor content, or direct main merge without approval.

## Handoff template
For each work session: base commit; modified files; commands + results; screenshots/log paths; completed criteria; blockers; next bounded task.
