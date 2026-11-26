# Asset inventory and production rules
All `assets/design/td35/` sources below are original edit-ready SVG concepts; they do not form an entire polished production texture pack by themselves. Rendered concept-art PNGs from the visual discussion are **not in this GitHub branch** and should be attached separately for manual comparison.

| Asset | Role | Source/target |
|---|---|---|
| `background-pearl.svg` | stretched edge-to-edge soft backdrop (no controls) | fullscreen decorative layer; vector source |
| `button-primary.svg` | visual direction for green Play/Continue | native Godot theme with hover/pressed/disabled states |
| `button-secondary.svg` | navy secondary action | native themed button; dynamic labels |
| `board-frame.svg` | border material/style reference only | **generate frame dynamically**; do NOT overlay a full fixed hole |
| `tile-gloss.svg` | shading/color reference for dynamic pieces | native polygon/shader per true connected silhouette |
| `gate-portal.svg` | glow/arrow style reference | **calculate exact aperture from gate span**, not fixed image |
| `icon-undo.svg`, `icon-restart.svg`, `icon-home.svg`, `star.svg` | static vector accents | Godot SVG import/PNG fallback as appropriate |

## Asset map
- Common SVG `viewBox` is logical, not DPI. Source keeps names and editable gradients; export at 1x/2x/3x as required.
- Do not recreate gameplay as a static PNG. Board, piece bodies, gate span and moves are data driven.
- No font files in this pack; source licensing must be checked independently.
- Original brand name/art needed before store release; working logo text is not final intellectual property clearance.

## Palette variants
Red/blue/green/yellow/orange/purple map to game logic; Godot shader/native draw can recolor `tile-gloss` shading and highlight. Use explicit color mapping from `tokens.json`, not inferred HSV substitution which may make similar colors indistinguishable.

## Production readiness checklist
Vector import actually inspected in Godot, icons readable at 24dp, touch button states implemented, scales pass 360 and 412 portrait, no per-frame new Textures, license record kept for any external assets.
