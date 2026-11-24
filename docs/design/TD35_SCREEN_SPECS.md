# TD-3.5 Screen specifications
## A. Gameplay (P0; implement FIRST)
Goal: recognizable, touch-safe, premium puzzle board; affordances prioritize actual play.

Hierarchy: safe topbar [Back/Menu | chapter/level | Undo | Restart] → level goal/short tutorial bubble (dismissible) → centered board → small move counter / optional progress bottom strip. DEV diagnostic only when `DevAccess.enabled()`, never overlapping a gate or bottom gesture inset.

- Content container is adaptive; measures the usable viewport AFTER SafeArea and HUD height. Center the board in that container. Use equal cell widths/heights.
- Portrait phone with short board: board must not sit at bottom leaving enormous dead space. Tall narrow board: constrain to usable height and scale proportionally. Test `5x1`, `1x5`, `5x5`, `6x7`, `9x9` visual fixtures.
- Exact outward exit portals: integrated recess in frame at `side/lo/hi`; an optional arrow points outward; show accept color and blocked/no-fit state truthfully. If two differently colored gates overlap span, separate visual markings/stacked stripes; don't paint a fake wider opening.
- Multi-cell silhouette must correspond exactly to `cells[]` for L/T/S/Z/bar/square/custom, including concavities. Rendering doesn't create a phantom bridge or fill a hole.
- Interaction: `BoardViewV2` sends intention only; `PuzzleSessionV2` commits action. One gesture = one engine action. A straight EXIT can start from interior. Choose a tested exit threshold to avoid unwanted exits. Preserve separate last-cell MOVE and EXIT affordances, including Android edge gesture zones.
- Undo/restart must restore exact logical state and visuals; during exit animation input is locked and board does not double-commit. Menu always reachable.
- Ingame status copy examples: `Level 4`, `Moves 2`, `Slide to the matching exit`. Do not show `solver SOLVED` in player mode.
- Loading/invalid pilot definition: diagnostic screen in dev mode, not a broken board.

## B. Main Menu (P1)
Top 18–22%: branded, short working title and optionally `Slide & Exit` subtitle. Working name **Block Puzzle** is NOT approved trademark/launch brand. Center: miniature stylized puzzle-board illustration using a mock showcase only (not fake gameplay preview). Bottom 25–30%: prominent **Play** CTA, **Levels** and **Settings** secondary buttons, safe area respected. Visual details: subtle pearl gradient, small corner pieces/leaves where tasteful. Avoid large obstructive gold/crown ornaments on narrow phones. `Play` launches currently approved existing campaign; separate developer-only `v2 Pilot` remains clearly QA-gated until product signoff.

## C. Level Complete (P1)
Use native modal/scene above completed board, responsive safe layout: `Level Complete!`, soft celebratory effect, action `Next` / `Retry` or `Replay` as the actual session allows. Three-star graphic may be **decorative placeholder only** unless it is bound to a real implemented scoring feature. Do not render fabricated gold, `Best 7`, or score value. Integrate with current win pipeline without duplicate completion grants. Buttons >=48dp touch, clear return path and no clipped overlays.

## D. Supporting (P2)
Level selection and settings must be visually consistent (colors, buttons, cards) but should not undergo unrelated feature work. Pause overlay, confirmation dialog, tutorial bubble follow tokens. Editor/dev surfaces remain utilitarian and separate.

## Responsive visual snapshots / evidence matrix
- 360x800, 390x844, 412x915, 360x780 with simulated notch/insets, 720x1280, 1344x2992, landscape for graceful warning if portrait-only.
- Capture same deterministic sample levels: single-row bar, tall column, L/T/S and cluttered multi-piece stage.
- For each screenshot capture original reference viewport, screenshot path, build SHA, device vs emulator vs synthetic and compare side-by-side with art direction.
- Explicit checks: board centered, no dead half-screen, no text touching system bars, no popup over gate, correct color, no unreachable controls.

## Scope/progression
First deliver Gameplay P0 and show screenshots + gesture video; then finish menu/completion. Do not claim TD-3.5 complete from a static mock or headless test.
