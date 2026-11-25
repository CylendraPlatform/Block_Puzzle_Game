# Risks, Unknowns & Technical Feasibility (Phase REA-02 — for review)

## Research-integrity risks
- **RE is declaration-level only.** Evidence is IL2CPP symbol names, not runtime behavior.
  Risk: over-reading a symbol into a confirmed rule. *Mitigation:* confidence tags; no TI
  item promoted to "observed"; single-token systems tagged INF.
- **No gameplay was captured.** All numeric tuning is UNK. Risk: building to guessed values.
  *Mitigation:* roadmap derives difficulty from our own solver metrics, not reference guesses.
- **Source confusion in public docs.** Several guides describe *Gem Jam* / *Block Jam*, not
  Color Block Jam. *Mitigation:* PD items cross-checked; booster set left low-confidence.

## Legal / IP risks (high priority — original-only mandate)
- Must not copy reference code, assets, art, audio, exact levels, or distinctive UI.
  *Mitigation:* reference package stays local, **never committed or pushed** (see
  `.gitignore` additions); all mechanics re-implemented from scratch as deterministic
  originals; our own art/audio/level sets; our own visual identity (TD-3.5).
- Risk of "too-close" level layouts. *Mitigation:* levels are solver-generated/hand-authored
  originals; no reference layout is reproduced or referenced numerically.

## Technical feasibility (by mechanic)
| Mechanic | Feasibility | Main risk | Note |
|---|---|---|---|
|Effect/trigger runtime (M1.1)|**High**|cascade loops|schema + `MAX_CASCADE=32` already exist|
|Counters/blockers/hidden (M1.2–1.3)|**High**|solver state growth|already in `search_key`|
|Locks/keys (M1.4)|**High**|—|reuses effect system|
|Color-switching/laser gates (M1.5)|**Medium**|solver determinism/branching|derive color from move index to avoid key blow-up|
|Sticky pieces (M1.6)|**Medium**|coupled legal-action generation|needs careful group-move rules + tests|
|Magnet/drain|**Medium**|forced-motion determinism|must resolve inside `transition()`|
|Grinder|**Medium**|effect-on-entry correctness|destructive transition; solver must model it|
|Feeders (dispenser/spawner/elevator)|**Medium-Low**|near-unbounded state|cap queue; may stress BFS; needs state-count guard|
|Timer (real-time)|**Medium**|leaves deterministic model|keep solver clock-agnostic; par-time from length|
|Boosters/lives/economy|**Medium**|save migration; balance|additive save schema; off by default|
|PvP/leagues/season (P4+)|**Low (this phase)**|server + bot AI + live-ops cost|deferred, own go/no-go|

## Solver-soundness risks (the core technical risk)
Adding mechanics that introduce forced or scheduled transitions can:
1. **Explode the search space** (feeders, magnets) → add explicit state-count budgets and
   per-mechanic solver tests; keep `UNKNOWN_CAP_REACHED` honest.
2. **Break determinism** if any reaction uses real time or unordered iteration →
   mandate sorted-id resolution and move-indexed schedules; add determinism regression tests.
3. **Make "solvable" ambiguous under a clock** → separate solvability (moves) from
   time-pressure (presentation/fail). Never claim a timed level is "verified solvable"
   without stating the move-based assumption.

## Process risks
- **Concurrent repo activity.** This repo has multiple active branches/agents; local `main`
  diverged from `origin/main` earlier this session. *Mitigation:* work only on
  `research/reference-parity-rea02`; don't touch others' branches; don't merge PR #6/#7/#8.
- **GateGuard fact-forcing hooks** add friction but no blocker. Noted for velocity planning.

## Unknowns requiring a later pass (explicit backlog)
- Native `libil2cpp.so` control-flow (exact gate/claim/magnet rules) — needs disassembly of
  the arm64 slice.
- Live gameplay capture for DO-class evidence (grid sizes, timer seconds, obstacle rules,
  difficulty curve, animation feel, booster economy).
- Which mechanics appear at which level index (progression pacing).

## Feasibility verdict
Core parity (P0) is already met. Advanced-mechanics parity (P1) is **high feasibility**
because our schema and solver were designed for it and merely fail-close the runtime.
New solver-affecting objects (P1.5/P2) are feasible with disciplined determinism + tests.
Live-ops/monetization (P4+) are feasible but are product/business decisions, not blocked by
engine limits.
