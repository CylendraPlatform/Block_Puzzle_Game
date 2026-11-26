# TD-3.6 — Generation, solver evaluation and deterministic QA
## Why not simply sample random boards
Uniform random pieces usually produce invalid/unsolvable clutter, trivial direct exits or enormous search; an accepted puzzle needs controlled structure and measurable tension.

## Pipeline
1. Choose `seed`, target tier, dimensions, allowed colors, shape pool, wall and gate constraints.
2. Build a *valid* terminal/winning condition or reference dependency template. Construct backwards where mathematically valid; otherwise mutate valid known benchmark states and preserve accepted witnesses.
3. Validate strict v2 schema using existing LevelLoader; reject bad connectivity, overlap, out-of-bounds, gate span mismatch.
4. Evaluate initial state with SolverV2 BFS under explicit per-tier cap and timeout guard. `SOLVED` requires replayable witness and session WIN; UNKNOWN is NOT a valid level.
5. Quantify metrics and compare targets: true shortest actions, legal branching over witnessed path, bottleneck state, independent actions, redundant detours and dead ends; separate computed metrics from qualitative judgement.
6. Reject trivial direct-access puzzles above Tutorial, fake complexity and duplicates. Keep acceptance/rejection reasons and seed.
7. Export reproducible JSON + metadata, ordered recommended difficulty. No random generation at runtime for the current campaign.
8. Human playtest, adjust/reject level; do not trust shortest path as sole difficulty label.

## Instrumentation / safeguards
- Record runtime Godot version, engine/schema versions, seed, candidate hash, solver cap and stop reason.
- Use canonical sorted piece representation, board walls, gates and goals for deterministic comparison.
- Define a maximum CPU seconds per candidate/batch and a bounded expansion budget. Separate timeouts from impossibility results.
- Replay every action against a new state and assert action legality at each step; inspect final WIN and no unexpected mutation.
- Capture solver profiling to prevent 30 tough levels from causing multi-hour validation. Cache context/results only when semantics remain identical; verify cache invalidation.

## Baseline
Current pilot 15 has shortest paths: 11 levels 1–2 actions, 3 levels 4 actions, 1 level 5 actions. The 30 candidate set must be quantitatively deeper than this, with evidence.

## Fallback
If 8 strong human-playable benchmark levels cannot be produced with existing v2 mechanics, report exactly which mechanism is missing, pause at P1, and propose a minimal TD-4 change. Do not silently expand engine scope or claim Expert by increasing piece count alone.
