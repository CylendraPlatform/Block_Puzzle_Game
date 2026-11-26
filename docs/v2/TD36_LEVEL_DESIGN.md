# TD-3.6 — Level design and difficulty framework (v1)
## Player experience
Single visible objective: move/exit matching pieces through exact gates. Players should plan because pieces block, share corridors, require staged relocation or ordered exits; the challenge is not tapping obvious one-piece goals.

## Tier targets (design hypotheses, not promised completion times)
| Tier | Initial distribution | Pieces | Target shortest legal actions | Hypothesized human completion |
| --- | ---: | ---: | ---: | --- |
| Tutorial | 4 | 1–3 | 1–5 | 10–30 sec |
| Easy | 8 | 3–5 | 5–10 | 30–60 sec |
| Medium | 10 | 5–8 | 10–20 | 1–3 min |
| Hard | 6 | 7–10 | 18–35 | 3–5 min |
| Expert | 2 | 8–12 | 30+ | 5–8 min |
These are **targets**, not mandatory per-level thresholds. State whether a level actually meets them, based on shortest replay and playtest outcomes; do not fabricate complexity by making meaningless back-and-forth moves.

## Level design requirements
- Stages must stay within validator-supported board geometry and actual performance envelope, not arbitrary sizes.
- Every accepted level is SOLVED under documented cap and witness replay reaches WIN. A level whose exhaustive proof is inconclusive is candidate-only, not accepted.
- Favor 3+ distinct connected polyomino silhouette classes over an entire campaign of square pieces, but don't overload small boards.
- Multi-color gates must follow exact `side/lo/hi/accept` schema and geometric fit. Human should be able to infer color/gate relationship. Color alone is not accessibility-safe.
- Include walls and narrow corridors only when they causally change the puzzle; ensure the win condition is feasible.
- At least one real dependency: moving piece A enables B, or exiting A enables B; with no dependency, label beginner.
- Distinguish useful decisions from fake difficulty. Early levels establish mechanics without penalizing learning. Avoid tightly packed inscrutable boards without visible reasoning path.
- Multiple exits matter only if routing/ordering interactions occur; decorating board with unused gates is not complexity.
- For the 30 candidate set, track board size, occupancy, piece count, colors, shape types, gate widths, wall count, solution length, decision points, false leads, bottleneck, replay and human median.
- No guarantee of unique shortest solution is required, but count/estimate alternative shortest solutions where feasible. Human-clear solution path preferred.
- Do not bake tutorial prompts that reveal every move for Medium/Hard/Expert.
- Maintain gradual difficulty progression with occasional lower-pressure relief stages.

## Level card required per JSON
Store level JSON in `levels_v2/td36/`; store author notes and calculated metrics in separate `docs/v2/td36_level_cards.json` keyed by stable level ID to avoid extending schema. Each card includes `id`, `tier_target`, `seed_or_handcrafted`, `concept`, `piece_count`, `color_count`, `shape_types`, `gate_count`, `wall_count`, `shortest_actions`, `solver_status`, `witness_replayed`, `search_cap`, `states_explored`, `dependency_description`, `human_test_notes`, `signoff_state`.

## Content acceptance
All levels have valid schema; solvable + witness; at least 70% of Medium+ levels have nontrivial dependencies proven by counterfactual test/trace (e.g. removing non-essential blocker changes difficulty). Record failures and replace weak puzzles; do not relabel a 2-move stage Expert.
