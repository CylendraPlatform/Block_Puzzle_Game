# TD-3.5 — Godot engineering blueprint
Target Godot 4.7.2; current pilot code is in `scripts/game/board_view_v2.gd`, `scripts/game/pilot_game.gd`, `scripts/core/puzzle_session_v2.gd`, `scripts/game/pilot_catalog.gd`. Verify paths in repository and resolve differing names by inspection.

## Boundaries
- `PuzzleEngine` + `PuzzleSessionV2`: authoritative state; no renderer rule duplication.
- `BoardViewV2`: draw and preview only, derive geometry from `PuzzleEngine._geometry`, accurate gesture conversion, lock during exit animation.
- `VisualTheme` or `TD35Theme`: token loader, safe color mapping and typography helpers.
- `PieceRenderer`: dynamic single silhouette contour (union of cell outlines), concave safe, bevel and shadow. The current `_silhouette` polygon tracing should be audited for winding/order across L/T/S/Z and concavities. For complicated concave polygons, triangulate / use Geometry2D or an atlas of 9-slice segment tiles; don't rely on a polygon that self-intersects. Verify fixture screenshots.
- `GateRenderer`: dynamic aperture from exact side and interval in grid coordinates, including shared-span distinct-color configurations. Frame should *visually open* rather than overlay a colored bar on a solid wall.
- `HUD`: responsive native controls themed from JSON, with actual SafeArea handling. Reuse small image/vector icons only for decoration.
- `AnimationLayer`: interpolates render transform from committed state/events; touch preview is ephemeral and cannot change authoritative `PuzzleState`.

## Implementation plan (reviewable commits)
**P0a Tokens + layout**: load design tokens, native Godot theme/resources, HUD responsive grouping, centered board rect, dev labels moved away from bottom system gesture strip, 360x800/412x915/cutout captures. No mechanics change.
**P0b Board + geometry**: actual border apertures; connected glossy piece shading; highlight, shadow, feedback; accurate grid and concave shapes; fixture screenshot diff. Keep color ID mapping stable.
**P0c Gesture correctness**: single-drag exit from interior, edge zones, threshold/preview, blocked/invalid case, Undo/Restart and animation input lock. Compare `choose_action` outcomes to legal engine actions.
**P1 Main menu + win modal**: apply visual system across both, reuse actual existing flow; don't add fake rewards.
**P2 Optional polish**: sounds/haptics only with existing opt-in configuration; low-motion and frame-time profiling.

## Specific acceptance tests
1. Every action in representative interactive journey is `PuzzleEngine.legal_actions` action, and session committed state matches expected after MOVE/EXIT, Undo/Restart.
2. Drag distance measured from the selected piece and board scaling; finger can trigger EXIT without leaving safe touch area. One last-cell stop remains possible.
3. For all four exit directions, true match and too-narrow/no-match/blocked are visually distinct and correctly enforced by solver.
4. Screenshots show connected silhouette for L/T/S; no polygon fold-over, no detached seams, no wrong footprint.
5. Auto-layout on tall row, long column and large grids, accurate hit mapping and accessible controls; real Android cutout/gesture test.
6. No regression to v1 and no changes to `levels/`, legacy `progress.save` or TD-4.
7. Render performance assessed in Android scene with real frame times, not headless script FPS. Record frame budget under test hardware, not invented performance claim.

## Integration plan
This visual branch is **derived from PR #6**. Open visual PR with base `feat/td3-geometry-gates-pilot` (stacked PR) while #6 is unmerged. Do not create a misleading PR directly against main with all #6 commits duplicated, do not merge automatically. Update PR base after parent PR merges if owner approves.

## Asset import rules
`assets/design/td35/*.svg` are ORIGINAL vector source/references. Godot may import SVG as texture for static symbols; prefer native Control/button themes for interactive states. Any SVG with filters or gradient features must be verified by actual Godot import; raster-export in deterministic PNG sizes if import is unsupported. Do not commit generated binary raster files without preserving source and checking license. Never use PNG background for a changing dynamic puzzle board.
