# Commercial Game Roadmap (Phase REA-02 — for review)

Dependency-ordered, independently testable milestones toward a complete, playable,
original game. Each milestone has acceptance criteria, tests, and (where relevant) an
APK. Nothing here starts until the research + architecture are reviewed. Monetization and
live-ops stay off/deferred.

Priority bands: **P0** core parity · **P1** advanced mechanics · **P2** timer/retries/
boosters/progression · **P3** production UI/feel · **P4** differentiation/live-ops ·
**P5** Android perf/QA/release.

## P0 — Core gameplay parity (mostly done; consolidate)
- **M0.1 v2 campaign spine.** Promote v2 pilot to the live campaign path; port stars/save
  to v2 catalog. *Accept:* play N v2 levels end-to-end; stars persist; `validate_all`
  green. *Tests:* existing suites + v2 catalog test.
- **M0.2 Benchmark levels.** 3 original solver-verified advanced benchmarks (see
  `REFERENCE_RESEARCH_EXECUTION.md`). *Accept:* each `SOLVED` with known length; debug APK.

## P1 — Advanced puzzle mechanics (schema already supports; add runtime)
Order chosen so each builds on the last; all solver-tested.
- **M1.1 Effect/trigger runtime** (open/lock gate, decrement counter, cascade guard).
  *Accept:* locked-gate level opens via trigger; solver finds it; fail-closed lifted only
  for implemented effects.
- **M1.2 Counters + blockers** runtime. *Accept:* counter-gated level solvable; blocker
  clears; regression tests.
- **M1.3 Hidden/revealed pieces** runtime. *Accept:* reveal-on-event level solvable.
- **M1.4 Locks + keys** (joined locks). *Accept:* key-exit unlocks; solver-verified.
- **M1.5 Color-switching gates / laser doors** (deterministic by move index).
  *Accept:* color-phase level solvable; `search_key` includes phase; determinism test.
- **M1.6 Sticky pieces** (grouped movement). *Accept:* sticky-coupling level solvable.
Dependencies: M1.1 precedes all (shared effect system). M1.5/M1.6 change solver state —
land each with a determinism + solvability test before any level ships using it.

## P2 — Timer, retries, boosters, progression
- **M2.1 Timer/session policy** (TD-6): move-budget + optional real-time countdown; fail
  on timeout. *Accept:* timed level fails on timeout, wins before; solver ignores clock
  but par-time derived from solution length.
- **M2.2 Fail → continue flow** (give-up window, continue). *Accept:* fail window offers
  continue/lose; no soft-locks.
- **M2.3 Lives (hearts)** + regen + save migration. *Accept:* life spent on fail; gate at
  zero; migration preserves progress.
- **M2.4 Boosters** (rocket, extra-time, pre-level, continue) via effect/action API +
  inventory UI. *Accept:* each booster changes state through the engine, solver-consistent.
- **M2.5 Hints** (SolverV2 next optimal move). *Accept:* hint highlights a legal optimal
  move; no hint on unsolved-cap levels.
Parallelizable: M2.3 (lives) and M2.5 (hints) are independent of M2.4 (boosters).

## P3 — Production UI, animation, feedback
- **M3.1** Apply TD-3.5 premium visuals to all v3 mechanics (gate color, laser, sticky,
  magnet, grinder VFX). *Accept:* visual QA screenshots; no rule in view layer.
- **M3.2** Level map / progression UI, booster/lives HUD, fail/continue polish.
- **M3.3** Juice pass: drag feel, exit "claim" animation, haptics. *Accept:* on-device QA.

## P4 — Differentiation & (deferred) live-ops
- **M4.1** Original differentiation features (our own hook, not a reference clone) — design
  first, decide later.
- **M4.2+ (deferred, needs product + possibly server decision):** daily challenge,
  collection/album meta, leagues/tournaments, PvP vs bots, season/battle pass. Each gets
  its own design doc and go/no-go. Not scheduled here.

## P5 — Android performance, QA, release readiness
- **M5.1** Performance pass with **real on-device** profiling (never script-mode FPS).
- **M5.2** Device-matrix QA, safe-area/cutout handling.
- **M5.3** Release pipeline: signed build, store listing (original art), privacy policy
  *if/when* analytics/ads are approved. Monetization integration only on explicit approval.

## Parallelization summary
- P1 is a sequential spine (M1.1 first) but M1.5/M1.6 can branch once M1.1–M1.4 land.
- P2 lives/hints parallel to boosters.
- P3 visuals track each P1 mechanic as it lands (visual work parallel to next mechanic).
- P4 live-ops are independent and deferred.

## Review gate
This roadmap, the architecture, and the research docs are the review package. Full
implementation (P1+) begins only after sign-off. PR #6/#7/#8 are **not** merged by this work.
