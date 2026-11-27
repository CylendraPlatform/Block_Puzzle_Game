# Positioned gates: technical gap analysis

Audit of what the current code already supports for short, positioned gates, and what an
implementation cycle would have to change. Source inspection plus the prototype check
(`test/proto_gates_check.gd`); no production code was changed for this proposal.

## Already supported (no change needed)

| Area | Evidence | Notes |
|---|---|---|
| Rule enforcement of partial gates | `PuzzleEngine._matching_gates`, `scripts/core/puzzle_engine.gd:266-308` | Exit only if the block's whole perpendicular extent is inside `lo..hi`, the gate is open and accepts the colour. Not cosmetic. |
| Multi-cell / irregular blocks | same function: `perp_min` / `perp_max` over every cell | Silhouette extent test; correct for bars, L, T, I shapes (Level C uses all four). |
| Exit as one move | `PuzzleEngine._actions_for_piece` / `_exit_slide` | Alignment slide + exit = one committed action; a misaligned block just stops at the frame. |
| State | `PuzzleState` (pieces, gates mode / counter / phase) | No gate geometry in state; nothing to change. |
| Schema | `LevelValidator`: gate fields id, side, lo, hi, accept, initial_state, unlock_when, counter, color_schedule | `lo..hi` bounds-checked per edge; same-colour overlap on an edge rejected (`OVERLAPPING_GATES`). Walls supported. |
| Loading | `LevelLoader.load_definition` (schema 2) | Prototype JSON loads unchanged. |
| Shortest solution | `SolverV2.solve` (BFS, witness replay) | Level C (6x6, four shapes): 50,410 states expanded, solved. |
| Level metrics | `PuzzleMetrics.evaluate` | Optimal-path count, dependency proof, unreachable gates; reused by the prototype check. |
| Advanced gates | locked / counter / colour-switching gates, triggers, blockers (M1.1) | Available for "multiple gates only when a mechanic justifies it". |
| Existing partial-gate content | `levels_v2/pilot` (21 gates: 14 one-cell, 5 two-cell, 2 three-cell), `levels_v2/td36` (51 gates) | Partial gates have been solver-verified since TD-2; only Classic is all full-edge. |
| Campaign slot | `CampaignCatalog.CHAPTER1` exists with no content | Progress is keyed by campaign + stable id, so a new campaign does not touch Classic saves. |

## Gaps

| # | Gap | Where | Size | Proposal |
|---|---|---|---|---|
| G1 | **Content.** Classic gates are full-edge by data (`test/gen_levels.gd`); no new-campaign levels exist. | `levels/`, `CampaignCatalog` | Large (design) | Author Chapter 1 in its own folder to the quality bar in the spec; register it in `CampaignCatalog.CHAPTER1`. Classic stays as is. |
| G2 | **Renderer.** `BoardViewV2` draws gates inside the frame band; the frame is never cut; no recess, posts or tunnel. The exit animation slides the block past the frame (`gameplay/exit_past`), not into an opening. | `scripts/game/board_view_v2.gd` | Medium | Draw the frame with real openings over `lo..hi`; recessed opening (floor, posts, threshold, chevron); clip the exiting block under the frame lip. Pre-bake frame + openings per level so the board does not rebuild them every frame (the board currently redraws every frame; device cost unmeasured). |
| G3 | **Editor.** The gate tool only toggles 1-cell gates (`scripts/editor/editor.gd:147-151`, `lo == hi`), and the editor writes the legacy schema (`blocks`, gate `color`). | `scripts/editor/` | Medium | Drag to set `lo..hi`; per-gate colour; export schema v2; run the lint below on save. |
| G4 | **Authoring lint.** Nothing flags an unusable gate (narrower than every block of its colour along that axis), a non-binding gate, or a block with no usable gate. The solver only reports "unsolvable" afterwards. | new lint script | Small | Warnings, not schema errors (Classic stays valid): usable gate per required block, binding-gate check (as in `proto_gates_check.gd`), no move-1 exit. |
| G5 | **New-campaign policy** (no overlap of different colours, width 1-3, one gate per colour in simple levels). | same lint | Small | Enforced for the new campaign only. |
| G6 | `chapter` must be an integer (found while authoring the prototypes). | `LevelValidator` | None | Use integer chapters in new content. |
| G7 | **Feedback.** No bump on a frame / wrong-door stop, no aligned-door highlight, no colour glyphs. | `BoardViewV2`, `TD35Theme` | Small-Medium | Presentation only, driven by existing move events and legal actions. |
| G8 | **Solver budget for bigger boards.** 6x6 with four shapes is about 50k states; 7x7 with five or more shapes may need the existing caps / time budget. | `SolverV2`, `PuzzleMetrics` | Small | Start Chapter 1 at 5x5-6x6; record `UNKNOWN_CAP_REACHED` as a limitation, never as unsolvable. |
| G9 | **Legacy route.** The legacy `Game` scene plays Classic only. | `scripts/game/game.gd` | None | The new campaign runs on the v2 GameScreen only; activating v2 stays an owner decision. |

## Risks

- Positioned gates make levels harder to author; the binding-gate and solver checks catch dead
  or decorative gates, not boring ones. Human playtests remain the gate for fun.
- Recesses on two edges meeting at a corner would make the frame look broken; the grammar
  forbids gates meeting at a corner.
- Pre-baked frame textures must be rebuilt on resize / safe-area change.

## Not affected

Classic level data, `rules.gd`, scoring, `ProgressStore` and its save formats, the
`gameplay/engine` flag (stays `legacy`).
