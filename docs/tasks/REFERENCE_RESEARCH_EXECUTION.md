# Reference Research Execution Ledger (Phase REA-02)

Status: **research + architecture deliverables complete; awaiting review.** No full
implementation started. PR #6/#7/#8 not merged. Reference APKs not committed/pushed.

## What was done (verifiable)
- Repo/branch/PR audit; created branch `research/reference-parity-rea02` from
  `feat/td36-puzzle-depth-production`.
- REA on `base.apk` (sha256 `083da716…50bd3`): `open_binary` → `inspect_artifact` →
  `extract_artifact`; offline scan of IL2CPP `global-metadata.dat` (~123,694 identifier
  tokens). Native `libil2cpp.so` disassembly deferred.
- One public-doc web search (Rollic help center + guides).
- Source audit of `puzzle_engine.gd`, `puzzle_state.gd`, `solver_v2.gd`, `SCHEMA_V2.md`.
- Deliverables written:
  - `docs/research/REFERENCE_EVIDENCE_REGISTER.md`
  - `docs/research/REFERENCE_FEATURE_INVENTORY.md`
  - `docs/research/GAP_ANALYSIS.md`
  - `docs/architecture/GAME_SYSTEMS_V3.md`
  - `docs/roadmap/COMMERCIAL_GAME_ROADMAP.md`
  - `docs/research/RISKS_AND_FEASIBILITY.md`
  - this ledger.

## REA vs observation vs unknown (required final statement)
- **REA established (TI, declaration-level):** the shipped binary *contains code* for
  color-matching timed-"claim" gates; color-switching + laser gate variants; grinder,
  sticky, magnet/drain, lock/joined-lock, crate obstacles; dispenser/spawner/elevator
  feeders; a booster framework (rocket/auto-rocket, extra-time, pre-level, continue);
  hearts/lives with cap perks; give-up/continue fail flow; coin economy; collection
  albums; leaderboards; and a live-ops meta layer (duel-vs-bots, leagues, tournaments,
  seasons, battle/diamond pass). It did **not** establish any rule tuning or runtime value.
- **Gameplay observation established:** nothing directly (no capture available). Via public
  documentation: slide colored blocks to matching-color doors before a timer; some blocks
  must move first; gates can be blocked or change color; a gate may peel a top layer.
- **Unknown:** all numeric tuning and exact rules — grid sizes, timer seconds, booster
  economy, obstacle interaction details, level count/difficulty curve, animation feel, and
  per-level mechanic pacing.

## Recommendation — first advanced playable benchmark (Deliverable 7)
Build **three original, solver-verified benchmark levels** that exercise the P1 mechanics
whose **schema already exists** (lowest risk, highest proof value), plus one that previews
a new solver-affecting gate. These validate the V3 direction before broad implementation.

> These are build targets for the *next, reviewed* phase (M0.2 / early M1.x), not part of
> this research PR unless the reviewer asks to include them.

1. **"Gatekeeper" — locked gate + trigger (M1.1).**
   Two colors; the matching gate for color B is `initial_state: locked` and opens via a
   trigger when a color-A piece exits (`decrement_counter`→`open_gate`). *Proves:* effect/
   trigger runtime + solver over conditional gates. *Accept:* `SolverV2` → `SOLVED`, known
   length; determinism test; no fail-closed rejection.
2. **"Hidden Hand" — hidden piece + blocker (M1.2–1.3).**
   A `reveal: hidden` piece is exposed when a blocker is cleared by an exit; revealed piece
   must then exit. *Proves:* blocker + reveal runtime and solver coverage. *Accept:* solver
   `SOLVED`; replay witness wins.
3. **"Shiftgate" — color-switching gate (M1.5 preview).**
   One gate whose accepted color alternates by move index; the solution requires timing a
   piece to the gate on the correct phase. *Proves:* deterministic move-indexed gate color
   in `search_key` without search blow-up. *Accept:* solver `SOLVED`; determinism +
   state-count tests; documented that color derives from `move_number`.

Design constraints (all three): original layouts; high-but-honest difficulty via real
dependencies (not padding moves); multi-cell pieces; ≥2 colors; validated by
`LevelValidator`; each ships with a solver test asserting status + length. A debug APK is
produced when the mechanics runtime (M1.1) lands, per roadmap M0.2.

## Built & solver-verified benchmarks (user-requested follow-up, 2026-11-25)
Three **original, core-mechanic** benchmarks were built and verified with `SolverV2`
(`test/solve_benchmarks.gd`, `levels_v2/benchmark/`). These use only currently-executable
mechanics (multi-cell polyominoes, multi-color, 4 gate sides, lane-blocking dependencies)
because the engine still fail-closes advanced mechanics — the Gatekeeper/Hidden-Hand/
Shiftgate concepts above require the M1.1 effect runtime, which is the reviewed next phase.

Runner: `test/solve_benchmarks.gd` (Godot 4.7.2 headless; cap = 200,000 states; witness
replayed independently of the solver's internal check). All three: witness `replay=OK`,
no `UNKNOWN_CAP_REACHED`.

| Level | Name | Board | Pieces/Colors | Shapes | Solver | Len | Explored | Time | Replay |
|-------|------|-------|---------------|--------|--------|-----|----------|------|--------|
|`bm-001`|Switchyard Squeeze|6×6|5 / 5|I-tromino, L-tromino, 2×domino, single|SOLVED|5|9,910|41.9 s|OK|
|`bm-002`|Three-Lane Jam|5×5|4 / 4|2×domino, 2×single|SOLVED|4|414|1.4 s|OK|
|`bm-003`|Keyhole Yard|6×6|5 / 5|3×domino, 2×single|SOLVED|5|29,666|157.9 s|OK|

Difficulty comes from **forced move ordering** (each blocker needs its own key move first)
and polyomino geometry, not padding. High explored-state counts (esp. bm-003) show many
dead-end orderings — nontrivial search, not a straight line.

**Recorded limitation:** BFS in GDScript is slow per state (~5 ms/state: bm-003 explored
29,666 states in ~158 s) because every transition re-checks schema/state. Within the
200,000 cap all three resolve, but this per-state cost caps how large a level the offline
solver can verify; a faster search context (cached geometry already exists) or raising the
cap would be needed for denser levels. No Android APK built in this step; per roadmap M0.2
an APK is produced once the mechanics runtime lands.

## Not done / explicitly out of scope this phase
- No mechanic runtime implemented (engine still fail-closes advanced mechanics).
- No benchmark levels built yet (recommendation only).
- No native `.so` disassembly, no gameplay capture, no live values.
- No monetization/analytics, no live-ops, no PR merges.
