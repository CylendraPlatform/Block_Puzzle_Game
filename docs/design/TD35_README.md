# TD-3.5 — Premium Playful 3D Design Production Pack
**Status: DESIGN HANDOFF READY — NOT A GODOT IMPLEMENTATION.**  
Base: PR #6 / `feat/td3-geometry-gates-pilot`.  
Target implementation: `feat/td35-premium-playful-visuals`.  
Owner-selected direction: **Premium Playful 3D**: warm pearl/ivory, navy recessed board, vibrant dimensional coherent polyominoes, integrated color-coded apertures, expressive controls, restrained celebration. English-only player UI.

## Start here (in order)
1. `docs/design/TD35_DESIGN_SYSTEM.md` — tokens, UI/layout rules, accessibility.
2. `docs/design/TD35_SCREEN_SPECS.md` — gameplay, main menu, win overlays and responsive constraints.
3. `docs/design/TD35_GODOT_IMPLEMENTATION.md` — precise architecture/asset integration plan.
4. `docs/design/TD35_ART_ASSETS.md` — source/vector asset inventory and export rules.
5. `docs/design/TD35_VISUAL_QA.md` — evidence and acceptance gates.
6. `docs/tasks/TD-3_5_IMPLEMENTATION.md` — bounded coding brief and PR protocol.
7. SVG source under `assets/design/td35/` and design token JSON.

## Relationship to approved concept artwork
Three portrait **concept renders** were approved in conversation: main menu, gameplay, and level complete. They communicate *art direction*, not pixel-perfect game states or logic. The source PNG renderings are not embedded in this GitHub commit; the repository contains implementable tokens and original SVG source components. Provide those three PNGs separately to Cursor for subjective visual comparison when available. Do not claim the PNG mockups are committed.

Art direction is fixed but its decorative details (e.g. crown, coins, three stars, leaves) are NOT authority to build economy, stars, or paid products outside TD-6. No false 'best score' or fake rewards.

## Deliverable state
This pack includes source SVGs, design tokens, screen/build specs, QA matrix and task contract. It contains **no rewritten Godot scenes, no Android APK, and no visual QA signoff**. Cursor/Claude Code implements and tests Godot UI in subsequent commits. Keep existing PR #6 unmerged, and never merge this branch directly into main before resolving its dependency on PR #6.
